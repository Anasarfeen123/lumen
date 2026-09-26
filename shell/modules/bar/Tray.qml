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
    highlighted: drawer.shown
    onClicked: drawer.shown ? drawer.close() : drawer.open()
    // Last app quit while the drawer was open → close it
    onItemsChanged: if (items.length === 0) drawer.close()

    function label(item) { return item.tooltipTitle || item.title || item.id || "App"; }

    Connections {
        target: TrayState
        function onMenuRequested(index) {
            const it = SystemTray.items.values[index];
            if (it && it.hasMenu && root.window.screen === Quickshell.screens[0]) drawer.menuFor(it);
        }
        function onToggleRequested(monitor) {
            if (root.visible && monitor === (root.window.screen?.name ?? ""))
                drawer.shown ? drawer.close() : drawer.open();
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
                    saturation: root.containsMouse || drawer.shown ? 0 : -0.85
                    opacity: root.containsMouse || drawer.shown ? 1 : 0.8
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

    LumenPopup {
        id: drawer
        anchor.window: root.window
        anchor.rect.x: root.mapToItem(root.window.contentItem, root.width, 0).x - contentWidth - margin
        anchor.rect.y: Theme.edgeGap + Theme.barHeight + Theme.space.s2 - margin
        contentWidth: 300
        contentHeight: (stack.length ? menuPage.implicitHeight : body.implicitHeight) + Theme.space.s2 * 2

        // An app's menu opens INSIDE the drawer, drawn by Lumen from the app's
        // menu model (QsMenuOpener). Native platform menus aren't used: they
        // crash Quickshell 0.2.1 when a tray app quits while its menu exists.
        property var stack: []             // [{ handle, title }] — submenus push
        property var menuApp: null
        function menuFor(item) { menuApp = item; stack = [{ handle: item.menu, title: root.label(item) }]; if (!shown) open(); }
        function back() { stack = stack.slice(0, -1); }
        onShownChanged: if (!shown) { stack = []; menuApp = null; }
        onVisibleChanged: if (!visible) { stack = []; menuApp = null; }

        Item {
            anchors.fill: parent

            // ── Apps ──
            Column {
                id: body
                visible: drawer.stack.length === 0
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
                            LIcon { anchors.centerIn: parent; icon: "chevron_right"; size: 18; color: Theme.textSecondary }
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
                    text: "Click to open · › or right-click for the app's menu"
                }
            }

            // ── An app's menu ──
            Column {
                id: menuPage
                visible: drawer.stack.length > 0
                x: Theme.space.s2; y: Theme.space.s2
                width: parent.width - Theme.space.s2 * 2
                readonly property var level: drawer.stack.length ? drawer.stack[drawer.stack.length - 1] : null

                QsMenuOpener { id: opener; menu: menuPage.level?.handle ?? null }

                Item {
                    width: parent.width; height: 36
                    HoverTarget {
                        id: backBtn
                        width: 30; height: 30
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        onClicked: drawer.back()
                        LIcon { anchors.centerIn: parent; icon: "arrow_back"; size: 18; color: Theme.textSecondary }
                    }
                    IconImage {
                        id: menuIcon
                        visible: drawer.stack.length === 1
                        anchors { left: backBtn.right; leftMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                        implicitSize: 18
                        source: drawer.menuApp?.icon ?? ""
                    }
                    LText {
                        anchors { left: menuIcon.visible ? menuIcon.right : backBtn.right; leftMargin: Theme.space.s2; right: parent.right; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        role: "bodyStrong"
                        text: menuPage.level?.title ?? ""
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.border }

                Repeater {
                    model: opener.children
                    delegate: Loader {
                        id: entryLoader
                        required property var modelData
                        width: menuPage.width
                        sourceComponent: modelData.isSeparator ? sepC : entryC
                        Component {
                            id: sepC
                            Item { height: 9; Rectangle { anchors.centerIn: parent; width: parent.width - Theme.space.s4; height: 1; color: Theme.border } }
                        }
                        Component {
                            id: entryC
                            HoverTarget {
                                readonly property var e: entryLoader.modelData
                                height: 34
                                radius: Theme.radius.sm
                                enabled: e.enabled
                                opacity: e.enabled ? 1 : 0.4
                                onClicked: {
                                    if (e.hasChildren) { drawer.stack = drawer.stack.concat([{ handle: e, title: e.text.replace(/&(?!&)/g, "") }]); return; }
                                    e.triggered();
                                    drawer.close();
                                }
                                // Check box / radio state, else the entry's icon
                                Item {
                                    id: lead
                                    width: 20; height: 20
                                    anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                    LIcon {
                                        anchors.centerIn: parent
                                        visible: e.buttonType !== QsMenuButtonType.None
                                        icon: e.buttonType === QsMenuButtonType.RadioButton
                                              ? (e.checkState === Qt.Checked ? "radio_button_checked" : "radio_button_unchecked")
                                              : (e.checkState === Qt.Checked ? "check_box" : "check_box_outline_blank")
                                        size: 17
                                        fill: e.checkState === Qt.Checked ? 1 : 0
                                        color: e.checkState === Qt.Checked ? Theme.accent : Theme.textMuted
                                    }
                                    IconImage {
                                        anchors.centerIn: parent
                                        visible: e.buttonType === QsMenuButtonType.None && (e.icon ?? "") !== ""
                                        implicitSize: 16
                                        source: e.icon ?? ""
                                    }
                                }
                                LText {
                                    anchors { left: lead.right; leftMargin: Theme.space.s2; right: chev.left; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                                    elide: Text.ElideRight
                                    // "&File" mnemonics → "File" ("&&" is a literal &)
                                    text: e.text.replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&")
                                }
                                LIcon {
                                    id: chev
                                    visible: e.hasChildren
                                    anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                    icon: "chevron_right"; size: 16; color: Theme.textMuted
                                }
                            }
                        }
                    }
                }
                LText {
                    visible: opener.children.values.length === 0
                    leftPadding: Theme.space.s2; topPadding: Theme.space.s2; bottomPadding: Theme.space.s2
                    role: "caption"; color: Theme.textMuted
                    text: "Loading…"
                }
            }
        }
    }
}
