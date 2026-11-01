pragma Singleton

// Live audio spectrum from cava, for the island's background equalizer.
// cava runs ONLY while something consumes it (`wanted`) — i.e. while music
// plays and the idle island is on screen. ~1 % CPU at 30 fps.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Singleton {
    id: root

    property bool wanted: false
    property bool desktopWanted: false
    property bool barWanted: false       // the bar's media chip equalizer (modules/bar/RibbonChips.qml)   // the wallpaper's bars (modules/background/DesktopVisualizer.qml), its own flag
    property var levels: []          // 0–1, mirrored stereo (symmetric)
    readonly property bool available: cavaCheck.found

    readonly property string configPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-cava.conf"

    // cava config written at runtime (no files outside the runtime dir)
    // (written, never read: no preload, so the first start doesn't try to read a
    // file that isn't there yet; cava waits until it's saved)
    property bool confReady: false
    FileView {
        id: conf
        path: root.configPath
        preload: false
        onSaved: root.confReady = true
        Component.onCompleted: setText(
            "[general]\nframerate = 30\nbars = 16\nautosens = 1\n" +
            "[input]\nmethod = pulse\nsource = auto\n" +
            "[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\n" +
            "ascii_max_range = 100\nbar_delimiter = 59\nframe_delimiter = 10\n" +
            "[smoothing]\nnoise_reduction = 70\n")
    }

    Process {
        id: cavaCheck
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v cava"]
        onExited: code => found = (code === 0)
    }

    SupervisedProcess {
        wanted: (root.wanted || root.desktopWanted || root.barWanted) && root.available && root.confReady && !LowPower.active   // rests on a low battery
        command: ["cava", "-p", root.configPath]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";");
                const out = [];
                for (let i = 0; i < v.length; i++) if (v[i] !== "") out.push(Math.min(1, parseInt(v[i]) / 100));
                root.levels = out;
            }
        }
        onRunningChanged: if (!running) root.levels = []
    }
}
