// timeline — the last hour, scrubbed like a film strip.
//   ╭──────────────────────────────────────────╮
//   │ ⟲ Now · last hour            12 min ago  │
//   │ [icon]  Title                            │
//   │         detail…                          │
//   │         [Open] [Reply]                   │
//   │ ─┃──┃────┃──────┃────────●now──┃──        │
//   ╰──────────────────────────────────────────╯
// Shift+scroll / sideways scroll (or ←/→) moves through moments; the card
// cross-fades between them and the cursor glides along the strip.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: col.implicitHeight

    readonly property var items: Island.timeline
    readonly property var item: Island.timelineItem
    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: true; onTriggered: root.now = Date.now() }

    function ago(t) {
        const m = Math.round((root.now - t) / 60000);
        if (m < 0) return "in " + -m + " min";
        if (m === 0) return "just now";
        if (m < 60) return m + " min ago";
        return "an hour ago";
    }

    // Cross-fade: the card shows `shown`, which follows `item` through a short fade
    property var shown: item
    onItemChanged: fade.restart()
    SequentialAnimation {
        id: fade
        NumberAnimation { target: entry; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 70 }
        ScriptAction { script: root.shown = root.item }
        NumberAnimation { target: entry; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : Theme.motion.micro }
    }

    readonly property var live: shown?.nid !== undefined ? (Notifications.live[shown.nid] ?? null) : null
    readonly property var actions: live ? live.actions.filter(a => a.identifier !== "default").slice(0, 2) : []

    Column {
        id: col
        width: parent.width
        spacing: Theme.space.s3

        // Header
        Item {
            width: parent.width; height: 18
            Row {
                spacing: 6
                anchors.verticalCenter: parent.verticalCenter
                LIcon { icon: "history"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "caption"; color: Theme.textSecondary; text: "Now · the last hour"; anchors.verticalCenter: parent.verticalCenter }
            }
            LText {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                role: "caption"
                color: root.shown?.future ? Theme.accent : Theme.textMuted
                text: root.shown ? root.ago(root.shown.time) + "   " + (Island.timelineIndex + 1) + " / " + root.items.length : ""
            }
        }

        // The moment
        Item {
            id: entry
            width: parent.width
            height: Math.max(44, text.implicitHeight) + (acts.visible ? acts.height + Theme.space.s2 : 0)
            visible: root.items.length > 0

            Rectangle {
                id: tile
                width: 40; height: 40; radius: Theme.radius.sm
                color: root.shown?.future ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.text, 0.06)
                Image {
                    id: img
                    anchors.fill: parent; anchors.margins: 6
                    visible: status === Image.Ready
                    source: root.shown?.image ?? ""
                    sourceSize: Qt.size(56, 56)
                    fillMode: Image.PreserveAspectFit
                }
                LIcon { anchors.centerIn: parent; visible: !img.visible; icon: root.shown?.icon ?? "info"; size: 20; fill: 1
                        color: root.shown?.future ? Theme.accent : Theme.textSecondary }
            }
            Column {
                id: text
                anchors { left: tile.right; leftMargin: Theme.space.s3; right: parent.right }
                spacing: 2
                LText { width: parent.width; role: "bodyStrong"; elide: Text.ElideRight; text: root.shown?.title ?? "" }
                LText { width: parent.width; role: "caption"; color: Theme.textSecondary; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        text: root.shown?.detail ?? ""; visible: text !== "" }
            }
            Row {
                id: acts
                anchors { left: text.left; top: text.bottom; topMargin: Theme.space.s2 }
                spacing: 6
                visible: children.length > 0 && (root.live !== null || !!root.shown?.path || root.shown?.kind === "event")
                Act {
                    visible: root.live !== null || !!root.shown?.path || root.shown?.kind === "event"
                    text: root.shown?.kind === "event" ? "Planner" : "Open"
                    onClicked: {
                        const s = root.shown;
                        if (s.kind === "event") Planner.open = true;
                        else if (s.path) Quickshell.execDetached(["xdg-open", s.path]);
                        else Notifications.activate(s.nid);
                        Island.closeTimeline();
                    }
                }
                Repeater {
                    model: root.actions
                    delegate: Act {
                        required property var modelData
                        text: modelData.text
                        onClicked: { Notifications.invoke(root.shown.nid, modelData.identifier); Island.closeTimeline(); }
                    }
                }
            }
        }

        LText {
            visible: root.items.length === 0
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            color: Theme.textMuted
            text: "Nothing in the last hour"
        }

        // The strip: an hour behind (left) to "now", then the next hour, compressed
        Item {
            id: strip
            width: parent.width
            height: 26
            readonly property real nowX: width * 0.82
            function xFor(t) {
                const d = t - root.now;
                return d <= 0 ? Math.max(0, nowX + d / 3600000 * nowX) : Math.min(width, nowX + d / 3600000 * (width - nowX));
            }

            Rectangle { x: 0; width: strip.nowX; y: 8; height: 2; radius: 1; color: Theme.withAlpha(Theme.text, 0.12) }
            Rectangle { x: strip.nowX; width: strip.width - strip.nowX; y: 8; height: 2; radius: 1; color: Theme.withAlpha(Theme.accent, 0.18) }
            // Now
            Rectangle { x: strip.nowX - 3; y: 6; width: 6; height: 6; radius: 3; color: Theme.textSecondary }
            LText { x: strip.nowX - width / 2; y: 14; role: "caption"; font.pixelSize: 9; color: Theme.textMuted; text: "now" }
            LText { x: 0; y: 14; role: "caption"; font.pixelSize: 9; color: Theme.textMuted; text: "1 h ago" }

            Repeater {
                model: root.items
                delegate: MouseArea {
                    required property var modelData
                    required property int index
                    x: strip.xFor(modelData.time) - 5
                    y: 0; width: 10; height: 18
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Island.timelineIndex = index
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 5; width: 2; height: 8; radius: 1
                        color: modelData.future ? Theme.accent : Theme.textMuted
                        opacity: parent.containsMouse ? 1 : 0.7
                    }
                }
            }
            // Cursor: glides to the chosen moment
            Rectangle {
                visible: root.item !== null
                x: strip.xFor(root.item?.time ?? root.now) - width / 2
                y: 1; width: 4; height: 16; radius: 2
                color: Theme.accent
                Behavior on x { enabled: !Theme.reducedMotion; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
        }
    }

    component Act: HoverTarget {
        id: act
        property string text
        width: al.implicitWidth + 20; height: 24
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: Theme.withAlpha(Theme.text, 0.06); border.width: 1; border.color: Theme.border }
        LText { id: al; anchors.centerIn: parent; role: "caption"; text: act.text }
    }
}
