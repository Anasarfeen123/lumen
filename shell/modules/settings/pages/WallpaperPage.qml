// Wallpaper: current picture, picker, shuffle, match accent.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Wallpaper"
    subtitle: "Put pictures in ~/Pictures/Wallpapers; sub-folders become categories in the picker."

    ClippingRectangle {
        width: parent.width
        height: width * 9 / 16 * 0.62
        radius: Theme.radius.lg
        color: Theme.surfaceElevated
        Image {
            anchors.fill: parent
            source: Wallpapers.current !== "" ? "file://" + Wallpapers.current : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize: Qt.size(1280, 720)
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 64
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) }
            }
            LText {
                anchors { left: parent.left; bottom: parent.bottom; margins: Theme.space.s4 }
                role: "bodyStrong"; color: "white"
                text: Wallpapers.current.split("/").slice(-3).join(" / ")
            }
        }
    }

    Row {
        spacing: Theme.space.s2
        Button { primary: true; icon: "grid_view"; text: "Choose wallpaper…"; onActivated: SettingsState.shellCall("wallpapers", "toggle") }
        Button { icon: "shuffle"; text: "Shuffle"; onActivated: SettingsState.shellCall("wallpapers", "random") }
    }

    Group {
        SetRow {
            icon: "colorize"
            title: "Match accent to wallpaper"
            description: "Takes the wallpaper's most vivid hue, kept clear of warning and error colours"
            LSwitch { checked: Wallpapers.matchAccent; onToggled: Wallpapers.setMatchAccent(!checked) }
        }
    }
}
