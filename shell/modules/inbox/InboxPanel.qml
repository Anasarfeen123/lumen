// Messages (Super+Shift+W): Lumen Inbox's quick reply, dropping from under
// the island like Halo.
//   chats     unread first, then recent; type to find (your contact book too)
//   compose   Enter on a chat → type → Enter → "Open WhatsApp with this
//             message?" → Enter: WhatsApp opens with it typed in; you send it.
// Lumen never sends anything itself. Esc steps back, then closes.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Inbox.panelOpen && isFocused

    // stage: "list" → "compose" → "confirm"
    property string stage: "list"
    property var target: null           // { key, title, provider } or a contact { title }
    property string draftText: ""
    property int current: 0

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-inbox"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: showing ? catcher : null }

    onShowingChanged: {
        if (!showing) return;
        filter.text = ""; draftText = ""; current = 0;
        const c = Inbox.replyTo ? Inbox.conv(Inbox.replyTo) : null;
        if (c) { target = c; stage = "compose"; Qt.callLater(() => reply.forceActiveFocus()); }
        else { target = null; stage = "list"; Qt.callLater(() => filter.forceActiveFocus()); }
    }
    function close() { Inbox.panelOpen = false; }

    // Chats (unread first), plus contact-book names not yet seen this session
    readonly property var rows: {
        const q = filter.text.trim().toLowerCase();
        const seen = Inbox.conversations.filter(c => !q || c.title.toLowerCase().includes(q))
                                         .sort((a, b) => (b.unread > 0) - (a.unread > 0) || b.lastTime - a.lastTime);
        const known = new Set(seen.map(c => c.title.toLowerCase()));
        const book = (WhatsApp.cfg.contacts ?? []).filter(c => !known.has(c.name.toLowerCase()) && (!q || c.name.toLowerCase().includes(q)))
                                                  .map(c => ({ key: "", title: c.name, provider: "whatsapp", unread: 0, contact: true }));
        const out = seen.concat(book);
        // Someone new: typed a name that isn't anywhere yet
        if (q && !out.length) out.push({ key: "", title: filter.text.trim(), provider: "whatsapp", unread: 0, fresh: true });
        return out;
    }
    onRowsChanged: current = Math.min(current, Math.max(0, rows.length - 1))

    function pick(row) {
        if (!row) return;
        // Sharing files: they go on the clipboard, the chat opens, you paste
        if (Inbox.shareFiles.length) { Inbox.sendFiles(row.key || row.title, Inbox.shareFiles); close(); return; }
        target = row; stage = "compose"; draftText = "";
        reply.text = Inbox.shareText;
        Qt.callLater(() => { reply.forceActiveFocus(); reply.cursorPosition = reply.length; });
    }
    function confirmNow() {
        if (reply.text.trim() === "") return;
        draftText = reply.text.trim();
        stage = "confirm";
    }
    function sendNow() {
        const d = Inbox.compose(target.key || target.title, draftText);
        Inbox.send(d);
        close();
    }

    MouseArea { id: catcher; anchors.fill: parent; onClicked: win.close() }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(560, win.width - 64)
        height: content.implicitHeight + Theme.space.s4 * 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.edgeGap + Theme.barHeight + Theme.space.s3
        transformOrigin: Item.Top
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.normal : Theme.motion.micro) } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.55) }
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3

            // ── header ──
            Item {
                width: parent.width; height: 28
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.s2
                    HoverTarget {
                        visible: win.stage !== "list"
                        width: 26; height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: { win.stage = "list"; Qt.callLater(() => filter.forceActiveFocus()); }
                        LIcon { anchors.centerIn: parent; icon: "arrow_back"; size: 18; color: Theme.textMuted }
                    }
                    LIcon { icon: "forum"; size: 20; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "heading"; anchors.verticalCenter: parent.verticalCenter
                            text: win.stage !== "list" ? (win.target?.title ?? "")
                                : Inbox.shareFiles.length ? "Send " + (Inbox.shareFiles.length === 1 ? Inbox.shareFiles[0].replace(/.*\//, "") : Inbox.shareFiles.length + " files") + " to…"
                                : Inbox.shareText ? "Send to…" : "Messages"
                            width: Math.min(implicitWidth, 300); elide: Text.ElideMiddle }
                    LText { role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                            text: win.stage === "list" ? ("WhatsApp" + (Inbox.unreadTotal ? " · " + Inbox.unreadTotal + " unread" : "")) : "WhatsApp" }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Pill { visible: win.stage === "list" && Inbox.unreadTotal > 0; icon: "done_all"; text: "Mark all read"; onClicked: Inbox.dismissAll() }
                    Pill { icon: "open_in_new"; text: "Open WhatsApp"; onClicked: { Inbox.focusApp("whatsapp"); win.close(); } }
                    HoverTarget { width: 28; height: 28; onClicked: win.close()
                                  LIcon { anchors.centerIn: parent; icon: "close"; size: 18; color: Theme.textMuted } }
                }
            }

            // ── WhatsApp not available ──
            LText {
                visible: !WhatsApp.enabled || !WhatsApp.available
                width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                text: !WhatsApp.enabled ? "WhatsApp is turned off in Settings → WhatsApp."
                    : "WhatsApp isn't installed. Install Whatsie, or choose \"web app\" in Settings → WhatsApp."
            }

            // What you're sending (text / link), shown while you pick the chat
            Rectangle {
                visible: win.stage === "list" && Inbox.shareText !== ""
                width: parent.width; height: shareLbl.implicitHeight + 16; radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surfaceElevated, 0.8); border.width: 1; border.color: Theme.border
                LText { id: shareLbl; x: 12; y: 8; width: parent.width - 24; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        textFormat: Text.PlainText; color: Theme.textSecondary; text: Inbox.shareText }
            }
            // ── list ──
            Rectangle {
                visible: win.stage === "list"
                width: parent.width; height: 40; radius: 20
                color: Theme.withAlpha(Theme.text, 0.05)
                border.width: 1; border.color: filter.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                LIcon { id: sIcon; x: 14; anchors.verticalCenter: parent.verticalCenter; icon: "search"; size: 18; color: Theme.textMuted }
                TextInput {
                    id: filter
                    anchors { left: sIcon.right; leftMargin: 10; right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    color: Theme.text; font.family: Theme.fontUi; font.pixelSize: 14
                    selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                    Keys.onDownPressed: win.current = Math.min(win.rows.length - 1, win.current + 1)
                    Keys.onUpPressed: win.current = Math.max(0, win.current - 1)
                    Keys.onReturnPressed: win.pick(win.rows[win.current])
                    Keys.onEnterPressed: win.pick(win.rows[win.current])
                    Keys.onEscapePressed: win.close()
                    LText { visible: parent.text === ""; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter; text: "Find a chat, or type a name" }
                }
            }
            Column {
                visible: win.stage === "list"
                width: parent.width
                spacing: 2
                LText {
                    visible: win.rows.length === 0
                    width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                    text: "No messages since Lumen started. Chats appear here as their messages arrive, and so do names from your contact book (Settings → WhatsApp)."
                }
                // Every chat, scrolling past seven; the selection stays in view
                ListView {
                    id: chatList
                    width: parent.width
                    height: Math.min(contentHeight, 7 * 54)
                    clip: true
                    spacing: 2
                    model: win.rows
                    currentIndex: win.current
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds
                    QQC.ScrollBar.vertical: QQC.ScrollBar { policy: chatList.contentHeight > chatList.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff }
                    delegate: HoverTarget {
                        id: row
                        required property var modelData
                        required property int index
                        width: chatList.width - 8; height: 52
                        radius: Theme.radius.sm
                        highlighted: win.current === index
                        onClicked: win.pick(modelData)
                        Avatar { id: av; x: 10; anchors.verticalCenter: parent.verticalCenter; name: row.modelData.title; source: row.modelData.avatar ?? "" }
                        Column {
                            anchors { left: av.right; leftMargin: Theme.space.s3; right: badge.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            LText { width: parent.width; elide: Text.ElideRight; role: row.modelData.unread > 0 ? "bodyStrong" : "body"; text: row.modelData.title; textFormat: Text.PlainText }
                            LText {
                                width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; textFormat: Text.PlainText
                                text: row.modelData.fresh ? "New chat — WhatsApp will ask you to pick them"
                                    : row.modelData.contact ? "From your contact book"
                                    : WhatsApp.cfg.previews && (row.modelData.previews ?? []).length
                                        ? ((row.modelData.previews[row.modelData.previews.length - 1].sender ? row.modelData.previews[row.modelData.previews.length - 1].sender + ": " : "") + row.modelData.previews[row.modelData.previews.length - 1].text)
                                        : (row.modelData.isGroup ? "Group" : "Chat") + " · " + Notifications.relativeTime(row.modelData.lastTime, Date.now())
                            }
                        }
                        Rectangle {
                            id: badge
                            visible: row.modelData.unread > 0
                            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                            width: Math.max(20, bl.implicitWidth + 10); height: 20; radius: 10
                            color: Theme.accent
                            LText { id: bl; anchors.centerIn: parent; role: "caption"; color: Theme.onAccent; font.weight: Font.DemiBold; text: row.modelData.unread }
                        }
                    }
                }
            }

            // ── compose ──
            Column {
                visible: win.stage === "compose" || win.stage === "confirm"
                width: parent.width
                spacing: Theme.space.s2
                // What arrived this session (only if previews are on)
                Repeater {
                    model: WhatsApp.cfg.previews ? (win.target?.previews ?? []).slice(-3) : []
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.min(parent.width * 0.85, msg.implicitWidth + 24)
                        height: msg.implicitHeight + 16
                        radius: Theme.radius.md
                        color: Theme.withAlpha(Theme.surfaceElevated, 0.8)
                        border.width: 1; border.color: Theme.border
                        LText { id: msg; x: 12; y: 8; width: Math.min(implicitWidth, parent.parent.width * 0.85 - 24); wrapMode: Text.Wrap; textFormat: Text.PlainText
                                text: (modelData.sender ? modelData.sender + ": " : "") + modelData.text }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Math.max(46, Math.min(140, reply.contentHeight + 24))
                    radius: 23
                    color: Theme.withAlpha(Theme.text, 0.05)
                    border.width: 1; border.color: reply.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                    QQC.ScrollView {
                        anchors { fill: parent; leftMargin: Theme.space.s4; rightMargin: 48; topMargin: 12; bottomMargin: 8 }
                        QQC.TextArea {
                            id: reply
                            enabled: win.stage === "compose"
                            wrapMode: TextEdit.Wrap
                            color: Theme.text
                            placeholderText: "Reply to " + (win.target?.title ?? "") + "…"
                            placeholderTextColor: Theme.textMuted
                            selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                            font.family: Theme.fontUi; font.pixelSize: 14
                            background: null; padding: 0
                            Keys.onPressed: event => {
                                if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) { win.confirmNow(); event.accepted = true; }
                                else if (event.key === Qt.Key_Escape) { if (Inbox.replyTo) win.close(); else { win.stage = "list"; filter.forceActiveFocus(); } event.accepted = true; }
                            }
                        }
                    }
                    HoverTarget {
                        anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                        width: 32; height: 32
                        onClicked: win.stage === "confirm" ? win.sendNow() : win.confirmNow()
                        Rectangle { anchors.fill: parent; radius: 16; color: reply.text !== "" ? Theme.accent : Theme.surfaceHover }
                        LIcon { anchors.centerIn: parent; icon: "arrow_upward"; size: 18; fill: 1; color: reply.text !== "" ? Theme.onAccent : Theme.textMuted }
                    }
                }
                // Confirmation — nothing leaves until you say so, and even then WhatsApp sends it, not Lumen
                Rectangle {
                    visible: win.stage === "confirm"
                    width: parent.width
                    height: confirmCol.implicitHeight + Theme.space.s3 * 2
                    radius: Theme.radius.md
                    color: Theme.withAlpha(Theme.accent, 0.1)
                    border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.35)
                    focus: win.stage === "confirm"
                    onVisibleChanged: if (visible) forceActiveFocus()
                    Keys.onReturnPressed: win.sendNow()
                    Keys.onEnterPressed: win.sendNow()
                    Keys.onEscapePressed: { win.stage = "compose"; reply.forceActiveFocus(); }
                    Column {
                        id: confirmCol
                        x: Theme.space.s3; y: Theme.space.s3
                        width: parent.width - Theme.space.s3 * 2
                        spacing: Theme.space.s2
                        LText { role: "bodyStrong"; text: "Open WhatsApp with this message?" }
                        LText {
                            width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary
                            text: WhatsApp.numberFor(win.target?.title ?? "") !== ""
                                ? "The chat with " + win.target.title + " opens with your message typed in. Press Enter there to send."
                                : "WhatsApp opens with your message ready — pick " + (win.target?.title ?? "the chat") + " there, then send. (Save their number in Settings → WhatsApp to go straight to the chat.)"
                        }
                        Row {
                            spacing: Theme.space.s2
                            Pill { primary: true; icon: "send"; text: "Open WhatsApp  ⏎"; onClicked: win.sendNow() }
                            Pill { icon: "edit"; text: "Edit  Esc"; onClicked: { win.stage = "compose"; reply.forceActiveFocus(); } }
                        }
                    }
                }
            }

            LText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "caption"; color: Theme.textMuted; font.pixelSize: 10
                text: win.stage === "list" ? (Inbox.shareFiles.length ? "↑↓ choose · Enter opens the chat, then paste with Ctrl+V · Esc close" : "↑↓ choose · Enter reply · Esc close") : "Enter to continue · Shift+Enter new line · Esc back"
            }
        }
    }

    component Pill: HoverTarget {
        id: pill
        property string icon
        property string text
        property bool primary: false
        width: pr.implicitWidth + 20; height: 28
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                    color: pill.primary ? Theme.accent : Theme.withAlpha(Theme.text, 0.06)
                    border.width: pill.primary ? 0 : 1; border.color: Theme.border }
        Row { id: pr; anchors.centerIn: parent; spacing: 5
              LIcon { icon: pill.icon; size: 14; color: pill.primary ? Theme.onAccent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: pill.text; color: pill.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }
    component Avatar: Item {
        property string name
        property string source
        width: 36; height: 36
        Rectangle {
            anchors.fill: parent; radius: width / 2
            color: Theme.withAlpha(Theme.accent, 0.16)
            visible: avImg.status !== Image.Ready
            LText { anchors.centerIn: parent; role: "bodyStrong"; color: Theme.accent
                    text: (Array.from((parent.parent.name ?? "?").replace(/^[~+\s\d()-]+/, "") || "?")[0] ?? "?").toUpperCase() }
        }
        ClippingRectangle {
            anchors.fill: parent; radius: width / 2; color: "transparent"
            visible: avImg.status === Image.Ready
            Image { id: avImg; anchors.fill: parent; source: parent.parent.source; sourceSize: Qt.size(72, 72); fillMode: Image.PreserveAspectCrop; asynchronous: true }
        }
    }
}
