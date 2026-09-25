// One workspace as a miniature of the monitor: wallpaper, live windows,
// number. Accent outline = current workspace; keyboard-selected = strong outline.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property int wsId
    required property var monitor           // HyprlandMonitor
    required property real tileWidth
    required property string wallpaper
    property bool current: false
    property bool selected: false
    property bool isNew: false
    signal done()

    readonly property real logicalW: (monitor?.width ?? 1920) / (monitor?.scale ?? 1)
    readonly property real logicalH: (monitor?.height ?? 1080) / (monitor?.scale ?? 1)
    readonly property real scaleFactor: tileWidth / logicalW
    property bool childDragging: false

    width: tileWidth
    height: logicalH * scaleFactor
    z: childDragging ? 50 : 0

    ClippingRectangle {
        id: frame
        anchors.fill: parent
        radius: Theme.radius.md
        color: Theme.bg
        border.width: root.current || root.selected || drop.containsDrag || hover.hovered ? 2 : 1
        border.color: drop.containsDrag ? Theme.accent
                    : root.current ? Theme.accent
                    : (root.selected || hover.hovered) ? Theme.borderStrong : Theme.border

        Image {
            anchors.fill: parent
            source: root.wallpaper ? "file://" + root.wallpaper : ""
            sourceSize: Qt.size(root.width, root.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.55
        }

        Repeater {
            model: Hyprland.toplevels.values.filter(t => t.workspace?.id === root.wsId && !(t.lastIpcObject?.hidden ?? false))
            delegate: WindowThumb {
                required property var modelData
                toplevel: modelData
                scaleFactor: root.scaleFactor
                monitor: root.monitor
                onDone: root.done()
                onDragStateChanged: dragging => root.childDragging = dragging
            }
        }

        LIcon {
            anchors.centerIn: parent
            visible: root.isNew
            icon: "add"
            color: Theme.textMuted
        }
    }

    LText {
        anchors { left: parent.left; bottom: parent.bottom; margins: Theme.space.s2 }
        role: "caption"
        color: root.current ? Theme.accent : Theme.textSecondary
        text: root.isNew ? "New" : String(root.wsId)
        z: 200
    }

    HoverHandler { id: hover }
    TapHandler {
        onTapped: { Hypr.workspace(root.wsId); root.done(); }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["lumen-window"]
        onDropped: d => {
            Hypr.moveToWorkspace(d.source.address, root.wsId, false);
            refresh.start();
        }
    }
    Timer { id: refresh; interval: 120; onTriggered: Hyprland.refreshToplevels() }
}
