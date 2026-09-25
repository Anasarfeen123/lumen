// Appearance: theme, accent, transparency, motion, clock.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Appearance"
    subtitle: "One palette for the whole desktop. Changes apply instantly, everywhere: shell, windows, terminal and lock screen."

    readonly property string curTheme: Theme.tokens.theme ?? "dark"
    readonly property string curAccent: Theme.tokens.accent_name ?? "ion"

    Group {
        title: "Theme"
        Item {
            width: parent.width
            height: themeRow.height + Theme.space.s4 * 2
            Row {
                id: themeRow
                x: Theme.space.s4; y: Theme.space.s4
                spacing: Theme.space.s3
                Repeater {
                    model: SettingsState.previews.themes
                    delegate: Column {
                        required property var modelData
                        spacing: Theme.space.s2
                        readonly property bool on: modelData.id === curTheme
                        // Miniature desktop in the theme's own colours
                        Rectangle {
                            width: 150; height: 96; radius: Theme.radius.md
                            color: "#" + modelData.bg
                            border.width: parent.on ? 2 : 1
                            border.color: parent.on ? Theme.accent : Theme.border
                            Rectangle { x: 10; y: 8; width: 130; height: 12; radius: 6; color: "#" + modelData.surface
                                Rectangle { x: 6; y: 4; width: 14; height: 4; radius: 2; color: "#" + modelData.accent } }
                            Rectangle { x: 10; y: 28; width: 80; height: 58; radius: 6; color: "#" + modelData.elevated
                                Rectangle { x: 8; y: 10; width: 50; height: 5; radius: 2; color: "#" + modelData.text }
                                Rectangle { x: 8; y: 20; width: 36; height: 4; radius: 2; color: "#" + modelData.muted }
                                Rectangle { x: 8; y: 40; width: 28; height: 10; radius: 5; color: "#" + modelData.accent } }
                            Rectangle { x: 98; y: 28; width: 42; height: 58; radius: 6; color: "#" + modelData.surface }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsState.lumen(["theme", modelData.id]) }
                        }
                        LText { anchors.horizontalCenter: parent.horizontalCenter; role: parent.on ? "bodyStrong" : "body"; text: modelData.name; color: parent.on ? Theme.text : Theme.textSecondary }
                    }
                }
            }
        }
    }

    Group {
        title: "Accent"
        SetRow {
            title: "Accent colour"
            description: curAccent === "wallpaper" ? "Following your wallpaper" : "Marks what's active: focus, toggles, progress"
            Row {
                spacing: Theme.space.s2
                Repeater {
                    model: SettingsState.previews.accents
                    delegate: Rectangle {
                        required property var modelData
                        width: 28; height: 28; radius: 14
                        color: "#" + modelData.hex
                        border.width: modelData.id === curAccent ? 3 : 0
                        border.color: Theme.text
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsState.lumen(["accent", modelData.id]) }
                    }
                }
                // From wallpaper
                Rectangle {
                    width: 28; height: 28; radius: 14
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#f3ad6d" }
                        GradientStop { position: 0.5; color: "#b6b3ff" }
                        GradientStop { position: 1; color: "#52d1e9" }
                    }
                    border.width: curAccent === "wallpaper" ? 3 : 0
                    border.color: Theme.text
                    LIcon { anchors.centerIn: parent; icon: "wallpaper"; size: 14; fill: 1; color: "#10141a" }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Wallpapers.setMatchAccent(true) }
                }
            }
        }
    }

    Group {
        title: "Glass & motion"
        SetRow {
            icon: "blur_on"
            title: "Window transparency"
            description: "Frosted glass on apps. Video, games and fullscreen stay opaque. Super+Shift+G"
            LSwitch { checked: Theme.tokens.transparency ?? true; onToggled: SettingsState.lumen(["transparency", checked ? "off" : "on"]) }
        }
        SetRow {
            icon: "animation"
            title: "Reduce motion"
            description: "Replace movement with quick fades"
            LSwitch { checked: Theme.reducedMotion; onToggled: SettingsState.lumen(["motion", checked ? "full" : "reduced"]) }
        }
    }

    Group {
        title: "Icons & sound"
        SetRow {
            icon: "apps"
            title: "App icons"
            description: "Lumen's own icon theme — the rest of the system keeps its own"
            Segmented {
                width: 300
                options: [{ id: "McMojave-circle-dark", label: "Mojave" }, { id: "breeze-plus-dark", label: "Breeze+" }, { id: "system", label: "System" }]
                current: Persist.data.iconTheme
                onPicked: id => Persist.data.iconTheme = id
            }
        }
        SetRow {
            icon: "music_note"
            title: "UI sounds"
            description: "Soft cues for notifications, volume, screenshots, lock and devices. Quiet during Focus and Game mode"
            LSwitch { checked: Persist.data.uiSounds; onToggled: Persist.data.uiSounds = !checked }
        }
    }

    Group {
        title: "Time"
        SetRow {
            icon: "schedule"
            title: "Clock"
            description: "Bar, island and lock screen"
            Segmented {
                width: 200
                options: [{ id: "12h", label: "12-hour" }, { id: "24h", label: "24-hour" }]
                current: Theme.clock12h ? "12h" : "24h"
                onPicked: id => SettingsState.lumen(["clock", id])
            }
        }
    }
}
