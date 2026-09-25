// A hot corner: push the pointer into the corner and pause briefly (dwell),
// and it fires — with a ripple of accent light blooming from the corner so
// you see what happened. Passing through on the way somewhere doesn't count,
// and it re-arms only after the pointer leaves. Off over fullscreen apps.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme

PanelWindow {
    id: win
    required property string corner        // "topLeft" | "topRight"
    property bool allowed: true            // user preference (Lumen Settings)
    signal triggered()

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool enabled: allowed && !(monitor?.activeWorkspace?.hasFullscreen ?? false)
    readonly property bool left: corner === "topLeft"
    property bool armed: true

    anchors { top: true; left: win.left; right: !win.left }
    implicitWidth: 96
    implicitHeight: 96
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-corner"
    WlrLayershell.layer: WlrLayer.Overlay
    // Only a 3×3 px sensor takes input; the rest is room for the ripple
    mask: Region { item: win.enabled ? sensor : null }

    Item {
        id: sensor
        width: 3; height: 3
        x: win.left ? 0 : win.width - width
        HoverHandler {
            onHoveredChanged: {
                if (hovered && win.armed) dwell.restart();
                else if (!hovered) { dwell.stop(); win.armed = true; }
            }
        }
    }

    Timer {
        id: dwell
        interval: 140
        onTriggered: { win.armed = false; ripple.restart(); win.triggered(); }
    }

    // Ripple: a soft quarter-glow expanding out of the corner
    Rectangle {
        id: glow
        width: 180; height: 180; radius: 90
        x: win.left ? -width / 2 : win.width - width / 2
        y: -height / 2
        scale: 0
        opacity: 0
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Theme.withAlpha(Theme.accent, 0.55) }
            GradientStop { position: 1.0; color: Theme.withAlpha(Theme.accent, 0.0) }
        }
    }
    ParallelAnimation {
        id: ripple
        NumberAnimation { target: glow; property: "scale"; from: 0.2; to: 1; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        SequentialAnimation {
            NumberAnimation { target: glow; property: "opacity"; from: 0; to: 1; duration: 60 }
            NumberAnimation { target: glow; property: "opacity"; to: 0; duration: Theme.motion.large }
        }
    }
}
