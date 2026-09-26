// The bar adapts to what's on screen (DESIGN.md §10.4):
//
//   empty workspace  → three floating glass pills with air between them
//   any window open  → the gaps between the pills fill with glass and they
//                      become ONE long floating bar — same position, same
//                      span, same rounded ends. Nothing moves; the bar just
//                      closes ranks.
//
// The island stays centred in it (flat clock when idle, its own glass when
// something happens). The input mask covers only the pills.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: bar

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool merged: (monitor?.activeWorkspace?.toplevels?.values?.length ?? 0) > 0

    anchors { top: true; left: true; right: true }
    color: "transparent"
    // Pills + room below them for the soft shadow to render
    implicitHeight: Theme.edgeGap + Theme.barHeight + Theme.space.s4
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.edgeGap + Theme.barHeight

    WlrLayershell.namespace: "lumen-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Pills always take input; once merged, the whole bar does (so you can
    // scroll anywhere on it to switch workspaces)
    // Caffeine: while on, hold an idle inhibitor (hypridle honours it).
    // One inhibitor is enough — only the first screen's bar takes it.
    IdleInhibitor {
        window: bar
        enabled: Caffeine.on && bar.screen === Quickshell.screens[0]
    }

    mask: Region {
        Region { item: workspaces }
        Region { item: status }
        Region { item: appMenu }
        Region { item: merged.visible ? merged : null }
        Region { item: chips }
        Region { item: strip }
        Region { item: vitals }
    }

    // The merged bar is the island stretching out.
    //   merge   it starts at the island's exact width (hidden behind it) and
    //           springs out to span pill-edge to pill-edge; a sheen of light
    //           runs outward with it; each pill's glass dissolves the moment
    //           the bar reaches it — the bar absorbs them.
    //   unmerge the same film in reverse: the sheen runs inward, the bar
    //           glides back into the island (the pills regain their glass as
    //           it passes), and only then does it fade.
    GlassSurface {
        id: merged
        readonly property real fullWidth: bar.width - 2 * Theme.edgeGap
        property real span: Math.min(fullWidth, Island.shapeWidth)
        y: Theme.edgeGap
        height: Theme.barHeight
        width: span
        x: (bar.width - span) / 2
        opacity: 0
        visible: opacity > 0.01

        // Scroll anywhere on the merged bar → previous / next workspace
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => Hypr.workspace(event.angleDelta.y > 0 ? "r-1" : "r+1")
        }

        states: State {
            name: "merged"
            when: bar.merged
            PropertyChanges { merged.span: merged.fullWidth; merged.opacity: 1 }
        }
        transitions: [
            Transition {
                to: "merged"
                SequentialAnimation {
                    NumberAnimation { target: merged; property: "opacity"; duration: Theme.reducedMotion ? 0 : 60 }
                    ParallelAnimation {
                        SpringAnimation { target: merged; property: "span"; spring: Theme.motion.springStrength * 0.75; damping: Theme.motion.springDamping + 0.08; epsilon: 0.5 }
                        ScriptAction { script: sheen.run(true) }
                    }
                }
            },
            Transition {
                from: "merged"
                SequentialAnimation {
                    ScriptAction { script: sheen.run(false) }
                    NumberAnimation { target: merged; property: "span"; duration: Theme.reducedMotion ? 0 : 380; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                    NumberAnimation { target: merged; property: "opacity"; duration: Theme.reducedMotion ? 0 : Theme.motion.micro }
                }
            }
        ]

        // Two soft bands of light that travel with the bar's growing edges
        Item {
            id: sheen
            anchors.fill: parent
            opacity: 0
            property real t: 0          // 0 = at the island, 1 = at the bar's ends

            function run(outward) {
                if (Theme.reducedMotion) return;
                sweep.stop();
                sweepT.from = outward ? 0 : 1;
                sweepT.to = outward ? 1 : 0;
                sweep.start();
            }

            ParallelAnimation {
                id: sweep
                NumberAnimation { id: sweepT; target: sheen; property: "t"; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                SequentialAnimation {
                    NumberAnimation { target: sheen; property: "opacity"; to: 1; duration: 90 }
                    PauseAnimation { duration: 200 }
                    NumberAnimation { target: sheen; property: "opacity"; to: 0; duration: 180 }
                }
            }

            component Band: Rectangle {
                width: 180
                height: parent.height
                radius: height / 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0) }
                    GradientStop { position: 0.5; color: Theme.withAlpha(Theme.accent, 0.22) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }
            Band { x: sheen.width / 2 - width / 2 - (sheen.width / 2 - width / 2) * sheen.t }
            Band { x: sheen.width / 2 - width / 2 + (sheen.width / 2 - width / 2) * sheen.t }
        }
    }

    Workspaces {
        id: workspaces
        screen: bar.screen
        peek: peek
        barWindow: bar
        // Dissolves into the bar the moment the bar's edge reaches its middle
        flat: merged.visible && merged.x <= x + width / 2
        x: Theme.edgeGap
        y: Theme.edgeGap
    }

    // Focused app + its menu, right after the workspaces (merged bar only)
    AppMenu {
        id: appMenu
        barWindow: bar
        monitor: bar.monitor
        shown: bar.merged
        x: workspaces.x + workspaces.width + Theme.space.s1
        y: Theme.edgeGap
    }

    readonly property bool ribbonOpen: bar.merged && merged.span > merged.fullWidth * 0.9

    // Peek: live previews under the strip and the workspace dots
    Peek { id: peek; barWindow: bar }

    // This workspace's windows, after the app menu
    WindowStrip {
        id: strip
        monitor: bar.monitor
        peek: peek
        barWindow: bar
        shown: bar.ribbonOpen
        x: appMenu.x + appMenu.width + Theme.space.s1
        y: Theme.edgeGap
    }

    // The Ribbon's shoulders: calm, contextual chips either side of the island
    RibbonChips {
        id: chips
        x: 0
        y: Theme.edgeGap
        width: bar.width
        height: Theme.barHeight
        shown: bar.ribbonOpen
        leftLimit: strip.visible ? strip.x + strip.width : appMenu.x + appMenu.width
        rightLimit: vitals.visible ? vitals.x : status.x
    }

    // CPU line + memory, beside the status pill
    Vitals {
        id: vitals
        shown: bar.ribbonOpen
        anchors.right: status.left
        anchors.rightMargin: Theme.space.s1
        y: Theme.edgeGap + (Theme.barHeight - height) / 2
    }

    StatusPill {
        id: status
        window: bar
        flat: merged.visible && merged.x + merged.width >= x + width / 2
        anchors.right: parent.right
        anchors.rightMargin: Theme.edgeGap
        y: Theme.edgeGap
    }
}
