// Power menu (Super+Escape, Ctrl+Alt+Delete, or the control centre).
// Five actions in one row. Lock and Sleep act immediately; Log out, Restart
// and Shut down ask once more: the tile turns red and says "Restart?", and
// the same key / click confirms (DESIGN.md: destructive actions confirm).
//   ←/→ or Tab to move · Enter to choose · L S E R P shortcuts · Esc cancels
import QtQuick
import Quickshell
import Quickshell.Io
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
    readonly property bool showing: Session.menuOpen && isFocused

    property int selected: 0
    property string confirming: ""      // action id awaiting confirmation
    property string uptime: ""

    visible: panel.retained
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-session"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: {
        if (showing) { selected = 0; confirming = ""; pointerBase = true; uptimeProc.running = true; panel.forceActiveFocus(); }
    }

    // hover selects only when the pointer moves (a menu opening under a resting
    // pointer mustn't pick Log out for you)
    property bool pointerBase: true
    property point lastPointer: Qt.point(-1, -1)
    function pointerMoved(at) {
        if (pointerBase) { pointerBase = false; lastPointer = at; return false; }
        if (Math.abs(at.x - lastPointer.x) < 2 && Math.abs(at.y - lastPointer.y) < 2) return false;
        lastPointer = at; return true;
    }

    function choose(i) {
        const a = Session.actions[i];
        selected = i;
        if (a.confirm && confirming !== a.id) { confirming = a.id; return; }
        Session.run(a.id);
    }

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Math.floor(parseFloat(text));
                const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                win.uptime = "Up " + (d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`);
            }
        }
    }

    // Dim the desktop; click outside the panel to cancel
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bg, 0.45)
        opacity: panel.alpha
        MouseArea { anchors.fill: parent; onClicked: Session.menuOpen = false }
    }

    MotionSurface {
        id: panel
        shown: win.showing
        motionStyle: "dialog"
        motionOrigin: Item.Center
        level: "panel"
        radius: Theme.radius.lg
        anchors.centerIn: parent
        width: tiles.implicitWidth + Theme.space.s5 * 2
        height: col.implicitHeight + Theme.space.s5 * 2


        focus: true
        Keys.onEscapePressed: {
            if (win.confirming !== "") win.confirming = "";
            else Session.menuOpen = false;
        }
        Keys.onLeftPressed: { win.selected = (win.selected + Session.actions.length - 1) % Session.actions.length; win.confirming = ""; }
        Keys.onRightPressed: { win.selected = (win.selected + 1) % Session.actions.length; win.confirming = ""; }
        Keys.onTabPressed: { win.selected = (win.selected + 1) % Session.actions.length; win.confirming = ""; }
        Keys.onReturnPressed: win.choose(win.selected)
        Keys.onSpacePressed: win.choose(win.selected)
        Keys.onPressed: event => {
            const i = Session.actions.findIndex(a => a.key === event.text.toUpperCase());
            if (i >= 0) { win.choose(i); event.accepted = true; }
        }

        MouseArea { anchors.fill: parent }   // swallow clicks so the scrim doesn't close the menu

        Column {
            id: col
            anchors.centerIn: parent
            spacing: Theme.space.s4

            Row {
                id: tiles
                spacing: Theme.space.s2
                Repeater {
                    model: Session.actions
                    delegate: HoverTarget {
                        id: tile
                        required property var modelData
                        required property int index
                        readonly property bool isSelected: win.selected === index
                        readonly property bool isConfirming: win.confirming === modelData.id

                        readonly property bool risky: tile.modelData.confirm
                        readonly property color tone: tile.risky ? Theme.error : Theme.accent
                        width: 104
                        height: 116
                        radius: Theme.radius.lg
                        highlighted: false
                        hoverFeedback: false
                        onClicked: win.choose(index)
                        onPositionChanged: m => { if (win.pointerMoved(mapToItem(null, m.x, m.y)) && win.selected !== index) { win.selected = index; win.confirming = ""; } }

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radius.lg
                            color: tile.isConfirming ? Theme.withAlpha(Theme.error, 0.14) : tile.isSelected ? Theme.withAlpha(Theme.text, 0.06) : "transparent"
                            border.width: tile.isConfirming ? 1 : 0
                            border.color: Theme.withAlpha(Theme.error, 0.6)
                            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                        }
                        // its letter: press it to choose
                        LText {
                            anchors { top: parent.top; right: parent.right; margins: 8 }
                            role: "caption"; color: Theme.textMuted
                            opacity: tile.isSelected ? 0.9 : 0.5
                            text: tile.modelData.key
                        }
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.space.s2
                            // the icon in a round well: filled with the accent when chosen — red for the ones that end your session
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 56; height: 56; radius: 28
                                color: tile.isSelected || tile.isConfirming ? tile.tone : Theme.withAlpha(Theme.text, 0.07)
                                border.width: tile.isSelected ? 0 : 1
                                border.color: Theme.border
                                scale: tile.pressed ? 0.92 : tile.isSelected ? 1.06 : 1
                                Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
                                Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
                                LIcon {
                                    anchors.centerIn: parent
                                    icon: tile.modelData.icon
                                    size: 26
                                    fill: tile.isSelected ? 1 : 0
                                    color: tile.isSelected || tile.isConfirming ? (tile.risky ? Theme.onMedia : Theme.onAccent) : Theme.textSecondary
                                }
                            }
                            LText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                role: "bodyStrong"
                                color: tile.isConfirming ? Theme.error : tile.isSelected ? Theme.text : Theme.textSecondary
                                text: tile.isConfirming ? tile.modelData.label + "?" : tile.modelData.label
                            }
                        }
                    }
                }
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                color: win.confirming !== "" ? Theme.textSecondary : Theme.textMuted
                text: win.confirming !== ""
                      ? "Press Enter again to confirm · Esc to cancel"
                      : win.uptime + "  ·  ←/→ to move · Enter to choose · Esc to cancel"
            }
        }
    }
}
