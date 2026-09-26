pragma Singleton

// Lyrics for what's playing, from LRCLIB via scripts/lyrics.sh.
// Looked up only while someone is looking (the island's now-playing view sets
// `wanted`) and only if Settings → Sound → Lyrics is on; never in the background.
//   state   "" (nothing asked) · loading · synced · plain · instrumental · none
//   lines   [{ t: seconds, text }] for synced lyrics; `index` is the line now
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool wanted: false          // the expanded media view is on screen
    property bool mode: false            // the island shows lyrics instead of just the current line
    readonly property bool enabled: Persist.data.lyrics ?? true

    property string state: ""
    property var lines: []
    property string plain: ""
    property string loadedKey: ""
    readonly property bool available: ["synced", "plain", "instrumental"].includes(state)

    readonly property string key: Media.present && Media.title ? (Media.artist + "|" + Media.title).toLowerCase() : ""
    onKeyChanged: { if (key !== loadedKey) { state = ""; lines = []; plain = ""; } maybeFetch(); }
    onWantedChanged: maybeFetch()
    onEnabledChanged: { if (!enabled) { state = ""; lines = []; plain = ""; loadedKey = ""; mode = false; } else maybeFetch(); }

    function maybeFetch() {
        if (!wanted || !enabled || !key || key === loadedKey || proc.running) return;
        loadedKey = key;
        state = "loading";
        proc.command = [Theme.lumenRoot + "/scripts/lyrics.sh", Media.artist, Media.title, Media.album,
                        Media.length > 0 ? String(Math.round(Media.length)) : ""];
        proc.running = true;
    }

    Process {
        id: proc
        property string forKey: ""
        onStarted: forKey = root.loadedKey
        stdout: StdioCollector {
            onStreamFinished: {
                if (proc.forKey !== root.key) { root.loadedKey = ""; root.maybeFetch(); return; }   // song changed meanwhile
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                if (!d || !d.found) { root.state = "none"; return; }
                if (d.instrumental && !d.synced && !d.plain) { root.state = "instrumental"; return; }
                const parsed = root.parse(d.synced || "");
                if (parsed.length > 1) { root.lines = parsed; root.state = "synced"; }
                else if (d.plain) { root.plain = d.plain.trim(); root.state = "plain"; }
                else root.state = "none";
            }
        }
    }

    // "[01:02.34] words" (several stamps per line allowed) → sorted [{ t, text }]
    function parse(lrc) {
        const out = [];
        for (const raw of lrc.split("\n")) {
            const stamps = [];
            let rest = raw, m;
            while ((m = /^\s*\[(\d+):(\d+(?:[.:]\d+)?)\]/.exec(rest)) !== null) {
                stamps.push(+m[1] * 60 + parseFloat(m[2].replace(":", ".")));
                rest = rest.slice(m[0].length);
            }
            for (const t of stamps) out.push({ t, text: rest.trim() });
        }
        return out.sort((a, b) => a.t - b.t);
    }

    // The line being sung (a little early reads better than a little late)
    readonly property real position: (devStart > 0 ? (devNow - devStart) / 1000 : (Media.active?.position ?? 0)) + 0.25
    readonly property int index: {
        if (state !== "synced") return -1;
        let i = -1;
        for (let k = 0; k < lines.length; k++) { if (lines[k].t <= position) i = k; else break; }
        return i;
    }
    readonly property string current: index >= 0 ? lines[index].text : ""

    // Dev only (LUMEN_DEV): sample synced lyrics on a fake clock
    property real devStart: 0
    property real devNow: 0
    Timer { interval: 200; repeat: true; running: root.devStart > 0; onTriggered: root.devNow = Date.now() }
    IpcHandler {
        target: "lyricsTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function demo(): void {
            root.lines = root.parse("[00:00.50] Look at the stars\n[00:03.00] Look how they shine for you\n[00:05.50] And everything you do\n[00:08.00] Yeah, they were all yellow\n[00:10.50] I came along\n[00:13.00] I wrote a song for you");
            root.loadedKey = root.key; root.state = "synced"; root.devStart = Date.now(); root.devNow = Date.now();
        }
        function stop(): void { root.devStart = 0; root.loadedKey = ""; root.state = ""; root.maybeFetch(); }
    }
    IpcHandler {
        target: "lyrics"
        function toggle(): void { root.mode = !root.mode; }
        function state(): string { return JSON.stringify({ key: root.key, loadedKey: root.loadedKey, state: root.state, index: root.index, current: root.current, lines: root.lines.length, position: root.position }); }
    }

    // Position is polled only while lyrics are on screen and playing
    Timer {
        interval: 250; repeat: true
        running: root.wanted && root.state === "synced" && Media.playing
        onTriggered: Media.active?.positionChanged()
    }
}
