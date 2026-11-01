pragma Singleton
// Live captions (scripts/halo-voice.py captions): what your speakers play —
// a video, a call, a lecture — as text near the bottom of the screen, on this
// computer (whisper.cpp). Ctrl+Super+C, "Live captions" in search, or Halo
// "turn on captions". English. Nothing is saved.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool on: false
    property bool ready: false
    property var lines: []              // the last few captions, newest last
    property string error: ""
    function toggle() { on = !on; }
    onOnChanged: { lines = []; error = ""; ready = false; if (on) Island.system("closed_caption", "Live captions on", "Getting ready…"); }

    Process {
        running: root.on
        command: [Theme.lumenRoot + "/scripts/halo-voice.py", "captions"]
        stdout: SplitParser {
            onRead: line => {
                let o = {}; try { o = JSON.parse(line); } catch (e) { return; }
                if (o.error) { root.error = o.error; Island.system("closed_caption_disabled", "No live captions", o.error, "warning"); root.on = false; return; }
                if (o.ready) { root.ready = true; return; }
                if (o.caption) root.lines = root.lines.concat([o.caption]).slice(-3);
                else if (root.lines.length) clearSoon.restart();          // a silence: let the text fade after a bit
            }
        }
    }
    Timer { id: clearSoon; interval: 6000; onTriggered: root.lines = [] }

    GlobalShortcut { appid: "lumen"; name: "captions"; description: "Live captions"; onPressed: root.toggle() }
    IpcHandler { target: "captions"; function toggle(): void { root.toggle(); } function state(): string { return JSON.stringify({ on: root.on, ready: root.ready, lines: root.lines }); } }
}
