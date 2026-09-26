pragma Singleton

// Installed applications + launch history (frecency) for ranking and the
// "recent" row. History lives in ~/.local/state/lumen/launcher.json.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    readonly property var list: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

    property var history: ({})   // id → { count, last }

    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/launcher.json"

    FileView {
        id: store
        path: root.statePath
        onLoaded: { try { root.history = JSON.parse(text()) ?? {}; } catch (e) { root.history = {}; } }
        onLoadFailed: root.history = {}
    }

    // Frecency: uses decay with a ~1-week half-life
    function frecency(id) {
        const h = history[id];
        if (!h) return 0;
        const ageDays = (Date.now() - h.last) / 86400000;
        return h.count * Math.pow(0.5, ageDays / 7);
    }

    readonly property var recent: list
        .filter(a => history[a.id])
        .sort((a, b) => frecency(b.id) - frecency(a.id))
        .slice(0, 7)

    function keywordsOf(a) {
        const k = a.keywords;
        if (!k) return [];
        return Array.isArray(k) ? k : String(k).split(/[;,]/).filter(x => x);
    }

    // ── App icons ────────────────────────────────────────────────────────────
    // Lumen can use its own app-icon theme without touching the system one
    // (KDE/ii keep theirs): an index of the chosen theme's app icons is built
    // once, preferring scalable SVGs, then the largest PNG. Anything missing
    // falls back to the system theme. Settings → Appearance → App icons.
    readonly property string iconTheme: Persist.data.iconTheme
    property var iconIndex: ({})
    onIconThemeChanged: rebuildIndex()
    Component.onCompleted: rebuildIndex()
    function rebuildIndex() {
        iconIndex = {};
        if (iconTheme === "" || iconTheme === "system") return;
        indexer.command = ["sh", "-c",
            'for d in "$HOME/.local/share/icons" "$HOME/.icons" /usr/share/icons; do ' +
            '  [ -d "$d/$1" ] && exec find -L "$d/$1" -path "*apps*" \\( -name "*.svg" -o -name "*.png" \\) 2>/dev/null; done',
            "sh", iconTheme];
        indexer.running = true;
    }
    Process {
        id: indexer
        stdout: StdioCollector {
            onStreamFinished: {
                const idx = {};
                const rank = p => /scalable|\/symbolic/.test(p) ? (/symbolic/.test(p) ? 0 : 1000)
                                : parseInt((p.match(/\/(\d+)(x\d+)?\//) ?? [0, 0])[1]) || 1;
                for (const p of text.split("\n")) {
                    if (p === "") continue;
                    const name = p.slice(p.lastIndexOf("/") + 1).replace(/\.(svg|png)$/, "");
                    const r = rank(p);
                    if (!idx[name] || r > idx[name].r) idx[name] = { p, r };
                }
                const flat = {};
                for (const k in idx) flat[k] = "file://" + idx[k].p;
                root.iconIndex = flat;
            }
        }
    }
    function iconNamed(name, fallback) {
        if (!name) return Quickshell.iconPath(fallback ?? "application-x-executable");
        if (name.startsWith("/")) return "file://" + name;
        return iconIndex[name] ?? Quickshell.iconPath(name, fallback ?? "application-x-executable");
    }
    // Best desktop entry for a loose hint (binary, app name, window class):
    // heuristicLookup first, then id / exec / name matches ("firefox" →
    // org.mozilla.firefox).
    function entryFor(...hints) {
        for (const h of hints) {
            if (!h) continue;
            const e = DesktopEntries.heuristicLookup(h);
            if (e) return e;
        }
        const all = DesktopEntries.applications.values;
        for (const h of hints) {
            if (!h) continue;
            const q = String(h).toLowerCase();
            const e = all.find(a => a.id.toLowerCase().endsWith("." + q) || a.id.toLowerCase() === q)
                   ?? all.find(a => (a.execString ?? a.command?.join(" ") ?? "").toLowerCase().split(/[\s/]/).includes(q))
                   ?? all.find(a => a.name.toLowerCase() === q);
            if (e) return e;
        }
        return null;
    }
    function iconFor(entry) { return iconNamed(entry?.icon ?? "", "application-x-executable"); }

    function launch(entry) {
        if (!entry) return;
        const h = Object.assign({}, history);
        const prev = h[entry.id] ?? { count: 0, last: 0 };
        h[entry.id] = { count: prev.count + 1, last: Date.now() };
        history = h;
        Quickshell.execDetached(["mkdir", "-p", statePath.substring(0, statePath.lastIndexOf("/"))]);
        store.setText(JSON.stringify(h));

        if (entry.runInTerminal)
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.execString.replace(/%[fFuUdDnNickvm]/g, "")]);
        else if (entry.command?.length)
            Quickshell.execDetached({ command: entry.command, workingDirectory: entry.workingDirectory || Quickshell.env("HOME"), environment: appEnv });
        else
            entry.execute();
    }

    // Lumen's Qt/KDE app theming (hypr/environment.lua sets the same for apps
    // Hyprland starts). Passed explicitly so apps launched here get it even if
    // this shell was started before the theming existed.
    readonly property var appEnv: {
        if (Quickshell.env("QT_QPA_PLATFORMTHEME") !== "qt6ct") return ({});
        const gen = Theme.lumenRoot + "/generated";
        const add = (v, dir, def) => { const cur = Quickshell.env(v) || def; return cur.includes(dir) ? cur : dir + ":" + cur; };
        return {
            XDG_CONFIG_DIRS: add("XDG_CONFIG_DIRS", gen + "/xdg", "/etc/xdg"),
            XDG_DATA_DIRS: add("XDG_DATA_DIRS", gen + "/share", "/usr/local/share:/usr/share"),
            KDE_COLOR_SCHEME_PATH: gen + "/share/color-schemes/Lumen.colors"
        };
    }

    function search(q) {
        const out = [];
        for (const a of list) {
            const s = Math.max(Fuzzy.score(q, a.name),
                               0.7 * Fuzzy.score(q, a.genericName ?? ""),
                               0.6 * Math.max(0, ...root.keywordsOf(a).map(k => Fuzzy.score(q, k))),
                               0.5 * Fuzzy.score(q, a.id ?? ""));
            if (s > 0) out.push({ entry: a, score: s + Math.log(1 + frecency(a.id)) * 60 });
        }
        return out.sort((x, y) => y.score - x.score);
    }
}
