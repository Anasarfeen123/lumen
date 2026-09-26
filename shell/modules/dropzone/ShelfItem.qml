// A file parked on the shelf. Drag it out into any app (it's offered as a
// file, like dragging from a file manager); × takes it off the shelf. The
// file itself never moves or changes.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    property string path: ""
    readonly property string name: path.replace(/\/+$/, "").replace(/.*\//, "")
    readonly property string ext: name.includes(".") ? name.replace(/.*\./, "").toLowerCase() : ""
    readonly property string glyph: /^(png|jpe?g|gif|webp|svg|heic|avif|bmp)$/.test(ext) ? "image"
                                  : /^(mp4|mkv|webm|mov|avi)$/.test(ext) ? "movie"
                                  : /^(mp3|flac|ogg|opus|wav|m4a)$/.test(ext) ? "music_note"
                                  : /^(zip|tar|gz|zst|xz|7z|rar)$/.test(ext) ? "folder_zip"
                                  : /^(pdf)$/.test(ext) ? "picture_as_pdf"
                                  : ext === "" ? "folder" : "description"
    implicitHeight: 38

    Rectangle {
        id: face
        width: root.width; height: root.height
        radius: Theme.radius.sm
        color: drag.active ? Theme.withAlpha(Theme.accent, 0.18) : hover.hovered ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
        border.width: drag.active ? 1 : 0
        border.color: Theme.withAlpha(Theme.accent, 0.5)

        Drag.active: drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": "file://" + encodeURI(root.path) + "\r\n", "text/plain": root.path })
        Drag.hotSpot.x: 18; Drag.hotSpot.y: 19
        // Moved away by the app it was dropped on: nothing left to hold
        Drag.onDragFinished: action => { if (action === Qt.MoveAction) DropZone.unshelve(root.path); }

        LIcon { id: ico; x: Theme.space.s2; anchors.verticalCenter: parent.verticalCenter; icon: root.glyph; size: 18; color: Theme.textSecondary }
        LText {
            anchors { left: ico.right; leftMargin: Theme.space.s2; right: rm.left; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
            role: "body"; text: root.name; elide: Text.ElideMiddle
        }
        HoverTarget {
            id: rm
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            width: 24; height: 24
            visible: hover.hovered
            onClicked: DropZone.unshelve(root.path)
            LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textMuted }
        }
    }
    HoverHandler { id: hover; cursorShape: Qt.OpenHandCursor }
    DragHandler { id: drag; target: null }
}
