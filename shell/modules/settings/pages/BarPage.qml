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
            icon: "apps"
            title: "App icons on workspaces"
            description: "Each workspace in the bar shows its app's icon; off: simple dots"
            LSwitch { checked: Persist.data.workspaceIcons ?? true; onToggled: Persist.data.workspaceIcons = !checked }
        }
        SetRow {
            icon: "rounded_corner"
            title: "Rounded screen corners"
            description: "The screen's corners drawn round, like a phone's display"
            LSwitch { checked: Persist.data.screenCorners ?? false; onToggled: Persist.data.screenCorners = !checked }
        }
        SetRow {
            icon: "monitor_heart"
            title: "System stats in the bar"
            description: (Persist.data.barVitals ?? "busy") === "busy" ? "The CPU line and memory appear when the computer is busy (CPU over 30 % or memory over 80 %)."
                       : (Persist.data.barVitals ?? "busy") === "always" ? "The CPU line and memory are always beside the status pill." : "Never shown — the Monitor app has them."
            Segmented {
                width: 240
                options: [{ id: "busy", label: "When busy" }, { id: "always", label: "Always" }, { id: "never", label: "Never" }]
                current: Persist.data.barVitals ?? "busy"
                onPicked: id => Persist.data.barVitals = id
            }
        }
        SetRow {
            icon: "picture_in_picture"
            title: "Video follows you"
            description: "Leave the workspace with a playing video and it continues in a small corner player — just the video. Go back and it steps away. Ctrl+Super+P or ⧉ in the player does it by hand."
            LSwitch { checked: Persist.data.pipAuto ?? true; onToggled: Persist.data.pipAuto = !checked }
        }
        SetRow {
            icon: "view_carousel"
            title: "Announce workspace changes"
            description: "Briefly shows the workspace name when you switch"
            LSwitch { checked: Persist.data.islandWorkspace; onToggled: Persist.data.islandWorkspace = !checked }
        }
        SetRow {
            icon: "schedule"
            title: "Island clock"
            description: (Persist.data.islandClock ?? "roll") === "flip" ? "Flip: each digit on a small card that flips over when it changes." : "Roll: changed digits slide up like a counter."
            Segmented {
                width: 220
                options: [{ id: "roll", label: "Roll" }, { id: "flip", label: "Flip" }]
                current: Persist.data.islandClock ?? "roll"
                onPicked: id => Persist.data.islandClock = id
            }
        }
        SetRow {
            icon: "swipe_vertical"
            title: "Scroll on the island"
            description: Persist.data.islandScroll === "volume"
                ? "Changes the volume · the Now timeline opens with a sideways scroll"
                : "Scrubs the Now timeline (the last hour) · volume scrolls on the status icons"
            Segmented {
                width: 220
                options: [{ id: "timeline", label: "Timeline" }, { id: "volume", label: "Volume" }]
                current: Persist.data.islandScroll ?? "timeline"
                onPicked: id => Persist.data.islandScroll = id
            }
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
