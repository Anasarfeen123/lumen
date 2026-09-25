pragma Singleton

// Emoji list (char + name), generated once from Python's Unicode database by
// scripts/emoji-data.py into ~/.cache/lumen/emoji.tsv.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property var all: []
    readonly property string cachePath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/lumen/emoji.tsv"

    property bool prepared: false

    // Generate the list on first use (fast: ~50 ms), then load it.
    function ensure() {
        if (all.length > 0 || prep.running) return;
        prep.running = true;
    }

    function search(q) {
        if (!q) return all.slice(0, 60);
        const out = [];
        for (const e of all) {
            const s = Fuzzy.score(q, e.name);
            if (s >= 600) out.push({ e, s });
        }
        return out.sort((a, b) => b.s - a.s).slice(0, 60).map(x => x.e);
    }

    function copy(ch) { Quickshell.execDetached(["wl-copy", ch]); }

    Process {
        id: prep
        command: ["sh", "-c", 'test -s "$1" || python3 "$2" "$1"', "sh", root.cachePath, Theme.lumenRoot + "/scripts/emoji-data.py"]
        onExited: code => { if (code === 0) { root.prepared = true; file.reload(); } else console.warn("Emoji: generation failed", code); }
    }

    FileView {
        id: file
        path: root.prepared ? root.cachePath : ""
        onLoaded: root.all = text().split("\n").filter(l => l).map(l => { const [ch, name] = l.split("\t"); return { ch, name }; })
    }
}
