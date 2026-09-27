pragma Singleton

// Lumen is the notification daemon (org.freedesktop.Notifications).
//
// Flow:  app → server → history (grouped by app, newest group first)
//                     → island popup, unless:
//                         • urgency Low                → history only
//                         • Do Not Disturb             → history only (Critical still shows)
//                         • hint x-lumen-kind          → history only (the island already showed it)
//
// History survives shell restarts (~/.local/state/lumen/notifications.json);
// restored entries keep their text but lose live actions.
//
// Client mode (LUMEN_SETTINGS_APP=1, the separate Settings process): NO
// notification server is created — only the main shell may ever own
// org.freedesktop.Notifications. The client mirrors history/DND from the
// state file and sends changes to the shell over IPC.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import qs.theme

Singleton {
    id: root

    readonly property bool isClient: Quickshell.env("LUMEN_SETTINGS_APP") === "1"
    property bool dnd: false
    readonly property int count: history.count
    readonly property int maxHistory: 100

    // id → live Notification object (absent for restored entries)
    property var live: ({})

    // Flat, grouped order: all entries of the most recently active app first.
    ListModel { id: history }
    readonly property ListModel model: history

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen"

    LazyLoader {
        id: serverLoader
        active: !root.isClient
        NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: false
        actionsSupported: true
        actionIconsSupported: false
        imageSupported: true
        inlineReplySupported: true

        onNotification: n => root.receive(n)
        }
    }
    readonly property var server: serverLoader.item
    function shellCall(fn) { Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "notifications", fn]); }

    // ── intake ──
    function iconSource(n) {
        const img = n.image || "";
        if (img) return img.startsWith("/") ? "file://" + img : img;
        const icon = n.appIcon || "";
        if (icon.startsWith("/")) return "file://" + icon;
        if (icon.startsWith("file://") || icon.startsWith("image://")) return icon;
        if (icon) return Apps.iconNamed(icon, "dialog-information");
        const entry = DesktopEntries.heuristicLookup(n.desktopEntry || n.appName || "");
        return entry ? Apps.iconFor(entry) : "";
    }

    // Notifications mirrored from your phone by KDE Connect (Lumen Link).
    // Settings → Lumen Link → Phone notifications: "calls" (default) lets only
    // calls and pairing requests through — the laptop already shows its own
    // WhatsApp etc., so the phone's copies would arrive twice — "all", or "none".
    function fromPhoneBlocked(appName, desktopEntry, summary, body) {
        if (!/kde ?connect/i.test(appName ?? "") && !/kdeconnect/i.test(desktopEntry ?? "")) return false;
        const text = (summary ?? "") + " " + (body ?? "");
        if (/\bpair/i.test(text)) return false;                         // pairing requests always
        const mode = Persist.data.phoneNotifications ?? "calls";
        const isCall = /\b(incoming|missed|ongoing)?\s*(voice |video )?call(ing)?\b|\bringing\b/i.test(text);
        if (mode === "none") return true;
        if (mode === "calls") return !isCall;
        // "all": still skip the phone's WhatsApp copies when the laptop's WhatsApp integration is on
        return !isCall && WhatsApp.enabled && /whatsapp/i.test(text);
    }

    function receive(n) {
        if (fromPhoneBlocked(n.appName, n.desktopEntry, n.summary, n.body)) { n.dismiss(); return; }
        n.tracked = true;
        const quiet = (n.hints?.["x-lumen-kind"] ?? "") !== "";
        const entry = {
            nid: n.id,
            appName: n.appName || "Notification",
            icon: iconSource(n),
            summary: n.summary || "",
            body: n.body || "",
            urgency: n.urgency,
            time: Date.now(),
            hasActions: n.actions.some(a => a.identifier !== "default"),
            canReply: n.hasInlineReply,
            chatKey: "", privateMsg: false,
        };

        const l = Object.assign({}, live);
        l[n.id] = n;
        live = l;
        n.closed.connect(() => root.forget(n.id, false));

        // Replacement (same id) updates in place
        const existing = indexOf(n.id);
        if (existing >= 0) history.remove(existing);

        // Messaging apps (WhatsApp…) belong to Lumen Inbox: grouped per chat,
        // its own banner, and never written to disk
        if (claimByInbox(entry, n.desktopEntry ?? "", n.image ? (n.image.startsWith("/") ? "file://" + n.image : n.image) : "", n.id)) { if (!n.transient) insertGrouped(entry); return; }

        if (!n.transient) insertGrouped(entry);

        if (!shouldPopup(entry, quiet)) return;
        popup(n, entry);
    }

    // Lumen Inbox takes messaging notifications: the entry becomes
    // "WhatsApp · <chat>" (one group per chat), its text follows the preview
    // setting, and it's marked private so history never saves it.
    function claimByInbox(entry, desktopEntry, image, nid) {
        const r = Inbox.intake(entry.appName, entry.summary, entry.body, desktopEntry, image, nid);
        if (!r) return false;
        entry.appName = r.appName;
        entry.summary = r.summary;
        entry.body = r.body;
        entry.chatKey = r.key;
        entry.privateMsg = true;
        // The sender's photo, else the WhatsApp client's own icon
        const client = DesktopEntries.byId("com.ktechpit.whatsie") ?? DesktopEntries.heuristicLookup("whatsapp");
        entry.icon = image || (client ? Apps.iconFor(client) : entry.icon);
        return true;
    }

    // Low urgency, island-originated (x-lumen-kind), muted apps, banners off
    // and Do Not Disturb all stay in history only. Critical breaks through
    // only if Settings → Notifications says so.
    function shouldPopup(entry, quiet) {
        if (quiet || entry.urgency === NotificationUrgency.Low) return false;
        // Critical used to always break through, which is why DND still made
        // noise: an urgent app could ring regardless. That is now a choice, and
        // off by default — DND means quiet. (Everything still lands in history.)
        if (entry.urgency === NotificationUrgency.Critical && Persist.data.dndCritical) return true;
        if (!Persist.data.notifBanners || (Persist.data.mutedApps ?? []).includes(entry.appName)) return false;
        return !dnd || Focus.lets(entry.appName);        // Work focus: allowed apps get through
    }

    function popup(n, entry) {
        const critical = n.urgency === NotificationUrgency.Critical;  // (banner rules applied in receive)
        Sounds.play("notify", critical);
        const burst = history.count > 0 ? countRecent(entry.appName, 4000) : 1;
        Island.push({
            kind: "notification",
            key: "notif:" + entry.appName,        // same app → updates in place
            priority: critical ? 0 : Island.priority.notification,
            duration: critical && n.expireTimeout <= 0 ? 86400000 : (Theme.evening ? 3500 : 4500),   // briefer in the evening
            queueable: true,
            force: true,
            data: {
                nid: n.id, appName: entry.appName, image: entry.icon, summary: entry.summary,
                body: plain(entry.body), critical, burst,
                actions: n.actions.filter(a => a.identifier !== "default").slice(0, 3).map(a => ({ id: a.identifier, text: a.text })),
                activate: () => root.activate(n.id),
                invoke: id => root.invoke(n.id, id),
            }
        });
    }

    function countRecent(app, ms) {
        let c = 0;
        const now = Date.now();
        for (let i = 0; i < history.count; i++) {
            const e = history.get(i);
            if (e.appName === app && now - e.time < ms) c++;
        }
        return c;
    }

    function insertGrouped(entry) {
        // Move the app's existing entries to the top, then put the new one first.
        let dest = 0;
        for (let i = 0; i < history.count; i++) {
            if (history.get(i).appName === entry.appName) {
                if (i !== dest) history.move(i, dest, 1);
                dest++;
            }
        }
        history.insert(0, entry);
        while (history.count > maxHistory) history.remove(history.count - 1);
        saveTimer.restart();
    }

    function indexOf(nid) {
        for (let i = 0; i < history.count; i++) if (history.get(i).nid === nid) return i;
        return -1;
    }

    // ── Mirror mode ──
    // Only one program per D-Bus session can own org.freedesktop.Notifications.
    // If another desktop running at the same time holds it (e.g. illogical-
    // impulse on another tty), Lumen watches the bus for Notify calls and shows
    // them here too: island + history. Mirrored entries have no live actions
    // (their buttons belong to the owner); clicking focuses the app instead.
    // The moment the owner quits, Lumen's own server takes over by itself.
    property bool mirroring: false
    property int mirrorSeq: 0

    Process {
        id: ownerCheck
        // $PPID of this sh is the shell itself
        command: ["sh", "-c", "busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p'; echo \"self=$PPID\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const owner = (text.match(/^(\d+)$/m) ?? [])[1] ?? "";
                const self = (text.match(/^self=(\d+)$/m) ?? [])[1] ?? "";
                root.mirroring = owner !== "" && owner !== self;
            }
        }
    }
    Timer {
        running: !root.isClient
        interval: 10000
        repeat: true
        triggeredOnStart: true
        onTriggered: ownerCheck.running = true
    }
    onMirroringChanged: console.info("Notifications:", mirroring ? "another program owns the notification service — mirroring" : "Lumen is the notification server")

    Process {
        id: mirror
        running: root.mirroring && !root.isClient
        command: ["busctl", "--user", "monitor", "--json=short",
                  "--match", "type='method_call',interface='org.freedesktop.Notifications',member='Notify'"]
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("{")) return;
                try {
                    const m = JSON.parse(line);
                    if (m.member === "Notify") root.receiveMirrored(m.payload?.data ?? []);
                } catch (e) {}
            }
        }
    }

    function receiveMirrored(d) {
        const hints = d[6] ?? {};
        const hint = k => hints[k]?.data;
        const app = d[0] || "Notification";
        const img = hint("image-path") || hint("image_path") || d[2] || "";
        let icon = "";
        if (img.startsWith("/")) icon = "file://" + img;
        else if (img.startsWith("file://")) icon = img;
        else if (img) icon = Apps.iconNamed(img, "dialog-information");
        else {
            const e = DesktopEntries.heuristicLookup(hint("desktop-entry") || app);
            icon = e ? Apps.iconFor(e) : "";
        }
        if (fromPhoneBlocked(app, hint("desktop-entry") ?? "", d[3] || "", d[4] || "")) return;
        const entry = {
            nid: -((Date.now() % 1e9) * 100 + (++mirrorSeq % 100)), appName: app, icon, summary: d[3] || "", body: d[4] || "",
            urgency: hint("urgency") ?? NotificationUrgency.Normal, time: Date.now(),
            hasActions: false, canReply: false, chatKey: "", privateMsg: false,
        };
        const photo = hint("image-path") || hint("image_path") || "";
        if (claimByInbox(entry, hint("desktop-entry") ?? "", photo.startsWith("/") ? "file://" + photo : photo, entry.nid)) { if (hint("transient") !== true) insertGrouped(entry); return; }
        if (hint("transient") !== true) insertGrouped(entry);
        if (!shouldPopup(entry, (hint("x-lumen-kind") ?? "") !== "")) return;
        const critical = entry.urgency === NotificationUrgency.Critical;
        Sounds.play("notify", critical);
        Island.push({
            kind: "notification",
            key: "notif:" + app,
            priority: critical ? 0 : Island.priority.notification,
            duration: 4500,
            queueable: true,
            force: true,
            data: {
                nid: entry.nid, appName: app, image: icon, summary: entry.summary,
                body: plain(entry.body), critical, burst: countRecent(app, 4000), actions: [],
                activate: () => root.activate(entry.nid),
                invoke: () => {},
            }
        });
    }

    // ── actions ──
    function invoke(nid, actionId) {
        const n = live[nid];
        const a = n?.actions.find(x => x.identifier === actionId);
        if (a) a.invoke();
        if (!n?.resident) dismiss(nid);
    }

    // Default action if the app offers one, otherwise focus its window.
    function activate(nid) {
        const n = live[nid];
        const def = n?.actions.find(a => a.identifier === "default");
        if (def) { def.invoke(); if (!n.resident) dismiss(nid); return; }
        const i = indexOf(nid);
        const app = (n?.desktopEntry || (i >= 0 ? history.get(i).appName : "")).toLowerCase();
        const win = Hyprland.toplevels.values.find(t => (t.lastIpcObject?.class ?? "").toLowerCase().includes(app));
        if (win) Hypr.focusWindow(win.lastIpcObject?.address ?? "0x" + win.address);
    }

    function reply(nid, text) {
        const n = live[nid];
        if (n?.hasInlineReply && text) n.sendInlineReply(text);
        dismiss(nid);
    }

    function dismiss(nid) {
        const n = live[nid];
        if (n) n.dismiss();
        forget(nid, true);
    }

    function forget(nid, save) {
        const i = indexOf(nid);
        if (i >= 0) history.remove(i);
        if (live[nid]) { const l = Object.assign({}, live); delete l[nid]; live = l; }
        saveTimer.restart();
    }

    // Screen locked: message previews (Lumen Inbox) leave memory too
    function redactPrivate() {
        for (let i = 0; i < history.count; i++)
            if (history.get(i).privateMsg) history.setProperty(i, "body", "New message");
    }

    function dismissApp(app) {
        for (let i = history.count - 1; i >= 0; i--) if (history.get(i).appName === app) dismiss(history.get(i).nid);
    }

    function clearAll() {
        if (isClient) { shellCall("clear"); return; }
        for (const id in live) live[id].dismiss();
        live = {};
        history.clear();
        saveTimer.restart();
    }

    function setDnd(on, quiet) {
        if (isClient) { if (on !== dnd) shellCall("toggleDnd"); return; }
        dnd = on;
        if (!quiet) Island.system(on ? "do_not_disturb_on" : "do_not_disturb_off",
                      on ? "Do Not Disturb" : "Notifications on", on ? "Only urgent alerts" : "");
        saveTimer.restart();
    }

    // ── helpers ──
    function plain(s) {
        return (s || "").replace(/<br\s*\/?>/gi, " ").replace(/<[^>]*>/g, "")
            .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&#39;/g, "'");
    }

    function relativeTime(t, now) {
        const s = Math.max(0, (now - t) / 1000);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        if (s < 172800) return "Yesterday";
        return Qt.formatDate(new Date(t), "d MMM");
    }

    // ── persistence ──
    Timer {
        id: saveTimer
        interval: 1000
        onTriggered: {
            const items = [];
            for (let i = 0; i < history.count; i++) {
                const e = history.get(i);
                if (e.privateMsg) continue;         // messages (Lumen Inbox) never go to disk
                items.push({ nid: e.nid, appName: e.appName, icon: e.icon, summary: e.summary, body: e.body,
                             urgency: e.urgency, time: e.time });
            }
            Quickshell.execDetached(["mkdir", "-p", root.stateDir]);
            store.setText(JSON.stringify({ dnd: root.dnd, items }));
        }
    }

    FileView {
        id: store
        path: root.stateDir + "/notifications.json"
        // The client follows the shell's writes live
        watchChanges: root.isClient
        onFileChanged: reload()
        // The shell owns `dnd` and also writes this file, so it may only take
        // the saved value once, at startup. Adopting it on every load undid a
        // toggle the moment saveTimer flushed — setText can trigger
        // onFileChanged -> reload, reload can read the pre-write text, and DND
        // silently snapped back to off. That is why "mute everything" stopped
        // muting. The settings app mirrors the shell and may follow freely.
        property bool adopted: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                if (root.isClient || !adopted) { root.dnd = d.dnd ?? false; adopted = true; }
                if (root.isClient) history.clear();
                for (const e of (d.items ?? []))
                    if (root.indexOf(e.nid) < 0)
                        history.append(Object.assign({ hasActions: false, canReply: false, chatKey: "", privateMsg: false }, e));
            } catch (err) {
                console.warn("Notifications: history unreadable:", err);
            }
        }
    }

    // Re-adopt notifications the server kept across a shell reload
    Component.onCompleted: {
        if (!server) return;
        for (const n of server.trackedNotifications.values)
            if (indexOf(n.id) < 0) {
                const l = Object.assign({}, live); l[n.id] = n; live = l;
            }
    }
}
