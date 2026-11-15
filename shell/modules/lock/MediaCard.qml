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
    implicitHeight: lyric ? 198 : 176
    readonly property string lyric: (Lyrics.enabled && Lyrics.state === "synced") ? Lyrics.current : ""
    Binding { target: MusicApp; property: "lockShowing"; value: root.visible }

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
            LText { width: parent.width; role: "caption"; color: Theme.accent; text: "♪ " + root.lyric; elide: Text.ElideRight; visible: root.lyric !== "" }

            Item { width: 1; height: Theme.space.s2 }

            // Progress — click or drag to seek
            Item {
                id: bar
                width: parent.width
                height: 4
                visible: Media.length > 0
                readonly property bool canSeek: (Media.active?.canSeek ?? false) && (Media.active?.positionSupported ?? false)
                readonly property real frac: seek.pressed ? seek.at : Math.max(0, Math.min(1, (Media.active?.position ?? 0) / Math.max(1, Media.length)))
                Rectangle { anchors.fill: parent; radius: 2; color: Theme.withAlpha(Theme.text, 0.18) }
                Rectangle {
                    height: parent.height; radius: 2; color: Theme.text
                    width: parent.width * bar.frac
                    Behavior on width { enabled: !seek.pressed; NumberAnimation { duration: Theme.motion.normal } }
                }
                Rectangle { x: parent.width * bar.frac - 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: Theme.text
                            visible: bar.canSeek; scale: seek.containsMouse || seek.pressed ? 1 : 0; Behavior on scale { NumberAnimation { duration: Theme.motion.micro } } }
                MouseArea {
                    id: seek
                    anchors { fill: parent; topMargin: -10; bottomMargin: -10 }
                    enabled: bar.canSeek
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true
                    property real at: 0
                    function frac(x) { return Math.max(0, Math.min(1, x / bar.width)); }
                    onPressed: m => at = frac(m.x)
                    onPositionChanged: m => { if (pressed) at = frac(m.x); }
                    onReleased: Media.active.position = at * Media.length
                }
            }
            Item {
                width: parent.width
                height: 16
                visible: Media.length > 0
                LText { role: "caption"; color: Theme.textMuted; text: Media.formatTime(seek.pressed ? seek.at * Media.length : (Media.active?.position ?? 0)) }
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
