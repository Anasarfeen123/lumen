// Shared frame for control-centre detail lists: back · title · optional
// switch, a scrolling list, and an optional footer link.
import QtQuick
import Quickshell
import qs.theme
import qs.components

FocusScope {
    id: root
    property string title: ""
    property bool showSwitch: false
    property bool switchOn: false
    property string footerText: ""
    property alias model: list.model
    property alias delegate: list.delegate
    property string emptyText: ""
    signal back()
    signal switchToggled()
    signal footerActivated()

    implicitHeight: head.height + Theme.space.s2 + listFrame.height + (footer.visible ? footer.height + Theme.space.s2 : 0)
    Keys.onEscapePressed: back()
    Keys.onLeftPressed: back()

    Item {
        id: head
        width: parent.width
        height: 32
        IconButton { id: backButton; icon: "arrow_back"; focus: true; onActivated: root.back() }
        LText { anchors { left: backButton.right; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter } role: "heading"; text: root.title }

        // Switch
        Rectangle {
            visible: root.showSwitch
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 40; height: 22; radius: 11
            color: root.switchOn ? Theme.accent : Theme.surfaceHover
            border.width: 1
            border.color: switchArea.activeFocus ? Theme.accent : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
            Rectangle {
                width: 16; height: 16; radius: 8
                y: 3
                x: root.switchOn ? parent.width - width - 3 : 3
                color: root.switchOn ? Theme.onAccent : Theme.textSecondary
                Behavior on x { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
            }
            MouseArea {
                id: switchArea
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                activeFocusOnTab: true
                onClicked: root.switchToggled()
                Keys.onSpacePressed: root.switchToggled()
                Keys.onReturnPressed: root.switchToggled()
            }
        }
    }

    Rectangle {
        id: listFrame
        anchors { top: head.bottom; topMargin: Theme.space.s2 }
        width: parent.width
        height: Math.min(Math.max(list.contentHeight, 48) + Theme.space.s1 * 2, 300)
        radius: Theme.radius.md
        color: Theme.surfaceElevated
        border.width: 1
        border.color: Theme.border

        ListView {
            id: list
            anchors { fill: parent; margins: Theme.space.s1 }
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            keyNavigationEnabled: true
            activeFocusOnTab: true
        }
        LText {
            anchors.centerIn: parent
            visible: list.count === 0 && root.emptyText !== ""
            role: "body"
            color: Theme.textMuted
            text: root.emptyText
        }
    }

    HoverTarget {
        id: footer
        visible: root.footerText !== ""
        anchors { top: listFrame.bottom; topMargin: Theme.space.s2 }
        width: footerLabel.implicitWidth + Theme.space.s3 * 2
        height: 28
        radius: Theme.radius.sm
        onClicked: root.footerActivated()
        LText { id: footerLabel; anchors.centerIn: parent; role: "bodyStrong"; color: Theme.accent; text: root.footerText }
    }
}
