import QtQuick
import qs.theme
import qs.components
import qs.services
import qs.modules.dropzone

Item {
    id: root
    Flow {
        id: pins; width: parent.width; spacing: Theme.space.s2
        Repeater {
            model: DesktopTools.defaultFolders.concat(DesktopTools.pinnedFolders)
            ToolButton {
                required property var modelData
                label: modelData.name; glyph: "folder"
                primary: DesktopTools.folder.path === modelData.path
                onClicked: DesktopTools.browse(modelData.path)
            }
        }
    }
    Row {
        id: pathRow
        anchors { top: pins.bottom; topMargin: Theme.space.s3; left: parent.left; right: parent.right }
        spacing: Theme.space.s2
        ToolButton { id: up; glyph: "arrow_upward"; label: ""; Accessible.name: "Parent folder"; enabled: !DesktopTools.browsing; onClicked: DesktopTools.browse(DesktopTools.folder.parent) }
        LField { width: pathRow.width - up.width - pin.width - Theme.space.s2 * 2; height: up.height; text: DesktopTools.folder.path; placeholder: "Folder path"; clearOnAccept: false; onAccepted: value => DesktopTools.browse(value) }
        ToolButton {
            id: pin
            readonly property bool pinned: DesktopTools.pinnedFolders.some(f => f.path === DesktopTools.folder.path)
            glyph: pinned ? "keep_off" : "keep"; label: pinned ? "Unpin" : "Pin"
            onClicked: pinned ? DesktopTools.unpinFolder(DesktopTools.folder.path) : DesktopTools.pinFolder()
        }
    }
    Row {
        id: filters; anchors { top: pathRow.bottom; topMargin: Theme.space.s2; left: parent.left; right: parent.right } spacing: Theme.space.s2
        LField { width: parent.width - hidden.width - refresh.width - Theme.space.s2 * 2; height: hidden.height; icon: "search"; placeholder: "Filter this folder"; text: DesktopTools.folderFilter; input.onTextEdited: DesktopTools.folderFilter = text }
        ToolButton { id: hidden; glyph: "visibility"; label: "Hidden"; primary: DesktopTools.showHidden; onClicked: DesktopTools.showHidden = !DesktopTools.showHidden }
        ToolButton { id: refresh; glyph: "refresh"; label: ""; Accessible.name: "Refresh folder"; enabled: !DesktopTools.browsing; onClicked: DesktopTools.browse(DesktopTools.folder.path) }
    }
    Item {
        anchors { top: filters.bottom; topMargin: Theme.space.s3; left: parent.left; right: parent.right; bottom: footer.top; bottomMargin: Theme.space.s3 }
        ListView {
            id: files
            width: parent.width * .60; height: parent.height
            clip: true; spacing: Theme.space.s1
            model: DesktopTools.folderEntries
            delegate: Item {
                id: file
                required property var modelData
                width: files.width; height: 48
                ToolButton {
                    width: parent.width - shelve.width - Theme.space.s2; height: parent.height
                    Accessible.name: (file.modelData.directory ? "Open folder " : "Open ") + file.modelData.name
                    contentItem: Row {
                        spacing: Theme.space.s2
                        LIcon { anchors.verticalCenter: parent.verticalCenter; icon: file.modelData.directory ? "folder" : file.modelData.link ? "link" : "description"; size: Theme.size.heading; color: Theme.textSecondary }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; width: parent.width - Theme.size.heading - Theme.space.s2
                            LText { width: parent.width; text: file.modelData.name; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                            LText { role: "caption"; color: Theme.textMuted; text: file.modelData.directory ? "Folder" : DesktopTools.size(file.modelData.size) }
                        }
                    }
                    onClicked: file.modelData.directory ? DesktopTools.browse(file.modelData.path) : DesktopTools.openPath(file.modelData.path)
                }
                ToolButton { id: shelve; anchors.right: parent.right; height: parent.height; glyph: "add"; label: ""; Accessible.name: "Add " + file.modelData.name + " to shelf"; onClicked: DropZone.run("shelve", [file.modelData.path]) }
            }
            EmptyState { anchors.centerIn: parent; width: parent.width - Theme.space.s4; visible: files.count === 0; title: DesktopTools.browsing ? "Opening folder…" : "No matching files"; detail: "Choose a folder above or change the filter." }
        }
        Rectangle {
            id: shelf
            anchors { left: files.right; leftMargin: Theme.space.s4; right: parent.right; top: parent.top; bottom: parent.bottom }
            color: Theme.withAlpha(Theme.bg, .35); radius: Theme.radius.md
            DropArea { anchors.fill: parent; onEntered: drag => { if (drag.hasUrls) drag.accept(Qt.CopyAction); }; onDropped: drop => { if (drop.hasUrls) { DropZone.run("shelve", DropZone.pathsOf(drop.urls)); drop.accept(Qt.CopyAction); } } }
            Column {
                id: shelfHeader
                x: Theme.space.s3; y: Theme.space.s3; width: parent.width - Theme.space.s3 * 2; spacing: Theme.space.s2
                LText { role: "heading"; text: "File shelf · " + DropZone.shelf.length }
                LText { width: parent.width; role: "caption"; color: Theme.textSecondary; text: "Drop files here. Drag them into any app."; wrapMode: Text.Wrap; lineHeight: 1.45 }
                ShelfBundle { width: parent.width; visible: DropZone.shelf.length > 1 }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    ToolButton { glyph: "content_copy"; label: "Copy all"; enabled: DropZone.shelf.length > 0; onClicked: DropZone.run("copy", DropZone.shelf) }
                    ToolButton { label: "Clear"; enabled: DropZone.shelf.length > 0; onClicked: DropZone.clearShelf() }
                }
            }
            ListView {
                anchors { top: shelfHeader.bottom; topMargin: Theme.space.s3; left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s3 }
                clip: true; spacing: Theme.space.s1; model: DropZone.shelf
                delegate: ShelfItem { required property string modelData; width: ListView.view.width; path: modelData }
            }
        }
    }
    Column {
        id: footer; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } spacing: Theme.space.s2
        Flow {
            width: parent.width; spacing: Theme.space.s2
            ToolButton { glyph: "content_copy"; label: "Copy shelf here"; enabled: DropZone.shelf.length > 0 && !DesktopTools.browsing; primary: true; onClicked: DesktopTools.queue("copy", DropZone.shelf, DesktopTools.folder.path) }
            ToolButton { glyph: "drive_file_move"; label: "Move shelf here"; enabled: DropZone.shelf.length > 0 && !DesktopTools.browsing; onClicked: DesktopTools.queue("move", DropZone.shelf, DesktopTools.folder.path) }
            ToolButton { glyph: "folder_zip"; label: "ZIP shelf here"; enabled: DropZone.shelf.length > 0 && !DesktopTools.browsing; onClicked: DesktopTools.queue("compress", DropZone.shelf, DesktopTools.folder.path) }
            ToolButton { glyph: "open_in_new"; label: "File manager"; onClicked: DesktopTools.openPath(DesktopTools.folder.path) }
        }
        LText { width: parent.width; role: "caption"; color: Theme.textMuted; wrapMode: Text.Wrap
                text: DesktopTools.folder.truncated ? "Showing the first 2,000 items. Open the file manager for the full folder." : "Shelf holds references; Clear leaves your files untouched. Jobs never overwrite existing items." }
    }
}
