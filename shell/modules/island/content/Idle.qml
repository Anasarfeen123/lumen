// idle — the island at rest, with a little life in it:
//
//   ( ◉ )  23:45  · Fri 26  ⓗ     ◉ = context: spinning album-art vinyl while
//                                     music plays · bolt when charging ·
//                                     moon when Do Not Disturb is on
//                                 ⓗ = Halo, resting (it breathes, blinks,
//                                     listens, thinks — services/Halo.qml)
//
// The clock rolls its digits when the minute changes (RollingClock). While
// music plays, the island's background also carries the album-tinted
// equalizer (Spectrum, placed by IslandWindow).
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height

    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property string context: Media.playing ? "music"
                                     : Notifications.dnd ? "dnd"
                                     : (Battery.available && Battery.charging) ? "charging" : ""

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2

        // Context glyph (only when there is something to say)
        Item {
            width: root.context !== "" ? 20 : 0
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            visible: width > 0
            Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

            // Vinyl: the album art as a slowly turning disc
            Art {
                id: vinyl
                anchors.centerIn: parent
                size: 20
                radius: 10
                source: Media.artUrl
                visible: root.context === "music"
                RotationAnimation on rotation {
                    running: vinyl.visible && !Theme.reducedMotion
                    from: 0; to: 360; duration: 6000; loops: Animation.Infinite
                }
                Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: Theme.bg }
            }
            LIcon {
                anchors.centerIn: parent
                visible: root.context === "charging"
                icon: "bolt"; fill: 1; size: 16; color: Theme.success
            }
            LIcon {
                anchors.centerIn: parent
                visible: root.context === "dnd"
                icon: "bedtime"; fill: 1; size: 15; color: Theme.textSecondary
            }
        }

        RollingClock {
            anchors.verticalCenter: parent.verticalCenter
            pixelSize: 16
            weight: 650
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Persist.data.islandDate
            text: Qt.formatDateTime(clock.date, "ddd d")
            color: Theme.textMuted
            font.family: Theme.fontUi
            font.pixelSize: 13
            font.variableAxes: ({ "wght": 500, "ROND": 100 })
            renderType: Text.NativeRendering
        }

        // Halo, resting beside the clock (Settings → Halo → "Show Halo").
        // Click: open Halo · right-click: talk to it
        HaloOrb {
            id: orb
            anchors.verticalCenter: parent.verticalCenter
            visible: Halo.present
            size: 17
            breathes: false             // the resting island spends nothing: blinks and glances only
            face: Persist.data.haloFace ?? true
            mood: Halo.mood
            level: Voice.level
            scale: orbTap.pressed ? 0.85 : orbHover.hovered ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
            HoverHandler { id: orbHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { id: orbTap; onTapped: Ai.toggle() }
            TapHandler { acceptedButtons: Qt.RightButton; onTapped: Halo.talk() }
        }
    }
}