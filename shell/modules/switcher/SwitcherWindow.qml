// Alt+Tab: a frosted strip of live window previews, most recent first.
// The selected card lifts, gets an accent edge and its title; the strip
// scrolls to keep it in view. See services/Switcher.qml for the keys.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Switcher.open && isFocused
    readonly property int cardW: 232
    readonly property int cardH: 196

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-switcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: showing ? panel : null }

    onShowingChanged: if (showing) keys.forceActiveFocus()

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Tab: case Qt.Key_Right: Switcher.step(1); break;
            case Qt.Key_Backtab: case Qt.Key_Left: Switcher.step(-1); break;
            case Qt.Key_Return: case Qt.Key_Enter: Switcher.commit(); break;
            case Qt.Key_Escape: Switcher.cancel(); break;
            case Qt.Key_Q: case Qt.Key_Delete: Switcher.closeSelected(); break;
            default: return;
            }
            event.accepted = true;
        }
        // Backup for the compositor's release bind
        Keys.onReleased: event => { if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) { Switcher.commit(); event.accepted = true; } }
    }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        anchors.centerIn: parent
        width: Math.min(strip.contentWidth, win.width * 0.86) + Theme.space.s4 * 2
        height: win.cardH + Theme.space.s4 * 2 + hint.height + Theme.space.s2
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.normal : Theme.motion.micro) } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.35) }

        ListView {
            id: strip
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            height: win.cardH
            orientation: ListView.Horizontal
            spacing: Theme.space.s2
            interactive: false
            model: Switcher.items
            currentIndex: Switcher.index
            highlightFollowsCurrentItem: true
            highlightMoveDuration: Theme.reducedMotion ? 0 : Theme.motion.normal
            preferredHighlightBegin: width / 2 - win.cardW / 2
            preferredHighlightEnd: width / 2 + win.cardW / 2
            highlightRangeMode: contentWidth > width ? ListView.ApplyRange : ListView.NoHighlightRange

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: index === Switcher.index
                readonly property var entry: DesktopEntries.heuristicLookup(modelData.cls ?? "")
                width: win.cardW
                height: win.cardH

                Rectangle {
                    id: frame
                    anchors.fill: parent
                    radius: Theme.radius.md
                    color: card.selected ? Theme.withAlpha(Theme.accent, 0.12) : (hover.containsMouse ? Theme.surfaceHover : "transparent")
                    border.width: card.selected ? 2 : 1
                    border.color: card.selected ? Theme.accent : "transparent"
                    scale: card.selected ? 1 : 0.95
                    Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }

                    ClippingRectangle {
                        id: shot
                        x: Theme.space.s2; y: Theme.space.s2
                        width: parent.width - Theme.space.s2 * 2
                        height: 136
                        radius: Theme.radius.sm
                        color: Theme.surfaceElevated
                        ScreencopyView {
                            id: preview
                            anchors.fill: parent
                            captureSource: win.showing && card.modelData.toplevel ? card.modelData.toplevel.wayland : null
                            live: true
                            constraintSize: Qt.size(shot.width * 2, shot.height * 2)
                        }
                        IconImage {
                            anchors.centerIn: parent
                            visible: !preview.hasContent
                            implicitSize: 48
                            source: card.entry ? Apps.iconFor(card.entry) : Quickshell.iconPath("application-x-executable")
                        }
                    }
                    // App icon badge over the preview's corner
                    IconImage {
                        anchors { left: shot.left; leftMargin: Theme.space.s2; bottom: shot.bottom; bottomMargin: -10 }
                        implicitSize: 28
                        source: card.entry ? Apps.iconFor(card.entry) : Quickshell.iconPath("application-x-executable")
                    }
                    Column {
                        anchors { left: parent.left; right: parent.right; top: shot.bottom; topMargin: Theme.space.s3; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
                        spacing: 1
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"
                                text: card.entry?.name || card.modelData.cls || "Window" }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                text: card.modelData.title + (card.modelData.workspace ? "  ·  " + card.modelData.workspace : "") }
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { Switcher.index = card.index; Switcher.commit(); }
                }
            }
        }

        LText {
            id: hint
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space.s3 }
            role: "caption"
            color: Theme.textMuted
            text: (Switcher.appMode ? "This app's windows  ·  " : "") + "Tab next  ·  Shift+Tab back  ·  Q close  ·  Esc cancel"
        }
    }
}
