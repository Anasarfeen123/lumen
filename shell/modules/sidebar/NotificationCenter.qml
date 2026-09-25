// Notification centre: header (count · DND · Clear), then history grouped by
// app (most recently active app first), newest first within each group.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Item {
        id: header
        width: parent.width
        height: 32

        LText { anchors.verticalCenter: parent.verticalCenter; role: "title"; text: "Notifications" }

        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s1

            HoverTarget {
                width: 32; height: 32
                highlighted: Notifications.dnd
                onClicked: Notifications.setDnd(!Notifications.dnd)
                LIcon {
                    anchors.centerIn: parent
                    icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    fill: Notifications.dnd ? 1 : 0
                    color: Notifications.dnd ? Theme.accent : Theme.textSecondary
                }
            }
            HoverTarget {
                visible: Notifications.count > 0
                width: clearLabel.implicitWidth + Theme.space.s3 * 2; height: 32
                radius: Theme.radius.sm
                onClicked: Notifications.clearAll()
                LText { id: clearLabel; anchors.centerIn: parent; role: "bodyStrong"; color: Theme.textSecondary; text: "Clear" }
            }
        }
    }

    ListView {
        id: list
        anchors { top: header.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true
        spacing: 0
        model: Notifications.model
        boundsBehavior: Flickable.StopAtBounds

        section.property: "appName"
        section.criteria: ViewSection.FullString
        section.delegate: Item {
            required property string section
            width: ListView.view.width
            height: 28
            LText { anchors { left: parent.left; leftMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                    role: "caption"; color: Theme.textMuted; text: section }
            HoverTarget {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 22; height: 22
                onClicked: Notifications.dismissApp(section)
                LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textMuted }
            }
        }

        delegate: NotificationCard { now: clock.date.getTime() }

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.motion.normal }
                NumberAnimation { property: "x"; from: 24; to: 0; duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.motion.normal * Theme.motion.exitRatio }
                NumberAnimation { property: "x"; to: 48; duration: Theme.motion.normal * Theme.motion.exitRatio; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
            }
        }
        displaced: Transition {
            NumberAnimation { properties: "x,y"; duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
        }
    }

    Column {
        anchors.centerIn: list
        visible: Notifications.count === 0
        spacing: Theme.space.s2
        LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "notifications_off"; size: 28; color: Theme.textMuted }
        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "body"; color: Theme.textMuted; text: "No notifications" }
    }
}
