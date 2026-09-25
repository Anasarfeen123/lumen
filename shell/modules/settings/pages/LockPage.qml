// Lock screen: widgets, Face ID shortcut, what locks it.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Lock screen"
    subtitle: "Super+L locks. It also locks after 5 minutes idle and always before sleep."

    Group {
        title: "Widgets"
        SetRow { icon: "music_note"; title: "Now playing"; description: "Artwork and controls while music plays"
                 LSwitch { checked: Persist.data.lockMedia; onToggled: Persist.data.lockMedia = !checked } }
        SetRow { icon: "battery_full"; title: "Battery"; description: "Charge ring and time remaining"
                 LSwitch { checked: Persist.data.lockBattery; onToggled: Persist.data.lockBattery = !checked } }
        SetRow { icon: "calendar_month"; title: "Calendar"; description: "This month"
                 LSwitch { checked: Persist.data.lockCalendar; onToggled: Persist.data.lockCalendar = !checked } }
        SetRow { icon: "notifications"; title: "Notifications"; description: "A count and app names only — never their content"
                 LSwitch { checked: Persist.data.lockNotifications; onToggled: Persist.data.lockNotifications = !checked } }
    }

    Group {
        title: "Unlocking"
        SetRow {
            icon: "face"
            title: "Face ID"
            description: "Set up, calibrate and adjust the anti-photo check"
            Button { text: "Open Face ID"; onActivated: SettingsState.page = "faceid" }
        }
        SetRow { icon: "password"; title: "Password"; description: "Always works, whatever Face ID does" }
    }
}
