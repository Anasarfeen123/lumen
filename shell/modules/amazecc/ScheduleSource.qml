import QtQuick
import qs.theme
import qs.components

Column {
    id: root
    property var schedule: ({})
    width: parent.width; spacing: Theme.space.s1
    LText { visible: !!root.schedule.error; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.warning; text: root.schedule.error || "" }
    LText {
        width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted
        text: "Schedule: unmessify · " + (root.schedule.fetchedAt ? (root.schedule.offline ? "Saved copy · fetched " : "Fetched ") + Qt.formatDateTime(new Date(root.schedule.fetchedAt), "d MMM, h:mm AP") : "Bundled offline copy")
              + (root.schedule.sourceUpdated ? " · Published " + root.schedule.sourceUpdated.slice(0, 10) : "") + ". Confirm changes at your hostel."
    }
}
