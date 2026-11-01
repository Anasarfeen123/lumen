// Live captions on screen (services/Captions.qml): a dark rounded strip near
// the bottom, the last two lines, the newest bright. Clicks pass through.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool mine: Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Captions.on && mine
    visible: showing
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 160
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-captions"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        width: Math.min(win.width * 0.7, Math.max(260, col.implicitWidth + 40))
        height: col.implicitHeight + 24
        radius: 14
        color: Theme.withAlpha(Theme.scrim, 0.72)
        opacity: Captions.lines.length || !Captions.ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }
        Behavior on height { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Column {
            id: col
            anchors.centerIn: parent
            width: Math.min(win.width * 0.7 - 40, implicitWidth)
            spacing: 4
            Repeater {
                model: Captions.ready ? Captions.lines.slice(-2) : ["Live captions — getting ready…"]
                Text {
                    required property string modelData
                    required property int index
                    width: Math.min(implicitWidth, win.width * 0.7 - 40)
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: modelData
                    color: Theme.onMedia
                    opacity: index === Math.min(1, Captions.lines.length - 1) || !Captions.ready ? 1 : 0.6
                    font.family: Theme.fontUi; font.pixelSize: 22; font.weight: Font.Medium
                }
            }
        }
    }
}
