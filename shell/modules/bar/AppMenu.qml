// The focused app in the bar — its icon and name (and the window title),
// like a menu bar. Click it, or press Super+Alt+Enter, for a frosted menu of
// window actions. Esc or clicking elsewhere closes it.
//
// Visible only while the bar is merged (windows are open) and only on the
// monitor that owns the focused window.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property var barWindow
    required property var monitor
    property bool shown: false

    readonly property var focused: Hyprland.activeToplevel
    readonly property var ipc: focused?.lastIpcObject ?? ({})
    readonly property bool onThisMonitor: (focused?.monitor?.name ?? "") === (monitor?.name ?? "")
    readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")
    readonly property string appName: entry?.name || ipc.class || ""
    readonly property string address: ipc.address ?? (focused ? "0x" + focused.address : "")
    readonly property bool active: shown && onThisMonitor && appName !== ""

    implicitWidth: active ? row.implicitWidth + Theme.space.s3 * 2 : 0
    implicitHeight: Theme.barHeight
    opacity: active ? 1 : 0
    visible: opacity > 0
    clip: true
    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    Behavior on implicitWidth { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

    HoverTarget {
        anchors { fill: parent; topMargin: 4; bottomMargin: 4 }
        radius: Theme.radius.sm
        highlighted: menu.visible
        onClicked: menu.visible ? menu.close() : menu.open()

        Row {
            id: row
            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s2
            IconImage {
                anchors.verticalCenter: parent.verticalCenter
                implicitSize: 18
                source: root.entry ? Apps.iconFor(root.entry) : Quickshell.iconPath("application-x-executable")
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.appName
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 14
                font.variableAxes: ({ "wght": 650, "ROND": 60 })
                renderType: Text.NativeRendering
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                visible: text !== "" && text !== root.appName
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                role: "body"
                color: Theme.textMuted
                text: root.ipc.title ?? ""
            }
            LIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "expand_more"
                size: 16
                color: Theme.textMuted
                rotation: menu.visible ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: Theme.motion.normal } }
            }
        }
    }

    Connections {
        target: AppMenuState
        function onToggleRequested() { if (root.active) { menu.visible ? menu.close() : menu.open(); } }
    }

    // ── The menu ──
    PopupWindow {
        id: menu
        anchor.window: root.barWindow
        anchor.rect.x: root.mapToItem(root.barWindow.contentItem, 0, 0).x
        anchor.rect.y: Theme.edgeGap + Theme.barHeight + Theme.space.s2
        implicitWidth: 300
        implicitHeight: body.implicitHeight + Theme.space.s2 * 2
        color: "transparent"
        visible: false

        function open() { visible = true; }
        function close() { visible = false; }
        function act(cmd) { Hyprland.dispatch(cmd); close(); }

        HyprlandFocusGrab {
            active: menu.visible
            windows: [menu, root.barWindow]
            onCleared: menu.close()
        }

        GlassSurface {
            anchors.fill: parent
            level: "panel"
            radius: Theme.radius.md
            opacity: menu.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }

            focus: true
            Keys.onEscapePressed: menu.close()

            // Menus hold text: a denser backing than panels, still frosted
            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.45) }

            Column {
                id: body
                x: Theme.space.s2; y: Theme.space.s2
                width: parent.width - Theme.space.s2 * 2

                // Header: which window this is about
                Item {
                    width: parent.width
                    height: 52
                    IconImage {
                        id: bigIcon
                        anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                        implicitSize: 32
                        source: root.entry ? Apps.iconFor(root.entry) : Quickshell.iconPath("application-x-executable")
                    }
                    Column {
                        anchors { left: bigIcon.right; leftMargin: Theme.space.s3; right: parent.right; verticalCenter: parent.verticalCenter }
                        LText { width: parent.width; role: "heading"; text: root.appName; elide: Text.ElideRight }
                        LText { width: parent.width; role: "caption"; color: Theme.textMuted; text: root.ipc.title ?? ""; elide: Text.ElideRight }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.border }

                component Item_: HoverTarget {
                    id: it
                    property string icon: ""
                    property string label: ""
                    property string keys: ""
                    property bool checked: false
                    property bool danger: false
                    width: body.width
                    height: 34
                    radius: Theme.radius.sm
                    LIcon { id: ic; anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            icon: it.checked ? "check" : it.icon; size: 18; color: it.danger ? Theme.error : it.checked ? Theme.accent : Theme.textSecondary }
                    LText { anchors { left: ic.right; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            text: it.label; color: it.danger ? Theme.error : Theme.text }
                    LText { anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            role: "caption"; color: Theme.textMuted; text: it.keys }
                }

                Item_ {
                    visible: !!root.entry
                    icon: "open_in_new"; label: "New window"
                    onClicked: { root.entry?.execute(); menu.close(); }
                }
                Item_ { icon: "picture_in_picture"; label: "Float"; keys: "Super+Alt+Space"; checked: root.ipc.floating === true
                        onClicked: menu.act("togglefloating address:" + root.address) }
                Item_ { icon: "fit_screen"; label: "Maximise"; keys: "Super+D"; checked: root.ipc.fullscreen === 1
                        onClicked: menu.act("fullscreen 1") }
                Item_ { icon: "fullscreen"; label: "Fullscreen"; keys: "Super+F"; checked: root.ipc.fullscreen === 2
                        onClicked: menu.act("fullscreen 0") }
                Item_ { icon: "push_pin"; label: "Keep on all workspaces"; keys: "Super+P"; checked: root.ipc.pinned === true
                        onClicked: menu.act("pin address:" + root.address) }

                // Move to workspace
                Item {
                    width: parent.width
                    height: 40
                    LText { anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            role: "caption"; color: Theme.textMuted; text: "Move to" }
                    Row {
                        anchors { right: parent.right; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                        spacing: 4
                        Repeater {
                            model: [1, 2, 3, 4, 5]
                            delegate: HoverTarget {
                                required property int modelData
                                readonly property bool here: (root.ipc.workspace?.id ?? 0) === modelData
                                width: 30; height: 28
                                radius: Theme.radius.sm
                                highlighted: here
                                onClicked: menu.act(`movetoworkspacesilent ${modelData},address:${root.address}`)
                                LText { anchors.centerIn: parent; role: "bodyStrong"; text: modelData; color: parent.here ? Theme.accent : Theme.text }
                            }
                        }
                        HoverTarget {
                            width: 30; height: 28
                            radius: Theme.radius.sm
                            onClicked: menu.act(`movetoworkspacesilent special:scratch,address:${root.address}`)
                            LIcon { anchors.centerIn: parent; icon: "inventory_2"; size: 16 }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Item_ { icon: "screenshot_monitor"; label: "Screenshot this window"; keys: "Alt+PrtSc"
                        onClicked: { menu.close(); Quickshell.execDetached(["sh", "-c", "sleep 0.25; exec \"$1\" window", "sh", Theme.lumenRoot + "/scripts/screenshot.sh"]); } }
                Item_ { icon: "close"; label: "Close"; keys: "Super+Q"
                        onClicked: menu.act("closewindow address:" + root.address) }
                Item_ { icon: "dangerous"; label: "Force quit"; danger: true
                        onClicked: menu.act("killwindow address:" + root.address) }
            }
        }
    }
}
