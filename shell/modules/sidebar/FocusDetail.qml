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
        // What the active mode is doing right now
        Column {
            visible: Focus.mode === modelData.id && (modelData.does ?? []).length > 0
            spacing: 2
            topPadding: 4
            Repeater {
                model: modelData.does ?? []
                delegate: Row {
                    required property string modelData
                    spacing: 6
                    LIcon { icon: "check"; size: 13; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "caption"; color: Theme.textSecondary; text: modelData }
                }
            }
        }
    }
}
