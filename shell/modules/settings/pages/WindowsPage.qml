// Windows: gaps, corners, border, animation speed, focus behaviour.
// Applied live (theme/build.py → Hyprland + shell).
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Windows"
    subtitle: "How windows sit on the desktop and how they move. Changes apply immediately."

    readonly property var prefs: Theme.tokens.prefs ?? ({})
    function set(k, v) { SettingsState.lumen(["set", k, v]); }

    Group {
        title: "Layout"
        SetRow {
            icon: "space_dashboard"
            title: "Gaps"
            description: "Space between windows and around the edges"
            Segmented {
                width: 300
                options: [{ id: "compact", label: "Compact" }, { id: "normal", label: "Normal" }, { id: "roomy", label: "Roomy" }]
                current: prefs.gaps ?? "normal"
                onPicked: id => set("gaps", id)
            }
        }
        SetRow {
            icon: "rounded_corner"
            title: "Corners"
            description: "Windows and cards"
            Segmented {
                width: 300
                options: [{ id: "square", label: "Square" }, { id: "soft", label: "Soft" }, { id: "round", label: "Round" }]
                current: prefs.corners ?? "soft"
                onPicked: id => set("corners", id)
            }
        }
        SetRow {
            icon: "border_style"
            title: "Focus border"
            description: "The accent line around the active window"
            Segmented {
                width: 300
                options: [{ id: "off", label: "Off" }, { id: "thin", label: "Thin" }, { id: "normal", label: "Normal" }]
                current: prefs.border ?? "normal"
                onPicked: id => set("border", id)
            }
        }
    }

    Group {
        title: "Motion & focus"
        SetRow {
            icon: "speed"
            title: "Animation speed"
            description: "All animations — windows, workspaces and the shell"
            Segmented {
                width: 300
                options: [{ id: "fast", label: "Fast" }, { id: "normal", label: "Normal" }, { id: "relaxed", label: "Relaxed" }]
                current: prefs.anim_speed ?? "normal"
                onPicked: id => set("anim_speed", id)
            }
        }
        SetRow {
            icon: "mouse"
            title: "Focus follows the pointer"
            description: "Windows take focus when the pointer moves over them"
            LSwitch { checked: (prefs.follow_mouse ?? "on") === "on"; onToggled: set("follow_mouse", checked ? "off" : "on") }
        }
    }
}
