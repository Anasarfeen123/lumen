// Right-hand glass panel (Super+N, or click the status pill).
// Control centre on top, notification centre below (fills the rest).
// Esc or clicking elsewhere closes it.
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
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Sidebar.open && isFocused
    readonly property int panelWidth: 380

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; right: true }
    margins.top: Theme.edgeGap + Theme.barHeight
    implicitWidth: panelWidth + Theme.edgeGap + Theme.space.s8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region { item: panel }

    HyprlandFocusGrab {
        active: win.showing
        windows: [win]
        onCleared: Sidebar.hide()
    }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: win.panelWidth
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right; topMargin: Theme.edgeGap; bottomMargin: Theme.edgeGap; rightMargin: Theme.edgeGap }

        opacity: win.showing ? 1 : 0
        transform: Translate { x: win.showing ? 0 : 24; Behavior on x { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } } }
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }

        focus: win.showing
        Keys.onEscapePressed: Sidebar.hide()

        ControlCenter {
            id: controls
            focus: true
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s5 }
        }

        Rectangle {
            id: divider
            anchors { top: controls.bottom; topMargin: Theme.space.s5; left: parent.left; right: parent.right; leftMargin: Theme.space.s5; rightMargin: Theme.space.s5 }
            height: 1
            color: Theme.border
        }

        NotificationCenter {
            anchors { top: divider.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: Theme.space.s5; rightMargin: Theme.space.s5; bottomMargin: Theme.space.s5 }
        }
    }
}
