// The sidebar's tab switcher: a recessed track with a raised pill that
// glides to the chosen tab. The Notifications tab carries an unread count.
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    readonly property var tabs: [
        { id: "controls", icon: "tune", label: "Controls" },
        { id: "notifications", icon: "notifications", label: "Notifications" },
    ]
    readonly property int current: Sidebar.tab === "notifications" ? 1 : 0

    height: 40
    radius: height / 2
    color: Theme.withAlpha(Theme.bg, 0.45)
    border.width: 1
    border.color: Theme.border

    // Raised pill under the current tab
    Rectangle {
        id: pill
        y: 4
        height: parent.height - 8
        width: (root.width - 8) / 2
        x: 4 + root.current * width
        radius: height / 2
        color: Theme.surfaceHover
        border.width: 1
        border.color: Theme.withAlpha(Theme.text, 0.08)
        Behavior on x { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        // A hairline of accent light along the top edge
        Rectangle {
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 1 }
            width: parent.width * 0.4; height: 1
            color: Theme.withAlpha(Theme.accent, 0.5)
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 4
        Repeater {
            model: root.tabs
            delegate: MouseArea {
                required property var modelData
                required property int index
                readonly property bool on: root.current === index
                width: (root.width - 8) / 2
                height: parent.height
                cursorShape: Qt.PointingHandCursor
                onClicked: Sidebar.tab = modelData.id

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.space.s2
                    LIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: modelData.icon
                        size: 18
                        fill: on ? 1 : 0
                        color: on ? Theme.accent : Theme.textMuted
                        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                    }
                    LText {
                        anchors.verticalCenter: parent.verticalCenter
                        role: "bodyStrong"
                        color: on ? Theme.text : Theme.textMuted
                        text: modelData.label
                        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                    }
                    // Unread count
                    Rectangle {
                        visible: modelData.id === "notifications" && Notifications.count > 0
                        anchors.verticalCenter: parent.verticalCenter
                        height: 18
                        width: Math.max(18, countLabel.implicitWidth + 10)
                        radius: 9
                        color: Notifications.dnd ? Theme.surfaceHover : Theme.accent
                        LText {
                            id: countLabel
                            anchors.centerIn: parent
                            role: "caption"
                            color: Notifications.dnd ? Theme.textSecondary : Theme.onAccent
                            text: Notifications.count > 99 ? "99+" : Notifications.count
                        }
                    }
                }
            }
        }
    }
}
