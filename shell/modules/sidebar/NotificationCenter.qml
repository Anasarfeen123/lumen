// Notifications tab.
//
//   toolbar   Do Not Disturb pill · Clear all (the count is on the tab)
//   groups    one card per app (most recently active first): app icon, name,
//             count, newest time, collapse, dismiss-all. Inside, newest first.
//             More than two → collapsed to the latest two with a stacked-
//             sheets edge and "Show N more".
//   empty     "You're all caught up" (or the Do Not Disturb note)
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── model → groups ──
    property var groups: []
    property var expanded: ({})           // appName → true
    function rebuild() {
        const m = Notifications.model, order = [], by = {};
        for (let i = 0; i < m.count; i++) {
            const e = m.get(i);
            if (!by[e.appName]) { by[e.appName] = []; order.push(e.appName); }
            by[e.appName].push({ nid: e.nid, appName: e.appName, icon: e.icon, summary: e.summary, body: e.body,
                                 urgency: e.urgency, time: e.time, canReply: e.canReply, chatKey: e.chatKey ?? "" });
        }
        groups = order.map(app => ({ app, items: by[app] }));
    }
    Connections {
        target: Notifications.model
        function onCountChanged() { Qt.callLater(root.rebuild); }
        function onRowsMoved() { Qt.callLater(root.rebuild); }
        function onDataChanged() { Qt.callLater(root.rebuild); }
    }
    Component.onCompleted: rebuild()

    // ── toolbar ──
    Item {
        id: toolbar
        width: parent.width
        height: 34

        Item {
            anchors.fill: parent

            // Do Not Disturb pill (left) · Clear all (right)
            HoverTarget {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: dndRow.implicitWidth + Theme.space.s3 * 2; height: 30
                onClicked: Notifications.setDnd(!Notifications.dnd)
                Rectangle {
                    anchors.fill: parent; radius: height / 2
                    color: Notifications.dnd ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                    border.width: 1
                    border.color: Notifications.dnd ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                }
                Row {
                    id: dndRow
                    anchors.centerIn: parent
                    spacing: 6
                    LIcon { anchors.verticalCenter: parent.verticalCenter; size: 16
                            icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"; fill: Notifications.dnd ? 1 : 0
                            color: Notifications.dnd ? Theme.accent : Theme.textSecondary }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"
                            color: Notifications.dnd ? Theme.accent : Theme.textSecondary; text: "Do Not Disturb" }
                }
            }
            HoverTarget {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                visible: Notifications.count > 0
                width: clearRow.implicitWidth + Theme.space.s3 * 2; height: 30
                onClicked: Notifications.clearAll()
                Rectangle { anchors.fill: parent; radius: height / 2; color: "transparent"; border.width: 1; border.color: Theme.border }
                Row {
                    id: clearRow
                    anchors.centerIn: parent
                    spacing: 6
                    LIcon { anchors.verticalCenter: parent.verticalCenter; icon: "clear_all"; size: 16; color: Theme.textSecondary }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textSecondary; text: "Clear all" }
                }
            }
        }
    }

    // ── groups ──
    Flickable {
        id: flick
        anchors { top: toolbar.bottom; topMargin: Theme.space.s3; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: stack.implicitHeight + Theme.space.s4
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Column {
            id: stack
            width: flick.width
            spacing: Theme.space.s3

            Repeater {
                model: root.groups
                delegate: Item {
                    id: group
                    required property var modelData
                    readonly property var items: modelData.items
                    readonly property bool collapsible: items.length > 2
                    readonly property bool open: !collapsible || root.expanded[modelData.app] === true
                    readonly property var shown: open ? items : items.slice(0, 2)
                    width: stack.width
                    height: card.height + (collapsible && !open ? 10 : 0)

                    // Dismiss the whole app: the card slides away, then goes
                    SequentialAnimation {
                        id: groupLeave
                        ParallelAnimation {
                            NumberAnimation { target: group; property: "x"; to: group.width; duration: Theme.reducedMotion ? 0 : 240; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
                            NumberAnimation { target: group; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 220 }
                        }
                        ScriptAction { script: Notifications.dismissApp(group.modelData.app) }
                    }

                    // Stacked sheets peeking out below a collapsed group
                    Repeater {
                        model: group.collapsible && !group.open ? 2 : 0
                        delegate: Rectangle {
                            required property int index
                            anchors.horizontalCenter: card.horizontalCenter
                            y: card.height - Theme.radius.md + (index + 1) * 5
                            width: card.width - (index + 1) * 16
                            height: Theme.radius.md
                            radius: Theme.radius.md
                            z: -1 - index
                            color: Theme.surfaceElevated
                            opacity: 0.7 - index * 0.25
                            border.width: 1; border.color: Theme.border
                        }
                    }

                    Rectangle {
                        id: card
                        width: parent.width
                        height: col.implicitHeight
                        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                        radius: Theme.radius.md
                        color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
                        border.width: 1
                        border.color: Theme.border
                        clip: true

                        Column {
                            id: col
                            width: parent.width

                            // Group header
                            Item {
                                width: parent.width
                                height: 36
                                ClippingRectangle {
                                    id: appIcon
                                    anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                                    width: 20; height: 20; radius: 6
                                    color: "transparent"
                                    Image { id: gIcon; anchors.fill: parent; source: group.items[0].icon; sourceSize: Qt.size(40, 40); fillMode: Image.PreserveAspectFit; asynchronous: true }
                                    LIcon { anchors.centerIn: parent; visible: gIcon.status !== Image.Ready; icon: "notifications"; size: 16; fill: 1; color: Theme.textMuted }
                                }
                                LText {
                                    id: appLabel
                                    anchors { left: appIcon.right; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                    role: "bodyStrong"
                                    text: group.modelData.app
                                }
                                Rectangle {
                                    visible: group.items.length > 1
                                    anchors { left: appLabel.right; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                    height: 18; width: Math.max(18, n.implicitWidth + 10); radius: 9
                                    color: Theme.surfaceHover
                                    LText { id: n; anchors.centerIn: parent; role: "caption"; color: Theme.textSecondary; text: group.items.length }
                                }
                                Row {
                                    anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    LText {
                                        anchors.verticalCenter: parent.verticalCenter
                                        rightPadding: Theme.space.s1
                                        role: "caption"; color: Theme.textMuted
                                        text: Notifications.relativeTime(group.items[0].time, clock.date.getTime())
                                    }
                                    HoverTarget {
                                        visible: group.collapsible
                                        width: 26; height: 26
                                        onClicked: { const e = Object.assign({}, root.expanded); e[group.modelData.app] = !group.open; root.expanded = e; }
                                        LIcon { anchors.centerIn: parent; icon: "expand_more"; size: 18; color: Theme.textSecondary
                                                rotation: group.open ? 180 : 0
                                                Behavior on rotation { NumberAnimation { duration: Theme.motion.normal } } }
                                    }
                                    HoverTarget {
                                        width: 26; height: 26
                                        onClicked: groupLeave.start()
                                        LIcon { anchors.centerIn: parent; icon: "close"; size: 16; color: Theme.textMuted }
                                    }
                                }
                            }

                            Repeater {
                                model: group.shown
                                delegate: NotificationCard {
                                    required property var modelData
                                    required property int index
                                    width: col.width
                                    entry: modelData
                                    first: index === 0
                                    now: clock.date.getTime()
                                }
                            }

                            // "Show N more"
                            HoverTarget {
                                visible: group.collapsible
                                width: parent.width; height: 34
                                radius: 0
                                onClicked: { const e = Object.assign({}, root.expanded); e[group.modelData.app] = !group.open; root.expanded = e; }
                                Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
                                            height: 1; color: Theme.border }
                                LText {
                                    anchors.centerIn: parent
                                    role: "caption"
                                    color: Theme.accent
                                    text: group.open ? "Show less" : "Show " + (group.items.length - 2) + " more"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── empty ──
    Column {
        anchors.centerIn: flick
        visible: Notifications.count === 0
        spacing: Theme.space.s3
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 76; height: 76; radius: 38
            color: Theme.withAlpha(Theme.accent, 0.10)
            border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.25)
            LIcon {
                anchors.centerIn: parent
                icon: Notifications.dnd ? "do_not_disturb_on" : "notifications_active"
                size: 34; fill: 1
                color: Theme.accent
            }
        }
        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "heading"
                text: Notifications.dnd ? "Do Not Disturb is on" : "You're all caught up" }
        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted
                text: Notifications.dnd ? "Only urgent alerts will interrupt you" : "New notifications will appear here" }
    }
}
