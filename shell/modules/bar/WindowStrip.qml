// The Ribbon's window strip: this workspace's windows as app icons, right
// after the focused app's name. The focused one wears a small accent bar.
//   click: focus · middle-click: close · hover: Peek (live preview + stats)
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

Row {
    id: root
    required property var monitor
    required property var peek                  // Peek popup
    required property var barWindow
    property bool shown: false

    readonly property var windows: (monitor?.activeWorkspace?.toplevels?.values ?? [])
        .slice().sort((a, b) => ((a.lastIpcObject?.at?.[0] ?? 0) - (b.lastIpcObject?.at?.[0] ?? 0)))
    readonly property var focused: Hyprland.activeToplevel

    spacing: 2
    height: Theme.barHeight
    // Worth showing only with two or more windows (one is already named by the app menu)
    opacity: shown && windows.length > 1 ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }

    Rectangle { width: 1; height: 14; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
    Item { width: Theme.space.s1; height: 1 }

    Repeater {
        model: root.windows
        delegate: MouseArea {
            id: slot
            required property var modelData
            readonly property var ipc: modelData.lastIpcObject ?? ({})
            readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")
            readonly property bool isFocused: root.focused === modelData
            width: 30; height: Theme.barHeight
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => {
                const addr = ipc.address ?? ("0x" + modelData.address);
                Hyprland.dispatch(m.button === Qt.MiddleButton ? `hl.dsp.window.close({ window = "address:${addr}" })`
                                                               : `hl.dsp.focus({ window = "address:${addr}" })`);
            }
            onContainsMouseChanged: {
                if (containsMouse) root.peek.peek([modelData], "", mapToItem(root.barWindow.contentItem, width / 2, 0).x);
                else root.peek.leave();
            }

            Rectangle {
                anchors.centerIn: parent
                width: 26; height: 26; radius: 8
                color: slot.containsMouse ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
            }
            IconImage {
                anchors.centerIn: parent
                width: 18; height: 18
                source: slot.entry ? Apps.iconFor(slot.entry) : Quickshell.iconPath("application-x-executable")
                opacity: slot.isFocused || slot.containsMouse ? 1 : 0.7
                Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            }
            Rectangle {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                width: slot.isFocused ? 12 : 4; height: 3; radius: 1.5
                color: slot.isFocused ? Theme.accent : Theme.textMuted
                opacity: slot.isFocused ? 1 : 0.5
                Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
        }
    }
}
