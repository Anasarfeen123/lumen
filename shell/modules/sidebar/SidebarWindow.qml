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
    readonly property int panelWidth: Math.min(Theme.panels.controlsWidth, (screen?.width ?? Theme.panels.controlsWidth) - Theme.edgeGap * 2)

    visible: panel.retained
    anchors { top: true; bottom: true; right: true }
    margins.top: Theme.edgeGap + Theme.barHeight
    implicitWidth: panelWidth + Theme.edgeGap + Theme.space.s8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    mask: Region { item: win.showing ? panel : null }


    HyprlandFocusGrab {
        active: win.showing
        windows: [win]
        onCleared: Sidebar.hide()
    }

    MotionSurface {
        id: panel
        shown: win.showing
        motionStyle: "sidebar"
        offsetX: Theme.space.s5
        motionOrigin: Item.TopRight
        level: "panel"
        radius: Theme.radius.lg
        width: win.panelWidth
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right; topMargin: Theme.edgeGap; bottomMargin: Theme.edgeGap; rightMargin: Theme.edgeGap }

        focus: win.showing
        Keys.onEscapePressed: Sidebar.hide()

        // Keyboard focus follows the visible tab (so arrows reach the toggles)
        function focusPage() { if (!win.showing) return; (Sidebar.tab === "controls" ? controls : notifPage).forceActiveFocus(); }
        onSettled: opened => { if (!opened) controls.detail = ""; }
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

        // Change content only at the transparent midpoint, keeping text crisp.
        Item {
            id: pages
            anchors { top: tabs.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
            clip: true
            PageTransition {
                id: tabsMotion
                key: Sidebar.tab
                active: panel.retained
                direction: key === "notifications" ? 1 : -1
                onSwapped: Qt.callLater(panel.focusPage)
            }

            Flickable {
                id: controlsPage
                x: tabsMotion.offset
                width: pages.width; height: pages.height
                opacity: tabsMotion.reveal
                visible: tabsMotion.presentedKey === "controls"
                enabled: Sidebar.tab === "controls"
                contentHeight: controls.implicitHeight + Theme.space.s5 * 2
                boundsBehavior: Flickable.StopAtBounds
                clip: true
                ControlCenter {
                    id: controls
                    motionActive: panel.retained
                    focus: Sidebar.tab === "controls"
                    x: Theme.space.s5; y: 0
                    width: parent.width - Theme.space.s5 * 2
                }
            }

            NotificationCenter {
                id: notifPage
                x: tabsMotion.offset + Theme.space.s4
                y: 0
                width: pages.width - Theme.space.s4 * 2
                height: pages.height - Theme.space.s4
                opacity: tabsMotion.reveal
                visible: tabsMotion.presentedKey === "notifications"
                enabled: Sidebar.tab === "notifications"
            }
        }
    }
}
