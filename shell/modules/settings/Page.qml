// A settings page: large title, optional subtitle, then groups stacked with
// consistent rhythm. Scrolls when taller than the window.
import QtQuick
import qs.theme
import qs.components

Flickable {
    id: root
    property string title: ""
    property string subtitle: ""
    default property alias content: col.data

    contentHeight: col.implicitHeight + Theme.space.s8 * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: col
        x: Theme.space.s8
        y: Theme.space.s8
        width: root.width - Theme.space.s8 * 2
        spacing: Theme.space.s5

        Column {
            width: parent.width
            spacing: Theme.space.s1
            LText { role: "title"; font.pixelSize: 26; text: root.title }
            LText { visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; color: Theme.textSecondary; text: root.subtitle }
        }
    }
}
