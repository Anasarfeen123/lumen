// Right-hand status pill. Shows only what is useful right now (DESIGN.md §0):
//   Wi-Fi                  always (it's the one you glance at)
//   Bluetooth              only while a device is connected
//   Speaker / mic muted    only while muted
//   Battery                icon + %, coloured only when low/critical
//   Unread notifications  a small accent dot (opens the notification centre)
// Scroll adjusts volume. Click opens the sidebar.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

GlassSurface {
    id: root
    required property var window

    implicitWidth: row.implicitWidth + Theme.space.s2 * 2
    implicitHeight: Theme.barHeight
    Behavior on implicitWidth { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        Tray { id: tray; window: root.window; anchors.verticalCenter: parent.verticalCenter }

        // Hairline between app tray and system status
        Rectangle {
            visible: tray.visible
            width: 1; height: 14
            color: Theme.border
            anchors.verticalCenter: parent.verticalCenter
        }

        HoverTarget {
            id: sys
            width: sysRow.implicitWidth + Theme.space.s3 * 2
            height: Theme.barHeight - 8
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Sidebar.toggle(Notifications.count > 0 && mouseX < Theme.space.s3 + 10 ? "notifications" : "controls")
            onWheel: wheel => Audio.nudge(wheel.angleDelta.y > 0 ? 0.05 : -0.05)

            Row {
                id: sysRow
                anchors.centerIn: parent
                spacing: Theme.space.s2

                Rectangle {
                    visible: Notifications.count > 0
                    width: 6; height: 6; radius: 3
                    color: Notifications.dnd ? Theme.textMuted : Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                LIcon {
                    icon: Network.icon
                    size: Theme.size.iconSmall
                    color: Network.connected ? Theme.textSecondary : Theme.textMuted
                }
                LIcon {
                    visible: Bluetooth.hasConnection
                    icon: Bluetooth.icon
                    size: Theme.size.iconSmall
                }
                LIcon {
                    visible: Audio.ready && Audio.muted
                    icon: "volume_off"
                    size: Theme.size.iconSmall
                    color: Theme.textMuted
                }
                LIcon {
                    visible: Audio.micMuted
                    icon: "mic_off"
                    size: Theme.size.iconSmall
                    color: Theme.textMuted
                }
                Row {
                    visible: Battery.available
                    spacing: 2
                    readonly property color tone: Battery.critical ? Theme.error
                                                : Battery.low ? Theme.warning
                                                : Battery.charging ? Theme.success : Theme.textSecondary
                    LIcon {
                        icon: Battery.icon
                        size: Theme.size.iconSmall
                        rotation: 90
                        fill: 1
                        color: parent.tone
                    }
                    LText {
                        role: "bodyStrong"
                        text: Math.round(Battery.percentage * 100) + "%"
                        color: parent.tone === Theme.textSecondary ? Theme.text : parent.tone
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
