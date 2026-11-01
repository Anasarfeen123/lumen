// The snap-layouts panel (services/SnapLayouts.qml): under the bar, centred,
// on the focused screen. Hover a zone to see it lit; click it, or press 1–9 for
// the zones in reading order. Esc or a click elsewhere closes.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool showing: SnapLayouts.open && (Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? ""))
    property real shown: showing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
    visible: showing || shown > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-snap"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // every zone in reading order, for the number keys
    readonly property var allZones: [].concat(...SnapLayouts.layouts.map(l => l.zones))

    MouseArea { anchors.fill: parent; onClicked: SnapLayouts.open = false }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: grid.implicitWidth + Theme.space.s4 * 2
        height: head.height + grid.implicitHeight + Theme.space.s4 * 3
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.edgeGap + Theme.barHeight + Theme.space.s2 - 12 * (1 - win.shown)
        opacity: win.shown
        scale: 0.96 + 0.04 * win.shown
        transformOrigin: Item.Top
        focus: win.showing
        MouseArea { anchors.fill: parent }

        Keys.onEscapePressed: SnapLayouts.open = false
        Keys.onPressed: e => {
            const n = e.key - Qt.Key_1;
            if (n >= 0 && n < 9 && n < win.allZones.length) { SnapLayouts.apply(win.allZones[n]); e.accepted = true; }
        }

        Row {
            id: head
            x: Theme.space.s4; y: Theme.space.s4
            spacing: Theme.space.s2
            LIcon { icon: "dashboard_customize"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "bodyStrong"; text: "Place"; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "body"; color: Theme.textMuted; width: Math.min(implicitWidth, 300); elide: Text.ElideRight
                    text: SnapLayouts.title; anchors.verticalCenter: parent.verticalCenter }
        }

        Grid {
            id: grid
            x: Theme.space.s4
            y: head.y + head.height + Theme.space.s4
            columns: 3
            spacing: Theme.space.s3
            Repeater {
                model: SnapLayouts.layouts
                Column {
                    id: lay
                    required property var modelData
                    required property int index
                    // where this layout's zones start in the 1–9 numbering
                    readonly property int first: SnapLayouts.layouts.slice(0, index).reduce((n, l) => n + l.zones.length, 0)
                    spacing: 6
                    Rectangle {
                        width: 148; height: 88
                        radius: Theme.radius.md
                        color: Theme.withAlpha(Theme.text, 0.05)
                        border.width: 1; border.color: Theme.border
                        Repeater {
                            model: lay.modelData.zones
                            MouseArea {
                                id: zone
                                required property var modelData
                                required property int index
                                readonly property int number: lay.first + index + 1
                                x: 5 + modelData[0] * 138; y: 5 + modelData[1] * 78
                                width: modelData[2] * 138 - 4; height: modelData[3] * 78 - 4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SnapLayouts.apply(modelData)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Theme.radius.sm
                                    color: zone.containsMouse ? Theme.accent : Theme.withAlpha(Theme.text, 0.12)
                                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                                }
                                LText {
                                    anchors.centerIn: parent
                                    visible: zone.number <= 9
                                    role: "caption"
                                    color: zone.containsMouse ? Theme.onAccent : Theme.textMuted
                                    text: zone.number
                                }
                            }
                        }
                    }
                    LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textSecondary; text: lay.modelData.label }
                }
            }
        }
    }
}
