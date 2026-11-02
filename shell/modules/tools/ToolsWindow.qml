// Shared desktop tools. Only the current page is constructed; scans and jobs
// live in services and survive closing this surface. Ctrl+1…6 switches pages.
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
    readonly property bool showing: DesktopTools.open && !Lock.locked && (Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? ""))
    visible: panel.retained
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-tools"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: win.showing ? panel : null }
    HyprlandFocusGrab { active: win.showing; windows: [win]; onCleared: DesktopTools.hide() }

    MotionSurface {
        id: panel
        shown: win.showing
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(1000, win.width - Theme.space.s4 * 2)
        height: Math.min(720, win.height - y - Theme.space.s4)
        x: (win.width - width) / 2
        y: Theme.edgeGap + Theme.barHeight + Theme.space.s3
        motionOrigin: DesktopTools.origin === "left" ? Item.TopLeft : DesktopTools.origin === "right" ? Item.TopRight : Item.Top
        focus: win.showing
        Keys.onEscapePressed: DesktopTools.hide()
        Keys.onPressed: event => {
            if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                DesktopTools.show(DesktopTools.pages[event.key - Qt.Key_1].id, DesktopTools.origin);
                event.accepted = true;
            }
        }
        Connections { target: win; function onShowingChanged() { if (win.showing) panel.forceActiveFocus(); } }

        Rectangle {
            id: rail
            x: Theme.space.s2; y: Theme.space.s2
            width: win.width < 720 ? 60 : 176
            height: parent.height - Theme.space.s2 * 2
            radius: Theme.radius.md
            color: Theme.withAlpha(Theme.bg, .35)
            Column {
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space.s2 }
                spacing: Theme.space.s2
                Item {
                    width: parent.width; height: Theme.space.s8 + Theme.space.s4
                    LIcon { x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter; icon: "widgets"; size: Theme.size.title; color: Theme.accent }
                    LText { visible: rail.width > 60; x: Theme.space.s3 + Theme.size.title + Theme.space.s2; anchors.verticalCenter: parent.verticalCenter; role: "heading"; text: "Tools" }
                }
                Repeater {
                    model: DesktopTools.pages
                    ToolButton {
                        required property var modelData
                        width: parent.width
                        glyph: modelData.icon
                        label: rail.width > 60 ? modelData.name + (modelData.id === "operations" && FileOperations.remaining ? " · " + FileOperations.remaining : "") : ""
                        Accessible.name: modelData.name
                        primary: DesktopTools.page === modelData.id
                        onClicked: DesktopTools.show(modelData.id, DesktopTools.origin)
                    }
                }
            }
            LText { visible: rail.width > 60; anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s4 }
                    role: "caption"; color: Theme.textMuted; text: "Ctrl + 1–6 to switch\nEsc to close"; lineHeight: 1.5 }
        }
        Column {
            id: heading
            anchors { left: rail.right; right: closeButton.left; top: parent.top; leftMargin: Theme.space.s5; topMargin: Theme.space.s5 }
            spacing: Theme.space.s1
            LText { width: parent.width; role: "title"; text: DesktopTools.currentPage.name; elide: Text.ElideRight }
            LText { width: parent.width; color: Theme.textSecondary; text: DesktopTools.currentPage.hint; elide: Text.ElideRight }
        }
        ToolButton { id: closeButton; anchors { top: parent.top; right: parent.right; margins: Theme.space.s4 } glyph: "close"; label: ""; Accessible.name: "Close tools"; onClicked: DesktopTools.hide() }
        Rectangle { id: divider; height: 1; color: Theme.border; anchors { left: heading.left; right: parent.right; rightMargin: Theme.space.s5; top: heading.bottom; topMargin: Theme.space.s4 } }
        Loader {
            id: pageLoader
            anchors { left: heading.left; right: divider.right; top: divider.bottom; topMargin: Theme.space.s4; bottom: feedback.top; bottomMargin: Theme.space.s3 }
            active: win.visible
            source: ({ screenshots: "ScreenshotPage.qml", folders: "FoldersPage.qml", operations: "OperationsPage.qml", storage: "StoragePage.qml", colours: "ColoursPage.qml", meeting: "MeetingPage.qml" })[DesktopTools.page] ?? "ScreenshotPage.qml"
        }
        LText {
            id: feedback
            anchors { left: heading.left; right: divider.right; bottom: parent.bottom; bottomMargin: Theme.space.s4 }
            height: Math.max(implicitHeight, Theme.size.caption * 1.5)
            role: "caption"; color: Theme.textSecondary
            text: DesktopTools.message || (DesktopTools.page === "operations" ? "Completed items stay in place if you cancel a batch." : "")
            wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText
        }
    }
}
