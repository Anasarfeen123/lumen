// WhatsApp: how Lumen works with WhatsApp (Lumen Inbox's first provider) —
// switches, privacy, which chats may interrupt each Focus mode, a small
// contact book (name → number) for opening chats, and what Lumen can't do.
// Everything here is stored in ~/.local/state/lumen/whatsapp.json: switches,
// chat names and numbers. Never message text.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "WhatsApp"
    subtitle: "Messages in the island and the Ribbon, quick replies (Super+Shift+W), chats in search. WhatsApp itself keeps doing the talking: Lumen only reads its notifications and opens chats for you."

    readonly property var cfg: WhatsApp.cfg
    // Chat names Lumen knows of: seen this session, in the contact book, or already chosen somewhere
    readonly property var knownChats: {
        const s = new Set();
        for (const c of Inbox.conversations) if (c.provider === "whatsapp") s.add(c.title);
        for (const c of (cfg.contacts ?? [])) s.add(c.name);
        for (const k in (cfg.focusAllow ?? {})) for (const n of cfg.focusAllow[k]) s.add(n);
        for (const n of (cfg.muted ?? [])) s.add(n);
        return Array.from(s).sort((a, b) => a.localeCompare(b));
    }

    Group {
        title: "WhatsApp"
        SetRow {
            icon: "forum"
            title: "Work with WhatsApp"
            description: !WhatsApp.available ? "WhatsApp isn't installed — install Whatsie, or use the web app below"
                       : WhatsApp.running ? "Connected to " + (WhatsApp.clientKind === "whatsie" ? "Whatsie" : "WhatsApp Web") + " — it's open"
                       : "Using " + (WhatsApp.clientKind === "whatsie" ? "Whatsie" : "WhatsApp Web") + " · it isn't open right now"
            LSwitch { checked: page.cfg.enabled; onToggled: page.cfg.enabled = !checked }
        }
        SetRow {
            visible: page.cfg.enabled
            icon: "apps"
            title: "WhatsApp app"
            description: "Whatsie is a desktop app for WhatsApp Web; the web app opens WhatsApp Web in your browser as its own window"
            Segmented {
                width: 300
                options: [{ id: "auto", label: "Automatic" }, { id: "whatsie", label: "Whatsie" }, { id: "web", label: "Web app" }]
                current: page.cfg.client
                onPicked: id => page.cfg.client = id
            }
        }
        SetRow {
            visible: page.cfg.enabled
            icon: "notifications"
            title: "Notifications"
            description: "New messages and calls appear in the island, grouped by chat in the notification centre"
            LSwitch { checked: page.cfg.notifications; onToggled: page.cfg.notifications = !checked }
        }
        SetRow {
            visible: page.cfg.enabled
            icon: "top_panel_open"
            title: "In the Ribbon"
            description: "A small chip with unread chats, or who's calling"
            LSwitch { checked: page.cfg.ribbon; onToggled: page.cfg.ribbon = !checked }
        }
        SetRow {
            visible: page.cfg.enabled
            icon: "play_circle"
            title: "Open WhatsApp when Lumen starts"
            description: "In the background, so notifications arrive from the start"
            LSwitch { checked: page.cfg.startWithLumen; onToggled: page.cfg.startWithLumen = !checked }
        }
    }

    Group {
        title: "Privacy"
        visible: page.cfg.enabled
        SetRow {
            icon: "visibility"
            title: "Show message previews"
            description: page.cfg.previews ? "The island and notification centre show what was said. Kept in memory only, and wiped when the screen locks."
                                           : "Only who wrote: \"New message\""
            LSwitch { checked: page.cfg.previews; onToggled: page.cfg.previews = !checked }
        }
        SetRow {
            icon: "auto_awesome"
            title: "Halo message context"
            description: "Let Halo read the previews seen this session when you ask it (\"what did Arya say?\"). Off unless you turn it on; Halo always asks before sending anything."
            LSwitch { checked: page.cfg.haloContext; onToggled: page.cfg.haloContext = !checked }
        }
        SetRow {
            icon: "search"
            title: "Chats in every search"
            description: "Plain searches also list chat names. Off: only \"wa …\" or \"whatsapp …\" searches do. Message text is never searched."
            LSwitch { checked: page.cfg.searchNames; onToggled: page.cfg.searchNames = !checked }
        }
    }

    // ── Focus modes: which chats may interrupt ──
    Group {
        title: "Chats that can reach you in Focus"
        visible: page.cfg.enabled
        SetRow {
            visible: page.knownChats.length === 0
            icon: "info"
            title: "No chats yet"
            description: "Chats appear here once one of their messages arrives, or when you add them to your contacts below."
        }
        Repeater {
            model: page.knownChats.length ? Focus.modes.filter(m => m.id !== "off") : []
            delegate: SetRow {
                id: modeRow
                required property var modelData
                icon: modelData.icon
                title: modelData.label
                description: {
                    const n = (page.cfg.focusAllow?.[modelData.id] ?? []).length;
                    return n ? n + " chat" + (n > 1 ? "s" : "") + " can interrupt" : "Every chat waits";
                }
                Flow {
                    width: 330
                    spacing: 6
                    layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: page.knownChats
                        delegate: HoverTarget {
                            id: chip
                            required property string modelData
                            readonly property bool on: (page.cfg.focusAllow?.[modeRow.modelData.id] ?? []).includes(modelData)
                            width: cl.implicitWidth + 30; height: 26
                            onClicked: WhatsApp.setAllowed(modeRow.modelData.id, modelData, !on)
                            Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                                        color: chip.on ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                                        border.width: 1; border.color: chip.on ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border }
                            Row { anchors.centerIn: parent; spacing: 4
                                  LIcon { icon: chip.on ? "check_box" : "check_box_outline_blank"; size: 14; color: chip.on ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                  LText { id: cl; role: "caption"; text: chip.modelData; color: chip.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter } }
                        }
                    }
                }
            }
        }
    }

    Group {
        title: "Muted chats"
        visible: page.cfg.enabled && (page.cfg.muted ?? []).length > 0
        Repeater {
            model: page.cfg.muted ?? []
            delegate: SetRow {
                required property string modelData
                icon: "notifications_off"
                title: modelData
                description: "Kept in the notification centre, never shown in the island"
                Button { text: "Unmute"; onActivated: WhatsApp.setMuted(modelData, false) }
            }
        }
    }

    // ── Contacts: name → number, so Lumen can open the right chat ──
    property string contactMsg: ""
    Group {
        title: "Contacts"
        visible: page.cfg.enabled
        SetRow {
            icon: "contacts"
            title: "Why numbers?"
            description: "WhatsApp opens a chat by phone number. Add the people you reply to often and Lumen goes straight to their chat; without a number, WhatsApp asks you to pick the chat. Only names and numbers are stored."
        }
        Repeater {
            model: page.cfg.contacts ?? []
            delegate: SetRow {
                required property var modelData
                icon: "person"
                title: modelData.name
                description: "+" + modelData.number
                Button { text: "Remove"; onActivated: WhatsApp.removeContact(modelData.name) }
            }
        }
        SetRow {
            icon: "person_add"
            title: "Add a contact"
            description: page.contactMsg !== "" ? page.contactMsg : "Name, then number with country code (10 digits are taken as India, +91)"
            Row {
                spacing: Theme.space.s2
                LField { id: cName; width: 140; icon: "person"; placeholder: "Name"; clearOnAccept: false; onAccepted: cNum.input.forceActiveFocus() }
                LField { id: cNum; width: 170; icon: "call"; placeholder: "+91 98765 43210"; clearOnAccept: false; onAccepted: addBtn.activated() }
                Button {
                    id: addBtn
                    text: "Add"
                    onActivated: {
                        if (WhatsApp.addContact(cName.text, cNum.text)) { page.contactMsg = cName.text.trim() + " added"; cName.text = ""; cNum.text = ""; }
                        else page.contactMsg = "Enter a name and a phone number (8–15 digits)";
                    }
                }
            }
        }
    }

    Group {
        title: "What Lumen can and can't do"
        SetRow { icon: "check_circle"; title: "Can"; description: "Show new messages and calls, group them by chat, open a chat, start a reply with your text typed in, hand WhatsApp files to paste, and keep chats quiet during Focus." }
        SetRow { icon: "do_not_disturb_on"; title: "Can't mark chats as read in WhatsApp"; description: "Dismiss clears them in Lumen only. There's no supported way to change WhatsApp's own read state." }
        SetRow { icon: "call"; title: "Can't answer calls"; description: "\"Open WhatsApp to answer\" brings WhatsApp to the front; you answer there." }
        SetRow { icon: "send"; title: "Doesn't send messages by itself"; description: "Replies open in WhatsApp with your text typed in. You press Enter there — nothing is ever sent without you." }
        SetRow { icon: "history"; title: "Can't search your history"; description: "Lumen only knows what arrived as notifications since it started, and forgets it when you log out or lock the screen." }
        SetRow { icon: "shield"; title: "Doesn't touch your account"; description: "No unofficial WhatsApp libraries, no reading WhatsApp's data or session. Only its notifications, its links and its window." }
    }
}
