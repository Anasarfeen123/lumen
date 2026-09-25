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
import qs.theme

Singleton {
    id: root

    // Change to your preferred engine; %s is replaced by the query.
    readonly property string webSearchUrl: "https://duckduckgo.com/?q=%s"

    readonly property var actions: [
        { title: "Lock", glyph: "lock", keys: "lock screen", cmd: ["loginctl", "lock-session"] },
        { title: "Suspend", glyph: "bedtime", keys: "sleep suspend", cmd: ["systemctl", "suspend"] },
        { title: "Log out", glyph: "logout", keys: "logout log out exit sign out", cmd: ["hyprctl", "dispatch", "exit"], destructive: true },
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
    ]

    // Keep the calculator fed as the query changes
    Connections {
        target: Overview
        function onQueryChanged() { if (Overview.mode === "search") Calc.evaluate(Overview.query.trim()); }
        function onModeChanged() {
            if (Overview.mode === "clipboard") Clipboard.refresh();
            if (Overview.mode === "emoji") Emoji.ensure();
        }
        function onOpenChanged() {
            if (!Overview.open) return;
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
        return Clipboard.entries
            .filter(e => !q || e.text.toLowerCase().includes(q.toLowerCase()))
            .slice(0, 50)
            .map(e => ({
                kind: "clipboard", id: e.id,
                title: e.isImage ? "Image" : e.text.replace(/\s+/g, " ").slice(0, 200),
                subtitle: e.isImage ? e.text.replace(/^\[\[ binary data |\]\]$/g, "") : "",
                glyph: e.isImage ? "image" : "content_paste", badge: "",
                run: () => Clipboard.copy(e.id) }));
    }

    function searchResults(q) {
        const out = [];

        if (q.startsWith(">")) {
            const cmd = q.slice(1).trim();
            if (cmd) out.push({ kind: "command", title: cmd, subtitle: "Run command", glyph: "terminal", badge: "Run",
                                run: () => Quickshell.execDetached(["sh", "-c", cmd]) });
            return out;
        }
        const webOnly = q.startsWith("?");
        const text = webOnly ? q.slice(1).trim() : q;

        if (!webOnly) {
            if (Calc.result !== "")
                out.push({ kind: "calc", title: Calc.result, subtitle: Calc.expression, glyph: "calculate", badge: "Copy",
                           run: () => Quickshell.execDetached(["wl-copy", Calc.result.replace(/^≈\s*/, "")]) });

            // Keep only matches in the same league as the best one
            const apps = Apps.search(text);
            const cut = (apps[0]?.score ?? 0) * 0.55;
            for (const r of apps.filter(a => a.score >= cut).slice(0, 6))
                out.push({ kind: "app", title: r.entry.name,
                           subtitle: r.entry.genericName || r.entry.comment || "",
                           icon: Apps.iconFor(r.entry), badge: "App", score: r.score,
                           run: () => Apps.launch(r.entry) });

            const wins = Hyprland.toplevels.values
                .map(t => ({ t, s: Math.max(Fuzzy.score(text, t.title), Fuzzy.score(text, t.lastIpcObject?.class ?? "")) }))
                .filter(x => x.s >= 600)
                .sort((a, b) => b.s - a.s)
                .slice(0, 3);
            for (const w of wins) {
                const cls = w.t.lastIpcObject?.class ?? "";
                const entry = DesktopEntries.heuristicLookup(cls);
                out.push({ kind: "window", title: w.t.title || cls,
                           subtitle: `${entry?.name ?? cls} · workspace ${w.t.workspace?.id ?? "?"}`,
                           icon: entry ? Apps.iconFor(entry) : "", glyph: "select_window", badge: "Window",
                           run: () => Hyprland.dispatch(`focuswindow address:${w.t.lastIpcObject?.address ?? ("0x" + w.t.address)}`) });
            }

            const acts = actions
                .map(a => ({ a, s: Math.max(Fuzzy.score(text, a.title), 0.9 * Fuzzy.score(text, a.keys)) }))
                .filter(x => x.s >= 600)
                .sort((a, b) => b.s - a.s)
                .slice(0, 4);
            for (const x of acts)
                out.push({ kind: "action", title: x.a.title, subtitle: x.a.destructive ? "Press Enter twice to confirm" : "",
                           glyph: x.a.glyph, badge: "Action", destructive: x.a.destructive ?? false,
                           run: () => root.exec(x.a.cmd, x.a.delay) });
        }

        if (text !== "")
            out.push({ kind: "web", title: `Search the web for “${text}”`, subtitle: "", glyph: "travel_explore", badge: "Web",
                       run: () => Quickshell.execDetached(["xdg-open", webSearchUrl.replace("%s", encodeURIComponent(text))]) });
        return out;
    }
}
