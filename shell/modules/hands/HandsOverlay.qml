// Halo's hands, drawn (services/Hands.qml). Click-through except the bubble
// that asks first. On the screen where it's acting:
//   the spot       rings that pulse round the target, its name in a pill
//   the ride       a small Halo glides along beside your cursor while it moves
//   the question   "Click “Download”?" · Allow · Allow for 2 min · Cancel
//                  (Enter allows, Esc cancels) — keys and typing ask the same way
//   the reminder   "Halo has your mouse — move it to take over" while it acts
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
    readonly property real ox: screen?.x ?? 0
    readonly property real oy: screen?.y ?? 0
    readonly property var t: Hands.target
    // Where things happen: the target's screen, else (keys, typing) the focused one
    readonly property bool here: {
        if (!t) return false;
        if (t.kind === "key" || t.kind === "type" || t.kind === "scroll")
            return Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "");
        return t.x >= ox && t.x < ox + (screen?.width ?? 0) && t.y >= oy && t.y < oy + (screen?.height ?? 0);
    }
    readonly property bool spot: here && ["point", "click", "done"].includes(t.kind)
    readonly property real lx: t ? t.x - ox : 0
    readonly property real ly: t ? t.y - oy : 0

    visible: here || companion.opacity > 0.01 || banner.opacity > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-hands"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: here && Hands.asking ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: here && Hands.asking ? bubble : nothing }
    Item { id: nothing; width: 0; height: 0 }

    // ── the spot ──
    Item {
        id: mark
        visible: win.spot
        x: win.lx; y: win.ly
        readonly property real r: Math.max(26, Math.min(70, Math.max(win.t?.w ?? 0, win.t?.h ?? 0) * 0.62))
        // the target itself, softly lit (text or a window's frame)
        Rectangle {
            visible: (win.t?.w ?? 0) > 0
            x: -width / 2; y: -height / 2
            width: (win.t?.w ?? 0) + 16; height: (win.t?.h ?? 0) + 12
            radius: Math.min(14, height / 2)
            color: Theme.withAlpha(Theme.accent, win.t?.kind === "done" ? 0.3 : 0.12)
            border.width: 2; border.color: Theme.withAlpha(Theme.accent, 0.85)
            Behavior on color { ColorAnimation { duration: 160 } }
            scale: 0.9
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.8; shadowOpacity: 0.7; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        }
        // rings going out from it
        Repeater {
            model: 2
            Rectangle {
                id: wave
                required property int index
                x: -width / 2; y: -height / 2
                width: mark.r * 2; height: width; radius: width / 2
                color: "transparent"
                border.width: 2; border.color: Theme.accent
                opacity: 0
                SequentialAnimation {
                    running: mark.visible && !Theme.reducedMotion
                    loops: Animation.Infinite
                    PauseAnimation { duration: wave.index * 600 }
                    ParallelAnimation {
                        NumberAnimation { target: wave; property: "scale"; from: 0.35; to: 1.15; duration: 1200; easing.type: Easing.OutCubic }
                        NumberAnimation { target: wave; property: "opacity"; from: 0.8; to: 0; duration: 1200; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
        // a click lands: one bright flash
        Rectangle {
            id: flash
            x: -width / 2; y: -height / 2
            width: 40; height: 40; radius: 20
            color: Theme.withAlpha(Theme.accent, 0.5)
            opacity: 0
            scale: 0.4
            Connections {
                target: Hands
                function onTargetChanged() { if (Hands.target?.kind === "done" && win.here) clickAnim.restart(); }
            }
            ParallelAnimation {
                id: clickAnim
                NumberAnimation { target: flash; property: "opacity"; from: 0.9; to: 0; duration: 520; easing.type: Easing.OutCubic }
                NumberAnimation { target: flash; property: "scale"; from: 0.4; to: 1.8; duration: 520; easing.type: Easing.OutCubic }
            }
        }
        // its name
        Rectangle {
            visible: (win.t?.label ?? "") !== "" && !Hands.asking
            x: -width / 2
            y: (win.t?.h ?? 0) / 2 + 14
            width: Math.min(320, nameRow.implicitWidth + 20); height: 28; radius: 14
            color: Theme.withAlpha(Theme.bg, 0.88)
            border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.5)
            Row {
                id: nameRow
                anchors.centerIn: parent
                spacing: 6
                LIcon { icon: win.t?.kind === "point" ? "near_me" : "ads_click"; size: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "caption"; text: win.t?.label ?? ""; elide: Text.ElideRight; width: Math.min(implicitWidth, 270); anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ── the ride: a small Halo beside your cursor while it glides ──
    HaloOrb {
        id: companion
        size: 22
        mood: Hands.driving ? "speaking" : "happy"
        face: Persist.data.haloFace ?? true
        opacity: 0
        Connections {
            target: Hands
            function onGlideIdChanged() {
                if (!win.here || !Hands.glideFrom || Theme.reducedMotion) return;
                companion.x = Hands.glideFrom.x - win.ox + 16; companion.y = Hands.glideFrom.y - win.oy - 34;
                ride.restart();
            }
        }
        SequentialAnimation {
            id: ride
            ScriptAction { script: companion.pop() }
            NumberAnimation { target: companion; property: "opacity"; to: 1; duration: 120 }
            ParallelAnimation {
                NumberAnimation { target: companion; property: "x"; to: win.lx + 16 + (win.t?.w ?? 0) / 2; duration: Hands.glideMs; easing.type: Easing.InOutCubic }
                NumberAnimation { target: companion; property: "y"; to: win.ly - 34 - (win.t?.h ?? 0) / 2; duration: Hands.glideMs; easing.type: Easing.InOutCubic }
            }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: companion; property: "opacity"; to: 0; duration: 260 }
        }
    }

    // ── the question ──
    Rectangle {
        id: bubble
        readonly property bool show: win.here && Hands.asking
        readonly property bool atSpot: win.t?.kind === "click"
        width: Math.min(440, win.width - 32)
        height: bCol.implicitHeight + Theme.space.s4 * 2
        radius: Theme.radius.lg
        // next to the target (below, or above when near the bottom); keys/typing: bottom centre
        x: atSpot ? Math.max(16, Math.min(win.width - width - 16, win.lx - width / 2)) : (win.width - width) / 2
        y: atSpot ? (win.ly + (win.t?.h ?? 0) / 2 + 24 + height < win.height - 16 ? win.ly + (win.t?.h ?? 0) / 2 + 24 : win.ly - (win.t?.h ?? 0) / 2 - 24 - height)
                  : win.height - height - 72
        color: Qt.tint(Theme.surface, Theme.withAlpha(Theme.bg, 0.25))
        border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.45)
        opacity: show ? 1 : 0
        scale: show ? 1 : 0.85
        transformOrigin: atSpot ? Item.Top : Item.Bottom
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: show ? 160 : 110 } }
        Behavior on scale { NumberAnimation { duration: bubble.show ? 320 : 120; easing.type: bubble.show ? Easing.OutBack : Easing.InCubic } }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1; shadowOpacity: 0.4; shadowVerticalOffset: 8; shadowHorizontalOffset: 0 }

        Column {
            id: bCol
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3
            Row {
                width: parent.width
                spacing: Theme.space.s3
                HaloOrb { id: askOrb; size: 34; mood: "rest"; lookY: bubble.atSpot && bubble.y > win.ly ? -0.8 : 0.6; face: Persist.data.haloFace ?? true; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: parent.width - askOrb.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    LText {
                        width: parent.width; wrapMode: Text.Wrap; role: "bodyStrong"; textFormat: Text.PlainText
                        text: !win.t ? "" : win.t.kind === "click" ? (win.t.button === "right" ? "Right-click" : win.t.button === "double" ? "Double-click" : "Click") + " “" + win.t.label + "”?"
                            : win.t.kind === "key" ? "Press " + win.t.combo + "?"
                            : win.t.kind === "type" ? "Type this?" : ""
                    }
                    LText {
                        width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted
                        text: win.t?.kind === "click" ? "I'll move your mouse there and click. Moving the mouse stops me."
                            : "Into " + (win.t?.window ? "“" + win.t.window.slice(0, 60) + "”" : "the focused window") + "."
                    }
                }
            }
            Rectangle {
                visible: win.t?.kind === "type"
                width: parent.width; height: visible ? Math.min(typed.implicitHeight, 110) + Theme.space.s3 * 2 : 0
                radius: Theme.radius.sm; color: Theme.withAlpha(Theme.accent, 0.1); clip: true
                LText { id: typed; x: Theme.space.s3; y: Theme.space.s3; width: parent.width - Theme.space.s3 * 2; wrapMode: Text.Wrap; textFormat: Text.PlainText; text: win.t?.text ?? "" }
            }
            Row {
                spacing: Theme.space.s2
                Pill { primary: true; icon: "check"; text: "Allow"; onClicked: Hands.allow(false) }
                Pill { icon: "timer"; text: "Allow for 2 min"; onClicked: Hands.allow(true) }
                Pill { icon: "close"; text: "Cancel"; onClicked: Hands.cancel() }
            }
        }
        Item {
            focus: bubble.show
            Keys.onReturnPressed: Hands.allow(false)
            Keys.onEnterPressed: Hands.allow(false)
            Keys.onEscapePressed: Hands.cancel()
        }
    }

    // ── the reminder while it acts ──
    Rectangle {
        id: banner
        readonly property bool show: win.here && (Hands.driving || Hands.trusted)
        anchors.horizontalCenter: parent.horizontalCenter
        y: show ? Theme.edgeGap + Theme.barHeight + Theme.space.s2 : Theme.edgeGap
        width: bnRow.implicitWidth + 28; height: 32; radius: 16
        color: Theme.withAlpha(Theme.bg, 0.9)
        border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.5)
        opacity: show ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
        Row {
            id: bnRow
            anchors.centerIn: parent
            spacing: 8
            HaloOrb { size: 18; mood: Hands.driving ? "speaking" : "rest"; breathes: false; face: Persist.data.haloFace ?? true; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "caption"; anchors.verticalCenter: parent.verticalCenter
                    text: Hands.driving ? "Halo has your mouse — move it to take over" : "Halo may act for " + Hands.trustLeft + " s more" }
        }
    }

    component Pill: HoverTarget {
        id: pl
        property string icon
        property string text
        property bool primary: false
        width: plRow.implicitWidth + 24; height: 32
        scale: pressed ? 0.95 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                    color: pl.primary ? Theme.accent : Theme.withAlpha(Theme.text, pl.containsMouse ? 0.12 : 0.07)
                    border.width: pl.primary ? 0 : 1; border.color: Theme.border }
        Row { id: plRow; anchors.centerIn: parent; spacing: 6
              LIcon { icon: pl.icon; size: 15; color: pl.primary ? Theme.onAccent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "bodyStrong"; text: pl.text; color: pl.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }
}
