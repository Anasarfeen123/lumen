// A folder in the bar, without switching to a file manager. Uses the same
// pinned paths and listing as Tools; the popup always grows from its button.
import QtQuick
import qs.theme
import qs.components
import qs.services
import qs.modules.tools

Item {
    id: root
    required property var barWindow
    property bool shown: false
    width: Theme.space.s8 + Theme.space.s2
    height: Theme.barHeight
    visible: shown
    function toggle() {
        if (portal.shown) { portal.close(); return; }
        DesktopTools.hide();
        DesktopTools.prepareFolders();
        portal.open();
    }
    ToolButton {
        anchors { fill: parent; topMargin: Theme.space.s1; bottomMargin: Theme.space.s1 }
        glyph: "folder_open"; label: ""; primary: portal.shown; flat: true
        Accessible.name: "Folder portals"
        onClicked: root.toggle()
    }
    LumenPopup {
        id: portal
        anchor.window: root.barWindow
        anchor.rect.x: root.mapToItem(root.barWindow.contentItem, 0, 0).x - margin
        anchor.rect.y: Theme.edgeGap + Theme.barHeight + Theme.space.s2 - margin
        contentWidth: 380
        contentHeight: body.implicitHeight + Theme.space.s4 * 2
        motionOrigin: Item.TopLeft
        Column {
            id: body
            x: Theme.space.s4; y: Theme.space.s4; width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3
            LText { role: "heading"; text: "Folder portals" }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                Repeater {
                    model: DesktopTools.defaultFolders.filter(f => f.name === "Downloads" || f.name === "Projects").concat(DesktopTools.pinnedFolders.slice(0, 6))
                    ToolButton {
                        required property var modelData
                        label: modelData.name
                        primary: DesktopTools.folder.path === modelData.path
                        onClicked: DesktopTools.browse(modelData.path)
                    }
                }
            }
            Row {
                width: parent.width; spacing: Theme.space.s2
                ToolButton { id: up; glyph: "arrow_upward"; label: ""; Accessible.name: "Parent folder"; enabled: !DesktopTools.browsing; onClicked: DesktopTools.browse(DesktopTools.folder.parent) }
                LText { width: parent.width - up.width - Theme.space.s2; height: up.height; role: "bodyStrong"; text: DesktopTools.folder.path.replace(DesktopTools.home, "~"); elide: Text.ElideMiddle; textFormat: Text.PlainText }
            }
            ListView {
                id: files
                width: parent.width; height: Math.min(count, 7) * 44
                model: DesktopTools.folderEntries
                clip: true; spacing: Theme.space.s1
                delegate: Item {
                    id: file
                    required property var modelData
                    width: files.width; height: 40
                    ToolButton {
                        width: parent.width - add.width - Theme.space.s2; height: parent.height
                        Accessible.name: file.modelData.name
                        contentItem: Row {
                            spacing: Theme.space.s2
                            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: file.modelData.directory ? "folder" : "description"; size: Theme.size.heading; color: Theme.textSecondary }
                            LText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - Theme.size.heading - Theme.space.s2; text: file.modelData.name; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                        }
                        onClicked: {
                            if (file.modelData.directory) DesktopTools.browse(file.modelData.path);
                            else { portal.close(); DesktopTools.openPath(file.modelData.path); }
                        }
                    }
                    ToolButton { id: add; anchors.right: parent.right; glyph: "add"; label: ""; height: parent.height; Accessible.name: "Add " + file.modelData.name + " to shelf"; onClicked: DropZone.run("shelve", [file.modelData.path]) }
                }
            }
            LText { visible: !files.count; text: DesktopTools.browsing ? "Opening folder…" : "This folder is empty"; color: Theme.textSecondary }
            LText { visible: DesktopTools.message !== ""; width: parent.width; text: DesktopTools.message; color: Theme.textSecondary; role: "caption"; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; textFormat: Text.PlainText }
            ToolButton { glyph: "open_in_new"; label: "Open Folders & shelf"; primary: true; onClicked: { portal.close(); DesktopTools.show("folders", "left"); } }
        }
    }
}
