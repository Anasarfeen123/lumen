import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    Row {
        id: pathRow; width: parent.width; spacing: Theme.space.s2
        LField { width: parent.width - scanButton.width - Theme.space.s2; height: scanButton.height; text: DesktopTools.storagePath; clearOnAccept: false; placeholder: "Folder to scan"; onAccepted: value => DesktopTools.scan(value); input.onTextEdited: DesktopTools.storagePath = text }
        ToolButton { id: scanButton; glyph: DesktopTools.scanning ? "stop" : "pie_chart"; label: DesktopTools.cancellingScan ? "Stopping…" : DesktopTools.scanning ? "Stop" : "Scan"; enabled: !DesktopTools.cancellingScan; primary: true; onClicked: DesktopTools.scanning ? DesktopTools.cancelScan() : DesktopTools.scan(DesktopTools.storagePath) }
    }
    Column {
        id: summary
        anchors { top: pathRow.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right } spacing: Theme.space.s2
        LText { width: parent.width; role: "bodyStrong"; elide: Text.ElideMiddle; text: DesktopTools.scanning ? DesktopTools.scanLabel : DesktopTools.storage.path ? DesktopTools.size(DesktopTools.storage.total) + " allocated in " + DesktopTools.storage.path : "Choose a folder, then Scan"; textFormat: Text.PlainText }
        Rectangle {
            visible: DesktopTools.storage.capacity > 0
            width: parent.width; height: Theme.space.s2; radius: height / 2; color: Theme.surfaceHover
            Rectangle { height: parent.height; width: parent.width * ((DesktopTools.storage.used ?? 0) / Math.max(1, DesktopTools.storage.capacity ?? 1)); radius: parent.radius; color: Theme.accent }
        }
        LText { width: parent.width; role: "caption"; color: Theme.textSecondary; wrapMode: Text.Wrap; lineHeight: 1.45
                text: DesktopTools.storage.capacity ? "Filesystem: " + DesktopTools.size(DesktopTools.storage.free) + " free of " + DesktopTools.size(DesktopTools.storage.capacity) + " · " + DesktopTools.storage.skipped + " inaccessible, linked or mounted entries skipped" : "Scans run only when requested. Links and other filesystems are skipped." }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            ToolButton { glyph: "home"; label: "Home"; enabled: !DesktopTools.scanning; onClicked: DesktopTools.scan(DesktopTools.home) }
            ToolButton { glyph: "arrow_upward"; label: "Parent"; enabled: !DesktopTools.scanning && !!DesktopTools.storage.parent; onClicked: DesktopTools.scan(DesktopTools.storage.parent) }
            ToolButton { glyph: "folder_open"; label: "Open folder"; enabled: !!DesktopTools.storage.path; onClicked: DesktopTools.openPath(DesktopTools.storage.path) }
        }
    }
    ListView {
        id: rows
        anchors { top: summary.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: note.top; bottomMargin: Theme.space.s3 }
        clip: true; spacing: Theme.space.s2; model: DesktopTools.storage.entries ?? []
        delegate: ToolButton {
            id: row
            required property var modelData
            width: rows.width; height: 64
            enabled: !DesktopTools.scanning
            Accessible.name: modelData.name + ", " + DesktopTools.size(modelData.size)
            contentItem: Column {
                spacing: Theme.space.s2
                Row {
                    width: parent.width; spacing: Theme.space.s2
                    LIcon { icon: row.modelData.directory ? "folder" : "description"; size: Theme.size.heading; color: Theme.textSecondary }
                    LText { width: parent.width - amount.implicitWidth - Theme.size.heading - Theme.space.s2 * 2; text: row.modelData.name; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                    LText { id: amount; role: "bodyStrong"; text: DesktopTools.size(row.modelData.size); color: Theme.textSecondary }
                }
                Rectangle {
                    width: parent.width; height: Theme.space.s1; radius: height / 2; color: Theme.surfaceHover
                    Rectangle { height: parent.height; width: parent.width * row.modelData.size / Math.max(1, DesktopTools.storage.total ?? 0); radius: parent.radius; color: Theme.withAlpha(Theme.accent, .65) }
                }
            }
            onClicked: { if (modelData.directory && !modelData.link) DesktopTools.scan(modelData.path); else DesktopTools.openPath(modelData.path); }
        }
    }
    EmptyState { anchors.centerIn: rows; width: Math.min(360, rows.width); visible: !DesktopTools.scanning && !rows.count; icon: "hard_drive"; title: DesktopTools.scanFinished ? "Nothing to show" : "Know what takes up space"; detail: "Largest items appear first. Open a folder to explore its contents." }
    LText { id: note; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } role: "caption"; color: Theme.textMuted; wrapMode: Text.Wrap; text: "Allocated disk space, including hidden items. Hard links count once. This explorer never deletes files." }
}
