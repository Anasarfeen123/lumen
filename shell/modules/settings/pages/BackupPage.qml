// Backup & recovery: your files (rsync snapshots onto a drive or folder, via
// scripts/backup.sh) and Lumen itself (settings backups, safe mode, theme
// reset, via scripts/recovery.sh). Nothing here deletes: restores copy into
// new folders or save your current settings first; resets move things aside.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Backup & recovery"
    subtitle: "Snapshots of your files on a drive you choose, and a way back for Lumen itself. Restores never overwrite anything."

    readonly property string backup: Theme.lumenRoot + "/scripts/backup.sh"
    readonly property string recovery: Theme.lumenRoot + "/scripts/recovery.sh"
    readonly property string home: Quickshell.env("HOME")
    function tilde(p) { return (p ?? "").replace(home, "~"); }
    function ago(t) {
        if (!t) return "never";
        const s = Date.now() / 1000 - t;
        return s < 90 ? "just now" : s < 3600 ? Math.round(s / 60) + " min ago" : s < 86400 ? Math.round(s / 3600) + " h ago" : Math.round(s / 86400) + " days ago";
    }
    function gb(b) { return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : Math.max(1, Math.round(b / 1e6)) + " MB"; }
    function snapLabel(s) { const m = s.match(/^(\d{4})-(\d\d)-(\d\d)_(\d\d)(\d\d)/); return m ? Qt.formatDateTime(new Date(+m[1], m[2] - 1, +m[3], +m[4], +m[5]), "ddd d MMM yyyy, hh:mm") : s; }

    // ── state ──
    property var st: ({})
    property var drives: []
    property var configs: []
    property string safe: "off"
    property string note: ""
    function refresh() { statusProc.running = true; drivesProc.running = true; configsProc.running = true; safeProc.running = true; cloudProc.running = true; }

    // ── cloud (scripts/cloud-backup.sh, through rclone) ──
    readonly property string cloudScript: Theme.lumenRoot + "/scripts/cloud-backup.sh"
    property var cloud: ({ installed: false, remotes: [], cloud: {} })
    property string cloudMsg: ""
    property int cloudPct: -1
    Process { id: cloudProc; command: [page.cloudScript, "status"]; stdout: StdioCollector { onStreamFinished: { try { page.cloud = JSON.parse(text); } catch (e) {} } } }
    Process {
        id: cloudRun
        command: [page.cloudScript, "run"]
        stdout: SplitParser { onRead: line => { let d; try { d = JSON.parse(line); } catch (e) { return; } if (d.e) page.cloudMsg = d.e; else { page.cloudPct = d.p; page.cloudMsg = d.st === "done" ? "Backed up" : "Copying " + d.st; } } }
        onExited: { page.cloudPct = -1; page.refresh(); }
    }
    Timer { interval: 4000; repeat: true; running: page.visible && !page.cloud.installed; onTriggered: cloudProc.running = true }
    Component.onCompleted: refresh()

    Process { id: statusProc; command: [page.backup, "status"]; stdout: StdioCollector { onStreamFinished: { try { page.st = JSON.parse(text); } catch (e) {} } } }
    Process {
        id: drivesProc
        command: ["lsblk", "-J", "-o", "NAME,LABEL,MOUNTPOINT,SIZE,HOTPLUG,FSTYPE"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const walk = (d, hot) => { const h = hot || d.hotplug; if (h && d.mountpoint && d.fstype) out.push({ label: d.label || d.name, path: d.mountpoint, size: d.size }); (d.children ?? []).forEach(c => walk(c, h)); };
                try { JSON.parse(text).blockdevices.forEach(d => walk(d, false)); } catch (e) {}
                page.drives = out;
            }
        }
    }
    Process { id: configsProc; command: [page.recovery, "config-list"]; stdout: StdioCollector { onStreamFinished: { try { page.configs = JSON.parse(text); } catch (e) {} } } }
    Process { id: safeProc; command: [page.recovery, "safe", "status"]; stdout: StdioCollector { onStreamFinished: page.safe = text.trim() } }

    // One-shot commands: show their message (or error), then refresh
    Process {
        id: act
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); let d; try { d = JSON.parse(t); } catch (e) {} page.note = d?.e ?? (d?.path ? "Restored to " + page.tilde(d.path) : act.msg || t); page.refresh(); } }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.note = text.trim() }
        property string msg: ""
    }
    function run(args, msg) { act.msg = msg ?? ""; act.command = args; act.running = true; }

    // Folder chooser: KDE's dialog, else GTK's
    Process {
        id: pick
        property var then: null
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p && pick.then) pick.then(p); } }
    }
    function chooseFolder(start, then) {
        pick.then = then;
        pick.command = ["sh", "-c", 'if command -v kdialog >/dev/null; then kdialog --title "$2" --getexistingdirectory "$1"; else zenity --file-selection --directory --title="$2" --filename="$1/"; fi 2>/dev/null', "sh", start, "Choose a folder"];
        pick.running = true;
    }

    // Back up now, with progress
    property int pct: -1
    property bool running: runProc.running
    Process {
        id: runProc
        command: [page.backup, "run"]
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.e) page.note = d.e;
                if (d.p !== undefined) page.pct = d.p;
                if (d.snapshot) page.note = "Backed up: " + page.snapLabel(d.snapshot);
            }
        }
        onExited: { page.pct = -1; page.refresh(); }
    }

    // Two-step confirmations
    property string confirming: ""
    Timer { id: confirmTimer; interval: 4000; onTriggered: page.confirming = "" }
    function confirm(key) { if (confirming === key) { confirming = ""; return true; } confirming = key; confirmTimer.restart(); return false; }

    // ── Files ──
    Group {
        title: "Your files"
        SetRow {
            icon: "backup"
            title: "Back up to"
            description: !page.st.dest ? "Choose a drive or folder. A USB drive is best: keep it somewhere else from your laptop."
                       : page.tilde(page.st.dest) + (page.st.destOk ? " · " + page.gb(page.st.free) + " free" + (["msdos", "vfat", "exfat", "fuseblk"].includes(page.st.fs) ? " · this drive can't share unchanged files between snapshots, so each one is a full copy" : "")
                                                 : " · " + page.st.destProblem)
            Button { text: "Choose…"; onActivated: page.chooseFolder(page.st.dest || "/run/media/" + Quickshell.env("USER"), p => page.run([page.backup, "set-dest", p], "Backups go to " + page.tilde(p))) }
        }
        Repeater {
            model: page.drives.filter(d => d.path !== page.st.dest)
            delegate: SetRow {
                required property var modelData
                icon: "hard_drive"
                title: modelData.label + " · " + modelData.size
                description: "Plugged in at " + modelData.path
                Button { text: "Use this drive"; onActivated: page.run([page.backup, "set-dest", modelData.path], "Backups go to " + modelData.label) }
            }
        }
        SetRow {
            icon: page.st.last?.ok === false ? "error" : "history"
            title: page.running ? "Backing up…" + (page.pct >= 0 ? " " + page.pct + "%" : "")
                 : "Last backup: " + page.ago(page.st.last?.time)
            description: page.running ? "You can keep working; the island shows progress."
                       : page.st.last?.ok === false ? "The last attempt failed — details in ~/.local/state/lumen/backup.err"
                       : page.st.last?.snapshot ? page.gb(page.st.last.size) + " of files · snapshot " + page.snapLabel(page.st.last.snapshot)
                       : "Only changed files are copied after the first time."
            Button { text: page.running ? "Running…" : "Back up now"; enabled: !page.running && page.st.destOk === true; primary: enabled; opacity: enabled ? 1 : 0.45; onActivated: runProc.running = true }
        }
        SetRow {
            icon: "event_repeat"
            title: "Every day"
            description: "Backs up once a day when the drive is plugged in (a systemd timer). Skipped quietly when it isn't."
            LSwitch { checked: page.st.timer === true; onToggled: page.run([page.backup, "timer", checked ? "off" : "on"], checked ? "Daily backup off" : "Daily backup on") }
        }
        SetRow {
            icon: "inventory_2"
            title: "Keep"
            description: "Older snapshots go to the drive's trash, not straight to deletion."
            Segmented {
                width: 300
                options: [{ id: "10", label: "10" }, { id: "30", label: "30" }, { id: "100", label: "100" }, { id: "0", label: "All" }]
                current: String(page.st.keep ?? 30)
                onPicked: id => page.run([page.backup, "set-keep", id])
            }
        }
    }

    Group {
        title: "Cloud"
        SetRow {
            visible: !page.cloud.installed
            icon: "cloud_off"
            title: "Back up to Google Drive, OneDrive, Dropbox…"
            description: "Lumen uses rclone, from Fedora's own repositories. Install it once in a terminal (you'll be asked for your password): sudo dnf install rclone"
            Button { primary: true; text: "Open a terminal"; onActivated: Quickshell.execDetached(["kitty", "--title", "Install rclone", "sh", "-c", "echo 'Installing rclone (cloud backups) from Fedora'\''s repositories:'; echo; sudo dnf install rclone; echo; echo 'Done — close this and go back to Settings.'; read -r _"]) }
        }
        SetRow {
            visible: page.cloud.installed
            icon: (page.cloud.cloud?.remote ?? "") !== "" ? "cloud_done" : "cloud_upload"
            title: (page.cloud.cloud?.remote ?? "") !== "" ? "Backing up to " + page.cloud.cloud.remote.replace(/:$/, "") : "Choose a cloud"
            description: (page.cloud.remotes ?? []).length === 0
                ? "No cloud set up yet. Set one up: you'll sign in in your browser, and rclone keeps the access on this computer."
                : (page.cloud.cloud?.remote ?? "") !== ""
                    ? ((page.cloud.remotes.find(r => r.name + ":" === page.cloud.cloud.remote)?.encrypted ? "Encrypted before it leaves · " : "Not encrypted (add a crypt remote to encrypt) · ")
                       + "“" + (page.cloud.cloud.folder ?? "") + "” · copies only what changed, never deletes in the cloud")
                    : "Pick one below. A “crypt” remote encrypts names and contents before upload."
            Button { text: "Set up a cloud…"; onActivated: Quickshell.execDetached([page.cloudScript, "setup"]) }
        }
        Repeater {
            model: page.cloud.installed ? (page.cloud.remotes ?? []) : []
            delegate: SetRow {
                required property var modelData
                readonly property bool chosen: (page.cloud.cloud?.remote ?? "") === modelData.name + ":"
                icon: modelData.encrypted ? "lock" : "cloud"
                title: modelData.name + (modelData.encrypted ? " · encrypted" : "")
                description: ({ drive: "Google Drive", onedrive: "OneDrive", dropbox: "Dropbox", s3: "S3", webdav: "WebDAV / Nextcloud", crypt: "Encrypted (on top of another remote)", sftp: "SFTP", b2: "Backblaze B2" })[modelData.type] ?? modelData.type
                Button { text: chosen ? "In use" : "Use"; primary: chosen; onActivated: if (!chosen) page.run([page.cloudScript, "set", modelData.name + ":"], "Cloud backups go to " + modelData.name) }
            }
        }
        SetRow {
            visible: page.cloud.installed && (page.cloud.cloud?.remote ?? "") !== ""
            icon: "backup"
            title: page.cloudPct >= 0 ? "Backing up · " + page.cloudPct + "%" : "Back up to the cloud now"
            description: page.cloudMsg !== "" ? page.cloudMsg
                : page.cloud.cloud?.last ? "Last: " + page.ago(page.cloud.cloud.last.time) + (page.cloud.cloud.last.ok ? "" : " · had problems") : "Never backed up yet"
            Button { primary: true; enabled: !cloudRun.running; text: cloudRun.running ? "Backing up…" : "Back up now"; onActivated: { page.cloudMsg = ""; cloudRun.running = true; } }
        }
        SetRow {
            visible: page.cloud.installed && (page.cloud.cloud?.remote ?? "") !== ""
            icon: "settings_backup_restore"
            title: "Restore a folder from the cloud"
            description: "Copies it into ~/Restored/cloud-<date>/ — never over your files"
            Button { text: "Choose…"; onActivated: page.chooseFolder(page.home, p => page.run([page.cloudScript, "restore", p.replace(page.home + "/", "")], "")) }
        }
    }

    Group {
        title: "Folders"
        Repeater {
            model: page.st.folders ?? []
            delegate: SetRow {
                required property string modelData
                icon: "folder"
                title: page.tilde(modelData)
                description: "Included in every backup"
                Button { text: "Remove"; onActivated: page.run([page.backup, "remove-folder", modelData]) }
            }
        }
        SetRow {
            icon: "create_new_folder"
            title: "Add a folder"
            description: "Skipped inside every folder: " + (page.st.exclude ?? []).join(", ")
            Button { text: "Add…"; onActivated: page.chooseFolder(page.home, p => page.run([page.backup, "add-folder", p])) }
        }
    }

    Group {
        title: "Snapshots"
        visible: (page.st.snapshots ?? []).length > 0
        Repeater {
            model: (page.st.snapshots ?? []).slice().reverse().slice(0, 6)
            delegate: SetRow {
                required property string modelData
                icon: "photo_library"
                title: page.snapLabel(modelData)
                description: "Open it like any folder, or bring a folder back as a copy in ~/Restored"
                Row {
                    spacing: Theme.space.s2
                    Button { text: "Open"; onActivated: Quickshell.execDetached([page.backup, "open", modelData]) }
                    Button {
                        text: "Restore a folder…"
                        onActivated: page.chooseFolder(page.st.root + "/" + modelData, p => {
                            const base = page.st.root + "/" + modelData + "/";
                            if (!p.startsWith(base)) { page.note = "Pick a folder inside that snapshot."; return; }
                            page.run([page.backup, "restore", modelData, p.slice(base.length)]);
                        })
                    }
                }
            }
        }
        SetRow {
            visible: (page.st.snapshots ?? []).length > 6
            icon: "folder_open"; title: "All " + (page.st.snapshots ?? []).length + " snapshots"
            Button { text: "Open"; onActivated: Quickshell.execDetached([page.backup, "open"]) }
        }
    }

    // ── Lumen ──
    Group {
        title: "Lumen's settings"
        SetRow {
            icon: "settings_backup_restore"
            title: "Settings backups"
            description: "Theme, shell preferences, planner, notes, snapshots and your local.lua — saved automatically once a day at login. The last 20 are kept."
            Button { text: "Back up now"; onActivated: page.run([page.recovery, "config-backup"], "Lumen's settings saved") }
        }
        Repeater {
            model: page.configs.slice(0, 5)
            delegate: SetRow {
                required property var modelData
                icon: "history"
                title: Qt.formatDateTime(new Date(modelData.time * 1000), "ddd d MMM, hh:mm")
                description: "Lumen " + modelData.commit + " · " + Math.max(1, Math.round(modelData.size / 1024)) + " KB"
                Button {
                    text: page.confirming === modelData.file ? "Press again to restore" : "Restore"
                    primary: page.confirming === modelData.file
                    onActivated: if (page.confirm(modelData.file)) page.run([page.recovery, "config-restore", modelData.file])
                }
            }
        }
    }

    Group {
        title: "Recovery"
        SetRow {
            icon: "health_and_safety"
            title: "Safe mode at next login"
            description: page.safe === "on" ? "On — the next login starts without the Lumen shell: a terminal with the recovery menu. Only once."
                                            : "Starts one login without the shell, with a terminal and the recovery menu. Useful if the desktop won't come up."
            LSwitch { checked: page.safe === "on"; onToggled: page.run([page.recovery, "safe", checked ? "off" : "on"]) }
        }
        SetRow {
            icon: "terminal"
            title: "Recovery menu"
            description: "The same tools in a terminal. From a TTY (Ctrl+Alt+F3), log in and run: ~/.config/lumen/bin/lumen recovery"
            Button { text: "Open"; onActivated: Quickshell.execDetached(["kitty", "--title", "Lumen Recovery", "-e", Theme.lumenRoot + "/bin/lumen", "recovery"]) }
        }
        SetRow {
            icon: "format_paint"
            title: "Reset the generated theme"
            description: "Moves generated/ aside and rebuilds it from the tokens — for when colours or app themes look broken."
            Button {
                text: page.confirming === "theme" ? "Press again to reset" : "Reset…"
                primary: page.confirming === "theme"
                onActivated: if (page.confirm("theme")) page.run([page.recovery, "reset-theme"], "Theme rebuilt — new windows use it")
            }
        }
        SetRow {
            icon: "fact_check"
            title: "Health check and logs"
            description: "Config errors, contrast, missing programs, and the startup, shell and system logs"
            Button { text: "Open Advanced"; onActivated: SettingsState.page = "advanced" }
        }
        SetRow { visible: page.note !== ""; icon: "info"; title: page.note }
    }
}
