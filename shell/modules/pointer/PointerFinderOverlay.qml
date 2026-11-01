// The finder's light show (services/PointerFinder.qml): on the screen the
// pointer is on, the screen dims around it and three accent rings close in on it, then it
// all fades. Takes no input; ~1 s.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    // the pointer, in this screen's coordinates (Hyprland's are in logical pixels)
    readonly property real px: PointerFinder.at.x - (monitor?.x ?? 0)
    readonly property real py: PointerFinder.at.y - (monitor?.y ?? 0)
    // (the monitor's size: the window is only full-size while it shows)
    readonly property bool here: px >= 0 && py >= 0 && px < (monitor?.width ?? 0) / (monitor?.scale ?? 1) && py < (monitor?.height ?? 0) / (monitor?.scale ?? 1)
    property bool playing: false
    visible: playing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-pointer-finder"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: PointerFinder
        function onSeqChanged() { if (win.here) { win.playing = true; show.restart(); } }
    }

    // the screen dims, softly clearing around the pointer
    Item {
        id: dim
        anchors.fill: parent
        opacity: 0
        Canvas {
            id: shade
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d"); c.reset();
                const g = c.createRadialGradient(win.px, win.py, 60, win.px, win.py, 260);
                g.addColorStop(0, "rgba(0,0,0,0)");
                g.addColorStop(1, "rgba(0,0,0,0.38)");
                c.fillStyle = g; c.fillRect(0, 0, width, height);
            }
            Connections { target: PointerFinder; function onSeqChanged() { shade.requestPaint(); } }
        }
    }

    // 0 → 1 over the show; each ring takes its own slice of it
    property real t: 0
    Repeater {
        model: 3
        Rectangle {
            id: ring
            required property int index
            // ring i runs from t = 0.14·i to 0.14·i + 0.62
            readonly property real k: Math.max(0, Math.min(1, (win.t - ring.index * 0.14) / 0.62))
            readonly property real s: 1 - 0.88 * (1 - Math.pow(1 - k, 3))          // ease-out: fast in, settles on the pointer
            width: 220 * s; height: width; radius: width / 2
            x: win.px - width / 2; y: win.py - height / 2
            color: "transparent"
            border.width: 3
            border.color: Theme.accent
            opacity: k <= 0 || k >= 1 ? 0 : k < 0.2 ? k / 0.2 * 0.9 : k > 0.7 ? (1 - k) / 0.3 * 0.9 : 0.9
        }
    }

    SequentialAnimation {
        id: show
        ParallelAnimation {
            NumberAnimation { target: dim; property: "opacity"; from: 0; to: 1; duration: 140 }
            NumberAnimation { target: win; property: "t"; from: 0; to: 1; duration: 900 }
        }
        NumberAnimation { target: dim; property: "opacity"; to: 0; duration: 260 }
        ScriptAction { script: { win.playing = false; win.t = 0; } }
    }
}
