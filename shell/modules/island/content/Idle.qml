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
            style: Persist.data.islandClock ?? "roll"
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
            accessory: HaloExtras.accessory
            // bobbing along with the bass while music plays (the island's equalizer is already listening)
            beat: Media.playing && !Theme.reducedMotion ? Math.min(1, (Visualizer.levels.slice(0, 4).reduce((a, b) => a + b, 0) / 4) * 1.4) : 0
            Behavior on beat { NumberAnimation { duration: 90 } }
            face: Persist.data.haloFace ?? true
            mood: Halo.mood
            level: Voice.level
            scale: orbArea.pressed ? 0.85 : orbArea.containsMouse ? 1.12 : 1
            Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
            // A MouseArea (not a tap handler) so the click is Halo's alone: the island
            // underneath doesn't pin or expand
            MouseArea {
                id: orbArea
                anchors.fill: parent; anchors.margins: -5
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onContainsMouseChanged: Island.orbHovered = containsMouse
                onClicked: m => { if (m.button === Qt.RightButton) Halo.talk(); else { orb.wink(); Ai.toggle(); } }
            }
            Component.onDestruction: Island.orbHovered = false
            // looks up at you when you come close; back from a card, it hops into its seat
            lookY: orbArea.containsMouse ? -0.6 : 0
            Component.onCompleted: if (Date.now() - Halo.cardClosedAt < 1500) pop()
            // listening for "hey halo": a small dot, always visible while it is
            Rectangle {
                visible: Voice.wakeActive
                width: 5; height: 5; radius: 2.5
                anchors { right: parent.right; top: parent.top; rightMargin: -2; topMargin: -1 }
                color: Theme.error
                border.width: 1; border.color: Theme.bg
            }
        }
    }
}