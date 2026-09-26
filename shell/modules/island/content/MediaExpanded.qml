// media (expanded) — art, title, artist, controls, seekable progress.
//   ╭──────────────────────────────────────────╮
//   │ [art]  Title                    ⏮ ⏯ ⏭  │
//   │        Artist                            │
//   │ 1:42 ━━━━━━━━━━━━━━━━━━━━━━░░░░░░░ 3:30   │
//   ╰──────────────────────────────────────────╯
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: 64 + Theme.space.s3 + 16 + (extras.visible ? extras.height + Theme.space.s2 : 0)

    // Position only needs refreshing while this view is on screen.
    Timer {
        interval: 1000; repeat: true
        running: root.visible && Media.playing
        onTriggered: Media.active?.positionChanged()
    }

    Art { id: art; source: Media.artUrl; size: 64 }

    // Several players → pick which one this controls; shuffle / repeat when supported
    Row {
        id: extras
        visible: Media.players.length > 1 || Media.shuffleOk || Media.loopOk
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 26
        spacing: 6
        Repeater {
            model: Media.players.length > 1 ? Media.players : []
            delegate: HoverTarget {
                required property var modelData
                readonly property bool on: modelData === Media.active
                width: pl.implicitWidth + 18; height: 24
                Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                            color: on ? Theme.withAlpha(Theme.text, 0.14) : "transparent"; border.width: 1; border.color: Theme.border }
                LText { id: pl; anchors.centerIn: parent; role: "caption"; color: on ? Theme.text : Theme.textMuted
                        text: (modelData.isPlaying ? "♪ " : "") + Media.playerName(modelData) }
                onClicked: Media.choose(modelData)
            }
        }
        Item { width: 1; height: 1 }
    }
    Row {
        anchors { right: parent.right; bottom: parent.bottom }
        visible: extras.visible
        height: 26
        spacing: 2
        HoverTarget {
            visible: Media.shuffleOk
            width: 28; height: 26; onClicked: Media.toggleShuffle()
            LIcon { anchors.centerIn: parent; icon: "shuffle"; size: 17; color: (Media.active?.shuffle ?? false) ? Theme.accent : Theme.textMuted }
        }
        HoverTarget {
            visible: Media.loopOk
            width: 28; height: 26; onClicked: Media.cycleLoop()
            readonly property int ls: Media.active?.loopState ?? 0
            LIcon { anchors.centerIn: parent; icon: parent.ls === 1 ? "repeat_one" : "repeat"; size: 17; color: parent.ls === 0 ? Theme.textMuted : Theme.accent }
        }
    }

    Column {
        anchors { left: art.right; leftMargin: Theme.space.s3; right: controls.left; rightMargin: Theme.space.s2; verticalCenter: art.verticalCenter }
        spacing: 2
        LText { width: parent.width; role: "heading"; text: Media.title || "Nothing playing"; elide: Text.ElideRight }
        LText { width: parent.width; role: "body"; color: Theme.textSecondary; text: Media.artist; elide: Text.ElideRight; visible: text !== "" }
    }

    Row {
        id: controls
        anchors { right: parent.right; verticalCenter: art.verticalCenter }
        spacing: Theme.space.s1
        HoverTarget {
            width: 32; height: 32; onClicked: Media.previous()
            LIcon { anchors.centerIn: parent; icon: "skip_previous"; fill: 1; color: Theme.text }
        }
        Rectangle {
            width: 36; height: 36; radius: 18
            // Takes the album's colour when it has one, so the player feels of a piece with the glow
            readonly property color base: Media.hasTint ? Media.tint : Theme.accent
            color: playArea.containsMouse ? Qt.lighter(base, 1.12) : base
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
            LIcon { anchors.centerIn: parent; icon: Media.playing ? "pause" : "play_arrow"; fill: 1; color: Theme.onAccent; size: 20 }
            MouseArea { id: playArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Media.toggle() }
        }
        HoverTarget {
            width: 32; height: 32; onClicked: Media.next()
            LIcon { anchors.centerIn: parent; icon: "skip_next"; fill: 1; color: Theme.text }
        }
    }

    // Progress
    Item {
        anchors { left: parent.left; right: parent.right; bottom: extras.visible ? extras.top : parent.bottom; bottomMargin: extras.visible ? Theme.space.s2 : 0 }
        height: 16
        readonly property real frac: Media.length > 0 ? Math.min(1, (Media.active?.position ?? 0) / Media.length) : 0

        LText { id: pos; role: "caption"; color: Theme.textMuted; text: Media.formatTime(Media.active?.position ?? 0); anchors.verticalCenter: parent.verticalCenter }
        LText { id: len; role: "caption"; color: Theme.textMuted; text: Media.formatTime(Media.length); anchors { right: parent.right; verticalCenter: parent.verticalCenter } }
        Rectangle {
            id: track
            anchors { left: pos.right; right: len.left; leftMargin: Theme.space.s2; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            height: seek.containsMouse ? 6 : 4
            radius: height / 2
            color: Theme.surfaceHover
            Behavior on height { NumberAnimation { duration: Theme.motion.micro } }
            Rectangle {
                width: parent.width * parent.parent.frac
                height: parent.height; radius: parent.radius
                color: Theme.text
                Behavior on width { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
            }
            MouseArea {
                id: seek
                anchors.fill: parent; anchors.margins: -6
                enabled: Media.canSeek
                hoverEnabled: true
                cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: mouse => Media.seekTo(Math.max(0, Math.min(1, (mouse.x - 6) / track.width)))
            }
        }
    }
}
