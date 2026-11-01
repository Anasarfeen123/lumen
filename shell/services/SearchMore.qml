pragma Singleton
// More for the launcher's search (services/Search.qml), read when it opens:
//   recent files   from the desktop's recently-used list (~/.local/share/recently-used.xbel)
//   tmux sessions  "tmux" lists them; Enter attaches in kitty
//   processes      "kill <name>" / "top" — the busiest first; ending one asks twice
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var recent: []             // [{ name, path, when }]
    property var tmux: []               // [{ name, windows, attached }]
    property var procs: []              // [{ pid, name, cpu, mem }]
    // "f <name>": files in your home folder (fd, hidden and ignored ones skipped), after a short pause in typing
    property var found: []              // [{ name, path }]
    property string findQuery: ""
    function find(q) { findQuery = q; if (q.length < 2) { found = []; return; } findSoon.restart(); }
    Timer { id: findSoon; interval: 180; onTriggered: { findProc.running = false; findProc.command = ["fd", "-i", "--max-results", "12", "--", root.findQuery, Quickshell.env("HOME") ?? "/"]; findProc.running = true; } }
    Process {
        id: findProc
        stdout: StdioCollector { onStreamFinished: root.found = text.split("\n").filter(l => l).map(p => ({ name: p.replace(/\/$/, "").replace(/^.*\//, ""), path: p.replace(/\/$/, ""), dir: p.endsWith("/") })) }
    }
    property var otp: []                // [{ name, code, left }] — "otp" / "2fa" (scripts/otp.py)
    function refreshOtp() { if (!otpProc.running) otpProc.running = true; }
    readonly property bool hasTmux: tmuxCheck.found

    function refresh() {
        if (!recentProc.running) recentProc.running = true;
        if (hasTmux && !tmuxProc.running) tmuxProc.running = true;
    }
    function refreshProcs() { if (!psProc.running) psProc.running = true; }

    Process {
        id: tmuxCheck
        property bool found: false
        running: true
        command: ["sh", "-c", "command -v tmux"]
        onExited: code => found = code === 0
    }
    // the newest 200 bookmarks, newest first: when|path
    Process {
        id: recentProc
        command: ["sh", "-c", 'f=${XDG_DATA_HOME:-$HOME/.local/share}/recently-used.xbel; [ -f "$f" ] || exit 0; ' +
                  'grep -o "<bookmark [^>]*>" "$f" | ' +
                  'sed -nE "s|.*href=\\"file://([^\\"]*)\\".*modified=\\"([^\\"]*)\\".*|\\2\\|\\1|p" | sort -r | head -200']
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {}, out = [];
                for (const l of text.split("\n")) {
                    const i = l.indexOf("|");
                    if (i < 0) continue;
                    const path = decodeURIComponent(l.slice(i + 1));
                    if (seen[path]) continue;
                    seen[path] = true;
                    out.push({ name: path.replace(/^.*\//, ""), path, when: l.slice(0, i) });
                }
                root.recent = out;
            }
        }
    }
    Process {
        id: tmuxProc
        command: ["tmux", "list-sessions", "-F", "#{session_name}|#{session_windows}|#{session_attached}"]
        stdout: StdioCollector {
            onStreamFinished: root.tmux = text.trim().split("\n").filter(l => l).map(l => { const f = l.split("|"); return { name: f[0], windows: +f[1], attached: f[2] !== "0" }; })
        }
        onExited: code => { if (code !== 0) root.tmux = []; }
    }
    Process {
        id: otpProc
        command: [Quickshell.env("HOME") + "/.config/lumen/scripts/otp.py", "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.otp = JSON.parse(text); } catch (e) { root.otp = []; } } }
    }
    Process {
        id: psProc
        command: ["ps", "-u", Quickshell.env("USER") ?? "", "-o", "pid=,comm=,pcpu=,rss=", "--sort=-pcpu"]
        stdout: StdioCollector {
            onStreamFinished: root.procs = text.trim().split("\n").map(l => l.trim().split(/\s+/)).filter(f => f.length >= 4)
                .map(f => ({ pid: f[0], name: f[1], cpu: +f[2], mem: +f[3] * 1024 })).slice(0, 200)
        }
    }
}
