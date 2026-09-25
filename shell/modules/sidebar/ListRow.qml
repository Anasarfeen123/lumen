// One row in a detail list: icon · title/subtitle · trailing glyph.
import QtQuick
import qs.theme
import qs.components

HoverTarget {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""        // icon name, e.g. "check" or "lock"
    property bool current: false
    default property alias extra: extraSlot.data

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: extraSlot.children.length > 0 && extraSlot.visible ? 44 + extraSlot.height : 44
    radius: Theme.radius.sm
    highlighted: ListView.isCurrentItem && (ListView.view?.activeFocus ?? false)

    Item {
        id: rowContent
        width: parent.width
        height: 44
        LIcon {
            id: lead
            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            icon: root.icon
            fill: root.current ? 1 : 0
            color: root.current ? Theme.accent : Theme.textSecondary
        }
        Column {
            anchors { left: lead.right; leftMargin: Theme.space.s3; right: trail.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            LText { width: parent.width; role: root.current ? "bodyStrong" : "body"; text: root.title; elide: Text.ElideRight }
            LText { width: parent.width; visible: text !== ""; role: "caption"; color: Theme.textMuted; text: root.subtitle; elide: Text.ElideRight }
        }
        LIcon {
            id: trail
            anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            icon: root.trailing
            size: Theme.size.iconSmall
            color: root.current ? Theme.accent : Theme.textMuted
        }
    }
    Item {
        id: extraSlot
        anchors { top: rowContent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
        height: childrenRect.height
    }
}
