// Video picture-in-picture (services/Pip.qml): a live copy of just the video,
// cropped out of its window, in a small rounded player in a corner.
//   click: play/pause · double-click or ⤢: back to the video · ×: close
//   hover (move the pointer): controls — previous/next when the page offers
//   them, ±10 s, a scrubber you can drag, the app's sound (click: mute,
//   scroll: volume) · drag: move (snaps to a corner) · scroll or drag an
//   inner edge: size
// Clicks never reach the browser: the controls drive the window's own player
// over MPRIS (matched by its process), and its sound through PipeWire.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool mine: Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Pip.videoShown && mine
    property real shown: showing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.normal : Theme.motion.fast); easing.type: win.showing ? Easing.OutBack : Easing.InQuad } }

    visible: showing || shown > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-pip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: card }

    // the source window and the part of it that's the video
    readonly property var src: Pip.videoTop
    readonly property var srcSize: src?.lastIpcObject?.size ?? [16, 9]
    readonly property var crop: Pip.videoCrop ?? { x: 0, y: 0, w: 1, h: 1 }
    readonly property real aspect: Math.max(0.5, Math.min(2.6, (srcSize[0] * crop.w) / Math.max(1, srcSize[1] * crop.h)))
    readonly property var player: Pip.video?.player ?? null

    // corner geometry (clear of the bar at the top)
    readonly property int gap: 20
    readonly property int topGap: 58
    readonly property real cardW: {
        let w = width * Pip.vSize;
        if (w / aspect > height * 0.5) w = height * 0.5 * aspect;
        return Math.round(w);
    }
    readonly property real cardH: Math.round(cardW / aspect)
    function homeX(c) { return c[1] === "l" ? gap : width - cardW - gap; }
    function homeY(c) { return c[0] === "t" ? topGap : height - cardH - gap; }

    // tell the service where the player is, so measuring the video leaves it out
    Binding { target: Pip; property: "cardRect"; when: win.showing; value: Qt.rect((win.screen?.x ?? 0) + card.x, (win.screen?.y ?? 0) + card.y, card.width, card.height) }

    Item {
        id: card
        width: win.cardW; height: win.cardH
        x: win.homeX(Pip.vCorner); y: win.homeY(Pip.vCorner)
        Behavior on x { enabled: !drag.drag.active; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on y { enabled: !drag.drag.active; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on width { NumberAnimation { duration: Theme.motion.fast } }
        Behavior on height { NumberAnimation { duration: Theme.motion.fast } }
        opacity: win.shown
        scale: 0.86 + 0.14 * win.shown * (drag.drag.active ? 1.03 : 1)
        transformOrigin: Pip.vCorner === "br" ? Item.BottomRight : Pip.vCorner === "bl" ? Item.BottomLeft : Pip.vCorner === "tl" ? Item.TopLeft : Item.TopRight

        // soft shadow, then the picture in a rounded mask
        RectangularShadow { anchors.fill: parent; radius: 16; blur: 28; spread: 0; color: Theme.withAlpha("#000000", 0.45); offset.y: 6 }
        Rectangle { anchors.fill: parent; radius: 16; color: "#000000" }
        Item {
            id: picture
            anchors.fill: parent
            visible: false
            ScreencopyView {
                id: view
                captureSource: win.showing ? win.src?.wayland ?? null : null
                live: true
                width: picture.width / win.crop.w
                height: picture.height / win.crop.h
                x: -win.crop.x * width
                y: -win.crop.y * height
                constraintSize: Qt.size(width, height)
            }
        }
        Item {
            id: roundMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: 16 }
        }
        MultiEffect { anchors.fill: parent; source: picture; maskEnabled: true; maskSource: roundMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
        Rectangle { anchors.fill: parent; radius: 16; color: "transparent"; border.width: 1; border.color: Theme.withAlpha("#ffffff", 0.12) }

        // still finding the video, or the window can't be shown
        LIcon { anchors.centerIn: parent; visible: !view.hasContent; icon: "smart_display"; size: 32; color: Theme.withAlpha("#ffffff", 0.5) }

        // ── showing the controls: while the pointer is over it and has moved in
        // the last couple of seconds (or it's paused); a passive hover, so
        // reaching for a button never hides them ──
        // (the live picture makes Qt send hover updates every frame: only real movement counts)
        HoverHandler {
            id: hov
            property point last: Qt.point(-1, -1)
            onPointChanged: {
                const p = point.position;
                if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) < 3) return;
                last = p; win.moved = true; idle.restart();
            }
        }
        Timer { id: idle; interval: 2200; onTriggered: win.moved = false }

        // the picture itself: click play/pause · double-click back to the video ·
        // drag to move (snaps to a corner) · scroll to resize
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            drag.target: card
            drag.threshold: 6
            onClicked: if (!drag.drag.active) single.restart()
            onDoubleClicked: { single.stop(); Pip.backToVideo(); }
            onReleased: if (drag.drag.active || Math.abs(card.x - win.homeX(Pip.vCorner)) > 2 || Math.abs(card.y - win.homeY(Pip.vCorner)) > 2) {
                const c = (card.y + card.height / 2 < win.height / 2 ? "t" : "b") + (card.x + card.width / 2 < win.width / 2 ? "l" : "r");
                Pip.moveVideo(c);
                card.x = Qt.binding(() => win.homeX(Pip.vCorner));
                card.y = Qt.binding(() => win.homeY(Pip.vCorner));
            }
            onWheel: w => Pip.resizeVideo(Pip.vSize + (w.angleDelta.y > 0 ? 0.02 : -0.02))
            Timer { id: single; interval: 230; onTriggered: win.togglePlay() }
        }

        // a quick sign of what a click did, in the middle
        Rectangle {
            id: flash
            anchors.centerIn: parent
            width: 64; height: 64; radius: 32
            color: Theme.withAlpha("#000000", 0.45)
            opacity: 0; scale: 0.8
            property string icon: "play_arrow"
            LIcon { anchors.centerIn: parent; icon: flash.icon; size: 36; color: "#ffffff"; fill: 1 }
            ParallelAnimation {
                id: flashAnim
                NumberAnimation { target: flash; property: "opacity"; from: 1; to: 0; duration: 600; easing.type: Easing.InQuad }
                NumberAnimation { target: flash; property: "scale"; from: 0.8; to: 1.25; duration: 600; easing.type: Easing.OutCubic }
            }
        }

        // ── controls ──
        Item {
            id: controls
            anchors.fill: parent
            readonly property bool on: hov.hovered && !drag.drag.active && (win.moved || !win.playing || scrub.pressed || edgeX.pressed || edgeY.pressed)
            opacity: on ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: controls.on ? 120 : 380 } }
            readonly property bool roomy: card.width >= 300
            readonly property bool tiny: card.width < 230

            Rectangle {
                anchors.fill: parent; radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.withAlpha("#000000", 0.62) }
                    GradientStop { position: 0.3; color: Theme.withAlpha("#000000", 0.18) }
                    GradientStop { position: 0.62; color: Theme.withAlpha("#000000", 0.18) }
                    GradientStop { position: 1; color: Theme.withAlpha("#000000", 0.72) }
                }
            }

            // top: back to the video · what's playing · close
            Row {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 2
                Btn { icon: "open_in_full"; size: 17; tip: "Back to the video"; onClicked: Pip.backToVideo() }
                LText {
                    width: parent.width - 2 * 31 - 4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !controls.tiny
                    role: "caption"; color: Theme.withAlpha("#ffffff", 0.92); elide: Text.ElideRight
                    text: win.player?.trackTitle ?? ""
                    style: Text.Raised; styleColor: Theme.withAlpha("#000000", 0.5)
                    horizontalAlignment: Text.AlignHCenter
                }
                Item { width: controls.tiny ? parent.width - 2 * 31 - 2 : 0; height: 1 }
                Btn { icon: "close"; size: 18; tip: "Close"; onClicked: Pip.closeVideo() }
            }

            // middle: previous · back 10 · play/pause · forward 10 · next
            Row {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: controls.tiny ? 2 : -2
                spacing: controls.tiny ? 4 : Math.max(6, card.width * 0.03)
                Btn { icon: "skip_previous"; size: 24; fill: true; visible: win.player?.canGoPrevious ?? false; onClicked: win.player.previous() }
                Btn { icon: "replay_10"; size: 24; visible: win.canSeek && controls.roomy; onClicked: win.seekBy(-10) }
                MouseArea {
                    width: controls.tiny ? 44 : 54; height: width
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: win.togglePlay()
                    Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.withAlpha("#000000", parent.containsMouse ? 0.55 : 0.42)
                                border.width: 1; border.color: Theme.withAlpha("#ffffff", 0.22)
                                Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
                    LIcon { anchors.centerIn: parent; icon: win.playing ? "pause" : "play_arrow"; size: parent.width * 0.58; color: "#ffffff"; fill: 1 }
                    scale: pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
                }
                Btn { icon: "forward_10"; size: 24; visible: win.canSeek && controls.roomy; onClicked: win.seekBy(10) }
                Btn { icon: "skip_next"; size: 24; fill: true; visible: win.player?.canGoNext ?? false; onClicked: win.player.next() }
            }

            // bottom: times · sound · the scrubber
            Item {
                id: bottom
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 12; rightMargin: 8; bottomMargin: 8 }
                height: 34
                LText {
                    anchors { left: parent.left; top: parent.top; topMargin: 2 }
                    visible: win.length > 0
                    role: "caption"; color: "#ffffff"
                    font.features: ({ "tnum": 1 })
                    style: Text.Raised; styleColor: Theme.withAlpha("#000000", 0.5)
                    text: Media.formatTime(scrub.pressed ? scrub.at * win.length : win.pos) + "  /  " + Media.formatTime(win.length)
                }
                // sound: click to mute that app · scroll for its volume
                Btn {
                    id: sound
                    anchors { right: parent.right; top: parent.top; topMargin: -8 }
                    visible: !!win.audio
                    size: 18
                    icon: !win.audio ? "volume_up" : Audio.groupMuted(win.audio) ? "volume_off" : Audio.groupVolume(win.audio) < 0.4 ? "volume_down" : "volume_up"
                    tip: win.audio ? win.audio.name + " · " + Math.round(Audio.groupVolume(win.audio) * 100) + "%" : ""
                    onClicked: Audio.toggleGroupMute(win.audio)
                    onWheel: w => Audio.setGroupVolume(win.audio, Audio.groupVolume(win.audio) + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                }
                // the scrubber: hover to see a time, click or drag to go there
                Item {
                    id: track
                    anchors { left: parent.left; right: parent.right; rightMargin: 4; bottom: parent.bottom }
                    height: 6
                    visible: win.length > 0
                    readonly property real frac: scrub.pressed ? scrub.at : Math.min(1, win.pos / Math.max(1, win.length))
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: scrub.containsMouse || scrub.pressed ? 6 : 4; radius: height / 2
                                color: Theme.withAlpha("#ffffff", 0.28); Behavior on height { NumberAnimation { duration: Theme.motion.micro } } }
                    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * track.frac; height: scrub.containsMouse || scrub.pressed ? 6 : 4; radius: height / 2
                                color: Theme.accent; Behavior on height { NumberAnimation { duration: Theme.motion.micro } } }
                    Rectangle { x: parent.width * track.frac - width / 2; anchors.verticalCenter: parent.verticalCenter
                                width: 14; height: 14; radius: 7; color: "#ffffff"; visible: win.canSeek
                                scale: scrub.containsMouse || scrub.pressed ? 1 : 0; Behavior on scale { NumberAnimation { duration: Theme.motion.micro } } }
                    MouseArea {
                        id: scrub
                        anchors { fill: parent; topMargin: -10; bottomMargin: -8 }
                        enabled: win.canSeek
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        property real at: 0
                        function frac(x) { return Math.max(0, Math.min(1, x / track.width)); }
                        onPressed: m => at = frac(m.x)
                        onPositionChanged: m => { if (pressed) at = frac(m.x); }
                        onReleased: { win.player.position = at * win.length; win.pos = at * win.length; }
                    }
                    // the time under the pointer
                    Rectangle {
                        visible: scrub.containsMouse && !scrub.pressed
                        x: Math.max(0, Math.min(track.width - width, scrub.mouseX - width / 2)); y: -26
                        width: tipText.implicitWidth + 10; height: 18; radius: 9
                        color: Theme.withAlpha("#000000", 0.75)
                        LText { id: tipText; anchors.centerIn: parent; role: "caption"; color: "#ffffff"; text: Media.formatTime(scrub.frac(scrub.mouseX) * win.length) }
                    }
                }
            }

        }

        // resize handles: the two edges facing the middle of the screen
        MouseArea {
            id: edgeX
            width: 8; height: parent.height - 40; anchors.verticalCenter: parent.verticalCenter
            x: Pip.vCorner[1] === "r" ? -3 : parent.width - 5
            cursorShape: Qt.SizeHorCursor
            preventStealing: true
            onPositionChanged: m => { if (!pressed) return; const p = mapToItem(null, m.x, 0).x; win.resizeTo(Pip.vCorner[1] === "r" ? card.x + card.width - p : p - card.x); }
        }
        MouseArea {
            id: edgeY
            height: 8; width: parent.width - 40; anchors.horizontalCenter: parent.horizontalCenter
            y: Pip.vCorner[0] === "b" ? -3 : parent.height - 5
            cursorShape: Qt.SizeVerCursor
            preventStealing: true
            onPositionChanged: m => { if (!pressed) return; const p = mapToItem(null, 0, m.y).y; win.resizeTo((Pip.vCorner[0] === "b" ? card.y + card.height - p : p - card.y) * win.aspect); }
        }
    }

    // playback, over MPRIS (the window's own player)
    readonly property bool playing: player?.isPlaying ?? false
    readonly property bool canSeek: (player?.canSeek ?? false) && (player?.positionSupported ?? false)
    readonly property real length: player?.length ?? 0
    property real pos: 0
    property bool moved: false
    function togglePlay() {
        if (!player?.canTogglePlaying) return;
        flash.icon = playing ? "pause" : "play_arrow";
        player.togglePlaying();
        flashAnim.restart();
    }
    function seekBy(s) {
        if (!canSeek) return;
        player.position = Math.max(0, Math.min(length - 1, player.position + s));
        pos = player.position;
        flash.icon = s < 0 ? "replay_10" : "forward_10";
        flashAnim.restart();
    }
    function resizeTo(w) { Pip.resizeVideo(Math.max(180, w) / width); }
    Timer { interval: 250; repeat: true; running: win.showing; triggeredOnStart: true; onTriggered: if (!scrub.pressed) win.pos = win.player?.position ?? 0 }
    // its sound, for mute and volume (Chromium ignores volume over MPRIS): the app's audio streams
    readonly property var audio: {
        const cls = (src?.lastIpcObject?.class ?? "").toLowerCase().replace(/^(org|com|io)\.[^.]+\./, "");
        const key = cls.split(/[-_.]/)[0];
        return key.length > 2 ? (Audio.appGroups.find(g => (g.name + " " + g.binary).toLowerCase().includes(key)) ?? null) : null;
    }

    component Btn: MouseArea {
        id: b
        property string icon
        property int size: 18
        property bool fill: false
        property string tip: ""
        width: size + 13; height: size + 13
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // a dark disc behind every icon, so it reads on a bright picture
        Rectangle { anchors.fill: parent; radius: width / 2
                    color: b.containsMouse ? Theme.withAlpha("#000000", 0.55) : Theme.withAlpha("#000000", 0.28)
                    border.width: b.containsMouse ? 1 : 0; border.color: Theme.withAlpha("#ffffff", 0.2)
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        LIcon { anchors.centerIn: parent; icon: b.icon; size: b.size; color: "#ffffff"; fill: b.fill ? 1 : 0 }
        scale: pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
        // a small label under it while hovered
        Rectangle {
            visible: b.containsMouse && b.tip !== ""
            anchors { top: parent.bottom; topMargin: 2; horizontalCenter: parent.horizontalCenter }
            width: bt.implicitWidth + 10; height: 18; radius: 9; z: 10
            color: Theme.withAlpha("#000000", 0.75)
            LText { id: bt; anchors.centerIn: parent; role: "caption"; color: "#ffffff"; text: b.tip }
        }
    }
}
