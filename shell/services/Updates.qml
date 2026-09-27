pragma Singleton
// Update centre. The shell owns it (so closing Settings never interrupts an
// upgrade); Settings → Updates is a view of runtime state + IPC buttons.
//   check     scripts/updates.sh check (as you) — every 6 h in a real session
//   install   system packages via pkexec scripts/update-admin.sh (your
//             password, every time), then Flatpak apps
// State for viewers: $XDG_RUNTIME_DIR/lumen-updates.json
//
// Lumen itself (scripts/lumen-self-update.sh): checked once a day here, in the
// main shell, if "Check for Lumen updates daily" is on; the island says so
// once per new version. Settings → Updates runs check / apply itself and
// watches $XDG_RUNTIME_DIR/lumen-self-update.json.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property var dnf: []
    property var flatpak: []
    property bool reboot: false
    property bool checking: false
    property bool installing: false
    property string phase: ""              // "", "system", "apps", "done", "failed"
    property var lines: []
    property real checkedAt: 0
    property string error: ""
    readonly property int count: dnf.length + flatpak.length
    readonly property int security: dnf.filter(p => p.security).length
    property int announced: -1

    readonly property string stateFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-updates.json"
    function publish() {
        state.setText(JSON.stringify({ dnf, flatpak, reboot, checking, installing, phase, lines: lines.slice(-14), checkedAt, error, count, security }));
    }
    FileView { id: state; path: root.stateFile; blockWrites: false; printErrors: false }

    function check() {
        if (checking || installing) return;
        checking = true; error = ""; publish();
        checkProc.running = true;
    }
    Process {
        id: checkProc
        command: [Theme.lumenRoot + "/scripts/updates.sh", "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                try {
                    const d = JSON.parse(text);
                    if (d.error) root.error = d.error;
                    else { root.dnf = d.dnf; root.flatpak = d.flatpak; root.reboot = d.reboot; root.checkedAt = Date.now(); }
                } catch (e) { root.error = "Couldn't check for updates"; }
                root.publish();
                // Tell once per new batch (never while gaming or sleeping)
                if (Persist.automates && root.count > 0 && root.count !== root.announced && !["game", "sleep"].includes(Focus.mode)) {
                    root.announced = root.count;
                    Island.system("system_update", root.count + (root.count === 1 ? " update" : " updates") + " available",
                                  root.security > 0 ? root.security + " security · Settings → Updates" : "Settings → Updates");
                }
            }
        }
    }
    Timer { interval: 6 * 3600 * 1000; running: Persist.automates; repeat: true; onTriggered: root.check() }
    Timer { interval: 90 * 1000; running: Persist.automates; onTriggered: root.check() }      // shortly after login

    function log(l) { if (l.trim()) { lines = lines.concat([l]).slice(-200); publish(); } }
    function install() {
        if (installing || count === 0) return;
        installing = true; lines = []; error = "";
        if (dnf.length > 0) { phase = "system"; publish(); sysProc.running = true; }
        else startApps();
    }
    function startApps() {
        if (flatpak.length > 0) { phase = "apps"; publish(); appProc.running = true; }
        else finish(true);
    }
    function finish(ok) {
        installing = false;
        phase = ok ? "done" : "failed";
        publish();
        Island.system(ok ? "task_alt" : "error", ok ? "Updates installed" : "Update stopped",
                      ok ? (reboot ? "Restart to finish" : "You're up to date") : "See Settings → Updates", ok ? "normal" : "error");
        check();
    }
    Process {
        id: sysProc
        command: ["pkexec", Theme.lumenRoot + "/scripts/update-admin.sh", "upgrade"]
        stdout: SplitParser { onRead: l => root.log(l) }
        stderr: SplitParser { onRead: l => root.log(l) }
        onExited: code => {
            if (code === 0) root.startApps();
            else { root.error = code === 126 || code === 127 ? "Cancelled — no password given" : "System update failed (exit " + code + ")"; root.finish(false); }
        }
    }
    Process {
        id: appProc
        command: [Theme.lumenRoot + "/scripts/updates.sh", "flatpak"]
        stdout: SplitParser { onRead: l => root.log(l) }
        stderr: SplitParser { onRead: l => root.log(l) }
        onExited: code => { if (code !== 0) root.error = "Flatpak update failed (exit " + code + ")"; root.finish(code === 0); }
    }

    // ── Lumen itself ──
    // The checkout to update: this Lumen, or (LUMEN_DEV only) a test clone
    readonly property string lumenRepo: Quickshell.env("LUMEN_DEV") === "1" && Quickshell.env("LUMEN_UPDATE_ROOT") ? Quickshell.env("LUMEN_UPDATE_ROOT") : Theme.lumenRoot
    readonly property string selfUpdate: Theme.lumenRoot + "/scripts/lumen-self-update.sh"
    property var lumen: ({})                // the script's last report
    property var lumenPrefs: ({ daily: true, announced: "" })
    readonly property int lumenBehind: lumen.behind ?? 0
    function lumenRun(mode) { return { command: [selfUpdate, mode], environment: { LUMEN_ROOT: lumenRepo } }; }
    function checkLumen() {
        if (lumenCheck.running) return;
        lumenCheck.exec(lumenRun("check"));
    }
    Process {
        id: lumenPrefsProc
        running: Persist.automates
        command: [root.selfUpdate, "settings"]
        stdout: StdioCollector { onStreamFinished: { try { root.lumenPrefs = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: lumenCheck
        stdout: StdioCollector {
            onStreamFinished: {
                const last = text.trim().split("\n").pop();
                try { root.lumen = JSON.parse(last); } catch (e) { return; }
                const sha = root.lumen.remoteSha ?? "";
                if (Persist.automates && root.lumenBehind > 0 && sha && sha !== root.lumenPrefs.announced && !["game", "sleep"].includes(Focus.mode)) {
                    root.lumenPrefs = Object.assign({}, root.lumenPrefs, { announced: sha });
                    Quickshell.execDetached([root.selfUpdate, "announced", sha]);
                    Island.system("auto_awesome", "Lumen update available · " + root.lumenBehind + (root.lumenBehind === 1 ? " change" : " changes"), "Settings → Updates");
                }
            }
        }
    }
    // Once a day (first check a few minutes after login), only when you asked for it
    Timer { interval: 24 * 3600 * 1000; running: Persist.automates && (root.lumenPrefs.daily ?? true); repeat: true; onTriggered: root.checkLumen() }
    Timer { interval: 4 * 60 * 1000; running: Persist.automates && (root.lumenPrefs.daily ?? true); onTriggered: root.checkLumen() }

    IpcHandler {
        target: "updates"
        function lumenCheck(): void { root.checkLumen(); }
        function check(): void { root.check(); }
        function install(): void { root.install(); }
        function count(): int { return root.count; }
    }
}
