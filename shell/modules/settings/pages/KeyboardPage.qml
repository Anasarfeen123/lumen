// Keyboard & gestures: the essentials, plus the full cheatsheet.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Keyboard & Gestures"
    subtitle: "Lumen is keyboard-first. These are the ones worth learning first."

    Button { primary: true; icon: "keyboard"; text: "Open the full cheatsheet  (Super+/)"; onActivated: SettingsState.shellCall("cheatsheet", "open") }

    Group {
        title: "Essentials"
        SetRow { icon: "search"; title: "Tap Super"; description: "Overview & search — apps, windows, calculator (=), commands (>), web (?)" }
        SetRow { icon: "tune"; title: "Super+N"; description: "Control centre and notifications" }
        SetRow { icon: "music_note"; title: "Super+M"; description: "Expand the island — Space play/pause, ← → tracks" }
        SetRow { icon: "content_paste"; title: "Super+V"; description: "Clipboard history" }
        SetRow { icon: "screenshot_region"; title: "Super+Shift+S"; description: "Screenshot a region (copied, and saved to Pictures)" }
        SetRow { icon: "lock"; title: "Super+L"; description: "Lock" }
        SetRow { icon: "settings"; title: "Super+I"; description: "These settings" }
    }

    Group {
        title: "Gestures"
        SetRow { icon: "swipe_up"; title: "Four fingers up / down"; description: "Open / close the overview" }
        SetRow { icon: "swipe"; title: "Four fingers left / right"; description: "Switch workspace" }
        SetRow { icon: "north_west"; title: "Top-left corner"; description: "Overview & search" }
        SetRow { icon: "north_east"; title: "Top-right corner"; description: "Control centre" }
        SetRow { icon: "mouse"; title: "Scroll on the bar / island"; description: "Workspaces / volume (Shift: brightness)" }
    }
}
