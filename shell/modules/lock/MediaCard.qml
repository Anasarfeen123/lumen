// Now playing: artwork, title, artist, progress, controls.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import qs.modules.island.content

FrostPane {
    id: root
    implicitWidth: 380
    implicitHeight: 176

    // Position only moves while this is on screen and playing
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && Media.playing
        onTriggered: Media.active?.positionChanged()
    }

    Row {
        anchors { fill: parent; margins: Theme.space.s5 }
        spacing: Theme.space.s4

        Art {
            source: Media.artUrl
            size: 96
            anchors.verticalCenter: parent.verticalCenter
        }

        Column {
            width: parent.width - 96 - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.space.s1

            LText { width: parent.width; role: "heading"; text: Media.title; elide: Text.ElideRight }
            LText { width: parent.width; role: "body"; color: Theme.textSecondary; text: Media.artist; elide: Text.ElideRight; visible: text !== "" }

            Item { width: 1; height: Theme.space.s2 }

            // Progress
            Item {
                width: parent.width
                height: 4
                visible: Media.length > 0
                Rectangle { anchors.fill: parent; radius: 2; color: Theme.withAlpha(Theme.text, 0.18) }
                Rectangle {
                    height: parent.height; radius: 2; color: Theme.text
                    width: parent.width * Math.max(0, Math.min(1, (Media.active?.position ?? 0) / Math.max(1, Media.length)))
                    Behavior on width { NumberAnimation { duration: Theme.motion.normal } }
                }
            }
            Item {
                width: parent.width
                height: 16
                visible: Media.length > 0
                LText { role: "caption"; color: Theme.textMuted; text: Media.formatTime(Media.active?.position ?? 0) }
                LText { anchors.right: parent.right; role: "caption"; color: Theme.textMuted; text: Media.formatTime(Media.length) }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space.s3
                IconButton { icon: "skip_previous"; tone: Theme.text; iconSize: 22; onActivated: Media.previous() }
                HoverTarget {
                    width: 40; height: 40
                    onClicked: Media.toggle()
                    Rectangle { anchors.fill: parent; radius: 20; color: Theme.text }
                    LIcon { anchors.centerIn: parent; icon: Media.playing ? "pause" : "play_arrow"; fill: 1; size: 24; color: Theme.bg }
                }
                IconButton { icon: "skip_next"; tone: Theme.text; iconSize: 22; onActivated: Media.next() }
            }
        }
    }
}
