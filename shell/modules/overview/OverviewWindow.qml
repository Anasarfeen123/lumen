// Overview + launcher overlay (tap Super). One surface, two layers of depth:
//   query empty  → recent apps + workspace grid with live window previews
//   typing       → results (apps, windows, calculator, actions, web)
//   Super+V / Super+.  → clipboard / emoji modes
//
// Opening is a morph, not a pop-up: the search field starts at the island's
// exact size and position and springs out to full width, so the island
// *becomes* the search. Closing runs it backwards and hands the shape back
// (Overview.handoff) only once the field is island-sized again.
//
// Keys: type to search · ↑↓ select · ↵ open · Esc clear, then close
//       ←→ + ↵ pick a workspace when the query is empty · Shift+Del removes a clipboard entry
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
    readonly property bool showing: Overview.open && isFocused
    readonly property bool gridMode: Overview.mode === "search" && Overview.query.trim() === ""

    visible: showing || Overview.handoff || content.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: {
        if (showing) {
            handBack.stop();
            Overview.handoff = true;
            textDelay.restart();
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            grid.selectedIndex = -1;
            field.input.forceActiveFocus();
        } else {
            textDelay.stop();
            field.textShown = false;
            handBack.restart();
        }
    }

    // Text appears once the pill is mostly open, so it never squashes
    Timer { id: textDelay; interval: Theme.reducedMotion ? 0 : 110; onTriggered: field.textShown = true }
    // Give the shape back to the island when the field has shrunk into it
    Timer { id: handBack; interval: Theme.reducedMotion ? 0 : Theme.motion.large + 40; onTriggered: Overview.handoff = false }

    // Scrim — dims and (via Hyprland layer blur) frosts the desktop behind.
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bg, 0.5)
        opacity: content.opacity
        MouseArea { anchors.fill: parent; onClicked: Overview.hide() }
    }

    Item {
        id: content
        anchors.fill: parent
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } }

        Column {
            id: column
            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.edgeGap + field.implicitHeight + Theme.space.s6
            spacing: Theme.space.s6

            RecentApps {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: win.gridMode && Apps.recent.length > 0
                onDone: Overview.hide()
            }

            WorkspaceGrid {
                id: grid
                anchors.horizontalCenter: parent.horizontalCenter
                visible: win.gridMode
                monitor: win.monitor
                maxWidth: win.width * 0.86
                onDone: Overview.hide()
            }

            ResultList {
                id: results
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !win.gridMode
                onDone: Overview.hide()
            }
        }
    }

    // The search field lives outside `content` so it morphs instead of fading
    SearchField {
        id: field
        readonly property bool open: win.showing
        property bool textShown: false
        anchors.horizontalCenter: parent.horizontalCenter
        level: open ? "panel" : "chrome"
        width: open ? implicitWidth : Island.shapeWidth
        height: open ? implicitHeight : Theme.island.height
        y: open ? Theme.edgeGap : Island.shapeY
        innerOpacity: textShown ? 1 : 0

        Behavior on width { enabled: !Theme.reducedMotion; SpringAnimation { spring: Theme.motion.springStrength; damping: Theme.motion.springDamping; epsilon: 0.25 } }
        Behavior on height { enabled: !Theme.reducedMotion; SpringAnimation { spring: Theme.motion.springStrength; damping: Theme.motion.springDamping; epsilon: 0.25 } }
        Behavior on y { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

        input.Keys.onPressed: event => {
            const k = event.key;
            if (k === Qt.Key_Escape) {
                if (Overview.query !== "") Overview.query = "";
                else if (Overview.mode !== "search") Overview.mode = "search";
                else Overview.hide();
            } else if (win.gridMode && (k === Qt.Key_Left || k === Qt.Key_Right)) {
                grid.move(k === Qt.Key_Left ? -1 : 1);
            } else if (k === Qt.Key_Down || (k === Qt.Key_Tab && !(event.modifiers & Qt.ShiftModifier))
                       || (k === Qt.Key_N && event.modifiers & Qt.ControlModifier)) {
                results.move(1);
            } else if (k === Qt.Key_Up || k === Qt.Key_Backtab
                       || (k === Qt.Key_P && event.modifiers & Qt.ControlModifier)) {
                results.move(-1);
            } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
                if (win.gridMode) { if (grid.activateSelected()) Overview.hide(); }
                else results.activate(undefined, Overview.mode !== "clipboard" ? undefined
                                          : (event.modifiers & Qt.ShiftModifier) ? "open"
                                          : (event.modifiers & Qt.ControlModifier) ? "plain"
                                          : (event.modifiers & Qt.AltModifier) ? "copy" : "paste");
            } else if ((k === Qt.Key_Left || k === Qt.Key_Right) && (event.modifiers & Qt.ControlModifier) && Overview.mode === "clipboard") {
                Clipboard.cycleFilter(k === Qt.Key_Left ? -1 : 1);
            } else if (k === Qt.Key_P && (event.modifiers & Qt.AltModifier) && Overview.mode === "clipboard") {
                results.togglePin();
            } else if (k === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
                results.removeCurrent();
            } else {
                return;
            }
            event.accepted = true;
        }
    }
}
