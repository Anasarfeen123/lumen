// One result: icon · title / subtitle · badge. The selected row gets the
// hover surface; an armed destructive action turns its subtitle red.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components

Item {
    id: root
    required property var modelData
    required property int index
    property bool selected: false
    property bool armed: false
    signal activated()
    signal hovered()

    height: 48

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.sm
        color: Theme.surfaceHover
        opacity: root.selected ? 1 : mouse.containsMouse ? 0.5 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
    }

    Item {
        id: iconBox
        width: 32; height: 32
        anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }

        IconImage {
            anchors.fill: parent
            visible: (root.modelData.icon ?? "") !== ""
            source: root.modelData.icon ?? ""
            asynchronous: true
        }
        LIcon {
            anchors.centerIn: parent
            visible: (root.modelData.icon ?? "") === "" && (root.modelData.glyph ?? "") !== ""
            icon: root.modelData.glyph ?? ""
            color: root.armed ? Theme.error : Theme.textSecondary
        }
        Text {
            anchors.centerIn: parent
            visible: (root.modelData.emoji ?? "") !== ""
            text: root.modelData.emoji ?? ""
            font.pixelSize: 24
        }
    }

    Column {
        anchors { left: iconBox.right; leftMargin: Theme.space.s3; right: badge.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        spacing: 1
        LText { width: parent.width; role: "bodyStrong"; text: root.modelData.title ?? ""; elide: Text.ElideRight; textFormat: Text.PlainText }
        LText {
            width: parent.width
            visible: text !== ""
            role: "caption"
            color: root.armed ? Theme.error : Theme.textMuted
            text: root.armed ? "Press Enter again to confirm" : (root.modelData.subtitle ?? "")
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }
    }

    LText {
        id: badge
        anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        role: "caption"
        color: Theme.textMuted
        text: root.selected ? (root.modelData.badge ? root.modelData.badge + "  ↵" : "↵") : (root.modelData.badge ?? "")
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
        onPositionChanged: root.hovered()
    }
}
