// Find my laptop's ring (services/FindMy.qml): the whole screen says this laptop
// is lost, with your message and number, over everything, while the alarm plays.
// "I found it" stops the sound (anyone at the laptop can — it's for being
// found); lost mode and the lock stay until you turn them off.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    visible: FindMy.ringing
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-findmy"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.withAlpha(Theme.scrim, 0.86)
        // a slow pulse of colour, so it's seen across a room
        Rectangle {
            anchors.fill: parent
            color: Theme.error
            opacity: 0
            SequentialAnimation on opacity {
                running: win.visible && !Theme.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.22; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.04; duration: 700; easing.type: Easing.InOutQuad }
            }
        }
        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 720)
            spacing: Theme.space.s5
            LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "crisis_alert"; size: 96; fill: 1; color: Theme.onMedia }
            LText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.onMedia
                    font.pixelSize: 46; font.weight: Font.Bold; text: FindMy.fromPhone ? "This laptop is lost" : "Find my laptop" }
            LText { visible: text !== ""; width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.onMedia
                    font.pixelSize: 24; text: FindMy.ringMessage || (FindMy.lost.message ?? "") }
            LText { visible: text !== ""; width: parent.width; horizontalAlignment: Text.AlignHCenter; color: Theme.onMedia
                    font.pixelSize: 34; font.weight: Font.DemiBold; text: (FindMy.lost.phone ?? "") ? "Please call " + FindMy.lost.phone : "" }
            Item { width: 1; height: Theme.space.s4 }
            HoverTarget {
                anchors.horizontalCenter: parent.horizontalCenter
                width: stopLabel.implicitWidth + 64; height: 56; radius: 28
                onClicked: FindMy.stop()
                Rectangle { anchors.fill: parent; radius: 28; color: Theme.onMedia }
                LText { id: stopLabel; anchors.centerIn: parent; color: Theme.scrim; font.pixelSize: 20; font.weight: Font.DemiBold
                        text: FindMy.fromPhone ? "I found it — stop the sound" : "Stop" }
            }
        }
    }
}
