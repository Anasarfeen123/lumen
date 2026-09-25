// Bar & Island: what the island shows, hot corners.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Bar & Island"
    subtitle: "The island is where the desktop talks to you — volume, music, notifications, recording. Here you decide how much it says."

    Group {
        title: "Island"
        SetRow {
            icon: "calendar_today"
            title: "Show the date"
            description: "Short date next to the clock"
            LSwitch { checked: Persist.data.islandDate; onToggled: Persist.data.islandDate = !checked }
        }
        SetRow {
            icon: "view_carousel"
            title: "Announce workspace changes"
            description: "Briefly shows the workspace name when you switch"
            LSwitch { checked: Persist.data.islandWorkspace; onToggled: Persist.data.islandWorkspace = !checked }
        }
    }

    Group {
        title: "Hot corners"
        SetRow {
            icon: "north_west"
            title: "Top-left: Overview & search"
            description: "Push the pointer into the corner and pause"
            LSwitch { checked: Persist.data.hotCornerLeft; onToggled: Persist.data.hotCornerLeft = !checked }
        }
        SetRow {
            icon: "north_east"
            title: "Top-right: Control centre"
            LSwitch { checked: Persist.data.hotCornerRight; onToggled: Persist.data.hotCornerRight = !checked }
        }
    }
}
