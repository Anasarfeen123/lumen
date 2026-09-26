// Right-hand glass panel with two tabs:
//   Controls       (click the status pill, Super+A)   — control centre
//   Notifications  (Super+N, or the unread dot)       — grouped by app
// Ctrl+Tab switches tabs · Esc or clicking elsewhere closes.
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

        // Keyboard focus follows the visible tab (so arrows reach the toggles)
        function focusPage() { if (!win.showing) return; (Sidebar.tab === "controls" ? controls : notifPage).forceActiveFocus(); }
        Connections { target: Sidebar; function onTabChanged() { Qt.callLater(panel.focusPage); } }
        Connections { target: win; function onShowingChanged() { Qt.callLater(panel.focusPage); } }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
                Sidebar.tab = Sidebar.tab === "controls" ? "notifications" : "controls";
                event.accepted = true;
            }
        }

        SidebarTabs {
            id: tabs
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s4 }
        }

        // Both tabs live side by side; the pair slides (and cross-fades)
        Item {
            id: pages
            anchors { top: tabs.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            readonly property real shift: Sidebar.tab === "notifications" ? 1 : 0
            property real t: shift
            Behavior on t { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

            Flickable {
                id: controlsPage
                x: -pages.t * pages.width * 0.35
                width: pages.width; height: pages.height
                opacity: 1 - pages.t
                visible: opacity > 0.01
                contentHeight: controls.implicitHeight + Theme.space.s5 * 2
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ControlCenter {
                    id: controls
                    focus: Sidebar.tab === "controls"
                    x: Theme.space.s5; y: 0
                    width: parent.width - Theme.space.s5 * 2
                }
            }

            NotificationCenter {
                id: notifPage
                x: (1 - pages.t) * pages.width * 0.35 + Theme.space.s4
                y: 0
                width: pages.width - Theme.space.s4 * 2
                height: pages.height - Theme.space.s4
                opacity: pages.t
                visible: opacity > 0.01
            }
        }
    }
}
