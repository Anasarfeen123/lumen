// Music picture-in-picture (services/MusicApp.qml): a small player that stays
// on top in a corner, across workspaces, for whatever's playing — ytm-rs or
// any other player (MPRIS).
//   Opens: hide the music scratchpad while music plays (Settings → Sound),
//   Ctrl+Super+P on the music app, Halo "mini player".
//   double-click or ⤢: the full app (the music scratchpad) · ×: close
//   drag: move (snaps to a corner) · scroll: volume · the line: seek
// The song's current lyric line shows under the title when lyrics are on.
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
    readonly property bool showing: MusicApp.pipVisible && mine
    property real shown: showing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: win.showing ? Easing.OutBack : Easing.InQuad } }

    visible: showing || shown > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-music-pip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: card }

    readonly property var player: Media.active
    readonly property bool playing: Media.playing
    readonly property bool canSeek: (player?.canSeek ?? false) && (player?.positionSupported ?? false)
    readonly property real length: player?.length ?? 0
    property real pos: 0
    Timer { interval: 500; repeat: true; running: win.showing; triggeredOnStart: true; onTriggered: if (!scrub.pressed) win.pos = win.player?.position ?? 0 }
    readonly property string lyric: (Lyrics.enabled && Lyrics.state === "synced") ? Lyrics.current : ""

    // corner geometry (clear of the bar at the top)
    readonly property string corner: MusicApp.pipCorner
    readonly property int gap: 20
    readonly property int topGap: 58
    function homeX(c) { return c[1] === "l" ? gap : width - card.width - gap; }
    function homeY(c) { return c[0] === "t" ? topGap : height - card.height - gap; }

    Item {
        id: card
        width: 360; height: win.lyric ? 118 : 100
        x: win.homeX(win.corner); y: win.homeY(win.corner)
        Behavior on x { enabled: !drag.drag.active; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on y { enabled: !drag.drag.active; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on height { NumberAnimation { duration: Theme.motion.normal } }
        opacity: win.shown
        scale: 0.86 + 0.14 * win.shown
        transformOrigin: win.corner === "br" ? Item.BottomRight : win.corner === "bl" ? Item.BottomLeft : win.corner === "tl" ? Item.TopLeft : Item.TopRight

        RectangularShadow { anchors.fill: parent; radius: 18; blur: 28; spread: 0; color: Theme.withAlpha(Theme.scrim, 0.45); offset.y: 6 }
        // the cover, blurred, behind a tint of the theme
        Item {
            id: back
            anchors.fill: parent
            visible: false
            Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(96, 96); asynchronous: true }
        }
        Item { id: roundMask; anchors.fill: parent; layer.enabled: true; visible: false; Rectangle { anchors.fill: parent; radius: 18 } }
        Rectangle { anchors.fill: parent; radius: 18; color: Theme.surface }
        MultiEffect { anchors.fill: parent; source: back; blurEnabled: true; blur: 1; blurMax: 48; saturation: 0.2
                      maskEnabled: true; maskSource: roundMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1; opacity: Media.artUrl ? 0.55 : 0 }
        Rectangle { anchors.fill: parent; radius: 18; color: Theme.withAlpha(Theme.surface, 0.62); border.width: 1; border.color: Theme.border }

        // drag to move · double-click: the full app · scroll: volume
        MouseArea {
            id: drag
            anchors.fill: parent
            cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
            drag.target: card
            drag.threshold: 6
            onDoubleClicked: MusicApp.openApp()
            onReleased: if (drag.drag.active || Math.abs(card.x - win.homeX(win.corner)) > 2 || Math.abs(card.y - win.homeY(win.corner)) > 2) {
                MusicApp.pipCorner = (card.y + card.height / 2 < win.height / 2 ? "t" : "b") + (card.x + card.width / 2 < win.width / 2 ? "l" : "r");
                card.x = Qt.binding(() => win.homeX(win.corner));
                card.y = Qt.binding(() => win.homeY(win.corner));
            }
            onWheel: w => { if (win.player?.volumeSupported) win.player.volume = Math.max(0, Math.min(1, win.player.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))); }
        }

        // cover
        Item {
            id: cover
            x: 12; y: 12; width: 76; height: 76
            Image { id: art; anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(152, 152); asynchronous: true; visible: false }
            Item { id: artMask; anchors.fill: parent; layer.enabled: true; visible: false; Rectangle { anchors.fill: parent; radius: 12 } }
            Rectangle { anchors.fill: parent; radius: 12; color: Theme.withAlpha(Theme.text, 0.08)
                        LIcon { anchors.centerIn: parent; visible: !Media.artUrl; icon: "music_note"; size: 30; color: Theme.textMuted } }
            MultiEffect { anchors.fill: parent; source: art; maskEnabled: true; maskSource: artMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1; visible: !!Media.artUrl }
        }

        // what's playing
        Column {
            anchors { left: cover.right; leftMargin: 12; right: tools.left; rightMargin: 4; top: parent.top; topMargin: 12 }
            spacing: 1
            LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: Media.title }
            LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: Media.artist || Media.playerName(win.player) }
            LText { visible: win.lyric !== ""; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.accent; topPadding: 2; text: "♪ " + win.lyric }
        }
        // the full app · close
        Row {
            id: tools
            anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 6 }
            Btn { icon: "open_in_full"; size: 15; tip: "Open " + Media.playerName(win.player); onClicked: MusicApp.openApp() }
            Btn { icon: "close"; size: 16; tip: "Close"; onClicked: MusicApp.closePip() }
        }

        // previous · play/pause · next
        Row {
            anchors { left: cover.right; leftMargin: 6; bottom: track.top; bottomMargin: 2 }
            spacing: 2
            Btn { icon: "skip_previous"; size: 22; fill: true; enabled: win.player?.canGoPrevious ?? false; onClicked: win.player.previous() }
            Btn { icon: win.playing ? "pause" : "play_arrow"; size: 26; fill: true; onClicked: if (win.player?.canTogglePlaying) win.player.togglePlaying() }
            Btn { icon: "skip_next"; size: 22; fill: true; enabled: win.player?.canGoNext ?? false; onClicked: win.player.next() }
        }
        LText {
            anchors { right: parent.right; rightMargin: 14; bottom: track.top; bottomMargin: 9 }
            visible: win.length > 0
            role: "caption"; color: Theme.textMuted; font.features: ({ "tnum": 1 })
            text: Media.formatTime(scrub.pressed ? scrub.at * win.length : win.pos) + " / " + Media.formatTime(win.length)
        }

        // the seek line
        Item {
            id: track
            anchors { left: cover.right; leftMargin: 12; right: parent.right; rightMargin: 14; bottom: parent.bottom; bottomMargin: win.lyric ? 14 : 12 }
            height: 6
            visible: win.length > 0
            readonly property real frac: scrub.pressed ? scrub.at : Math.min(1, win.pos / Math.max(1, win.length))
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: scrub.containsMouse || scrub.pressed ? 6 : 4; radius: height / 2; color: Theme.withAlpha(Theme.text, 0.14) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * track.frac; height: scrub.containsMouse || scrub.pressed ? 6 : 4; radius: height / 2; color: Theme.accent }
            MouseArea {
                id: scrub
                anchors { fill: parent; topMargin: -8; bottomMargin: -8 }
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
        }
    }

    component Btn: MouseArea {
        id: b
        property string icon
        property int size: 18
        property bool fill: false
        property string tip: ""
        width: size + 12; height: size + 12
        hoverEnabled: true
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        opacity: enabled ? 1 : 0.35
        Rectangle { anchors.fill: parent; radius: width / 2; color: b.containsMouse ? Theme.withAlpha(Theme.text, 0.1) : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        LIcon { anchors.centerIn: parent; icon: b.icon; size: b.size; color: Theme.text; fill: b.fill ? 1 : 0 }
        scale: pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
        Rectangle {
            visible: b.containsMouse && b.tip !== ""
            anchors { top: parent.bottom; topMargin: 2; horizontalCenter: parent.horizontalCenter }
            width: bt.implicitWidth + 10; height: 18; radius: 9; z: 10
            color: Theme.withAlpha(Theme.scrim, 0.75)
            LText { id: bt; anchors.centerIn: parent; role: "caption"; color: Theme.onMedia; text: b.tip }
        }
    }
}
