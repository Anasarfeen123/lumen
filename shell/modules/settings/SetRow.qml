// One setting: icon · title/description · control on the right.
// A hairline separates it from the row above (skipped for the first row).
import QtQuick
import qs.theme
import qs.components

Item {
    id: root
    property string icon: ""
    property string title: ""
    property string description: ""
    default property alias control: slot.data

    width: parent ? parent.width : 400
    implicitHeight: Math.max(56, text.implicitHeight + Theme.space.s4 * 2, slot.childrenRect.height + Theme.space.s3 * 2)

    Rectangle {
        visible: root.parent && root.parent.children[0] !== root
        anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: root.icon !== "" ? 52 : Theme.space.s4 }
        height: 1
        color: Theme.border
    }

    LIcon {
        id: glyph
        visible: root.icon !== ""
        anchors { left: parent.left; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
        icon: root.icon
        color: Theme.textSecondary
    }

    Column {
        id: text
        anchors { left: root.icon !== "" ? glyph.right : parent.left; leftMargin: root.icon !== "" ? Theme.space.s3 : Theme.space.s4
                  right: slot.left; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
        spacing: 2
        LText { width: parent.width; role: "bodyStrong"; text: root.title; wrapMode: Text.WordWrap }
        LText { width: parent.width; visible: text !== ""; role: "caption"; color: Theme.textMuted; text: root.description; wrapMode: Text.WordWrap }
    }

    Item {
        id: slot
        anchors { right: parent.right; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
        width: childrenRect.width
        height: childrenRect.height
    }
}
