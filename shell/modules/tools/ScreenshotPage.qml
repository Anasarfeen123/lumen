import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    Flow {
        id: capture
        width: parent.width; spacing: Theme.space.s2
        ToolButton { glyph: "screenshot_region"; label: "Region"; primary: true; onClicked: DesktopTools.capture("region") }
        ToolButton { glyph: "screenshot_monitor"; label: "Screen"; onClicked: DesktopTools.capture("screen") }
        ToolButton { glyph: "refresh"; label: "Refresh"; enabled: !DesktopTools.loadingShots; onClicked: DesktopTools.refreshShots() }
    }
    Item {
        anchors { top: capture.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
        ListView {
            id: history
            width: Math.min(180, parent.width * .3); height: parent.height
            clip: true; spacing: Theme.space.s2
            model: DesktopTools.shots
            delegate: ToolButton {
                required property var modelData
                width: history.width
                height: thumbnail.height + fileLabel.implicitHeight + Theme.space.s3 * 2
                label: modelData.name
                Accessible.name: modelData.name
                primary: DesktopTools.selectedShot?.path === modelData.path
                contentItem: Column {
                    spacing: Theme.space.s2
                    Image { id: thumbnail; width: history.width - Theme.space.s3 * 2; height: 86; source: modelData.uri; sourceSize: Qt.size(320, 180); fillMode: Image.PreserveAspectFit; asynchronous: true }
                    LText { id: fileLabel; width: parent.width; role: "caption"; text: modelData.name; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                }
                onClicked: DesktopTools.selectedShot = modelData
            }
        }
        Column {
            id: detail
            anchors { left: history.right; leftMargin: Theme.space.s4; right: parent.right; top: parent.top; bottom: parent.bottom }
            visible: DesktopTools.selectedShot !== null
            spacing: Theme.space.s3
            Rectangle {
                width: parent.width
                height: Math.max(60, detail.height - actions.implicitHeight - filename.implicitHeight - note.implicitHeight - Theme.space.s3 * 3)
                radius: Theme.radius.md; color: Theme.bg
                Image {
                    anchors { fill: parent; margins: Theme.space.s2 }
                    source: DesktopTools.selectedShot?.uri ?? ""
                    sourceSize: Qt.size(1600, 1200)
                    fillMode: Image.PreserveAspectFit; asynchronous: true; cache: false
                    LText { anchors.centerIn: parent; visible: parent.status === Image.Error; text: "Image unavailable"; color: Theme.textSecondary }
                }
            }
            LText { id: filename; width: parent.width; role: "bodyStrong"; text: DesktopTools.selectedShot?.name ?? ""; elide: Text.ElideMiddle; textFormat: Text.PlainText }
            Flow {
                id: actions; width: parent.width; spacing: Theme.space.s2
                ToolButton { glyph: "draw"; label: "Edit in Swappy"; primary: true; enabled: !DesktopTools.imageBusy; onClicked: DesktopTools.imageAction("edit") }
                ToolButton { glyph: "content_copy"; label: "Copy image"; enabled: !DesktopTools.imageBusy; onClicked: DesktopTools.imageAction("copy-image") }
                ToolButton { glyph: "document_scanner"; label: "Copy text"; enabled: !DesktopTools.imageBusy; onClicked: DesktopTools.imageAction("ocr") }
                ToolButton { glyph: "inventory_2"; label: "Shelf"; onClicked: DropZone.run("shelve", [DesktopTools.selectedShot.path]) }
                ToolButton { glyph: "folder_open"; label: "Folder"; onClicked: DesktopTools.openPath(DesktopTools.shotsPath) }
            }
            LText { id: note; width: parent.width; role: "caption"; color: Theme.textSecondary; wrapMode: Text.Wrap; lineHeight: 1.45
                    text: DesktopTools.imageBusy ? "Working… the editor may be in another window." : "Crop, draw, add text or blur in Swappy. Edits save a new PNG; your original stays intact." }
        }
        EmptyState {
            anchors.centerIn: parent; width: Math.min(360, parent.width)
            visible: !DesktopTools.shots.length
            icon: "screenshot_monitor"; title: DesktopTools.loadingShots ? "Loading captures…" : "A home for your screenshots"
            detail: "Capture a region or screen above. Your latest 100 saved screenshots appear here."
        }
    }
}
