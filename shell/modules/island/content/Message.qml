// message — a chat speaking up (Lumen Inbox): the sender's picture, the chat,
// the preview (or just "New message" if previews are off), and what you can do.
//   message   Reply · Open · Dismiss · Mute
//   call      Open WhatsApp to answer · Dismiss   (calls are answered in WhatsApp itself)
//   missed    Call back (opens the chat) · Dismiss
//   info: { key, provider, title, isGroup, avatar, text, unread, kind, video, others }
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property var info
    readonly property bool isCall: info.kind === "call"
    readonly property bool isMissed: info.kind === "missed"
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: Math.max(44, col.implicitHeight) + Theme.space.s3 + 30

    // Picture: the sender's photo, else their initial
    Item {
        id: pic
        width: 44; height: 44
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Theme.withAlpha(Theme.accent, root.isCall ? 0.3 : 0.16)
            visible: img.status !== Image.Ready
            LText { anchors.centerIn: parent; visible: !root.isCall && !root.isMissed; role: "heading"; color: Theme.accent
                    text: (Array.from((root.info.title ?? "?").replace(/^[~+\s\d()-]+/, "") || "?")[0] ?? "?").toUpperCase() }
            LIcon { anchors.centerIn: parent; visible: root.isCall || root.isMissed; fill: 1; color: root.isMissed ? Theme.warning : Theme.accent
                    icon: root.isMissed ? "phone_missed" : (root.info.video ? "videocam" : "call") }
        }
        ClippingRectangle {
            anchors.fill: parent; radius: width / 2
            color: "transparent"
            visible: img.status === Image.Ready
            Image { id: img; anchors.fill: parent; source: root.info.avatar || ""; sourceSize: Qt.size(88, 88); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
        // A ringing call breathes
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: width; radius: width / 2
            color: "transparent"; border.width: 2; border.color: Theme.accent
            visible: root.isCall && !Theme.reducedMotion
            SequentialAnimation on opacity { running: root.isCall; loops: Animation.Infinite
                NumberAnimation { from: 0.8; to: 0; duration: 1100; easing.type: Easing.OutQuad } }
            SequentialAnimation on scale { running: root.isCall; loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.25; duration: 1100; easing.type: Easing.OutQuad } }
        }
    }

    Column {
        id: col
        anchors { left: pic.right; leftMargin: Theme.space.s3; right: parent.right; top: parent.top }
        spacing: 2
        Row {
            spacing: Theme.space.s1
            LIcon { icon: "forum"; size: 13; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            LText {
                role: "caption"; color: Theme.textMuted
                text: "WhatsApp" + (root.info.isGroup ? " · group" : "")
                      + ((root.info.unread ?? 0) > 1 ? " · " + root.info.unread + " new" : "")
                      + ((root.info.others ?? 0) > 0 ? " · " + root.info.others + " other chat" + (root.info.others > 1 ? "s" : "") : "")
            }
        }
        LText { width: parent.width; role: "heading"; text: root.isCall ? (root.info.title + " is calling") : (root.info.title ?? ""); elide: Text.ElideRight; textFormat: Text.PlainText }
        LText {
            width: parent.width; role: "body"; color: Theme.textSecondary; textFormat: Text.PlainText
            elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            text: root.isCall ? (root.info.video ? "Video call" : "Voice call") + " · answer it in WhatsApp" : (root.info.text ?? "")
        }
    }

    Row {
        anchors { left: col.left; bottom: parent.bottom }
        spacing: Theme.space.s2
        Act { visible: !root.isCall && !root.isMissed; primary: true; icon: "reply"; text: "Reply"
              onClicked: { Island.dismiss(); Inbox.showPanel(root.info.key); } }
        Act { visible: root.isCall; primary: true; icon: "call"; text: "Open WhatsApp to answer"
              onClicked: { Island.dismiss(); Inbox.focusApp(root.info.provider); } }
        Act { visible: root.isMissed; primary: true; icon: "call"; text: "Call back"
              onClicked: { Island.dismiss(); Inbox.open(root.info.key); } }
        Act { visible: !root.isCall; icon: "open_in_new"; text: "Open"
              onClicked: { Island.dismiss(); Inbox.open(root.info.key); } }
        Act { icon: "done"; text: "Dismiss"
              onClicked: { Inbox.dismiss(root.info.key); if (root.isCall) Inbox.call = null; Island.dismiss(); } }
        Act { visible: !root.isCall; icon: "notifications_off"; text: "Mute"
              onClicked: { Inbox.mute(root.info.key, true); Inbox.dismiss(root.info.key); Island.dismiss(); } }
    }

    component Act: HoverTarget {
        id: act
        property string icon
        property string text
        property bool primary: false
        width: actRow.implicitWidth + 20; height: 28
        Rectangle {
            anchors.fill: parent; radius: height / 2; z: -1
            color: act.primary ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.text, 0.06)
            border.width: 1; border.color: act.primary ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
        }
        Row { id: actRow; anchors.centerIn: parent; spacing: 5
              LIcon { icon: act.icon; size: 14; color: act.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: act.text; color: act.primary ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }
}
