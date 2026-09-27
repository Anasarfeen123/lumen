pragma Singleton

// WhatsApp — the first provider of Lumen Inbox (services/Inbox.qml).
//
// Lumen doesn't talk WhatsApp's protocol and never reads its data. It works
// only through what WhatsApp Web's official surfaces give every desktop:
//   • its notifications (freedesktop, from Whatsie or a WhatsApp Web app window)
//   • its deep links (whatsapp://send, web.whatsapp.com/send) which open a
//     chat with a message *pre-filled* — you press Enter in WhatsApp to send
//   • its window (focus it)
// So: Lumen never sends anything itself, can't mark chats read inside
// WhatsApp, can't answer calls, and can't see messages from before it
// started watching. Settings → WhatsApp says the same.
//
// Settings live in ~/.local/state/lumen/whatsapp.json: switches, chat names
// (muted, allowed per Focus mode) and your contact book (name → number).
// Never message text.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    readonly property string id: "whatsapp"
    readonly property string label: "WhatsApp"
    readonly property string glyph: "forum"

    // ── settings ──
    readonly property alias cfg: adapter
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/whatsapp.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property bool enabled: true           // the whole integration
            property bool notifications: true     // banners in the island
            property bool ribbon: true            // the unread chip in the Ribbon
            property bool previews: true          // message text in banners (memory only)
            property bool haloContext: false      // Halo may read this session's previews
            property bool searchNames: false      // plain searches also list chats (not only "wa …")
            property string client: "auto"       // "auto" | "whatsie" | "web"
            property bool startWithLumen: false
            property var muted: []                // chat names: history only, no banner
            property var focusAllow: ({})         // Focus mode id → [chat names] that may interrupt it
            property var contacts: []             // [{ name, number }] — digits with country code
        }
    }
    readonly property bool enabled: cfg.enabled

    // ── the client ──
    property bool whatsieInstalled: false
    Process {
        running: true
        command: ["sh", "-c", "flatpak info com.ktechpit.whatsie >/dev/null 2>&1 && echo yes"]
        stdout: StdioCollector { onStreamFinished: root.whatsieInstalled = text.trim() === "yes" }
    }
    readonly property string clientKind: cfg.client === "auto" ? (whatsieInstalled ? "whatsie" : "web") : cfg.client
    readonly property bool available: clientKind === "web" || whatsieInstalled
    // Whatsie, or a WhatsApp Web app window (Brave/Chrome --app)
    function isClientClass(c) { return /whatsie|web\.whatsapp\.com|whatsapp/i.test(c ?? ""); }
    readonly property var window: Hyprland.toplevels.values.find(t => isClientClass(t.lastIpcObject?.class ?? t.wayland?.appId ?? "")) ?? null
    readonly property bool running: window !== null

    function focusClient() {
        if (window) { Hypr.focusWindow(window.lastIpcObject?.address ?? "0x" + window.address); return true; }
        launch("");
        return false;
    }
    // Opens WhatsApp, optionally at a deep link (https://web.whatsapp.com/send?…)
    function launch(url) {
        if (clientKind === "whatsie") {
            const deep = url ? url.replace("https://web.whatsapp.com/send?", "whatsapp://send?") : "";
            Quickshell.execDetached(deep ? ["xdg-open", deep] : ["flatpak", "run", "com.ktechpit.whatsie"]);
        } else {
            Quickshell.execDetached(["sh", "-c", 'u="$1"; for b in brave-origin brave-browser google-chrome-stable chromium-browser chromium; do command -v "$b" >/dev/null && exec "$b" --app="$u"; done; exec xdg-open "$u"',
                                     "sh", url || "https://web.whatsapp.com/"]);
        }
    }

    // ── contacts (your own small book: name → number) ──
    function numberFor(name) {
        const n = (name ?? "").trim().toLowerCase();
        if (!n) return "";
        const c = (cfg.contacts ?? []).find(c => (c.name ?? "").toLowerCase() === n)
               ?? (cfg.contacts ?? []).find(c => (c.name ?? "").toLowerCase().startsWith(n));
        return c ? normaliseNumber(c.number) : "";
    }
    // Digits only; a 10-digit Indian mobile gets +91
    function normaliseNumber(s) {
        let d = String(s ?? "").replace(/[^\d]/g, "");
        if (d.length === 10) d = "91" + d;
        return d.length >= 8 && d.length <= 15 ? d : "";
    }
    function addContact(name, number) {
        const num = normaliseNumber(number);
        if (!name.trim() || !num) return false;
        cfg.contacts = (cfg.contacts ?? []).filter(c => c.name.toLowerCase() !== name.trim().toLowerCase()).concat([{ name: name.trim(), number: num }]);
        return true;
    }
    function removeContact(name) { cfg.contacts = (cfg.contacts ?? []).filter(c => c.name !== name); }

    // Open a chat, with text pre-filled if given. Without a number, the text
    // opens WhatsApp's own "send to…" chat picker instead.
    function openChat(title, text) {
        const num = numberFor(title);
        const q = [];
        if (num) q.push("phone=" + num);
        if (text) q.push("text=" + encodeURIComponent(text));
        if (!q.length) { focusClient(); return "focused"; }
        launch("https://web.whatsapp.com/send?" + q.join("&"));
        return num ? "chat" : "picker";
    }

    // ── recognising its notifications ──
    // Whatsie (native notifications on): app "Whatsie"/"WhatsApp", summary = chat,
    // body = message. A WhatsApp Web app window in Brave/Chrome: app = the
    // browser, body carries the origin "web.whatsapp.com". Groups: the summary
    // is the group and the body starts "Sender: …" (or the summary is
    // "Sender @ Group"). Calls are notifications too ("Incoming voice call").
    // Returns null when the notification isn't WhatsApp's.
    function parse(appName, summary, body, desktopEntry) {
        const plainBody = (body ?? "").replace(/<[^>]*>/g, "").replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'");
        const byApp = /whatsie|whatsapp/i.test(appName ?? "") || /whatsie|whatsapp/i.test(desktopEntry ?? "");
        const byOrigin = /web\.whatsapp\.com/i.test(plainBody);
        if (!byApp && !byOrigin) return null;
        let text = plainBody.split("\n").filter(l => !/^\s*(https?:\/\/)?web\.whatsapp\.com\/?\s*$/i.test(l)).join("\n").trim();
        let chat = (summary ?? "").trim();
        let sender = "", isGroup = false;
        let m = /^(.+?)\s+@\s+(.+)$/.exec(chat);
        if (m) { sender = m[1]; chat = m[2]; isGroup = true; }
        else if ((m = /^~?\s*([^:\n]{1,40}):\s+([\s\S]+)$/.exec(text)) && !/https?$/i.test(m[1])) { sender = m[1].trim(); text = m[2]; isGroup = true; }
        // "3 new messages" style summaries carry no chat
        if (!chat || /^WhatsApp$/i.test(chat)) chat = sender || "WhatsApp";
        const kind = /incoming (voice|video) call|is calling|calling you/i.test(text + " " + summary) ? "call"
                   : /missed (voice|video) call/i.test(text + " " + summary) ? "missed"
                   : "message";
        return { provider: id, chat, sender, isGroup, text, kind,
                 video: /video/i.test(text + " " + summary) };
    }

    // Lumen-side per-chat choices
    function isMuted(chat) { return (cfg.muted ?? []).includes(chat); }
    function setMuted(chat, on) { cfg.muted = on ? Array.from(new Set((cfg.muted ?? []).concat([chat]))) : (cfg.muted ?? []).filter(c => c !== chat); }
    function allowedDuring(mode, chat) { return ((cfg.focusAllow ?? {})[mode] ?? []).includes(chat); }
    function setAllowed(mode, chat, on) {
        const all = Object.assign({}, cfg.focusAllow ?? {});
        const list = (all[mode] ?? []).filter(c => c !== chat);
        if (on) list.push(chat);
        all[mode] = list;
        cfg.focusAllow = all;
    }

    // Start with Lumen (main shell only, once)
    Timer {
        interval: 8000
        running: Persist.automates && root.cfg.enabled && root.cfg.startWithLumen
        onTriggered: if (!root.running && root.available) root.launch("")
    }
}
