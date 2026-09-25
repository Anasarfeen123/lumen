// The Dynamic Island — one per monitor, rendering what services/Island.qml
// decides. Events appear only on the focused monitor; others show the clock.
//
// Morph (DESIGN.md §8.3): the glass body springs to the new size while the
// content fades out → swaps → fades in once the shape is mostly there, so
// text never squashes. Only the island's own size animates.
//
// Pointer:  hover ≥300 ms → peek   ·   click → pin / act   ·   leave → collapse (250 ms)
// Keyboard: Super+M pins (focus grabbed) · Space play/pause · ←/→ prev/next · Esc close
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services
import "content"

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    // Single monitor: always the focused one (Hyprland sends no focus events).
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool fullscreenBelow: monitor?.activeWorkspace?.hasFullscreen ?? false
    // Mirrors the bar: when windows are open the pills merge into one bar and
    // the idle island becomes a flat clock inside it (no glass on glass).
    readonly property bool merged: (monitor?.activeWorkspace?.toplevels?.values?.length ?? 0) > 0
    // The island hands its glass to the bar the instant merging starts (the
    // bar begins at the island's exact shape), and takes it back only after
    // the bar has finished gliding home — so there is never a gap or a double.
    property bool mergedLook: merged
    onMergedChanged: {
        if (merged) { mergeRelease.stop(); mergedLook = true; }
        else mergeRelease.restart();
    }
    Timer { id: mergeRelease; interval: Theme.reducedMotion ? 0 : 400; onTriggered: win.mergedLook = false }
    // The overview's search field has taken the island's place
    readonly property bool handedOff: Overview.handoff && isFocused

    // Local hover intent: only the focused monitor's island feeds the controller.
    property bool hoverIntent: false
    readonly property string variant: isFocused ? Island.variant : (hoverIntent ? "idlePeek" : "idle")
    readonly property bool expanded: ["mediaExpanded", "notification", "critical"].includes(variant)

    // Over fullscreen apps, stay invisible unless something is actually happening.
    readonly property bool hidden: fullscreenBelow && ["idle", "idlePeek", "recording"].includes(variant)

    anchors.top: true
    color: "transparent"
    implicitWidth: Theme.island.expandedWidth + 2 * Theme.space.s8
    implicitHeight: Theme.edgeGap + Theme.island.mediaHeight + Theme.space.s8 + Theme.space.s4
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-island"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: (Island.pinned && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: win.hidden || win.handedOff ? emptyMask : body }
    Item { id: emptyMask; width: 0; height: 0 }

    // Unpin rules (a Hyprland focus grab proved unreliable here):
    //   Esc · click the island again · focus moves to a window · 6 s with the
    //   pointer away
    Connections {
        target: Hyprland
        enabled: Island.pinned && win.isFocused
        function onActiveToplevelChanged() { Island.unpin(); }
    }
    Timer {
        interval: 6000
        running: Island.pinned && win.isFocused && !Island.pointerInside
        onTriggered: Island.unpin()
    }

    // ── Content swap sequencing ──
    property string shown: variant
    property var shownData: Island.info
    onVariantChanged: {
        if (variant === shown) return;
        swap.restart();
    }
    Connections {
        target: Island
        // Same variant, new data (e.g. volume burst): update in place, no animation.
        function onInfoChanged() { if (win.variant === win.shown) win.shownData = Island.info; }
    }
    SequentialAnimation {
        id: swap
        NumberAnimation { target: loader; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 70 }
        ScriptAction { script: { win.shown = win.variant; win.shownData = Island.info; } }
        PauseAnimation { duration: Theme.reducedMotion ? 0 : 90 }
        NumberAnimation { target: loader; property: "opacity"; to: 1; duration: Theme.motion.micro; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
    }

    function componentFor(v) {
        return ({
            idle: idleC, idlePeek: peekC, osd: osdC, workspace: wsC, system: sysC,
            screenshot: shotC, recording: recC, mediaCompact: mediaCompactC,
            mediaExpanded: mediaExpandedC, notification: notifC, critical: critC
        })[v] ?? idleC;
    }

    Component { id: idleC; Idle {} }
    Component { id: peekC; IdlePeek {} }
    Component { id: osdC; Osd { info: win.shownData } }
    Component { id: wsC; Workspace { info: win.shownData } }
    Component { id: sysC; System { info: win.shownData } }
    Component { id: shotC; Screenshot { info: win.shownData } }
    Component { id: recC; Recording {} }
    Component { id: mediaCompactC; MediaCompact {} }
    Component { id: mediaExpandedC; MediaExpanded {} }
    Component { id: notifC; Notification { info: win.shownData } }
    Component { id: critC; Critical {} }

    // ── The body ──
    GlassSurface {
        id: body

        readonly property bool bodyExpanded: ["mediaExpanded", "notification", "critical"].includes(win.shown)
        readonly property int padX: bodyExpanded ? Theme.space.s4 : Theme.space.s4
        readonly property int padY: bodyExpanded ? Theme.space.s4 : 0
        readonly property real targetW: bodyExpanded
            ? Theme.island.expandedWidth
            : Math.min(Theme.island.maxCompactWidth,
                       Math.max(Theme.island.idleMinWidth, (loader.item?.implicitWidth ?? 0) + 2 * padX))
        readonly property real targetH: bodyExpanded
            ? (loader.item?.implicitHeight ?? 0) + 2 * padY
            : Theme.island.height

        level: bodyExpanded ? "panel" : "chrome"
        flat: win.mergedLook && win.shown === "idle"
        radius: Math.min(height / 2, Theme.radius.island)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.edgeGap
        visible: !win.handedOff
        width: targetW
        height: targetH
        opacity: win.hidden ? 0 : 1
        scale: mouse.pressed ? 0.98 : 1

        Behavior on width {
            enabled: !Theme.reducedMotion
            SpringAnimation { spring: Theme.motion.springStrength; damping: Theme.motion.springDamping; epsilon: 0.25 }
        }
        Behavior on height {
            enabled: !Theme.reducedMotion
            SpringAnimation { spring: Theme.motion.springStrength; damping: Theme.motion.springDamping; epsilon: 0.25 }
        }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }

        // Hover is tracked by a passive handler: it keeps seeing the pointer
        // while it is over buttons inside the content.
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: {
                if (win.isFocused) Island.pointerInside = hovered;
                if (hovered) { leaveTimer.stop(); enterTimer.restart(); }
                else { enterTimer.stop(); leaveTimer.restart(); }
            }
        }

        // Click layer sits UNDER the content so buttons inside win.
        MouseArea {
            id: mouse
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            onClicked: m => win.activate(m.button)
            onWheel: w => {
                // Scroll over the island = volume (brightness with Shift)
                const up = w.angleDelta.y > 0;
                if (w.modifiers & Qt.ShiftModifier) up ? Brightness.up() : Brightness.down();
                else Audio.nudge(up ? 0.05 : -0.05);
            }
        }

        MediaGlow {
            anchors.fill: parent
            radius: body.radius
            active: win.shown === "mediaExpanded" && !win.hidden
        }

        Spectrum {
            anchors.fill: parent
            active: Media.playing && win.shown === "idle" && !win.hidden
        }

        Loader {
            id: loader
            anchors.centerIn: parent
            width: item ? (body.bodyExpanded ? body.width - 2 * body.padX : item.implicitWidth) : 0
            height: item?.implicitHeight ?? 0
            sourceComponent: win.componentFor(win.shown)
        }

        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) Island.unpin();
            else if (event.key === Qt.Key_Space) Media.toggle();
            else if (event.key === Qt.Key_Right) Media.next();
            else if (event.key === Qt.Key_Left) Media.previous();
            else return;
            event.accepted = true;
        }
    }

    // Publish the focused island's shape for the overview morph
    Binding { when: win.isFocused; target: Island; property: "shapeWidth"; value: body.width }
    Binding { when: win.isFocused; target: Island; property: "shapeY"; value: body.y }

    // Hover intent — ignore the pointer passing over on its way somewhere else
    Timer { id: enterTimer; interval: 300; onTriggered: { win.hoverIntent = true; if (win.isFocused) Island.hovered = true; } }
    Timer { id: leaveTimer; interval: 250; onTriggered: { win.hoverIntent = false; if (win.isFocused) Island.hovered = false; } }

    function activate(button) {
        if (button === Qt.MiddleButton) { Media.toggle(); return; }
        if (button === Qt.RightButton) {
            // Resting island → the tray drawer; otherwise dismiss what it shows
            if (["idle", "idlePeek"].includes(win.shown)) TrayState.toggle(win.screen?.name ?? "");
            else Island.dismiss();
            return;
        }
        switch (win.shown) {
        case "recording":
            Quickshell.execDetached([Theme.lumenRoot + "/scripts/screen-record.sh", "stop"]);
            break;
        case "screenshot":
            if (Island.info.path) Quickshell.execDetached(["xdg-open", Island.info.path]);
            Island.dismiss();
            break;
        case "system":
            if (Island.info.path) Quickshell.execDetached(["xdg-open", Island.info.path]);
            Island.dismiss();
            break;
        case "notification":
            Island.info.activate?.();
            Island.dismiss();
            break;
        default:
            Island.togglePinned();
        }
    }
}
