// A card in the AmazeCC app: an optional icon + title row, then its content.
import QtQuick
import qs.theme
import qs.components

Rectangle {
    id: card
    property string title: ""
    property string icon: ""
    property alias headerRight: right.data
    default property alias body: inner.data
    property real pad: Theme.space.s4
    implicitHeight: (title !== "" ? head.height + Theme.space.s3 : 0) + inner.childrenRect.height + pad * 2
    radius: Theme.radius.lg
    color: Theme.withAlpha(Theme.surfaceElevated, 0.75)
    border.width: 1; border.color: Theme.border

    Item {
        id: head
        visible: card.title !== ""
        x: card.pad; y: card.pad
        width: parent.width - card.pad * 2; height: 24
        Row {
            spacing: Theme.space.s2
            anchors.verticalCenter: parent.verticalCenter
            LIcon { visible: card.icon !== ""; icon: card.icon; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "bodyStrong"; text: card.title; anchors.verticalCenter: parent.verticalCenter }
        }
        Row { id: right; anchors { right: parent.right; verticalCenter: parent.verticalCenter } spacing: Theme.space.s2 }
    }
    Item {
        id: inner
        x: card.pad
        y: card.title !== "" ? head.y + head.height + Theme.space.s3 : card.pad
        width: parent.width - card.pad * 2
        height: childrenRect.height
    }
}
