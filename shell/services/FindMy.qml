pragma Singleton

// Find my laptop (scripts/findmy.py): the laptop listens on a private, end-to-end
// sealed ntfy channel for your phone's remote (a page Lumen sends it over Lumen
// Link). The script does the networking, sealing, locating and pictures; Lumen
// does what needs the screen:
//   ring    a loud alarm through the laptop's own speakers (not headphones),
//           volume up and unmuted, and a full-screen "this laptop is lost" with
//           your message and number (modules/findmy/RingOverlay.qml) — 3 min, or
//           until stopped from the phone or "I found it" on the laptop
//   lock    the lock screen, with lost mode's card on it (modules/lock)
// Settings → Find my laptop. Main shell only; off until you turn it on.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/findmy.py"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen"
    readonly property bool enabled: Persist.data.findMy ?? false
    readonly property bool runs: enabled && Persist.automates

    property var info: ({ setup: false })
    property string status: ""             // "listening" | "offline" | error text
    function refresh() { run(["info"], r => { if (r.ok) root.info = r; }); }
    Component.onCompleted: refresh()
    onEnabledChanged: refresh()            // (turned on in the Settings app, its own process)

    // lost mode (findmy-lost.json — the script keeps it; the lock screen shows it)
    property var lost: ({ on: false })
    FileView {
        path: root.stateDir + "/findmy-lost.json"
        printErrors: false                 // (no file until lost mode is first used)
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.lost = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: root.lost = { on: false }
    }
    function setLost(on, message, phone) { run(["lost", on ? "on" : "off", message ?? "", phone ?? ""], () => {}); }

    // ── the listener ──
    Process {
        id: daemon
        running: root.runs && root.info.setup
        command: [root.script, "serve"]
        stdout: SplitParser {
            onRead: line => {
                let m; try { m = JSON.parse(line); } catch (e) { return; }
                if (m.event) root.status = m.event === "offline" ? "offline" : m.event;
                if (m.error) root.status = m.error;
                if (m.do === "ring") root.ring(m.message ?? "", true);
                else if (m.do === "stop") root.stop();
                else if (m.do === "lock") Lock.lock();
            }
        }
        onExited: { root.status = "stopped"; if (root.runs) restart.start(); }
    }
    Timer { id: restart; interval: 30000; onTriggered: if (root.runs && root.info.setup) daemon.running = true }

    // ── ringing ──
    property bool ringing: false
    readonly property bool silent: Quickshell.env("LUMEN_NESTED") === "1"     // a test session shares your real speakers
    property string ringMessage: ""
    property bool fromPhone: false
    property string savedVolume: ""        // "sink|volume%|muted" to put back
    function ring(message, remote) {
        ringMessage = message || (lost.message ?? "");
        fromPhone = !!remote;
        if (ringing) return;
        ringing = true;
        // the laptop's own speakers, loud: headphones would hide it
        alarm.command = ["sh", "-c", `
            s=$(pactl list short sinks | awk '$2 ~ /^alsa_output/ {print $2; exit}'); [ -n "$s" ] || s=@DEFAULT_SINK@
            v=$(pactl get-sink-volume "$s" | grep -o '[0-9]*%' | head -1); m=$(pactl get-sink-mute "$s" | awk '{print $2}')
            echo "$s|$v|$m"
            pactl set-sink-mute "$s" 0; pactl set-sink-volume "$s" 100%
            f=/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga; [ -f "$f" ] || f=/usr/share/sounds/freedesktop/stereo/bell.oga
            while :; do paplay --device="$s" "$f"; done`];
        if (!silent) alarm.running = true;
        ringFor.restart();
    }
    function stop() {
        if (!ringing) return;
        ringing = false;
        alarm.running = false;
        ringFor.stop();
        const p = savedVolume.split("|");
        if (p.length === 3 && p[0])
            Quickshell.execDetached(["sh", "-c", 'pactl set-sink-volume "$1" "$2"; [ "$3" = yes ] && pactl set-sink-mute "$1" 1; true', "sh", p[0], p[1] || "60%", p[2]]);
        savedVolume = "";
    }
    Process {
        id: alarm
        stdout: SplitParser { onRead: line => { if (!root.savedVolume && line.includes("|")) root.savedVolume = line.trim(); } }
    }
    Timer { id: ringFor; interval: 180000; onTriggered: root.stop() }

    // ── setup, the phone page ──
    function enable(on) {
        if (!on) { Persist.data.findMy = false; return; }
        run(["setup"], r => { root.info = r; Persist.data.findMy = true; });
    }
    function rotate() { run(["setup", "--rotate"], r => { root.info = r; daemon.running = false; restart.start(); }); }
    // cb(text) lets the Settings app (its own process, whose island isn't on screen) say what happened
    function sendRemote(cb) {
        const say = (icon, title, detail) => { if (cb) cb(title + ". " + detail); else Island.system(icon, title, detail); };
        run(["remote"], r => {
            if (!r.ok) { say("error", "Couldn't make the remote", r.error ?? ""); return; }
            refresh();
            if (Link.available && Link.connected) { Link.sendFiles([r.path]); say("phonelink", "Sent to your phone", "Open it from the phone's downloads, in its browser"); }
            else say("phonelink_off", "Made, but your phone isn't nearby", "Open Lumen Link on the phone (same Wi-Fi) and press Send again, or use Show file and move it over yourself");
        });
    }
    // the file manager, with the remote selected
    function showRemote() {
        Quickshell.execDetached(["sh", "-c", 'f="$1"; gdbus call --session --dest org.freedesktop.FileManager1 --object-path /org/freedesktop/FileManager1 --method org.freedesktop.FileManager1.ShowItems "[\'file://$f\']" "" >/dev/null 2>&1 || dolphin --select "$f" >/dev/null 2>&1 || xdg-open "${f%/*}"', "sh", root.stateDir + "/findmy-remote.html"]);
    }

    function run(args, cb) {
        const p = runner.createObject(root, { cb: cb });
        p.command = [root.script].concat(args);
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: rp
            property var cb: null
            stdout: StdioCollector { onStreamFinished: { let r = {}; try { r = JSON.parse(text); } catch (e) {} if (rp.cb) rp.cb(r); rp.destroy(); } }
        }
    }

    IpcHandler {
        target: "findmy"
        function ring(): void { root.ring("", false); }
        function stop(): void { root.stop(); }
        function state(): string { return JSON.stringify({ enabled: root.enabled, setup: root.info.setup, status: root.status, ringing: root.ringing, lost: root.lost }); }
    }
}
