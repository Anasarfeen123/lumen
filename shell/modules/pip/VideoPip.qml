// Video picture-in-picture (services/Pip.qml): a live copy of just the video,
// cropped out of its window, in a small rounded player in a corner.
//   hover: controls · drag: move (snaps to the nearest corner) · scroll: size
//   double-click or ⤢: back to the video · ×: close
// Clicks never reach the browser: the controls drive the player over MPRIS.
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

        MouseArea {
            id: drag
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
            drag.target: card
            drag.threshold: 6
            onReleased: if (drag.drag.active || Math.abs(card.x - win.homeX(Pip.vCorner)) > 2 || Math.abs(card.y - win.homeY(Pip.vCorner)) > 2) {
                const c = (card.y + card.height / 2 < win.height / 2 ? "t" : "b") + (card.x + card.width / 2 < win.width / 2 ? "l" : "r");
                Pip.moveVideo(c);
                card.x = Qt.binding(() => win.homeX(Pip.vCorner));
                card.y = Qt.binding(() => win.homeY(Pip.vCorner));
            }
            onDoubleClicked: Pip.backToVideo()
            onWheel: w => Pip.resizeVideo(Pip.vSize + (w.angleDelta.y > 0 ? 0.02 : -0.02))
        }

        // ── controls, on hover ──
        Item {
            id: controls
            anchors.fill: parent
            opacity: drag.containsMouse && !drag.drag.active ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.motion.fast } }
            Rectangle {
                anchors.fill: parent; radius: 16
                gradient: Gradient {
                    GradientStop { position: 0; color: Theme.withAlpha("#000000", 0.55) }
                    GradientStop { position: 0.35; color: Theme.withAlpha("#000000", 0.15) }
                    GradientStop { position: 0.65; color: Theme.withAlpha("#000000", 0.15) }
                    GradientStop { position: 1; color: Theme.withAlpha("#000000", 0.6) }
                }
            }
            Btn { anchors { left: parent.left; top: parent.top; margins: 8 } icon: "open_in_full"; size: 17; onClicked: Pip.backToVideo() }
            Btn { anchors { right: parent.right; top: parent.top; margins: 8 } icon: "close"; size: 18; onClicked: Pip.closeVideo() }
            Row {
                anchors.centerIn: parent
                spacing: Math.max(8, card.width * 0.05)
                Btn { icon: "replay_10"; size: 22; visible: win.canSeek; onClicked: win.seekBy(-10) }
                Btn { icon: (win.player?.isPlaying ?? false) ? "pause" : "play_arrow"; size: 34; fill: true; onClicked: if (win.player?.canTogglePlaying) win.player.togglePlaying() }
                Btn { icon: "forward_10"; size: 22; visible: win.canSeek; onClicked: win.seekBy(10) }
            }
            // where it is in the video
            Item {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                height: 16
                visible: win.length > 0
                LText {
                    anchors { left: parent.left; bottom: bar.top; bottomMargin: 4 }
                    role: "caption"; color: "#ffffff"
                    text: Media.formatTime(win.pos) + " / " + Media.formatTime(win.length)
                }
                Rectangle { id: bar; anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 3; radius: 1.5; color: Theme.withAlpha("#ffffff", 0.3)
                    Rectangle { width: parent.width * Math.min(1, win.pos / Math.max(1, win.length)); height: parent.height; radius: 1.5; color: Theme.accent } }
                MouseArea { anchors { fill: bar; topMargin: -6; bottomMargin: -4 } enabled: win.canSeek; cursorShape: Qt.PointingHandCursor
                            onClicked: m => { win.player.position = win.length * m.x / width; win.pos = win.player.position; } }
            }
        }
    }

    // playback, over MPRIS
    readonly property bool canSeek: (player?.canSeek ?? false) && (player?.positionSupported ?? false)
    readonly property real length: player?.length ?? 0
    property real pos: 0
    function seekBy(s) { if (!canSeek) return; player.position = Math.max(0, Math.min(length - 1, player.position + s)); pos = player.position; }
    Timer { interval: 500; repeat: true; running: win.showing && controls.visible; triggeredOnStart: true; onTriggered: win.pos = win.player?.position ?? 0 }

    component Btn: MouseArea {
        id: b
        property string icon
        property int size: 18
        property bool fill: false
        width: size + 14; height: size + 14
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.withAlpha("#ffffff", b.containsMouse ? 0.22 : 0.0)
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        LIcon { anchors.centerIn: parent; icon: b.icon; size: b.size; color: "#ffffff"; fill: b.fill ? 1 : 0 }
        scale: pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
    }
}
