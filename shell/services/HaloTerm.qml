pragma Singleton
// Halo's terminal: commands with their output kept, so Halo can read the
// result and carry on ("why is my disk full?" → du → an answer).
//
//   Halo's commands     ALWAYS wait for your Allow — the exact command is shown,
//                       with a hint (read-only / changes things / touches secrets).
//                       Halo reads the output only after you allowed it to run.
//   your commands       ("$ df -h" in Halo) run straight away — you typed them
//   sudo                never runs here; "Run in a terminal" and you type the password
// A fresh bash in your home folder each time (no profile), 60 s at most,
// output capped at 60 KB, Stop any time. Kept for this session only.
//
//   request(cmd, by, cb, why)   by: "halo" | "you" · cb(output, exitCode) — -1 when denied
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []            // [{ id, cmd, by, state: waiting|queued|running|done|failed|denied|stopped, code, out, why, kind, at, ms }]
    property int count: 0
    readonly property var current: entries.find(e => e.state === "running") ?? null
    readonly property var waiting: entries.filter(e => e.state === "waiting")
    readonly property int maxOut: 60000

    // A hint for you, never a permission: what the command looks like it does
    readonly property var lookers: ["ls", "du", "df", "free", "uptime", "cat", "head", "tail", "wc", "grep", "rg", "fd", "find", "which", "file", "stat",
        "uname", "lsblk", "lsusb", "lspci", "lscpu", "sensors", "date", "pwd", "whoami", "ps", "pgrep", "sort", "uniq", "cut", "jq", "tree",
        "journalctl", "coredumpctl", "upower", "wpctl", "pactl", "ip", "ss", "getent", "rpm", "free", "dmesg", "echo", "printf"]
    function kindOf(cmd) {
        if (/\.ssh|\.gnupg|\.pem\b|\.key\b|id_rsa|id_ed25519|\.netrc|token|passw|secret|credential|keyring|kwallet|lumen\/ai\/|cookies/i.test(cmd)) return "secret";
        if (/(^|[;&|]\s*)(sudo|pkexec|doas)\b/.test(cmd)) return "root";
        if (/>|`|\$\(/.test(cmd.replace(/\d?>&\d|&?\d?>\s*\/dev\/null/g, ""))) return "change";
        const parts = cmd.split(/\|\||&&|;|\|/).map(p => p.trim().split(/\s+/)[0]?.replace(/^.*\//, "") ?? "");
        const readish = w => lookers.includes(w);
        if (parts.every(readish) && !/\s-(delete|exec)\b|\s-i\b|--in-place/.test(cmd)) return "read";
        if (/^(git (status|log|diff|show|branch)|systemctl (--user )?(status|list-units|is-active|--failed)|dnf (info|list|search|history)|hyprctl (-j )?(clients|monitors|workspaces|devices|version)|flatpak list|ollama (list|ps))\b/.test(cmd.trim())) return "read";
        return "change";
    }

    // ── running ──
    property var callbacks: ({})
    function request(cmd, by, cb, why) {
        cmd = String(cmd ?? "").trim();
        if (!cmd) { if (cb) cb("No command.", -1); return ""; }
        const id = "t" + (++count);
        const kind = kindOf(cmd);
        const st = kind === "root" ? "denied" : by === "you" ? "queued" : "waiting";
        entries = entries.concat([{ id, cmd, by: by ?? "halo", state: st, code: null, out: "", why: why ?? "", kind, at: Date.now(), ms: 0 }]).slice(-40);
        if (cb) { const c = Object.assign({}, callbacks); c[id] = cb; callbacks = c; }
        if (kind === "root") finish(id, "This needs your password, so it doesn't run here. Use “Run in a terminal” and type it yourself.", -1, "denied");
        else if (st === "queued") pump();
        return id;
    }
    function allow(id) { if (entries.find(e => e.id === id)?.state === "waiting") { set(id, { state: "queued" }); pump(); } }
    function deny(id) { if (entries.find(e => e.id === id)?.state === "waiting") finish(id, "The user said no to running this.", -1, "denied"); }
    function stop() { if (proc.running) { proc.stopped = true; proc.signal(15); } }
    function clear() { entries = entries.filter(e => e.state === "running" || e.state === "waiting"); }
    function inTerminal(id) {
        const e = entries.find(x => x.id === id);
        if (e) Quickshell.execDetached(["kitty", "--title", "Halo · command", "--hold", "sh", "-c", 'printf "\\033[2m$ %s\\033[0m\\n" "$1"; eval "$1"', "sh", e.cmd]);
    }
    function set(id, patch) { entries = entries.map(e => e.id === id ? Object.assign({}, e, patch) : e); }
    function finish(id, out, code, state) {
        set(id, { state: state ?? (code === 0 ? "done" : "failed"), code, out: out !== undefined ? out : (entries.find(e => e.id === id)?.out ?? "") });
        const cb = callbacks[id];
        if (cb) { const c = Object.assign({}, callbacks); delete c[id]; callbacks = c; cb(entries.find(e => e.id === id)?.out ?? "", code); }
        Qt.callLater(pump);
    }
    function pump() {
        if (proc.running) return;
        const next = entries.find(e => e.state === "queued");
        if (!next) return;
        proc.id = next.id; proc.buf = ""; proc.stopped = false; proc.t0 = Date.now();
        set(next.id, { state: "running" });
        proc.command = ["timeout", "--kill-after=5", "60", "bash", "--noprofile", "--norc", "-c", "cd ~ && " + next.cmd + " 2>&1"];
        proc.running = true;
    }
    Process {
        id: proc
        property string id: ""
        property string buf: ""
        property bool stopped: false
        property real t0: 0
        environment: ({ TERM: "dumb", NO_COLOR: "1", PAGER: "cat", GIT_PAGER: "cat", SYSTEMD_PAGER: "", LC_ALL: "C.UTF-8" })
        stdout: SplitParser {
            onRead: line => {
                if (proc.buf.length > root.maxOut) return;
                proc.buf += line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, "") + "\n";
                flushOut.restart();
            }
        }
        onExited: code => {
            flushOut.stop();
            const out = proc.buf.length > root.maxOut ? proc.buf.slice(0, root.maxOut) + "\n… (output cut at 60 KB)" : proc.buf;
            root.set(proc.id, { ms: Date.now() - proc.t0 });
            root.finish(proc.id, out + (code === 124 ? "\n(stopped after 60 s)" : ""), proc.stopped ? -2 : code, proc.stopped ? "stopped" : undefined);
        }
    }
    // live output, a few times a second
    Timer { id: flushOut; interval: 120; onTriggered: root.set(proc.id, { out: proc.buf }) }

    IpcHandler {
        target: "term"
        function you(cmd: string): string { return root.request(cmd, "you", null); }
        function state(): string { return JSON.stringify(root.entries.map(e => ({ id: e.id, cmd: e.cmd, state: e.state, kind: e.kind, code: e.code, out: e.out.slice(-300) }))); }
        function deny(id: string): void { root.deny(id); }
    }
}
