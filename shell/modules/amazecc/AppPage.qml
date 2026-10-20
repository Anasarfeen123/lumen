// A page of the AmazeCC app: a title and line, then content that scrolls.
import QtQuick
import QtQuick.Controls.Basic as QQC
import qs.theme
import qs.components

Flickable {
    id: root
    property string title: ""
    property string subtitle: ""
    property alias headerRight: right.data
    default property alias content: col.data
    contentHeight: col.y + col.implicitHeight + Theme.space.s8
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    QQC.ScrollBar.vertical: QQC.ScrollBar { policy: root.contentHeight > root.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff }

    Item {
        id: head
        x: Theme.space.s8; y: Theme.space.s8
        width: root.width - Theme.space.s8 * 2; height: titleCol.height
        Column {
            id: titleCol
            width: parent.width - right.width - Theme.space.s3
            spacing: 2
            LText { role: "title"; font.pixelSize: 28; text: root.title }
            LText { visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; color: Theme.textSecondary; text: root.subtitle }
        }
        Row { id: right; anchors { right: parent.right; verticalCenter: titleCol.verticalCenter } spacing: Theme.space.s2 }
    }
    Column {
        id: col
        x: Theme.space.s8
        y: head.y + head.height + Theme.space.s5
        width: root.width - Theme.space.s8 * 2
        spacing: Theme.space.s4
    }
}
