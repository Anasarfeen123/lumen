pragma Singleton

// Launcher results. A single reactive list built from the query + mode, so
// async providers (calculator, clipboard) slot in as soon as they answer.
//
// Result shape: { kind, title, subtitle, icon (image path) | glyph (symbol)
//                 | emoji, badge, destructive?, run: function }
//
// Search mode prefixes:  ">"  run a shell command   "?"  web search only
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme

Singleton {
    id: root

    // Change to your preferred engine; %s is replaced by the query.
    readonly property string webSearchUrl: "https://duckduckgo.com/?q=%s"

    readonly property var actions: [
        { title: "Lock", glyph: "lock", keys: "lock screen", cmd: ["loginctl", "lock-session"] },
        { title: "Suspend", glyph: "bedtime", keys: "sleep suspend", cmd: ["systemctl", "suspend"] },
        { title: "Log out", glyph: "logout", keys: "logout log out exit sign out", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"], destructive: true },
        { title: "Restart", glyph: "restart_alt", keys: "restart reboot", cmd: ["systemctl", "reboot"], destructive: true },
        { title: "Shut down", glyph: "power_settings_new", keys: "shutdown shut down power off poweroff", cmd: ["systemctl", "poweroff"], destructive: true },
        { title: "Screenshot (region)", glyph: "screenshot_region", keys: "screenshot capture snip", cmd: [Theme.lumenRoot + "/scripts/screenshot.sh", "region"], delay: true },
        { title: "Record screen", glyph: "screen_record", keys: "record screen recording video", cmd: [Theme.lumenRoot + "/scripts/screen-record.sh", "toggle", "screen"], delay: true },
        { title: "Colour picker", glyph: "colorize", keys: "color colour picker eyedropper hex", cmd: ["hyprpicker", "-a"], delay: true },
        { title: "Dark theme", glyph: "dark_mode", keys: "theme dark", cmd: [Theme.lumenRoot + "/bin/lumen", "theme", "dark"] },
        { title: "Midnight theme", glyph: "nights_stay", keys: "theme midnight blue", cmd: [Theme.lumenRoot + "/bin/lumen", "theme", "midnight"] },
        { title: "OLED theme", glyph: "contrast", keys: "theme oled black amoled", cmd: [Theme.lumenRoot + "/bin/lumen", "theme", "oled"] },
        { title: "Light theme", glyph: "light_mode", keys: "theme light day", cmd: [Theme.lumenRoot + "/bin/lumen", "theme", "light"] },
        { title: "Accent: Ion", glyph: "palette", keys: "accent colour color ion cyan blue", cmd: [Theme.lumenRoot + "/bin/lumen", "accent", "ion"] },
        { title: "Accent: Ember", glyph: "palette", keys: "accent colour color ember amber orange", cmd: [Theme.lumenRoot + "/bin/lumen", "accent", "ember"] },
        { title: "Accent: Iris", glyph: "palette", keys: "accent colour color iris violet purple", cmd: [Theme.lumenRoot + "/bin/lumen", "accent", "iris"] },
        { title: "Accent: Jade", glyph: "palette", keys: "accent colour color jade green mint", cmd: [Theme.lumenRoot + "/bin/lumen", "accent", "jade"] },
        { title: "Accent from wallpaper", glyph: "wallpaper", keys: "accent colour color wallpaper match adaptive", cmd: [Theme.lumenRoot + "/bin/lumen", "accent", "wallpaper"] },

        // Live system actions — they run here, no terminal needed
        { title: "Mute microphone", glyph: "mic_off", keys: "mute mic microphone unmute", state: () => Audio.micMuted, fn: () => Audio.toggleMicMute() },
        { title: "Mute sound", glyph: "volume_off", keys: "mute sound audio volume unmute speaker", state: () => Audio.muted, fn: () => Audio.toggleMute() },
        { title: "Wi-Fi", glyph: "wifi", keys: "wifi wi-fi wireless network internet on off", state: () => Network.wifiEnabled, fn: () => Network.setWifiEnabled(!Network.wifiEnabled) },
        { title: "Bluetooth", glyph: "bluetooth", keys: "bluetooth bt on off", state: () => Bluetooth.enabled, fn: () => Bluetooth.setEnabled(!Bluetooth.enabled) },
        { title: "Airplane mode", glyph: "flight", keys: "airplane flight mode radios", state: () => Airplane.on, fn: () => Airplane.toggle() },
        { title: "Caffeine (keep awake)", glyph: "coffee", keys: "caffeine awake keep awake no sleep inhibit", state: () => Caffeine.on, fn: () => Caffeine.toggle() },
        { title: "Night light", glyph: "nightlight", keys: "night light warm blue light filter", state: () => NightLight.enabled, fn: () => NightLight.toggle() },
        { title: "Do Not Disturb", glyph: "do_not_disturb_on", keys: "dnd do not disturb quiet silence notifications focus", state: () => Notifications.dnd, fn: () => Notifications.setDnd(!Notifications.dnd) },
        { title: "Focus: Deep work", glyph: "psychology", keys: "focus deep work pomodoro concentrate", fn: () => Focus.set("deep") },
        { title: "Focus: Study", glyph: "school", keys: "focus study learn pomodoro", fn: () => Focus.set("study") },
        { title: "Focus: Work", glyph: "work", keys: "focus work mode", fn: () => Focus.set("work") },
        { title: "Focus: Game", glyph: "sports_esports", keys: "focus game gaming mode performance", fn: () => Focus.set("game") },
        { title: "Focus: Sleep", glyph: "bedtime", keys: "focus sleep night bedtime", fn: () => Focus.set("sleep") },
        { title: "Focus off", glyph: "do_not_disturb_off", keys: "focus off normal", fn: () => Focus.set("off") },
        { title: "Performance mode", glyph: "bolt", keys: "power performance profile fast", fn: () => { PowerProfiles.profile = PowerProfile.Performance; } },
        { title: "Balanced power", glyph: "balance", keys: "power balanced profile", fn: () => { PowerProfiles.profile = PowerProfile.Balanced; } },
        { title: "Battery saver", glyph: "battery_saver", keys: "power saver battery eco profile", fn: () => { PowerProfiles.profile = PowerProfile.PowerSaver; } },
        { title: "Window glass", glyph: "blur_on", keys: "glass transparency blur windows", cmd: [Theme.lumenRoot + "/bin/lumen", "transparency", "toggle"] },
        { title: "Copy text from screen", glyph: "document_scanner", keys: "ocr copy text screen read", cmd: [Theme.lumenRoot + "/scripts/screen-text.sh"], delay: true },
        { title: "Shuffle wallpaper", glyph: "shuffle", keys: "wallpaper random shuffle background", fn: () => Wallpapers.random() },
        { title: "Control centre", glyph: "tune", keys: "control centre center quick settings", fn: () => Sidebar.show("controls") },
        { title: "Notifications", glyph: "notifications", keys: "notifications history", fn: () => Sidebar.show("notifications") },
        { title: "Planner", glyph: "event_note", keys: "planner calendar agenda todo notes weather", fn: () => { Planner.open = true; } },
        { title: "Lumen Halo", glyph: "auto_awesome", keys: "halo ai assistant ask chat claude ollama", fn: () => Ai.show() },
        { title: "System inspector", glyph: "monitor_heart", keys: "system inspector cpu gpu memory ram disk temperature hardware stats", fn: () => SettingsState.launch("system") },
        { title: "Security", glyph: "shield", keys: "security firewall updates ssh secure boot encryption", fn: () => SettingsState.launch("security") },
        { title: "Find my phone", glyph: "phone_in_talk", keys: "find my phone ring locate lost link", fn: () => Link.connected ? Link.ring() : SettingsState.launch("phone") },
        { title: "Send a file to my phone", glyph: "upload_file", keys: "send file phone share transfer link", fn: () => Link.connected ? Link.pickAndSend() : SettingsState.launch("phone") },
        { title: "Send clipboard to my phone", glyph: "content_paste_go", keys: "send clipboard phone copy link", fn: () => Link.connected ? Link.sendClipboard() : SettingsState.launch("phone") },
        { title: "Send a screenshot to my phone", glyph: "screenshot_region", keys: "screenshot phone send share link", fn: () => Link.connected ? Link.screenshotToPhone() : SettingsState.launch("phone") },
        { title: "Lumen Link", glyph: "phonelink", keys: "phone link kde connect pair connect android iphone", fn: () => SettingsState.launch("phone") },
        { title: "Keyboard shortcuts", glyph: "keyboard", keys: "shortcuts keybinds cheatsheet keys help", fn: () => CheatsheetState.open = true },
    ]
    // Settings pages as search results ("settings network", "bluetooth settings", "wifi")
    readonly property var settingsActions: SettingsState.pages.map(pg => ({
        title: pg.label + " settings", glyph: pg.icon, keys: "settings preferences " + pg.label + " " + pg.keys, fn: () => SettingsState.launch(pg.id) }))

    // Workspace snapshots ("save radar", "restore radar")
    property var snapshots: []
    Process {
        id: snapScan
        command: [Theme.lumenRoot + "/scripts/snapshot.sh", "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.snapshots = JSON.parse(text); } catch (e) { root.snapshots = []; } } }
    }
    function snap(cmd, name) { Quickshell.execDetached([Theme.lumenRoot + "/scripts/snapshot.sh", cmd, name]); }

    // ~/Projects folders for "open project …"
    property var projects: []
    Process {
        id: projectScan
        command: ["sh", "-c", 'for d in "$HOME"/Projects/*/ "$HOME"/projects/*/ "$HOME"/src/*/ "$HOME"/code/*/; do [ -d "$d" ] && printf "%s\n" "${d%/}"; done 2>/dev/null']
        stdout: StdioCollector { onStreamFinished: root.projects = text.split("\n").filter(Boolean) }
    }
    function openProject(dir) {
        // Editor (first one installed) + a terminal in the folder
        Quickshell.execDetached(["sh", "-c", 'cd "$1" && exec "$2" "code ." "codium ." "zed ." "kate ."', "sh", dir, Theme.lumenRoot + "/bin/lumen-launch"]);
        Quickshell.execDetached(["kitty", "--directory", dir]);
    }

    // Keep the calculator fed as the query changes
    Connections {
        target: Overview
        function onQueryChanged() { if (Overview.mode === "search") Calc.evaluate(Overview.query.trim()); }
        function onModeChanged() {
            if (Overview.mode === "clipboard") { Clipboard.filter = "all"; Clipboard.refresh(); }
            if (Overview.mode === "emoji") Emoji.ensure();
        }
        function onOpenChanged() {
            if (!Overview.open) return;
            projectScan.running = true;
            snapScan.running = true;
            if (Overview.mode === "clipboard") Clipboard.refresh();
            if (Overview.mode === "emoji") Emoji.ensure();
        }
    }

    function exec(cmd, delay) {
        // Capture tools must start after the overlay is gone
        if (delay) Quickshell.execDetached(["sh", "-c", "sleep 0.25; exec \"$0\" \"$@\"", ...cmd]);
        else Quickshell.execDetached(cmd);
    }

    readonly property var results: {
        const q = Overview.query.trim();
        switch (Overview.mode) {
        case "clipboard": return clipboardResults(q);
        case "emoji": return Emoji.search(q).map(e => ({
            kind: "emoji", title: e.name, emoji: e.ch, badge: "", subtitle: "",
            run: () => Emoji.copy(e.ch) }));
        default: return q === "" ? [] : searchResults(q);
        }
    }

    function clipboardResults(q) {
        const ql = q.toLowerCase();
        const pins = Clipboard.pins
            .map((p, i) => ({ p, i, kind: p.kind === "image" ? "image" : Clipboard.kindOf({ text: p.text }) }))
            .filter(({ p, kind }) => Clipboard.inFilter(kind) && (!q || (p.text ?? "").toLowerCase().includes(ql)))
            .map(({ p, i, kind }) => ({
                kind: "clipPin", group: "Pinned", pinIndex: i, clipKind: kind,
                title: kind === "image" ? "Image" : kind === "secret" ? "•".repeat(Math.min(24, p.text.length)) : p.text.replace(/\s+/g, " ").slice(0, 200),
                subtitle: Clipboard.labels[kind] || "Pinned", thumb: p.kind === "image" ? "file://" + p.file : "",
                swatch: kind === "color" ? p.text.trim() : "",
                glyph: Clipboard.glyphs[kind] ?? "push_pin", badge: "",
                run: mode => kind === "link" && mode === "open" ? Quickshell.execDetached(["xdg-open", p.text.trim()]) : Clipboard.usePin(p, mode) }));
        const hist = Clipboard.entries
            .map(e => ({ e, kind: Clipboard.kindOf(e) }))
            .filter(({ e, kind }) => Clipboard.inFilter(kind) && (!q || (kind !== "secret" && e.text.toLowerCase().includes(ql))))
            .filter(({ e }) => e.isImage || !Clipboard.isPinnedText(e.text))
            .slice(0, 60)
            .map(({ e, kind }) => ({
                kind: "clipboard", group: "Recent", id: e.id, entry: e, clipKind: kind,
                title: e.isImage ? "Image" : kind === "secret" ? "•".repeat(Math.min(24, e.text.length)) : e.text.replace(/\s+/g, " ").slice(0, 200),
                subtitle: e.isImage ? e.text.replace(/^\[\[ binary data |\]\]$/g, "") : (Clipboard.labels[kind] ?? ""),
                thumb: e.isImage ? "file://" + e.thumb + "?v=" + Clipboard.thumbVersion : "",
                swatch: kind === "color" ? e.text.trim() : "",
                glyph: Clipboard.glyphs[kind] ?? "content_paste", badge: kind === "link" ? "⇧↵ open" : "",
                run: mode => kind === "link" && mode === "open" ? Quickshell.execDetached(["xdg-open", e.text.trim()]) : Clipboard.use(e.id, mode) }));
        return pins.concat(hist);
    }

    function searchResults(q) {
        const out = [];

        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            if (cmd) out.push({ kind: "command", group: "Commands", title: cmd, subtitle: "Run command", glyph: "terminal", badge: "Run",
                                run: () => Quickshell.execDetached(["sh", "-c", cmd]) });
            return out;
        }
        // Commands with an argument
        {
            let m;
            if ((m = /^(?:vol|volume)\s+(\d{1,3})%?$/i.exec(q))) {
                const v = Math.min(100, +m[1]);
                out.push({ kind: "command", group: "Commands", title: "Set volume to " + v + "%", glyph: "volume_up", badge: "Set",
                           run: () => { if (Audio.sink?.audio) { Audio.sink.audio.muted = false; Audio.setVolume(v / 100); } } });
            }
            if ((m = /^(?:bright|brightness)\s+(\d{1,3})%?$/i.exec(q))) {
                const v = Math.max(1, Math.min(100, +m[1]));
                out.push({ kind: "command", group: "Commands", title: "Set brightness to " + v + "%", glyph: "brightness_6", badge: "Set", run: () => Brightness.set(v / 100) });
            }
            if ((m = /^(?:open\s+)?(?:project|proj)\s*(.*)$/i.exec(q))) {
                const want = m[1].trim();
                const hits = root.projects.map(d => ({ d, name: d.split("/").pop() }))
                    .map(x => ({ x, s: want ? Fuzzy.score(want, x.name) : 1 }))
                    .filter(y => y.s > 0).sort((a, b) => b.s - a.s).slice(0, 6);
                for (const h of hits)
                    out.push({ kind: "project", group: "Projects", title: h.x.name, subtitle: h.x.d.replace(Quickshell.env("HOME"), "~") + " · editor + terminal",
                               glyph: "folder_code", badge: "Open", run: () => root.openProject(h.x.d) });
                if (!hits.length) out.push({ kind: "project", group: "Projects", title: "No project matches “" + want + "”", subtitle: "Projects are folders in ~/Projects", glyph: "folder_off", badge: "", run: () => {} });
            }
            if ((m = /^(?:kill|quit|close|force quit)\s+(.+)$/i.exec(q))) {
                const want = m[1].trim(), force = /^force/i.test(q) || /^kill/i.test(q);
                const wins = Hyprland.toplevels.values.filter(t => Fuzzy.score(want, t.lastIpcObject?.class ?? "") >= 600 || Fuzzy.score(want, t.title ?? "") >= 700);
                for (const t of wins.slice(0, 4)) {
                    const cls = t.lastIpcObject?.class ?? "", addr = t.lastIpcObject?.address ?? ("0x" + t.address);
                    const e = Apps.entryFor(cls);
                    out.push({ kind: "command", group: "Commands", title: (force ? "Force quit " : "Close ") + (e?.name ?? cls), subtitle: t.title,
                               icon: e ? Apps.iconFor(e) : "", glyph: force ? "dangerous" : "close", badge: force ? "Kill" : "Close",
                               destructive: force, run: () => force ? Hypr.killWindow(addr) : Hypr.closeWindow(addr) });
                }
                if (/^kill\s/i.test(q) && /^[\w.+-]{2,}$/.test(want))
                    out.push({ kind: "command", group: "Commands", title: "End every “" + want + "” process", subtitle: "pkill -x " + want + " · press Enter twice",
                               glyph: "dangerous", badge: "Kill", destructive: true, run: () => Quickshell.execDetached(["pkill", "-x", "-u", Quickshell.env("USER"), "--", want]) });
            }
            if ((m = /^(?:save|snapshot)\s+(?:workspace\s+|setup\s+)?(.+)$/i.exec(q)))
                out.push({ kind: "command", group: "Snapshots", title: "Save this setup as “" + m[1].trim() + "”", subtitle: "Apps, workspaces, terminal folders, Focus mode and wallpaper",
                           glyph: "bookmark_add", badge: "Save", run: () => root.snap("save", m[1].trim()) });
            if ((m = /^(?:restore|load)\s*(.*)$/i.exec(q))) {
                const want = m[1].trim();
                const hits = root.snapshots.map(x => ({ x, s: want ? Fuzzy.score(want, x.name) : 1 })).filter(y => y.s > 0).sort((a, b) => b.s - a.s).slice(0, 6);
                for (const h of hits)
                    out.push({ kind: "command", group: "Snapshots", title: "Restore “" + h.x.name + "”", subtitle: h.x.windows + " windows · " + h.x.apps.slice(0, 4).join(", "),
                               glyph: "bookmark", badge: "Restore", run: () => root.snap("restore", h.x.name) });
                if (!hits.length) out.push({ kind: "command", group: "Snapshots", title: want ? "No snapshot “" + want + "”" : "No snapshots yet",
                                              subtitle: "Save one: type “save <name>”", glyph: "bookmark_border", badge: "", run: () => {} });
            }
            if ((m = /^(?:ask|ai)\s+(.+)$/i.exec(q)))
                out.push({ kind: "command", group: "Halo", title: "Ask Halo: " + m[1], subtitle: Ai.configured ? "Answers in the AI panel" : "Set up AI first (Settings → AI)",
                           glyph: "auto_awesome", badge: "Ask", run: () => { Ai.show(); Ai.send(m[1]); } });
            if (out.length) return out;
        }
        // Timers: "timer 5m", "25 min timer", "t 90s", "stopwatch"
        {
            let m = /^(?:timer|t)\s+(.+)$/i.exec(q) ?? /^(.+?)\s+timer$/i.exec(q);
            const ms = m ? Countdown.parse(m[1]) : 0;
            if (ms > 0) out.push({ kind: "timer", group: "Timer", title: "Start a " + Countdown.fmt(ms) + " timer", subtitle: "Shown in the island · click it to pause",
                                  glyph: "timer", badge: "Start", run: () => Countdown.startTimer(ms, "") });
            if (/^stop ?watch$/i.test(q)) out.push({ kind: "timer", group: "Timer", title: "Start a stopwatch", subtitle: "Shown in the island · right-click it to stop",
                                  glyph: "avg_pace", badge: "Start", run: () => Countdown.startStopwatch() });
            if (out.length) return out;
        }
        const webOnly = q.startsWith("?");
        const text = webOnly ? q.slice(1).trim() : q;

        if (!webOnly) {
            if (Calc.result !== "")
                out.push({ kind: "calc", group: Calc.money ? "Money" : "Calculator", title: Calc.result,
                           subtitle: [Calc.words(Calc.result), Calc.expression.replace(/\s+to INR$/, "")].filter(x => x).join(" · "),
                           glyph: Calc.money ? "currency_rupee" : "calculate", badge: "Copy",
                           run: () => Quickshell.execDetached(["wl-copy", Calc.result.replace(/^≈\s*/, "")]) });

            // Apps, windows and actions are ranked as groups by their best match,
            // so "mute mic" puts the action above a loosely matching app
            const groups = [];
            const apps = Apps.search(text);
            const cut = (apps[0]?.score ?? 0) * 0.55;
            const appRows = apps.filter(a => a.score >= cut).slice(0, 6).map(r => ({ kind: "app", group: "Applications", title: r.entry.name,
                           subtitle: r.entry.genericName || r.entry.comment || "",
                           icon: Apps.iconFor(r.entry), badge: "App", score: r.score,
                           run: () => Apps.launch(r.entry) }));
            if (appRows.length) groups.push({ best: apps[0].score, rows: appRows });

            const wins = Hyprland.toplevels.values
                .map(t => ({ t, s: Math.max(Fuzzy.score(text, t.title), Fuzzy.score(text, t.lastIpcObject?.class ?? "")) }))
                .filter(x => x.s >= 600)
                .sort((a, b) => b.s - a.s)
                .slice(0, 3);
            const winRows = wins.map(w => {
                const cls = w.t.lastIpcObject?.class ?? "";
                const entry = Apps.entryFor(cls);
                return { kind: "window", group: "Windows", title: w.t.title || cls,
                         subtitle: `${entry?.name ?? cls} · workspace ${w.t.workspace?.id ?? "?"}`,
                         icon: entry ? Apps.iconFor(entry) : "", glyph: "select_window", badge: "Window",
                         run: () => Hypr.focusWindow(w.t.lastIpcObject?.address ?? ("0x" + w.t.address)) };
            });
            if (winRows.length) groups.push({ best: wins[0].s, rows: winRows });

            const acts = actions.concat(settingsActions)
                .map(a => ({ a, s: Math.max(Fuzzy.score(text, a.title), 0.9 * Fuzzy.score(text, a.keys)) }))
                .filter(x => x.s >= 600)
                .sort((a, b) => b.s - a.s)
                .slice(0, 5);
            const actRows = acts.map(x => {
                const st = x.a.state ? x.a.state() : null;
                return { kind: "action", group: x.a.title.endsWith(" settings") ? "Settings" : "Actions", title: x.a.title,
                         subtitle: x.a.destructive ? "Press Enter twice to confirm" : st === null ? "" : st ? "On — Enter turns it off" : "Off — Enter turns it on",
                         glyph: x.a.glyph, badge: x.a.title.endsWith(" settings") ? "Open" : st === null ? "Action" : st ? "On" : "Off", destructive: x.a.destructive ?? false,
                         run: () => x.a.fn ? x.a.fn() : root.exec(x.a.cmd, x.a.delay) };
            });
            // settings rows form their own group after actions
            const actOnly = actRows.filter(r => r.group === "Actions"), setRows = actRows.filter(r => r.group === "Settings");
            if (actOnly.length) groups.push({ best: acts.find(x => !x.a.title.endsWith(" settings")).s * 1.05, rows: actOnly });
            if (setRows.length) groups.push({ best: acts.find(x => x.a.title.endsWith(" settings")).s, rows: setRows });

            groups.sort((a, b) => b.best - a.best);
            for (const g of groups) out.push(...g.rows);
        }

        if (text !== "")
            out.push({ kind: "web", group: "Web", title: `Search the web for “${text}”`, subtitle: "", glyph: "travel_explore", badge: "Web",
                       run: () => Quickshell.execDetached(["xdg-open", webSearchUrl.replace("%s", encodeURIComponent(text))]) });
        return out;
    }
}
