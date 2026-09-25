// Tray: apps running in the background (Discord, Steam, WARP…).
//
// The bar shows one small button — up to three of their icons, overlapped —
// and a click opens the tray drawer: every app by name, in colour.
//   click: open the app · right-click / ⋯: its own menu · middle: secondary action
// Also opens from right-click on the workspaces pill or on the resting island,
// and with Super+Alt+T.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.theme
import qs.components
import qs.services

HoverTarget {
    id: root
    required property var window

    readonly property var items: SystemTray.items.values
    readonly property bool attention: items.some(i => i.status === Status.NeedsAttention)
    visible: items.length > 0
    width: visible ? peek.width + Theme.space.s2 * 2 : 0
    height: Theme.barHeight - 8
    highlighted: drawer.visible
    onClicked: drawer.visible ? drawer.close() : drawer.open()
    // Last app quit while the drawer was open → close it
    onItemsChanged: if (items.length === 0) drawer.close()

    function label(item) { return item.tooltipTitle || item.title || item.id || "App"; }

    Connections {
        target: TrayState
        function onToggleRequested(monitor) {
            if (root.visible && monitor === (root.window.screen?.name ?? ""))
                drawer.visible ? drawer.close() : drawer.open();
        }
    }

    // Up to three icons, overlapped, quiet until hovered
    Row {
        id: peek
        anchors.centerIn: parent
        spacing: -5
        Repeater {
            model: root.items.slice(0, 3)
            delegate: Item {
                required property var modelData
                width: 18; height: 18
                IconImage { id: ic; anchors.fill: parent; source: modelData.icon; visible: false }
                MultiEffect {
                    anchors.fill: ic
                    source: ic
                    saturation: root.containsMouse || drawer.visible ? 0 : -0.85
                    opacity: root.containsMouse || drawer.visible ? 1 : 0.8
                    Behavior on saturation { NumberAnimation { duration: Theme.motion.micro } }
                }
            }
        }
        LText {
            visible: root.items.length > 3
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 8
            role: "caption"
            color: Theme.textMuted
            text: "+" + (root.items.length - 3)
        }
    }
    // Something wants you (e.g. an unread chat)
    Rectangle {
        visible: root.attention
        width: 6; height: 6; radius: 3
        color: Theme.accent
        anchors { right: parent.right; rightMargin: 4; top: parent.top; topMargin: 3 }
    }

    PopupWindow {
        id: drawer
        anchor.window: root.window
        anchor.rect.x: root.mapToItem(root.window.contentItem, root.width, 0).x - implicitWidth
        anchor.rect.y: Theme.edgeGap + Theme.barHeight + Theme.space.s2
        implicitWidth: 300
        implicitHeight: body.implicitHeight + Theme.space.s2 * 2
        color: "transparent"
        visible: false

        function open() { visible = true; }
        function close() { visible = false; }
        // The app's own menu, drawn by the app, just under the bar
        function menuFor(item) {
            close();
            const p = root.mapToItem(root.window.contentItem, root.width, root.height + Theme.space.s2);
            item.display(root.window, p.x - 220, p.y);
        }

        HyprlandFocusGrab {
            active: drawer.visible
            windows: [drawer, root.window]
            onCleared: drawer.close()
        }

        GlassSurface {
            anchors.fill: parent
            level: "panel"
            radius: Theme.radius.md
            focus: true
            Keys.onEscapePressed: drawer.close()
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.45) }

            Column {
                id: body
                x: Theme.space.s2; y: Theme.space.s2
                width: parent.width - Theme.space.s2 * 2

                LText {
                    leftPadding: Theme.space.s2
                    topPadding: Theme.space.s1
                    bottomPadding: Theme.space.s2
                    role: "caption"
                    color: Theme.textMuted
                    text: "Running in the background"
                }

                Repeater {
                    model: SystemTray.items
                    delegate: HoverTarget {
                        id: row
                        required property SystemTrayItem modelData
                        width: body.width
                        height: 44
                        radius: Theme.radius.sm
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) { modelData.secondaryActivate(); return; }
                            if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                if (modelData.hasMenu) drawer.menuFor(modelData);
                                return;
                            }
                            modelData.activate();
                            drawer.close();
                        }

                        IconImage {
                            id: appIcon
                            anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            implicitSize: 24
                            source: row.modelData.icon
                        }
                        Column {
                            anchors { left: appIcon.right; leftMargin: Theme.space.s3; right: more.left; rightMargin: Theme.space.s1
                                      verticalCenter: parent.verticalCenter }
                            LText { width: parent.width; elide: Text.ElideRight; text: root.label(row.modelData) }
                            LText {
                                width: parent.width
                                visible: text !== ""
                                elide: Text.ElideRight
                                role: "caption"
                                color: row.modelData.status === Status.NeedsAttention ? Theme.accent : Theme.textMuted
                                text: row.modelData.status === Status.NeedsAttention ? "Wants your attention"
                                    : Notifications.plain(row.modelData.tooltipDescription || "")
                            }
                        }
                        HoverTarget {
                            id: more
                            visible: row.modelData.hasMenu
                            width: 30; height: 30
                            anchors { right: parent.right; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                            onClicked: drawer.menuFor(row.modelData)
                            LIcon { anchors.centerIn: parent; icon: "more_horiz"; size: 18; color: Theme.textSecondary }
                        }
                    }
                }

                LText {
                    width: body.width
                    leftPadding: Theme.space.s2
                    topPadding: Theme.space.s2
                    bottomPadding: Theme.space.s1
                    wrapMode: Text.Wrap
                    role: "caption"
                    color: Theme.textMuted
                    text: "Click to open · right-click for the app's menu"
                }
            }
        }
    }
}
