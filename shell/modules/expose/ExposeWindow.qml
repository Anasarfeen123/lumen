// Exposé on the focused screen (services/Expose.qml): a dimmed, blurred-feel
// backdrop and every window as a live card, grouped in workspace order.
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
    readonly property bool showing: Expose.open && (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    visible: showing || fade.running
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-expose"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property string filter: ""
    property int index: 0
    readonly property var shown: {
        const f = filter.toLowerCase();
        return Expose.items.filter(it => !f || (it.title + " " + it.cls).toLowerCase().includes(f));
    }
    onShowingChanged: if (showing) { filter = ""; index = 0; keys.forceActiveFocus(); }
    onShownChanged: index = Math.min(index, Math.max(0, shown.length - 1))

    // a grid that fits: as many columns as keep the cards near 16:10
    readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(shown.length * (width / Math.max(1, height)) / 1.6)))
    readonly property int rows: Math.max(1, Math.ceil(shown.length / cols))
    readonly property real cellW: (width - 160) / cols
    readonly property real cellH: Math.min(cellW * 0.68, (height - 220) / rows)

    Rectangle {
        id: shade
        anchors.fill: parent
        color: Theme.withAlpha(Theme.scrim, 0.62)
        opacity: win.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { id: fade; duration: Theme.motion.normal } }
        MouseArea { anchors.fill: parent; onClicked: Expose.open = false }
    }

    Item {
        id: keys
        anchors.fill: parent
        opacity: shade.opacity
        scale: 0.96 + 0.04 * shade.opacity
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { if (win.filter) win.filter = ""; else Expose.open = false; }
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) Expose.go(win.shown[win.index]);
            else if (e.key === Qt.Key_Right) win.index = Math.min(win.shown.length - 1, win.index + 1);
            else if (e.key === Qt.Key_Left) win.index = Math.max(0, win.index - 1);
            else if (e.key === Qt.Key_Down) win.index = Math.min(win.shown.length - 1, win.index + win.cols);
            else if (e.key === Qt.Key_Up) win.index = Math.max(0, win.index - win.cols);
            else if (e.key === Qt.Key_Backspace) win.filter = win.filter.slice(0, -1);
            else if (e.text && e.text.trim() && !(e.modifiers & Qt.ControlModifier)) win.filter += e.text;
            else return;
            e.accepted = true;
        }

        // the filter, when typing
        Rectangle {
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 48 }
            width: Math.max(260, ftext.implicitWidth + 60); height: 40; radius: 20
            color: Theme.withAlpha(Theme.surface, 0.85); border.width: 1; border.color: Theme.border
            Row {
                anchors.centerIn: parent; spacing: 8
                LIcon { icon: "search"; size: 18; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                LText { id: ftext; anchors.verticalCenter: parent.verticalCenter; color: win.filter ? Theme.text : Theme.textMuted
                        text: win.filter || (Expose.items.length + (Expose.items.length === 1 ? " window" : " windows") + " · type to filter") }
            }
        }

        Grid {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: 24
            columns: win.cols
            Repeater {
                model: win.shown
                Item {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.index
                    width: win.cellW; height: win.cellH
                    // the window's own proportions, inside the cell
                    readonly property real ar: modelData.w / Math.max(1, modelData.h)
                    readonly property real cw: Math.min(width - 24, (height - 40) * ar)
                    readonly property real ch: cw / ar
                    ClippingRectangle {
                        id: card
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: (parent.height - 30 - cell.ch) / 2
                        width: cell.cw; height: cell.ch
                        radius: Theme.radius.md
                        color: Theme.surfaceElevated
                        scale: cell.sel ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: win.showing && cell.modelData.toplevel ? cell.modelData.toplevel.wayland : null
                            live: true
                            constraintSize: Qt.size(card.width * 1.5, card.height * 1.5)
                        }
                        Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"
                                    border.width: cell.sel ? 2 : 1; border.color: cell.sel ? Theme.accent : Theme.withAlpha(Theme.onMedia, 0.15) }
                        Rectangle {          // its workspace
                            anchors { top: parent.top; right: parent.right; margins: 8 }
                            width: 22; height: 22; radius: 11; color: Theme.withAlpha(Theme.scrim, 0.6)
                            LText { anchors.centerIn: parent; role: "caption"; color: Theme.onMedia; text: cell.modelData.workspace }
                        }
                    }
                    Row {
                        anchors { horizontalCenter: parent.horizontalCenter; top: card.bottom; topMargin: 8 }
                        spacing: 6
                        IconImage { implicitSize: 16; anchors.verticalCenter: parent.verticalCenter
                                    source: { const e = Apps.entryFor(cell.modelData.cls); return e ? Apps.iconFor(e) : ""; } }
                        LText { anchors.verticalCenter: parent.verticalCenter; width: Math.min(implicitWidth, cell.width - 40); elide: Text.ElideRight
                                color: cell.sel ? Theme.onMedia : Theme.withAlpha(Theme.onMedia, 0.75); text: cell.modelData.title || cell.modelData.cls }
                    }
                    MouseArea {
                        anchors.fill: card
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse) win.index = cell.index
                        onClicked: m => {
                            if (m.button === Qt.MiddleButton) { Hypr.closeWindow(cell.modelData.address); Expose.items = Expose.items.filter(x => x.address !== cell.modelData.address); if (!Expose.items.length) Expose.open = false; }
                            else Expose.go(cell.modelData);
                        }
                    }
                }
            }
        }
    }
}
