// Focus modes: pick one; each explains itself. Schedules and allowed apps
// live in Settings → Notifications (footer link).
import QtQuick
import qs.theme
import qs.components
import qs.services

DetailPage {
    title: "Focus"
    footerText: "Schedules & allowed apps…"
    onFooterActivated: { Sidebar.hide(); SettingsState.launch("notifications"); }
    model: Focus.modes
    delegate: ListRow {
        required property var modelData
        icon: modelData.icon
        title: modelData.label
        subtitle: modelData.detail
        trailing: Focus.mode === modelData.id ? "check" : ""
        current: Focus.mode === modelData.id
        onClicked: Focus.set(modelData.id)
    }
}
