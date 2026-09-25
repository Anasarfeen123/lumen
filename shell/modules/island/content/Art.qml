// Album art with a quiet fallback glyph.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components

ClippingRectangle {
    id: root
    property string source: ""
    property real size: 20
    width: size; height: size
    radius: size > 40 ? Theme.radius.md : Theme.radius.xs
    color: Theme.surfaceElevated

    LIcon { anchors.centerIn: parent; visible: img.status !== Image.Ready; icon: "music_note"; size: root.size * 0.55; color: Theme.textMuted }
    Image {
        id: img
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    }
}
