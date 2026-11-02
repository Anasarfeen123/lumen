import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    Row {
        id: header; width: parent.width; spacing: Theme.space.s2
        LText { width: parent.width - clear.width - Theme.space.s2; height: clear.height; role: "bodyStrong"; text: FileOperations.remaining ? FileOperations.remaining + " in progress or waiting" : "All jobs settled" }
        ToolButton { id: clear; label: "Clear finished"; glyph: "done_all"; onClicked: FileOperations.clearFinished() }
    }
    ListView {
        id: list
        anchors { top: header.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true; spacing: Theme.space.s3; model: FileOperations.jobs
        delegate: Rectangle {
            id: card
            required property var modelData
            readonly property bool active: ["queued", "running", "cancelling"].includes(modelData.status)
            width: list.width; height: content.implicitHeight + Theme.space.s4 * 2
            radius: Theme.radius.md; color: Theme.surfaceElevated
            Column {
                id: content
                x: Theme.space.s4; y: Theme.space.s4; width: parent.width - Theme.space.s4 * 2; spacing: Theme.space.s2
                Row {
                    width: parent.width; spacing: Theme.space.s2
                    LIcon { icon: card.modelData.status === "failed" ? "error" : card.modelData.status === "done" ? "check_circle" : card.modelData.kind === "compress" ? "folder_zip" : "swap_horiz"; size: Theme.size.heading; color: card.modelData.status === "failed" ? Theme.error : card.modelData.status === "done" ? Theme.success : Theme.textSecondary }
                    LText { width: parent.width - Theme.size.heading - Theme.space.s2; role: "bodyStrong"; text: ({ copy: "Copy", move: "Move", compress: "Compress" })[card.modelData.kind] + " · " + card.modelData.name; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                }
                LText { width: parent.width; role: "caption"; color: Theme.textSecondary; text: "To " + card.modelData.destination; elide: Text.ElideMiddle; textFormat: Text.PlainText }
                Rectangle {
                    width: parent.width; height: Theme.space.s1; radius: height / 2; color: Theme.surfaceHover
                    Rectangle { width: parent.width * card.modelData.progress; height: parent.height; radius: parent.radius; color: card.modelData.status === "failed" ? Theme.error : Theme.accent }
                }
                LText {
                    width: parent.width; color: card.modelData.status === "failed" ? Theme.error : Theme.textSecondary
                    text: card.modelData.error || (card.modelData.status === "running" ? (card.modelData.current || "Preparing…") + " · " + Math.round(card.modelData.progress * 100) + "%" : ({ done: "Complete", queued: "Waiting", cancelled: "Cancelled", cancelling: "Stopping and cleaning partial output…" })[card.modelData.status] ?? card.modelData.status)
                    wrapMode: Text.Wrap; textFormat: Text.PlainText; lineHeight: 1.45
                }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    ToolButton { visible: card.active; label: card.modelData.status === "cancelling" ? "Stopping…" : "Cancel"; enabled: card.modelData.status !== "cancelling"; onClicked: FileOperations.cancel(card.modelData.id) }
                    ToolButton { visible: !card.active && card.modelData.status !== "done"; label: "Retry remaining"; onClicked: FileOperations.retry(card.modelData.id) }
                    ToolButton { label: "Open destination"; glyph: "folder_open"; onClicked: DesktopTools.openPath(card.modelData.destination) }
                }
            }
        }
    }
    EmptyState { anchors.centerIn: parent; width: Math.min(360, parent.width); visible: !FileOperations.jobs.length; icon: "swap_horiz"; title: "Room for your next job"; detail: "Add files to the shelf, then choose Copy, Move or ZIP in Folders. You can keep working while jobs run." }
}
