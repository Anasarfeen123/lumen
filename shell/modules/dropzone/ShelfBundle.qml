// Drag the entire collection into another app. Every URI is encoded on its
// own, so spaces, Unicode, # and ? remain part of the filename.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitHeight: Theme.space.s8 + Theme.space.s3
    activeFocusOnTab: true
    Keys.onReturnPressed: DropZone.run("copy", DropZone.shelf)
    Keys.onSpacePressed: DropZone.run("copy", DropZone.shelf)
    Accessible.name: "Drag all shelved files, or press Enter to copy them"
    Rectangle {
        anchors.fill: parent; radius: Theme.radius.sm
        color: drag.active ? Theme.withAlpha(Theme.accent, .16) : Theme.surfaceElevated
        border.width: 1; border.color: root.activeFocus ? Theme.accent : Theme.border
        Drag.active: drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": DropZone.shelf.map(p => "file://" + p.split("/").map(encodeURIComponent).join("/")).join("\r\n") + "\r\n" })
        Row {
            anchors.centerIn: parent; spacing: Theme.space.s2
            LIcon { icon: "drag_indicator"; size: Theme.size.heading; color: Theme.textSecondary }
            LText { role: "bodyStrong"; text: "Drag all " + DropZone.shelf.length + " files" }
        }
    }
    HoverHandler { cursorShape: Qt.OpenHandCursor }
    DragHandler { id: drag; target: null; enabled: DropZone.shelf.length > 0 }
}
