// One notification inside its app's group card.
// Hover: soft highlight and a × · swipe right (or ×) dismisses · click opens.
// Live notifications show their action buttons and, if supported, a reply field.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    property var entry: ({})
    property bool first: false
    property real now: Date.now()

    readonly property int nid: entry.nid ?? 0
    readonly property var liveNotif: Notifications.live[nid] ?? null
    readonly property var actions: (liveNotif?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool critical: (entry.urgency ?? 1) === 2

    // Leaving: slide out to the right and fade, then the gap closes; only then
    // is it removed (so the list never jumps)
    property bool leaving: false
    function dismissAnimated() {
        if (leaving) return;
        body.x = body.x; body.opacity = body.opacity;      // freeze: the animation takes over from here
        leaving = true;
        leave.start();
    }
    height: leaving ? collapse : body.height
    property real collapse: body.height
    clip: leaving
    SequentialAnimation {
        id: leave
        ParallelAnimation {
            NumberAnimation { target: body; property: "x"; to: root.width; duration: Theme.reducedMotion ? 0 : 220; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
            NumberAnimation { target: body; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 200 }
        }
        NumberAnimation { target: root; property: "collapse"; to: 0; duration: Theme.reducedMotion ? 0 : 180; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
        ScriptAction { script: Notifications.dismiss(root.nid) }
    }
    // Arriving: rise and fade in
    // Only genuinely new ones (the list is rebuilt on every change)
    readonly property bool fresh: Date.now() - (entry.time ?? 0) < 3000
    Component.onCompleted: if (fresh) arrive.start()
    ParallelAnimation {
        id: arrive
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: Theme.reducedMotion ? 0 : Theme.motion.normal }
        NumberAnimation { target: body; property: "y"; from: 8; to: 0; duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
    }

    Item {
        id: body
        x: drag.active ? drag.xOffset : 0
        width: parent.width
        height: content.implicitHeight + (root.first ? Theme.space.s1 : Theme.space.s3) + Theme.space.s3
        opacity: 1 - Math.min(0.7, Math.max(0, x) / (width * 0.8))
        Behavior on x { enabled: !drag.active && !root.leaving; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

        Rectangle {        // hover wash
            anchors { fill: parent; leftMargin: 4; rightMargin: 4 }
            radius: Theme.radius.sm
            color: Theme.surfaceHover
            opacity: hover.hovered ? 0.6 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
        }
        Rectangle {        // hairline between entries
            visible: !root.first
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
            height: 1
            color: Theme.border
        }
        Rectangle {        // urgent: error-tone edge
            visible: root.critical
            width: 3; radius: 1.5
            color: Theme.error
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: Theme.space.s2 }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: (root.entry.chatKey ?? "") !== "" ? Inbox.open(root.entry.chatKey) : Notifications.activate(root.nid) }
        DragHandler {
            id: drag
            xAxis.enabled: true; yAxis.enabled: false
            xAxis.minimum: 0
            property real xOffset: Math.max(0, translation.x)
            onActiveChanged: if (!active && translation.x > body.width * 0.35) root.dismissAnimated()
        }

        Column {
            id: content
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space.s3; topMargin: root.first ? Theme.space.s1 : Theme.space.s3; leftMargin: Theme.space.s3 + (root.critical ? 6 : 0) }
            spacing: 3

            Item {
                width: parent.width; height: title.implicitHeight
                LText { id: title; anchors { left: parent.left; right: meta.left; rightMargin: Theme.space.s2 }
                        role: "bodyStrong"; text: root.entry.summary ?? ""; elide: Text.ElideRight; textFormat: Text.PlainText }
                Item {
                    id: meta
                    anchors.right: parent.right
                    width: Math.max(timeLabel.implicitWidth, 20); height: parent.height
                    LText { id: timeLabel; anchors.right: parent.right; visible: !hover.hovered; role: "caption"; color: Theme.textMuted
                            text: root.first ? "" : Notifications.relativeTime(root.entry.time ?? 0, root.now) }
                    HoverTarget {
                        visible: hover.hovered
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: 22; height: 22
                        onClicked: root.dismissAnimated()
                        LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textSecondary }
                    }
                }
            }
            LText {
                width: parent.width
                visible: text !== ""
                role: "body"; color: Theme.textSecondary
                text: root.entry.body ?? ""
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                lineHeight: 1.1
                linkColor: Theme.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                width: parent.width
                visible: root.actions.length > 0
                spacing: Theme.space.s2
                topPadding: Theme.space.s1
                Repeater {
                    model: root.actions
                    delegate: HoverTarget {
                        required property var modelData
                        width: al.implicitWidth + Theme.space.s4 * 2; height: 28
                        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.withAlpha(Theme.accent, 0.14); border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.35); z: -1 }
                        onClicked: Notifications.invoke(root.nid, modelData.identifier)
                        LText { id: al; anchors.centerIn: parent; role: "caption"; color: Theme.accent; text: modelData.text }
                    }
                }
            }

            // Messages (Lumen Inbox): reply through the Messages panel; Dismiss
            // only clears it in Lumen (WhatsApp keeps its own unread state)
            Flow {
                width: parent.width
                visible: (root.entry.chatKey ?? "") !== ""
                spacing: Theme.space.s2
                topPadding: Theme.space.s1
                Repeater {
                    model: [{ id: "reply", icon: "reply", text: "Reply", primary: true },
                            { id: "dismiss", icon: "done", text: "Dismiss" },
                            { id: "mute", icon: "notifications_off", text: "Mute chat" }]
                    delegate: HoverTarget {
                        required property var modelData
                        width: cr.implicitWidth + Theme.space.s4 * 2; height: 28
                        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                                    color: modelData.primary ? Theme.withAlpha(Theme.accent, 0.14) : Theme.withAlpha(Theme.text, 0.05)
                                    border.width: 1; border.color: modelData.primary ? Theme.withAlpha(Theme.accent, 0.35) : Theme.border }
                        onClicked: {
                            const key = root.entry.chatKey;
                            if (modelData.id === "reply") { Sidebar.hide(); Inbox.showPanel(key); }
                            else if (modelData.id === "dismiss") { Inbox.dismiss(key); root.dismissAnimated(); }
                            else { Inbox.mute(key, true); Inbox.dismiss(key); root.dismissAnimated(); }
                        }
                        Row { id: cr; anchors.centerIn: parent; spacing: 4
                              LIcon { icon: modelData.icon; size: 13; color: modelData.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                              LText { role: "caption"; color: modelData.primary ? Theme.accent : Theme.text; text: modelData.text; anchors.verticalCenter: parent.verticalCenter } }
                    }
                }
            }

            QQC.TextField {
                visible: (root.entry.canReply ?? false) && root.liveNotif !== null
                width: parent.width
                placeholderText: root.liveNotif?.inlineReplyPlaceholder || "Reply…"
                placeholderTextColor: Theme.textMuted
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.size.body
                background: Rectangle { radius: height / 2; color: Theme.surface; border.width: 1; border.color: parent.activeFocus ? Theme.accent : Theme.border }
                leftPadding: Theme.space.s3
                onAccepted: Notifications.reply(root.nid, text)
            }
        }
    }
}
