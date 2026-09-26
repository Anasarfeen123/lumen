pragma Singleton
// Downloads in the island: while a browser writes a partial file
// (*.part, *.crdownload, *.download) the island shows its name and growing
// size; when the finished file lands it says "Downloaded" — click opens it.
// Watches only your Downloads folder (inotifywait), only in a real session.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string dir: Quickshell.env("XDG_DOWNLOAD_DIR") || (Quickshell.env("HOME") + "/Downloads")
    property var partials: ({})          // partial name → { final }
    property real lastPartialGone: 0
    readonly property var partialRe: /\.(part|crdownload|download|opdownload)$/

    function finalName(p) {
        // Chrome: "Unconfirmed 123.crdownload" has no real name yet
        return /^Unconfirmed \d+\.crdownload$/.test(p) ? "" : p.replace(partialRe, "");
    }

    Process {
        running: Persist.automates
        command: ["inotifywait", "-m", "-q", "-e", "create,moved_to,moved_from,delete", "--format", "%e|%f", root.dir]
        stdout: SplitParser {
            onRead: line => {
                const i = line.indexOf("|");
                const ev = line.slice(0, i), name = line.slice(i + 1);
                if (!name || name.startsWith(".")) return;
                const partial = root.partialRe.test(name);
                const p = Object.assign({}, root.partials);
                // A rename arrives as MOVED_FROM (old name) then MOVED_TO (new name)
                if (ev.includes("MOVED_FROM")) {
                    if (partial) { delete p[name]; root.partials = p; root.lastPartialGone = Date.now(); }
                    return;
                }
                if (ev.includes("DELETE")) { if (partial) { delete p[name]; root.partials = p; } return; }
                if (partial) {                                  // CREATE / MOVED_TO a partial: downloading
                    p[name] = { final: root.finalName(name) };
                    root.partials = p;
                    return;
                }
                // A finished file: a partial was just renamed onto it (Firefox also
                // writes an empty placeholder first, so creations don't count)
                if (ev.includes("MOVED_TO") && Date.now() - root.lastPartialGone < 2000) root.finished(name);
            }
        }
    }

    // While something is downloading, report its size every second
    Timer {
        interval: 1000; repeat: true; running: Object.keys(root.partials).length > 0 && Persist.automates; triggeredOnStart: true
        onTriggered: { sizes.command = ["sh", "-c", 'cd "$1" && shift && for f; do [ -e "$f" ] && printf "%s\t%s\n" "$(stat -c %s -- "$f")" "$f"; done', "sh", root.dir].concat(Object.keys(root.partials)); sizes.running = true; }
    }
    Process {
        id: sizes
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(Boolean).map(l => l.split("\t"));
                if (!rows.length) return;
                const [bytes, name] = rows[0];
                const shown = root.partials[name]?.final || "Downloading";
                Island.push({ kind: "system", key: "download", priority: Island.priority.system, duration: 1600, force: true,
                              data: { icon: "downloading", title: shown, detail: root.human(+bytes) + (rows.length > 1 ? " · +" + (rows.length - 1) + " more" : ""), tone: "normal" } });
            }
        }
    }
    function finished(name) {
        Sounds.play("done");
        Island.push({ kind: "system", key: "download", priority: Island.priority.system, duration: 4000, force: true, queueable: true,
                      data: { icon: "download_done", title: "Downloaded", detail: name, tone: "normal", path: root.dir + "/" + name } });
    }
    function human(b) {
        return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1) + " MB" : b >= 1e3 ? Math.round(b / 1e3) + " KB" : b + " B";
    }
}
