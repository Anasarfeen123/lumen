// Advanced: Lumen's files, a health check, logs, reload/reset, and developer
// bits. scripts/doctor.sh does the work; it only writes when you press
// Create (a missing template) or Reset (renames the file, never deletes it).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Advanced"
    subtitle: "Lumen's files, a health check, logs, and resets. Nothing here changes anything until you press a button."

    readonly property string doctor: Theme.lumenRoot + "/scripts/doctor.sh"
    readonly property string home: Quickshell.env("HOME")
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || home + "/.local/state") + "/lumen"
    readonly property string runDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    function tilde(p) { return p.replace(home, "~"); }
    function run(args) { Quickshell.execDetached([doctor].concat(args)); }

    // ── doctor.sh check ──
    property var checks: []
    property bool checking: false
    Process {
        id: checkProc
        command: [page.doctor, "check"]
        stdout: StdioCollector { onStreamFinished: { try { page.checks = JSON.parse(text); } catch (e) {} page.checking = false; } }
    }
    function verify() { checking = true; checkProc.running = true; }

    property string version: ""
    Process {
        command: [page.doctor, "version"]
        running: true
        stdout: StdioCollector { onStreamFinished: page.version = text.trim() }
    }

    // Which optional files exist (local.lua, session.env)
    property var exists: ({})
    Process {
        id: existsProc
        command: ["sh", "-c", 'for f in "$@"; do [ -e "$f" ] && printf "%s\\n" "$f"; done', "sh",
                  Theme.lumenRoot + "/local.lua", Theme.lumenRoot + "/session.env"]
        stdout: StdioCollector {
            onStreamFinished: {
                const e = {};
                for (const l of text.split("\n")) if (l) e[l] = true;
                page.exists = e;
            }
        }
    }

    // One-shot actions whose output we report ("created", "moved"…)
    property string note: ""
    Process {
        id: actProc
        stdout: StdioCollector { onStreamFinished: { page.note = actProc.msgs[text.trim()] ?? text.trim(); existsProc.running = true; } }
        property var msgs: ({})
    }
    function act(args, msgs) { actProc.msgs = msgs; actProc.command = [doctor].concat(args); actProc.running = true; }

    // Logs are copied to a private runtime file, then opened in the editor
    Process {
        id: logProc
        property string out: ""
        onExited: Quickshell.execDetached([page.doctor, "open", out])
    }
    function openLog(mode) {
        const out = runDir + "/lumen-" + mode + ".log";
        logProc.out = out;
        logProc.command = [doctor, mode, out];
        logProc.running = true;
    }

    Component.onCompleted: { existsProc.running = true; verify(); }

    // ── Files ──
    Group {
        title: "Configuration files"
        Repeater {
            model: [
                { icon: "folder", title: "Lumen", path: Theme.lumenRoot, desc: "The code — a git checkout; ~/.config/lumen points here" },
                { icon: "code", title: "local.lua", path: Theme.lumenRoot + "/local.lua", desc: "Your Hyprland additions: monitors, keyboard layouts, extra keys", optional: "local.lua" },
                { icon: "terminal", title: "session.env", path: Theme.lumenRoot + "/session.env", desc: "Environment for the session, e.g. LUMEN_DGPU=off", optional: "session.env" },
                { icon: "data_object", title: "state.json", path: page.stateDir + "/state.json", desc: "Theme, accent, window and idle preferences" },
                { icon: "data_object", title: "shell.json", path: page.stateDir + "/shell.json", desc: "Shell preferences: widgets, Focus, weather, AI, music app…" },
            ]
            delegate: SetRow {
                required property var modelData
                readonly property bool missing: !!modelData.optional && !page.exists[modelData.path]
                icon: modelData.icon
                title: modelData.title
                description: (missing ? "Not created yet · " : page.tilde(modelData.path) + " · ") + modelData.desc
                Row {
                    spacing: Theme.space.s2
                    Button {
                        visible: missing
                        icon: "note_add"; text: "Create"
                        onActivated: page.act(["create", modelData.optional], { created: modelData.title + " created from a template", exists: modelData.title + " already exists" })
                    }
                    Button { visible: !missing; text: "Open"; onActivated: page.run(["open", modelData.path]) }
                    Button { visible: !missing && modelData.icon !== "folder"; icon: "folder_open"; text: ""; onActivated: page.run(["reveal", modelData.path]) }
                }
            }
        }
    }

    // ── Health check ──
    Group {
        title: "Check"
        SetRow {
            icon: "fact_check"
            title: page.checking ? "Checking…"
                 : page.checks.some(c => c.state === "error") ? "Something needs fixing"
                 : page.checks.some(c => c.state === "warn") ? "Working, with suggestions" : "Everything looks right"
            description: "Hyprland config, theme contrast, the install link, and the programs Lumen uses. Read-only."
            Button { icon: "refresh"; text: "Verify config"; onActivated: page.verify() }
        }
        Repeater {
            model: page.checks
            delegate: SetRow {
                required property var modelData
                icon: modelData.state === "ok" ? "check_circle" : modelData.state === "warn" ? "warning" : "error"
                title: modelData.title
                description: modelData.detail
                Rectangle {
                    height: 24; radius: 12
                    width: stLbl.implicitWidth + 20
                    color: modelData.state === "ok" ? Theme.withAlpha(Theme.success, 0.16)
                         : modelData.state === "warn" ? Theme.withAlpha(Theme.warning, 0.18) : Theme.withAlpha(Theme.error, 0.18)
                    LText { id: stLbl; anchors.centerIn: parent; role: "caption"
                            color: modelData.state === "ok" ? Theme.success : modelData.state === "warn" ? Theme.warning : Theme.error
                            text: modelData.state === "ok" ? "OK" : modelData.state === "warn" ? "Check" : "Fix" }
                }
            }
        }
    }

    // ── Logs ──
    Group {
        title: "Logs"
        SetRow {
            icon: "article"; title: "Startup"
            description: "What Lumen started at login, and any errors — " + page.tilde(page.runDir) + "/lumen-startup.log"
            Button { text: "Open"; onActivated: page.run(["open", page.runDir + "/lumen-startup.log"]) }
        }
        SetRow {
            icon: "bug_report"; title: "Shell"
            description: "The Lumen shell's log for this session (QML warnings and errors)"
            Button { text: "Open"; onActivated: page.openLog("shell-log") }
        }
        SetRow {
            icon: "history"; title: "System journal"
            description: "The last 300 lines of your user journal since this boot"
            Button { text: "Open"; onActivated: page.openLog("journal") }
        }
    }

    // ── Reload & reset ──
    property string confirming: ""          // "shell" | "state" — second press resets
    Timer { id: confirmTimer; interval: 4000; onTriggered: page.confirming = "" }
    function reset(which) {
        if (confirming !== which) { confirming = which; confirmTimer.restart(); return; }
        confirming = "";
        act(["reset", which], { moved: (which === "shell" ? "shell.json" : "state.json") + " moved aside — defaults are back. Rename the .bak file to undo.", nothing: "Already at defaults" });
        if (which === "state") Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "rebuild"]);
    }
    Group {
        title: "Reload & reset"
        SetRow {
            icon: "restart_alt"; title: "Reload Lumen"
            description: "Re-reads the Hyprland config and restarts the shell's interface. Windows stay open."
            Button { text: "Reload"; onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "reload"]) }
        }
        SetRow {
            icon: "palette"; title: "Rebuild theme"
            description: "Regenerates colours and app themes (Hyprland, kitty, Qt/KDE apps) from the tokens"
            Button { text: "Rebuild"; onActivated: { Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "rebuild"]); page.note = "Theme rebuilt — new app windows use it"; } }
        }
        SetRow {
            icon: "settings_backup_restore"; title: "Reset shell preferences"
            description: "Widgets, Focus schedules, weather, AI and music choices go back to defaults. The old file is kept as shell.json.bak-…"
            Button { text: page.confirming === "shell" ? "Press again to reset" : "Reset…"; primary: page.confirming === "shell"; onActivated: page.reset("shell") }
        }
        SetRow {
            icon: "settings_backup_restore"; title: "Reset appearance & windows"
            description: "Theme, accent, gaps, corners and idle timings back to defaults. The old file is kept as state.json.bak-…"
            Button { text: page.confirming === "state" ? "Press again to reset" : "Reset…"; primary: page.confirming === "state"; onActivated: page.reset("state") }
        }
        SetRow { visible: page.note !== ""; icon: "info"; title: page.note }
    }

    // ── Developer ──
    Group {
        title: "Developer"
        SetRow {
            icon: "commit"; title: "Version"
            description: page.version === "" ? "…" : page.version + (page.version.endsWith("-dirty") ? " · with local changes" : "")
        }
        SetRow {
            icon: "code"; title: "Developer mode"
            description: Quickshell.env("LUMEN_DEV") === "1" ? "On — the shell reloads when its files change, and test hooks are available"
                       : "Off — on automatically in a test session"
        }
        SetRow {
            icon: "science"; title: "Test session"
            description: "Runs a second Lumen in a window, with live reload. Safe: it doesn't touch this session, its idle or its portals."
            Button { text: "Start"; onActivated: Quickshell.execDetached(["kitty", "--title", "Lumen test session", "-e", Theme.lumenRoot + "/bin/lumen-session"]) }
        }
    }
}
