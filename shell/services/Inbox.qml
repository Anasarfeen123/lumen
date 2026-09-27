pragma Singleton

// Lumen Inbox — conversations from messaging providers, one model for the
// Ribbon, the island, Search, the quick-reply panel and Halo.
// WhatsApp (services/WhatsApp.qml) is the first provider; Discord or email
// can join by offering the same small surface:
//   id, label, glyph, enabled, cfg.{notifications, ribbon, previews, haloContext}
//   parse(appName, summary, body, desktopEntry) → { chat, sender, isGroup, text, kind } | null
//   openChat(title, text) · focusClient() · isMuted(chat) · allowedDuring(mode, chat)
//
// Privacy: conversations (names, unread counts) and message previews exist
// only in memory for this session. Previews are kept only if you allow them,
// are never written anywhere, and are wiped when the screen locks.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    readonly property var providers: [WhatsApp]
    function provider(id) { return providers.find(p => p.id === id) ?? null; }

    // key "provider:chat" → { key, provider, title, isGroup, avatar, unread,
    //                          lastTime, nid, previews: [{ sender, text, time }] }
    property var convs: ({})
    readonly property var conversations: Object.values(convs).sort((a, b) => b.lastTime - a.lastTime)
    readonly property var unreadConversations: conversations.filter(c => c.unread > 0)
    readonly property int unreadTotal: unreadConversations.reduce((s, c) => s + c.unread, 0)
    property var call: null             // { key, title, video, state: "incoming" }

    signal arrived(var conv)

    // ── intake (from services/Notifications.qml) ──
    // Returns null if no provider claims the notification; otherwise how the
    // notification should be shown: { appName, summary, body, popup: bool, key }
    function intake(appName, summary, body, desktopEntry, image, nid) {
        for (const p of providers) {
            if (!p.enabled) continue;
            const m = p.parse(appName, summary, body, desktopEntry);
            if (!m) continue;
            const key = p.id + ":" + m.chat;
            const c = Object.assign({ key, provider: p.id, title: m.chat, isGroup: m.isGroup, avatar: "", unread: 0, lastTime: 0, previews: [] }, convs[key] ?? {});
            c.lastTime = Date.now();
            c.nid = nid;
            // Only a real picture (a file or inline image data) is a photo —
            // an app-icon name is WhatsApp's logo, not the sender
            if (image && !/^image:\/\/icon\//.test(image) && !/^[\w.-]+$/.test(image)) c.avatar = image;
            c.isGroup = c.isGroup || m.isGroup;
            const previewText = m.kind === "message" ? m.text : (m.kind === "call" ? "Incoming " + (m.video ? "video" : "voice") + " call" : "Missed " + (m.video ? "video" : "voice") + " call");
            if (m.kind !== "call") c.unread += 1;
            if (p.cfg.previews) c.previews = c.previews.concat([{ sender: m.sender, text: previewText, time: c.lastTime }]).slice(-20);
            const all = Object.assign({}, convs); all[key] = c; convs = all;

            const muted = p.isMuted(m.chat);
            const shown = p.cfg.previews ? (m.isGroup && m.sender ? m.sender + ": " : "") + previewText
                        : (m.kind === "message" ? "New message" : previewText);
            // Calls ring through Do Not Disturb only if the chat is allowed in the current Focus mode
            const focusOk = !Notifications.dnd || p.allowedDuring(Focus.mode, m.chat);
            if (m.kind === "call") {
                root.call = { key, title: m.chat, video: m.video, state: "incoming", provider: p.id };
                callEnd.restart();
            } else if (m.kind === "missed" && root.call?.key === key) root.call = null;
            const popup = p.cfg.notifications && !muted && focusOk && !Lock.locked;
            if (popup) announce(c, m, shown);
            arrived(c);
            return { appName: p.label + " · " + m.chat, summary: m.isGroup && m.sender ? m.sender : m.chat, body: shown, popup: false, key, chat: m.chat, provider: p.id };
        }
        return null;
    }
    // An incoming call notification has no "ended" signal we can see: forget it after a minute
    Timer { id: callEnd; interval: 60000; onTriggered: root.call = null }

    function announce(c, m, shown) {
        Sounds.play("notify", false);
        Island.push({
            kind: "message",
            key: m.kind === "call" ? "call:" + c.key : "msg:" + c.key,
            priority: m.kind === "call" ? 0 : Island.priority.notification,
            duration: m.kind === "call" ? 30000 : (Theme.evening ? 3500 : 5000),
            queueable: true,
            force: true,
            data: { key: c.key, provider: c.provider, title: c.title, isGroup: c.isGroup, avatar: c.avatar,
                    text: shown, unread: c.unread, kind: m.kind, video: m.video,
                    others: unreadConversations.filter(o => o.key !== c.key).length }
        });
    }

    // ── actions ──
    function conv(key) { return convs[key] ?? null; }
    function find(name) {
        const n = (name ?? "").trim().toLowerCase();
        return conversations.find(c => c.title.toLowerCase() === n) ?? conversations.find(c => c.title.toLowerCase().includes(n)) ?? null;
    }
    // Lumen-side "read": WhatsApp itself still shows it unread (no supported way to change that)
    function dismiss(key) {
        const c = convs[key];
        if (!c) return;
        const all = Object.assign({}, convs);
        all[key] = Object.assign({}, c, { unread: 0 });
        convs = all;
    }
    // Lumen can't see you read a chat in WhatsApp, so: opening WhatsApp clears
    // the unread counts (you've seen them), and counts older than 2 hours fade.
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const w = WhatsApp.window;
            if (w && Hyprland.activeToplevel === w && root.unreadTotal > 0) root.dismissAll();
        }
    }
    Timer {
        interval: 300000; repeat: true; running: root.unreadTotal > 0
        onTriggered: {
            const old = Date.now() - 2 * 3600000, all = Object.assign({}, root.convs);
            let changed = false;
            for (const k in all) if (all[k].unread > 0 && all[k].lastTime < old) { all[k] = Object.assign({}, all[k], { unread: 0 }); changed = true; }
            if (changed) root.convs = all;
        }
    }
    function dismissAll() {
        const all = {};
        for (const k in convs) all[k] = Object.assign({}, convs[k], { unread: 0 });
        convs = all;
    }
    function mute(key, on) {
        const c = convs[key];
        if (c) provider(c.provider)?.setMuted(c.title, on ?? true);
    }
    // Open the conversation: the notification's own "open" action if it's still
    // live (that lands in the right chat), else the contact's number, else the app.
    function open(key) {
        const c = convs[key];
        if (!c) return;
        dismiss(key);
        const live = Notifications.live[c.nid];
        if (live && live.actions.some(a => a.identifier === "default")) { Notifications.activate(c.nid); return; }
        provider(c.provider)?.openChat(c.title, "");
    }
    function focusApp(providerId) { provider(providerId ?? "whatsapp")?.focusClient(); }

    // ── composing (always confirmed by you; the provider only pre-fills) ──
    // A draft: { provider, key, title, text, hasNumber }
    function compose(target, text) {
        const c = typeof target === "string" ? (convs[target] ?? find(target)) : target;
        const title = c?.title ?? String(target ?? "");
        const p = provider(c?.provider ?? "whatsapp");
        if (!p || !p.enabled) return null;
        return { provider: p.id, key: c?.key ?? "", title, text: text ?? "", hasNumber: WhatsApp.numberFor(title) !== "" };
    }
    // Hand the draft to WhatsApp, pre-filled. You press Enter there.
    // Without a saved number, WhatsApp's own chat picker opens with the text.
    function send(draft) {
        if (!draft) return "";
        const p = provider(draft.provider);
        if (!p) return "";
        if (draft.key) dismiss(draft.key);
        const how = p.openChat(draft.title, draft.text);
        Island.system("forum", how === "chat" ? "Opened " + draft.title : how === "picker" ? "Choose " + draft.title + " in WhatsApp" : "WhatsApp",
                      draft.text ? "Your message is typed in — press Enter there to send" : "");
        return how;
    }
    // Files and images: put them on the clipboard, open the chat, paste there
    function sendFiles(target, paths) {
        if (!paths?.length) return;
        const image = paths.length === 1 && /\.(png|jpe?g|webp|gif)$/i.test(paths[0]);
        if (image) Quickshell.execDetached(["sh", "-c", 'wl-copy --type "$(file -b --mime-type "$1")" < "$1"', "sh", paths[0]]);
        else Quickshell.execDetached(["sh", "-c", 'printf "%s\\r\\n" "$@" | sed "s|^|file://|" | wl-copy --type text/uri-list', "sh"].concat(paths));
        const d = compose(target, "");
        if (d && d.title) { if (d.key) open(d.key); else provider(d.provider).openChat(d.title, ""); }
        else focusApp("whatsapp");
        Island.system("content_paste", paths.length === 1 ? "Ready to paste in WhatsApp" : paths.length + " files ready to paste",
                      "Open the chat and press Ctrl+V");
    }

    // ── Halo (it always shows a confirmation before anything is sent) ──
    // draftFromHalo("Arya", "I'll send the build tonight")
    //   → { ok, draft, needsNumber } — show draft, send only on the user's OK
    function draftFromHalo(name, text) {
        if (!WhatsApp.enabled) return { ok: false, reason: "WhatsApp is turned off in Settings" };
        const c = find(name);
        const d = compose(c ?? name, text);
        return { ok: d !== null, draft: d, needsNumber: d ? !d.hasNumber : false };
    }
    // What this session has seen from a chat — only if Halo context is allowed
    function recentFor(name) {
        if (!WhatsApp.cfg.haloContext) return { ok: false, reason: "Halo message context is off (Settings → WhatsApp)" };
        const c = find(name);
        if (!c) return { ok: false, reason: "No messages from " + name + " since Lumen started" };
        return { ok: true, source: "WhatsApp notifications seen this session", title: c.title,
                 messages: (c.previews ?? []).map(p => ({ sender: p.sender || c.title, text: p.text, time: p.time })) };
    }
    // For "what happened while I was away?"
    function unreadSummaryText() {
        if (!WhatsApp.cfg.haloContext) return "";
        return unreadConversations.map(c => "## " + c.title + (c.isGroup ? " (group)" : "") + " — " + c.unread + " unread\n"
            + (c.previews ?? []).slice(-c.unread).map(p => "- " + (p.sender ? p.sender + ": " : "") + p.text).join("\n")).join("\n\n");
    }

    // ── privacy: forget previews when the screen locks ──
    Connections {
        target: Lock
        function onLockedChanged() {
            if (!Lock.locked) return;
            const all = {};
            for (const k in root.convs) all[k] = Object.assign({}, root.convs[k], { previews: [] });
            root.convs = all;
            Notifications.redactPrivate();
        }
    }

    // ── quick reply panel (Super+Shift+W) ──
    property bool panelOpen: false
    property string replyTo: ""          // conversation key to jump straight into
    // "Send to WhatsApp": what's waiting for you to pick a chat (cleared on close)
    property var shareFiles: []
    property string shareText: ""
    function showPanel(key) { replyTo = key ?? ""; panelOpen = true; }
    onPanelOpenChanged: if (!panelOpen) { shareFiles = []; shareText = ""; }
    function share(text, files) {
        if (!WhatsApp.enabled) { Island.system("forum", "WhatsApp is off", "Turn it on in Settings → WhatsApp"); return; }
        shareText = text ?? ""; shareFiles = files ?? []; showPanel("");
    }
    function shareClipboard() { clipRead.running = true; }
    Process {
        id: clipRead
        command: ["sh", "-c", "wl-paste --no-newline --type text 2>/dev/null | head -c 4000"]
        stdout: StdioCollector { onStreamFinished: root.share(text, []) }
    }
    GlobalShortcut { appid: "lumen"; name: "inbox"; description: "Messages: reply, find a chat"; onPressed: root.panelOpen ? root.panelOpen = false : root.showPanel("") }
    IpcHandler {
        target: "inbox"
        function toggle(): void { root.panelOpen ? root.panelOpen = false : root.showPanel(""); }
        function reply(name: string): void { const c = root.find(name); root.showPanel(c?.key ?? ""); }
        function share(text: string): void { root.share(text, []); }
        function shareFile(path: string): void { root.share("", [path]); }
        function shareClipboard(): void { root.shareClipboard(); }
        function state(): string { return JSON.stringify({ unread: root.unreadTotal, chats: root.conversations.map(c => ({ title: c.title, unread: c.unread })) }); }
    }

    // ── dev only (LUMEN_DEV): notifications shaped like WhatsApp Web's ──
    IpcHandler {
        target: "whatsappTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function message(name: string, text: string): void { Notifications.receiveMirrored(["Whatsie", 0, "", name, text, [], {}, -1]); }
        function group(group: string, sender: string, text: string): void { Notifications.receiveMirrored(["Whatsie", 0, "", group, sender + ": " + text, [], {}, -1]); }
        function web(name: string, text: string): void { Notifications.receiveMirrored(["Brave Origin", 0, "", name, "web.whatsapp.com\n\n" + text, [], {}, -1]); }
        function call(name: string): void { Notifications.receiveMirrored(["Whatsie", 0, "", name, "Incoming voice call", [], {}, -1]); }
        function missed(name: string): void { Notifications.receiveMirrored(["Whatsie", 0, "", name, "Missed voice call", [], {}, -1]); }
        function reset(): void { root.convs = {}; root.call = null; }
    }
}
