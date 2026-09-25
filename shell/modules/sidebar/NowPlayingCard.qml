// Compact player for the control centre: art, title/artist, controls, and a
// thin progress line — tinted with the album's own colour.
import QtQuick
import qs.theme
import qs.components
import qs.services
import qs.modules.island.content

Rectangle {
    id: root
    implicitHeight: 76
    radius: Theme.radius.md
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.border
    clip: true

    Timer { interval: 1000; repeat: true; running: root.visible && Media.playing; onTriggered: Media.active?.positionChanged() }

    // Album-colour wash from the left
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        opacity: Media.hasTint ? 0.22 : 0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Media.hasTint ? Media.tint : "transparent" }
            GradientStop { position: 0.7; color: "transparent" }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }
    }

    Art { id: art; source: Media.artUrl; size: 52; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter } }

    Column {
        anchors { left: art.right; leftMargin: Theme.space.s3; right: controls.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
        spacing: 2
        LText { width: parent.width; role: "bodyStrong"; text: Media.title; elide: Text.ElideRight }
        LText { width: parent.width; role: "caption"; color: Theme.textSecondary; text: Media.artist; elide: Text.ElideRight; visible: text !== "" }
    }

    Row {
        id: controls
        anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
        IconButton { icon: "skip_previous"; tone: Theme.text; onActivated: Media.previous() }
        IconButton { icon: Media.playing ? "pause" : "play_arrow"; tone: Theme.text; iconSize: 22; onActivated: Media.toggle() }
        IconButton { icon: "skip_next"; tone: Theme.text; onActivated: Media.next() }
    }

    Rectangle {
        anchors { left: parent.left; bottom: parent.bottom }
        height: 2
        width: parent.width * Math.max(0, Math.min(1, (Media.active?.position ?? 0) / Math.max(1, Media.length)))
        color: Media.hasTint ? Media.tint : Theme.accent
        visible: Media.length > 0
        Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
    }
}
