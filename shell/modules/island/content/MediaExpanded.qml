// media (expanded) — art, title, artist, controls, seekable progress.
//   ╭──────────────────────────────────────────╮
//   │ [art]  Title                    ⏮ ⏯ ⏭  │
//   │        Artist                            │
//   │        ♪ the line being sung             │
//   │ 1:42 ━━━━━━━━━━━━━━━━━━━━━━░░░░░░░ 3:30   │
//   │ [players]                [Lyrics] ⤮ ↻   │
//   ╰──────────────────────────────────────────╯
// Lyrics (LRCLIB, Settings → Sound): the current line sits softly under the
// artist; the Lyrics chip opens three lines that glide up as the song plays.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: 64 + Theme.space.s3 + (lyricsView.visible ? lyricsView.height + Theme.space.s3 : 0)
                    + 16 + (ctrls.visible ? 26 + Theme.space.s2 : 0)
    Behavior on implicitHeight { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

    // Lyrics are looked up only while this view is on screen
    Binding { target: Lyrics; property: "wanted"; value: root.visible }
    readonly property bool showLyrics: Lyrics.mode && Lyrics.available

    // Position only needs refreshing while this view is on screen.
    Timer {
        interval: 1000; repeat: true
        running: root.visible && Media.playing
        onTriggered: Media.active?.positionChanged()
    }

    // ── Art, with a record sliding out from behind it while it plays (scroll: this player's volume) ──
    Item {
        id: vinyl
        anchors { left: art.left; verticalCenter: art.verticalCenter }
        width: 58; height: 58
        anchors.leftMargin: Media.playing && !Theme.reducedMotion ? 28 : 4
        Behavior on anchors.leftMargin { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Rectangle {
            id: disc
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient { orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#1c1d21" } GradientStop { position: 0.55; color: "#2a2b31" } GradientStop { position: 1; color: "#141518" } }
            border.width: 1; border.color: Theme.withAlpha("#ffffff", 0.18)
            // grooves
            Repeater { model: 4
                Rectangle { required property int index; anchors.centerIn: parent
                            width: disc.width * (0.86 - index * 0.13); height: width; radius: width / 2
                            color: "transparent"; border.width: 1; border.color: Theme.withAlpha("#ffffff", 0.1 + index * 0.03) } }
            // the label, in the album's colour, with a sheen so the turn shows
            Rectangle { anchors.centerIn: parent; width: disc.width * 0.34; height: width; radius: width / 2
                        color: Media.hasTint ? Media.tint : Theme.accent
                        Rectangle { anchors.centerIn: parent; width: 4; height: 4; radius: 2; color: "#111214" } }
            Rectangle { anchors.centerIn: parent; width: 2; height: disc.height * 0.94; color: Theme.withAlpha("#ffffff", 0.16) }
            RotationAnimation on rotation { running: Media.playing && root.visible && !Theme.reducedMotion; from: 0; to: 360; duration: 3600; loops: Animation.Infinite }
        }
    }
    Art { id: art; source: Media.artUrl; size: 64 }
    MouseArea {
        anchors.fill: art
        acceptedButtons: Qt.NoButton
        onWheel: w => {
            const p = Media.active;
            if (!p?.volumeSupported || !p.canControl) return;
            p.volume = Math.max(0, Math.min(1, p.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            Island.system("volume_up", Media.playerName(p) + " · " + Math.round(p.volume * 100) + "%", "");
        }
    }

    // a small live spectrum while it plays, top right
    Binding { target: Visualizer; property: "wanted"; value: true; when: root.visible && Media.playing }
    Row {
        anchors { right: parent.right; top: parent.top; topMargin: -2 }
        spacing: 2
        opacity: Media.playing && Visualizer.levels.length > 0 ? 0.85 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        Repeater {
            model: Math.min(10, Visualizer.levels.length)
            Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: 3; radius: 1.5
                height: 12
                color: Media.hasTint ? Qt.lighter(Media.tint, 1.3) : Theme.accent
                transform: Scale { origin.y: 12; yScale: Math.max(0.18, Visualizer.levels[Math.floor(index * Visualizer.levels.length / 20)] ?? 0)
                                   Behavior on yScale { NumberAnimation { duration: 70 } } }
            }
        }
    }

    // Several players → pick which one this controls; shuffle / repeat when supported
    // Players: a strip that stops before the controls on the right and
    // scrolls sideways when there are many; long names are trimmed
    Item {
        id: extras
        visible: true
        anchors { left: parent.left; right: ctrls.left; rightMargin: Theme.space.s2; bottom: parent.bottom }
        height: 26
        ListView {
            anchors.fill: parent
            orientation: ListView.Horizontal
            spacing: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: Media.players.length > 1 ? Media.players : []
            delegate: HoverTarget {
                required property var modelData
                readonly property bool on: modelData === Media.active
                width: pl.width + 18; height: 24
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                            color: on ? Theme.withAlpha(Theme.text, 0.14) : "transparent"; border.width: 1; border.color: Theme.border }
                LText { id: pl; anchors.centerIn: parent; role: "caption"; color: on ? Theme.text : Theme.textMuted
                        width: Math.min(implicitWidth, 130); elide: Text.ElideRight
                        text: (modelData.isPlaying ? "♪ " : "") + Media.playerName(modelData) }
                onClicked: Media.choose(modelData)
            }
        }
    }
    Row {
        id: ctrls
        anchors { right: parent.right; bottom: parent.bottom }
        visible: Media.present
        height: 26
        spacing: 2
        // picture in picture: pop the player out (a PiP already up: next corner; right-click puts it back)
        HoverTarget {
            width: 28; height: 26
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => { if (m.button === Qt.RightButton) Pip.back(); else if (Pip.active) Pip.corner("next"); else Pip.popPlayer(); }
            LIcon { anchors.centerIn: parent; icon: Pip.active ? "picture_in_picture_alt" : "picture_in_picture"; size: 17; color: Pip.active ? Theme.accent : Theme.textMuted }
        }
        // where it plays: click for the next output
        HoverTarget {
            visible: Audio.sinks.length > 1
            width: 28; height: 26
            onClicked: {
                const s = Audio.sinks, i = s.indexOf(Audio.sink);
                const next = s[(i + 1) % s.length];
                Audio.setSink(next);
                Island.system("speaker", "Playing on " + Audio.label(next), "");
            }
            LIcon { anchors.centerIn: parent; icon: /bluez|head|buds/i.test((Audio.sink?.name ?? "") + Audio.deviceName) ? "headphones" : "speaker"; size: 17; color: Theme.textMuted }
        }
        // sleep timer: 15 → 30 → 60 min → off
        HoverTarget {
            width: Media.sleepLeft ? slRow.implicitWidth + 12 : 28; height: 26
            onClicked: Media.sleepCycle()
            Row { id: slRow; anchors.centerIn: parent; spacing: 2
                  LIcon { icon: "bedtime"; size: 16; color: Media.sleepLeft ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                  LText { visible: Media.sleepLeft > 0; role: "caption"; color: Theme.accent; text: Media.sleepLeft + "m"; anchors.verticalCenter: parent.verticalCenter } }
        }
        HoverTarget {
            id: lyricsChip
            visible: Lyrics.available
            width: lyRow.implicitWidth + 16; height: 24
            anchors.verticalCenter: parent.verticalCenter
            onClicked: Lyrics.mode = !Lyrics.mode
            Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                        color: Lyrics.mode ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                        border.width: 1; border.color: Lyrics.mode ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border }
            Row { id: lyRow; anchors.centerIn: parent; spacing: 4
                  LIcon { icon: "lyrics"; size: 14; color: Lyrics.mode ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                  LText { role: "caption"; text: "Lyrics"; color: Lyrics.mode ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter } }
        }
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
        anchors { left: vinyl.right; leftMargin: Theme.space.s3; right: controls.left; rightMargin: Theme.space.s2; verticalCenter: art.verticalCenter }
        spacing: 2
        LText { width: parent.width; role: "heading"; text: Media.title || "Nothing playing"; elide: Text.ElideRight }
        LText { width: parent.width; role: "body"; color: Theme.textSecondary; text: Media.artist; elide: Text.ElideRight; visible: text !== "" }
        // The line being sung, softly (hidden while the full lyrics are open)
        LText {
            width: parent.width
            visible: !root.showLyrics && Lyrics.state === "synced" && text !== ""
            role: "caption"
            color: Theme.withAlpha(Media.hasTint ? Qt.lighter(Media.tint, 1.35) : Theme.accent, 0.9)
            elide: Text.ElideRight
            text: Lyrics.current ? "♪  " + Lyrics.current : ""
        }
    }

    // ── Lyrics ──
    Item {
        id: lyricsView
        visible: root.showLyrics
        anchors { left: parent.left; right: parent.right; top: art.bottom; topMargin: Theme.space.s3 }
        height: 92
        clip: true

        // Synced: three lines, the sung one bright and centred; they glide up
        ListView {
            id: lines
            anchors.fill: parent
            visible: Lyrics.state === "synced"
            model: Lyrics.state === "synced" ? Lyrics.lines : []
            interactive: false
            currentIndex: Math.max(0, Lyrics.index)
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: height / 2 - 15
            preferredHighlightEnd: height / 2 + 15
            highlightMoveDuration: Theme.reducedMotion ? 0 : 420
            highlightMoveVelocity: -1
            delegate: Item {
                required property var modelData
                required property int index
                readonly property int dist: Math.abs(index - Lyrics.index)
                readonly property bool isNow: index === Lyrics.index
                width: lines.width
                height: 30
                LText {
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    text: modelData.text || "♪"
                    font.pixelSize: isNow ? 17 : 13
                    font.weight: isNow ? Font.DemiBold : Font.Normal
                    color: isNow ? Theme.text : Theme.textMuted
                    opacity: isNow ? 1 : dist === 1 ? 0.7 : 0.3
                    Behavior on font.pixelSize { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.motion.normal } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                }
            }
        }

        // Plain lyrics (no timing): scroll through them yourself
        Flickable {
            anchors.fill: parent
            visible: Lyrics.state === "plain"
            contentHeight: plainCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: plainCol
                width: parent.width
                spacing: 4
                LText { role: "caption"; color: Theme.textMuted; text: "Lyrics without timing" }
                LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary; text: Lyrics.plain; verticalAlignment: Text.AlignTop }
            }
        }

        LText {
            anchors.centerIn: parent
            visible: Lyrics.state === "instrumental"
            color: Theme.textMuted
            text: "♪  Instrumental"
        }
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
            color: "transparent"
            Behavior on height { NumberAnimation { duration: Theme.motion.micro } }
            property real played: width * parent.frac
            Behavior on played { NumberAnimation { duration: 1000; easing.type: Easing.Linear } }
            // the rest of the song: a quiet straight line
            Rectangle { x: track.played + 4; width: Math.max(0, track.width - track.played - 4); height: track.height; radius: track.radius
                        anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceHover }
            // what's played: a line that ripples while it plays and lies flat when paused
            Canvas {
                id: wave
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(0, track.played) + 2; height: 14
                property real amp: Media.playing && !Theme.reducedMotion && !seek.containsMouse ? 2.4 : 0
                Behavior on amp { NumberAnimation { duration: Theme.motion.large } }
                property real phase: 0
                NumberAnimation on phase { running: wave.amp > 0 && root.visible; from: 0; to: 2 * Math.PI; duration: 1400; loops: Animation.Infinite }
                onPhaseChanged: requestPaint()
                onAmpChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d");
                    g.reset();
                    g.lineWidth = track.height;
                    g.lineCap = "round";
                    g.strokeStyle = Media.hasTint ? Qt.lighter(Media.tint, 1.35) : Theme.text;
                    g.beginPath();
                    const mid = height / 2, end = width - track.height / 2;
                    for (let x = track.height / 2; x <= end; x += 2) {
                        const y = mid + amp * Math.sin(x / 5.5 - phase);
                        if (x === track.height / 2) g.moveTo(x, y); else g.lineTo(x, y);
                    }
                    g.stroke();
                }
            }
            // the playhead
            Rectangle { x: track.played - width / 2 + 1; anchors.verticalCenter: parent.verticalCenter; width: 4; height: 12; radius: 2
                        color: Media.hasTint ? Qt.lighter(Media.tint, 1.35) : Theme.text; visible: track.parent.frac > 0 }
            // hover: the time you'd jump to
            Rectangle {
                visible: seek.containsMouse && Media.canSeek
                x: Math.max(0, Math.min(track.width - width, seek.mouseX - 6 - width / 2)); y: -24
                width: tip.implicitWidth + 10; height: 18; radius: 9
                color: Theme.surfaceElevated; border.width: 1; border.color: Theme.border
                LText { id: tip; anchors.centerIn: parent; role: "caption"
                        text: Media.formatTime(Media.length * Math.max(0, Math.min(1, (seek.mouseX - 6) / track.width))) }
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
