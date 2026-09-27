pragma Singleton

// The first-run welcome: five short steps (hello · look · phone · Halo · keys)
// shown once, on the first login of the main shell. Finishing or skipping
// writes ~/.local/state/lumen/welcomed, so it never comes back by itself.
// `lumen-shell-ipc welcome show` (or Settings → About) shows it again.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property int step: 0
    readonly property int steps: 5
    readonly property string flag: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/welcomed"

    function show() { step = 0; open = true; Ai.refreshStatus(); Link.refresh(); }
    function next() { if (step < steps - 1) step++; else finish(); }
    function back() { if (step > 0) step--; }
    function go(i) { step = Math.max(0, Math.min(steps - 1, i)); }
    function finish() { close(); Island.system("waving_hand", "Welcome to Lumen", "Tap Super to start"); }
    function skip() { close(); }
    function close() {
        open = false;
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && date -Is > "$1"', "sh", flag]);
    }

    // First login of the real session only (never nested/test, never the Settings app)
    Process {
        running: Persist.automates
        command: ["sh", "-c", '[ -e "$1" ] && echo seen || echo new', "sh", root.flag]
        stdout: StdioCollector { onStreamFinished: if (text.trim() === "new") firstRun.start() }
    }
    Timer { id: firstRun; interval: 2500; onTriggered: root.show() }   // after the desktop has settled

    IpcHandler {
        target: "welcome"
        function show(): void { root.show(); }
        function open(): void { root.show(); }
        function close(): void { root.skip(); }
    }
    IpcHandler {
        target: "welcomeTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function step(n: int): void { if (!root.open) root.show(); root.go(n); }
    }
}
