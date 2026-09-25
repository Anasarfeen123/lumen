pragma Singleton

// Screen lock state + authentication (password and face).
//
// Security model
//   • The lock is a Wayland ext-session-lock (modules/lock). If the shell dies
//     while locked, the compositor keeps the session locked — it never falls
//     open. `misc:allow_session_lock_restore` lets a restarted shell re-lock.
//   • Unlocking happens ONLY on PamResult.Success, from either path.
//   • The password lives in memory only until PAM asks for it, then is cleared.
//
// Two independent PAM conversations
//   password  service "hyprlock"        — typed password (Fedora: includes `login`)
//   face      service "hyprlock-gaze"   — pam_gaze (Gaze), then the password stack.
//             We stop it the moment it falls through to asking for a password,
//             so a face miss never counts as a password failure.
//
// When the camera runs (so a manual lock doesn't instantly unlock itself while
// you are still sitting there — Gaze's own troubleshooting note):
//   On AC power (automatic)
//     • on intent: a key press or pointer movement on the lock screen
//     • on wake from sleep (`lumen … ipc call lock wake`, from hypridle)
//     • not during the first `faceGraceMs` after locking
//   On battery (the camera costs power, and you may be on the move)
//     • ONLY when you press F2 on the lock screen
//   Always: at most once per `faceCooldownMs`; typing a password cancels a scan
//
// Lock-in / unlock transitions (LockSurface) use a snapshot of each output
// taken just before locking (scripts/lock-snapshot.sh → $XDG_RUNTIME_DIR,
// 0700). It is deleted as soon as the unlock animation finishes.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import Quickshell.Services.UPower
import qs.theme

Singleton {
    id: root

    property bool locked: false
    property string text: ""
    property string status: "idle"      // idle | checking | failed | success
    property string message: ""
    property int failures: 0
    property date lockedAt: new Date()

    // Face unlock
    property bool faceReady: false      // Gaze installed, daemon up, a face enrolled
    property string faceStatus: "off"   // off | ready | scanning | failed | matched
    readonly property int faceGraceMs: 2500
    readonly property int faceCooldownMs: 2500
    property real lastFaceAttempt: 0
    property string faceHint: ""        // last message from Gaze during a scan

    // Transitions
    readonly property int unlockAnimMs: 560
    // One folder per Hyprland instance, so parallel sessions never share snapshots
    readonly property string snapshotDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-lock/"
                                          + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "default")
    property bool snapshotReady: false
    property int snapshotVersion: 0

    signal failed()

    // "Locked" marker: if the shell restarts or crashes while locked, the new
    // instance locks again at once (Hyprland's allow_session_lock_restore lets
    // it take over the still-locked session instead of showing the red screen).
    readonly property string marker: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-locked-"
                                     + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "default")
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: code => { if (code === 0) root.engage(); }
    }

    // ── Locking ──────────────────────────────────────────────────────────────
    function lock() {
        if (locked || snapshotter.running) return;
        // Nothing else should hold the keyboard or show over the lock
        Overview.hide();
        Sidebar.hide();
        Session.menuOpen = false;
        Island.unpin();
        // Snapshot first (≤ 400 ms), so the desktop can visibly dissolve into
        // the lock screen; lock regardless if it fails or is slow.
        snapshotReady = false;
        snapshotter.running = true;
        snapshotTimeout.restart();
    }

    function engage() {
        if (locked) return;
        snapshotTimeout.stop();
        text = "";
        status = "idle";
        message = "";
        failures = 0;
        faceStatus = "off";
        lockedAt = new Date();
        locked = true;
        Quickshell.execDetached(["touch", marker]);
        Sounds.play("lock");
        faceProbe.running = true;
    }

    Process {
        id: snapshotter
        command: [Theme.lumenRoot + "/scripts/lock-snapshot.sh", "take", root.snapshotDir]
        onExited: code => {
            root.snapshotReady = code === 0;
            root.snapshotVersion++;
            root.engage();
        }
    }
    Timer { id: snapshotTimeout; interval: 400; onTriggered: root.engage() }

    // ── Password ─────────────────────────────────────────────────────────────
    // pw is handed over at submit time; it is held here only until PAM asks.
    function submit(pw) {
        if (!locked || status === "checking" || status === "success" || pw === "") return;
        if (face.active) face.abort();
        if (faceStatus === "scanning") faceStatus = faceReady ? "ready" : "off";
        text = pw;
        status = "checking";
        message = "";
        pam.start();
    }

    PamContext {
        id: pam
        config: "hyprlock"

        onPamMessage: {
            if (responseRequired) {
                respond(root.text);
                root.text = "";
            } else if (message !== "") {
                root.message = message;
            }
        }

        onCompleted: result => {
            root.text = "";
            if (result === PamResult.Success) {
                root.succeed();
            } else {
                root.failures++;
                root.status = "failed";
                root.message = result === PamResult.MaxTries ? "Too many attempts — wait a moment"
                                                            : "Incorrect password";
                root.failed();
            }
        }

        onError: {
            root.text = "";
            root.status = "failed";
            root.message = "Authentication unavailable — try again";
            root.failed();
        }
    }

    // ── Face ─────────────────────────────────────────────────────────────────
    // Availability: the PAM service exists, gazed is running, and this user
    // has at least one enrolled face. Checked each time the screen locks.
    Process {
        id: faceProbe
        command: ["sh", "-c", "test -r /etc/pam.d/hyprlock-gaze && systemctl is-active -q gazed && gaze list-faces 2>/dev/null | grep -q 'RGB'"]
        onExited: code => {
            root.faceReady = code === 0;
            if (root.locked && root.faceStatus === "off" && root.faceReady) root.faceStatus = "ready";
        }
    }

    // Automatic face scans only on AC power; on battery, F2 asks for one
    readonly property bool autoFace: !UPower.onBattery

    // Called by the lock surface on key press / pointer movement
    function intent() { if (autoFace) tryFace(false); }
    // Called after resume from sleep: you are opening the lid — look and go
    function wake() { if (autoFace) tryFace(true); }
    // F2 on the lock screen: scan now, on any power source
    function requestFace() { tryFace(true); }

    function tryFace(ignoreGrace) {
        if (!locked || !faceReady || status === "checking" || status === "success") return;
        if (faceStatus !== "ready" && faceStatus !== "failed") return;
        const now = Date.now();
        if (!ignoreGrace && now - lockedAt.getTime() < faceGraceMs) return;
        if (now - lastFaceAttempt < faceCooldownMs) return;
        lastFaceAttempt = now;
        faceStatus = "scanning";
        message = "";
        faceHint = "";
        face.start();
    }

    PamContext {
        id: face
        config: "hyprlock-gaze"

        onPamMessage: {
            if (responseRequired) {
                // pam_gaze gave up and the stack now wants a password: this
                // conversation is done. The password path is separate.
                abort();
                root.faceMissed();
            } else if (message !== "") {
                // Gaze's own guidance ("Please look at the camera", "Face
                // matched, but the liveness check did not pass…")
                root.faceHint = message;
            }
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.faceStatus = "matched";
                root.succeed();
            } else {
                root.faceMissed();
            }
        }
        onError: root.faceMissed()
    }

    function faceMissed() {
        if (faceStatus !== "scanning") return;
        faceStatus = "failed";
        if (status === "checking") return;
        // Say why, in plain words, using what Gaze reported
        const h = faceHint.toLowerCase();
        message = h.includes("liveness") ? "Recognised you, but the camera couldn't confirm it's live — more light helps, or type your password"
                : h.includes("dark") || h.includes("light") ? "Too dark for Face ID — type your password"
                : "Face not recognised — " + (autoFace ? "look at the camera" : "press F2 to try again") + ", or type your password";
    }

    // ── Success → unlock ─────────────────────────────────────────────────────
    function succeed() {
        Sounds.play("unlock");
        status = "success";
        message = "";
        if (face.active) face.abort();
        unlockDelay.restart();           // the surface plays the unlock film meanwhile
    }

    Timer {
        id: unlockDelay
        interval: root.unlockAnimMs
        onTriggered: {
            root.locked = false;
            root.status = "idle";
            root.faceStatus = "off";
            Quickshell.execDetached(["rm", "-f", root.marker]);
            cleanup.restart();
        }
    }
    // Remove the snapshot once the real desktop is back on screen
    Timer {
        id: cleanup
        interval: 300
        onTriggered: Quickshell.execDetached([Theme.lumenRoot + "/scripts/lock-snapshot.sh", "clear", root.snapshotDir])
    }
}
