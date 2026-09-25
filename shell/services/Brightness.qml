pragma Singleton

// Screen brightness. The shell owns brightness changes (keybinds call
// `qs ipc call brightness up|down`) so it knows the change was user-initiated
// and can show the island — while hypridle's dimming stays silent.
// Steps are exponential (brightnessctl -e4) and the value exposed is the
// perceived level, so each key press moves the bar by the same amount.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real value: 0          // perceived 0–1
    property bool available: false
    property var pending: null

    signal changedByUser()

    readonly property real exponent: 4

    function parse(line, fromUser) {
        // brightnessctl -m: device,class,current,percent,max
        const f = line.trim().split("\n").pop().split(",");
        if (f.length < 5) return;
        const cur = parseInt(f[2]), max = parseInt(f[4]);
        if (!(max > 0)) return;
        available = true;
        value = Math.pow(cur / max, 1 / exponent);
        if (fromUser) changedByUser();
    }

    // notify: show the island afterwards (keys yes, slider drags no)
    function run(args, notify) {
        const job = { cmd: ["brightnessctl", "-m", "-e" + exponent, "-n2"].concat(args), notify: notify };
        if (proc.running) { pending = job; return; }   // key repeat / drag: coalesce
        proc.launch(job);
    }

    function up() { run(["set", "5%+"], true); }
    function down() { run(["set", "5%-"], true); }
    // v is the perceived level (0–1); with -e4, "N%" is on the same curve
    function set(v) {
        value = Math.max(0.01, Math.min(1, v));
        run(["set", Math.round(value * 100) + "%"], false);
    }

    Process {
        id: proc
        property bool notify: true
        function launch(job) { notify = job.notify; command = job.cmd; running = true; }
        stdout: StdioCollector { onStreamFinished: root.parse(text, proc.notify) }
        onExited: {
            if (root.pending) {
                const job = root.pending;
                root.pending = null;
                launch(job);
            }
        }
    }

    // Initial read (no island)
    Process {
        running: true
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector { onStreamFinished: root.parse(text, false) }
    }
}
