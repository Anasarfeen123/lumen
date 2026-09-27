// Your phone and your messages, at a glance. Counts only: never a chat's
// name or a word of a message — the lock screen is visible to anyone at the
// desk (Lumen Inbox also wipes previews while locked).
import QtQuick
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 176
    implicitHeight: 176

    readonly property var phone: Link.phone
    readonly property bool showPhone: Persist.data.lockPhone && phone !== null
    readonly property int unread: Inbox.unreadTotal
    readonly property int chats: Inbox.unreadConversations.length
    readonly property bool showMessages: Persist.data.lockMessages && WhatsApp.enabled && unread > 0
    readonly property bool wanted: showPhone || showMessages

    Column {
        anchors { fill: parent; margins: Theme.space.s4 }
        spacing: Theme.space.s3

        // Phone
        Column {
            visible: root.showPhone
            width: parent.width
            spacing: 2
            Row {
                spacing: Theme.space.s2
                LIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "smartphone"; size: 18; fill: root.phone?.reachable ? 1 : 0
                    color: root.phone?.reachable ? Theme.accent : Theme.textMuted
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (root.phone?.reachable && (root.phone?.battery ?? -1) >= 0) ? root.phone.battery + "%" : "—"
                    color: (root.phone?.battery ?? 100) <= 15 && !root.phone?.charging ? Theme.warning : Theme.text
                    font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                }
                LIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.phone?.charging ?? false
                    icon: "bolt"; size: 14; fill: 1; color: Theme.success
                }
            }
            LText {
                width: parent.width; elide: Text.ElideRight
                role: "caption"; color: Theme.textSecondary
                text: root.phone?.reachable ? (root.phone.name + " · " + Link.viaLabel(root.phone.via)).replace(/ · $/, "") : "Phone not linked"
            }
        }

        Rectangle { visible: root.showPhone && root.showMessages; width: parent.width; height: 1; color: Theme.border }

        // Messages: how many, in how many chats
        Column {
            visible: root.showMessages
            width: parent.width
            spacing: 2
            Row {
                spacing: Theme.space.s2
                LIcon { anchors.verticalCenter: parent.verticalCenter; icon: "forum"; size: 18; fill: 1; color: Theme.accent }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.unread
                    color: Theme.text
                    font.family: Theme.fontUi; font.pixelSize: 26; font.weight: Font.Light
                    font.features: ({ "tnum": 1 })
                }
            }
            LText {
                width: parent.width; elide: Text.ElideRight
                role: "caption"; color: Theme.textSecondary
                text: (root.unread === 1 ? "unread message" : "unread messages") + " · " + root.chats + (root.chats === 1 ? " chat" : " chats")
            }
        }
    }
}
