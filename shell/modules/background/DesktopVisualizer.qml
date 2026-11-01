// Music on the wallpaper (Settings → Appearance → Desktop): cava's bars, faint
// and in the accent, along the bottom of the screen while something plays —
// only on an empty workspace (cava stops when windows would cover them).
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool empty: (monitor?.activeWorkspace?.toplevels?.values?.length ?? 1) === 0
    readonly property bool active: (Persist.data.desktopVisualizer ?? false) && Media.playing && empty && !Lock.locked
    Binding { target: Visualizer; property: "desktopWanted"; value: true; when: win.active }
    visible: active || bars.opacity > 0
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 220
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-desktop-visualizer"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Row {
        id: bars
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 24 }
        height: parent.height - 24
        spacing: 6
        opacity: win.active && Visualizer.levels.length ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }
        readonly property int n: Math.max(1, Visualizer.levels.length)
        Repeater {
            model: Visualizer.levels.length
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: (bars.width - bars.spacing * (bars.n - 1)) / bars.n
                height: Math.max(4, (Visualizer.levels[index] ?? 0) * bars.height)
                radius: Math.min(width / 2, 10)
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.accent }
                    GradientStop { position: 1; color: Theme.withAlpha(Theme.accent, 0.15) }
                }
                Behavior on height { NumberAnimation { duration: 90 } }
            }
        }
    }
}
