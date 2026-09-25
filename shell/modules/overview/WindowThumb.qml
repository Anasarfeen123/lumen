// A live window preview inside a workspace tile.
//   click: focus · middle-click: close · drag onto another tile: move there
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

ClippingRectangle {
    id: root
    required property var toplevel      // HyprlandToplevel
    required property real scaleFactor
    required property var monitor       // HyprlandMonitor of the tile
    signal done()
    signal dragStateChanged(bool dragging)

    readonly property var ipc: toplevel.lastIpcObject ?? ({})
    readonly property string address: ipc.address ?? ("0x" + toplevel.address)
    readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")
    readonly property real homeX: ((ipc.at?.[0] ?? 0) - (monitor?.x ?? 0)) * scaleFactor
    readonly property real homeY: ((ipc.at?.[1] ?? 0) - (monitor?.y ?? 0)) * scaleFactor

    x: homeX
    y: homeY
    width: Math.max(24, (ipc.size?.[0] ?? 200) * scaleFactor)
    height: Math.max(16, (ipc.size?.[1] ?? 120) * scaleFactor)
    radius: Theme.radius.xs
    color: Theme.surfaceElevated
    border.width: mouse.containsMouse || mouse.drag.active ? 2 : 0
    border.color: Theme.accent
    z: mouse.drag.active ? 100 : (ipc.floating ? 2 : 1)

    Drag.active: mouse.drag.active
    Drag.keys: ["lumen-window"]
    Drag.hotSpot: Qt.point(width / 2, height / 2)

    ScreencopyView {
        id: preview
        anchors.fill: parent
        captureSource: Overview.open ? root.toplevel.wayland : null
        live: true
        constraintSize: Qt.size(root.width * 2, root.height * 2)
    }

    IconImage {
        anchors.centerIn: parent
        visible: !preview.hasContent || root.width > 90
        opacity: preview.hasContent ? 0.9 : 1
        width: Math.min(32, root.width * 0.4); height: width
        source: root.entry ? Apps.iconFor(root.entry) : Quickshell.iconPath("application-x-executable")
        asynchronous: true
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        drag.target: root
        drag.threshold: 6
        property bool dragged: false

        onPressed: dragged = false
        onPositionChanged: if (drag.active) dragged = true
        drag.onActiveChanged: root.dragStateChanged(drag.active)
        onReleased: m => {
            if (dragged) {
                root.Drag.drop();
                root.x = Qt.binding(() => root.homeX);
                root.y = Qt.binding(() => root.homeY);
            }
        }
        onClicked: m => {
            if (dragged) return;
            if (m.button === Qt.MiddleButton) {
                Hyprland.dispatch(`closewindow address:${root.address}`);
            } else {
                Hyprland.dispatch(`focuswindow address:${root.address}`);
                root.done();
            }
        }
    }
}
