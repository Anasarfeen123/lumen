// A card of related rows. Rows are separated by hairlines automatically.
import QtQuick
import qs.theme
import qs.components

Column {
    id: root
    property string title: ""
    default property alias rows: body.data
    width: parent ? parent.width : 400
    spacing: Theme.space.s2

    LText {
        visible: root.title !== ""
        leftPadding: Theme.space.s1
        role: "caption"
        color: Theme.textMuted
        text: root.title.toUpperCase()
        font.letterSpacing: 0.8
    }
    Rectangle {
        width: parent.width
        height: body.implicitHeight
        radius: Theme.radius.md
        color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
        border.width: 1
        border.color: Theme.border
        Column {
            id: body
            width: parent.width
        }
    }
}
