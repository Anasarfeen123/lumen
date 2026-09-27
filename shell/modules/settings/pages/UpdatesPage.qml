// Updates: Lumen itself (from its git remote), then system packages (dnf)
// and Flatpak apps. The shell does the work
// (services/Updates) so closing this window never interrupts an upgrade;
// this page shows its state and sends it "check" / "install".
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Updates"
    subtitle: "Lumen and your system. Nothing installs until you press Update or Install — system packages ask for your password."

    property var st: ({ dnf: [], flatpak: [], count: 0, security: 0, lines: [] })
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-updates.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.st = JSON.parse(text()); } catch (e) {} }
    }
    function call(fn) { Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "updates", fn]); }
    Component.onCompleted: if (!(st.checkedAt > 0)) call("check")

    // ── Lumen itself (scripts/lumen-self-update.sh, run detached: closing
    // Settings never interrupts it; its state file is the source of truth) ──
    property var ls: ({})
    property bool lsLoaded: false
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-self-update.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.ls = JSON.parse(text()); } catch (e) {} page.lsLoaded = true; }
        onLoadFailed: page.lsLoaded = true
    }
    function lumen(mode) { Quickshell.execDetached({ command: [Updates.selfUpdate, mode], environment: { LUMEN_ROOT: Updates.lumenRepo } }); }
    property bool daily: true
    Process {
        running: true
        command: [Updates.selfUpdate, "settings"]
        stdout: StdioCollector { onStreamFinished: { try { page.daily = JSON.parse(text).daily !== false; } catch (e) {} } }
    }
    // Check on open if the last check is older than an hour
    Timer { interval: 400; running: page.lsLoaded; onTriggered: if (!(Date.now() - (page.ls.checkedAt ?? 0) < 3600000) && page.ls.state !== "updating") page.lumen("check") }

    readonly property string lsState: ls.state ?? ""
    readonly property bool lsBusy: lsState === "checking" || lsState === "updating"
    readonly property int behind: ls.behind ?? 0
    function ago(ms) {
        const m = Math.round((Date.now() - ms) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Qt.formatDate(new Date(ms), "d MMM");
    }
    function day(iso) {
        const d = new Date(iso), t = new Date();
        const y = new Date(); y.setDate(t.getDate() - 1);
        return d.toDateString() === t.toDateString() ? "Today" : d.toDateString() === y.toDateString() ? "Yesterday" : Qt.formatDate(d, "dddd, d MMMM");
    }

    Rectangle {
        width: parent.width
        height: lumenCol.implicitHeight + Theme.space.s5 * 2
        radius: Theme.radius.lg
        color: page.behind > 0 || page.lsState === "updated" ? Theme.withAlpha(Theme.accent, 0.10) : Theme.withAlpha(Theme.text, 0.03)
        border.width: 1
        border.color: page.behind > 0 || page.lsState === "updated" ? Theme.withAlpha(Theme.accent, 0.35) : Theme.border
        Column {
            id: lumenCol
            x: Theme.space.s5; y: Theme.space.s5
            width: parent.width - Theme.space.s5 * 2
            spacing: Theme.space.s3
            Item {
                width: parent.width
                height: Math.max(lumenHead.implicitHeight, lumenBtns.implicitHeight)
                Row {
                    id: lumenHead
                    spacing: Theme.space.s4
                    anchors.verticalCenter: parent.verticalCenter
                    LumenLogo { size: 40; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        LText {
                            role: "title"
                            text: page.lsState === "checking" ? "Checking for Lumen updates…"
                                : page.lsState === "updating" ? "Updating Lumen…"
                                : page.lsState === "updated" ? "Lumen is updated"
                                : page.lsState === "offline" ? "Couldn't check"
                                : page.lsState === "error" || page.lsState === "failed" ? "Lumen couldn't update"
                                : page.behind > 0 ? page.behind + (page.behind === 1 ? " change" : " changes") + " to Lumen"
                                : page.lsLoaded && page.ls.current ? "Lumen is up to date" : "Lumen"
                        }
                        LText {
                            role: "caption"; color: Theme.textSecondary
                            text: (page.ls.current ? page.ls.current + (page.ls.date ? " · " + Qt.formatDate(new Date(page.ls.date), "d MMM yyyy") : "") + " · " : "")
                                + (page.ls.branch ? page.ls.branch + " · " : "")
                                + (page.ls.checkedAt ? "checked " + page.ago(page.ls.checkedAt) : "not checked yet")
                        }
                    }
                }
                Row {
                    id: lumenBtns
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s2
                    Button { icon: "refresh"; text: "Check now"; visible: page.lsState !== "updated"; enabled: !page.lsBusy; onActivated: page.lumen("check") }
                    Button {
                        primary: true; icon: "download"; text: "Update"
                        visible: page.behind > 0 && !page.ls.dirty && !page.ls.diverged && page.lsState !== "updated"
                        enabled: !page.lsBusy
                        onActivated: page.lumen("apply")
                    }
                    Button {
                        icon: "inventory_2"; text: "Stash & update"
                        visible: page.behind > 0 && !!page.ls.dirty && !page.ls.diverged && page.lsState !== "updated"
                        enabled: !page.lsBusy
                        onActivated: page.lumen("stash-apply")
                    }
                    Button { primary: true; icon: "restart_alt"; text: "Reload Lumen now"; visible: page.lsState === "updated"
                             onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "reload"]) }
                }
            }

            // Why it can't update right now
            LText {
                visible: text !== ""
                width: parent.width; wrapMode: Text.Wrap
                color: page.lsState === "offline" ? Theme.textSecondary : Theme.warning
                text: page.ls.error ? page.ls.error
                    : page.behind > 0 && page.ls.dirty ? "You have changes that aren't committed (" + (page.ls.dirtyFiles ?? []).slice(0, 4).join(", ") + ((page.ls.dirtyFiles ?? []).length > 4 ? "…" : "")
                      + "). Commit them, or use Stash & update: they're set aside with git stash, and you get them back with “git stash pop” in " + Updates.lumenRepo.replace(Quickshell.env("HOME"), "~") + "."
                    : page.ls.diverged ? "Your copy has commits GitHub doesn't, and GitHub has new ones. Lumen won't merge or overwrite anything — update by hand with git."
                    : page.lsState === "updated" ? "Updated from " + (page.ls.from ?? "?") + " to " + page.ls.current + ". The theme was rebuilt; reload to use the new version."
                    : ""
            }

            // What changed, newest first, grouped by day
            Column {
                visible: page.behind > 0 && page.lsState !== "updated"
                width: parent.width
                spacing: 2
                Repeater {
                    model: page.ls.changes ?? []
                    delegate: Column {
                        id: ch
                        required property var modelData
                        required property int index
                        readonly property string d: page.day(modelData.date)
                        width: parent.width
                        LText {
                            visible: ch.index === 0 || page.day(page.ls.changes[ch.index - 1].date) !== ch.d
                            topPadding: ch.index === 0 ? 0 : Theme.space.s2
                            bottomPadding: 2
                            role: "caption"; font.weight: Font.DemiBold; color: Theme.textMuted
                            text: ch.d
                        }
                        Row {
                            width: parent.width
                            spacing: Theme.space.s2
                            Rectangle { width: 5; height: 5; radius: 2.5; color: Theme.accent; y: 7 }
                            Column {
                                width: parent.width - 13
                                LText { width: parent.width; wrapMode: Text.Wrap; text: ch.modelData.subject }
                                LText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: ch.modelData.body ?? "" }
                            }
                        }
                    }
                }
                LText {
                    visible: page.behind > (page.ls.changes ?? []).length
                    role: "caption"; color: Theme.textMuted
                    text: "…and " + (page.behind - (page.ls.changes ?? []).length) + " more"
                }
            }

            Item {
                width: parent.width; height: dailyRow.implicitHeight
                Row {
                    id: dailyRow
                    spacing: Theme.space.s3
                    LSwitch { checked: page.daily; onToggled: { page.daily = !checked; Quickshell.execDetached([Updates.selfUpdate, "set", "daily", page.daily ? "on" : "off"]); } }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textSecondary
                            text: "Check for Lumen updates daily · from " + (page.ls.remote ?? "its git remote").replace(/^https:\/\//, "") }
                }
            }
        }
    }

    // ── Summary ──
    Rectangle {
        width: parent.width
        height: 96
        radius: Theme.radius.lg
        color: page.st.count > 0 ? Theme.withAlpha(Theme.accent, 0.10) : Theme.withAlpha(Theme.success, 0.08)
        border.width: 1
        border.color: page.st.count > 0 ? Theme.withAlpha(Theme.accent, 0.35) : Theme.withAlpha(Theme.success, 0.3)
        Row {
            anchors { left: parent.left; leftMargin: Theme.space.s5; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s4
            LIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: page.st.checking ? "progress_activity" : page.st.installing ? "downloading" : page.st.count > 0 ? "system_update" : "task_alt"
                size: 40; fill: 1
                color: page.st.count > 0 || page.st.installing ? Theme.accent : Theme.success
                RotationAnimation on rotation { running: page.st.checking ?? false; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                LText {
                    role: "title"
                    text: page.st.checking ? "Checking…"
                        : page.st.installing ? (page.st.phase === "apps" ? "Updating apps…" : "Updating the system…")
                        : page.st.count > 0 ? page.st.count + (page.st.count === 1 ? " system update" : " system updates") + " available"
                        : page.st.checkedAt > 0 ? "System is up to date" : "System & apps"
                }
                LText {
                    role: "caption"; color: Theme.textSecondary
                    text: (page.st.security > 0 ? page.st.security + " security · " : "")
                        + (page.st.reboot ? "needs a restart · " : "")
                        + (page.st.checkedAt > 0 ? "checked " + Qt.formatTime(new Date(page.st.checkedAt), Theme.timeFormatFull) : "not checked yet")
                }
            }
        }
        Row {
            anchors { right: parent.right; rightMargin: Theme.space.s5; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s2
            Button { icon: "refresh"; text: "Check now"; enabled: !page.st.checking && !page.st.installing; onActivated: page.call("check") }
            Button { primary: true; icon: "download"; text: "Install all"; visible: page.st.count > 0; enabled: !page.st.installing; onActivated: page.call("install") }
        }
    }

    LText { visible: (page.st.error ?? "") !== ""; color: Theme.error; text: page.st.error ?? "" }

    // ── Progress log while installing ──
    Rectangle {
        visible: page.st.installing || ((page.st.lines ?? []).length > 0 && page.st.phase === "failed")
        width: parent.width
        height: logText.implicitHeight + Theme.space.s3 * 2
        radius: Theme.radius.md
        color: Theme.withAlpha("black", 0.25)
        border.width: 1; border.color: Theme.border
        Text {
            id: logText
            x: Theme.space.s3; y: Theme.space.s3
            width: parent.width - Theme.space.s3 * 2
            text: (page.st.lines ?? []).join("\n")
            color: Theme.textSecondary
            font.family: Theme.fontMono
            font.pixelSize: 11
            wrapMode: Text.WrapAnywhere
        }
    }

    Group {
        title: "System packages" + (page.st.dnf.length ? " · " + page.st.dnf.length : "")
        visible: page.st.dnf.length > 0
        Repeater {
            model: page.st.dnf
            delegate: SetRow {
                required property var modelData
                minHeight: 44
                icon: modelData.security ? "security" : "deployed_code"
                title: modelData.name
                description: modelData.version + "  ·  " + modelData.repo
                Rectangle {
                    visible: modelData.security
                    height: 22; width: secLbl.implicitWidth + 16; radius: 11
                    color: Theme.withAlpha(Theme.warning, 0.18)
                    LText { id: secLbl; anchors.centerIn: parent; role: "caption"; color: Theme.warning; text: "Security" }
                }
            }
        }
    }
    Group {
        title: "Apps (Flatpak)" + (page.st.flatpak.length ? " · " + page.st.flatpak.length : "")
        visible: page.st.flatpak.length > 0
        Repeater {
            model: page.st.flatpak
            delegate: SetRow {
                required property var modelData
                minHeight: 44
                icon: "apps"
                title: modelData.name
                description: modelData.id + (modelData.version ? "  ·  " + modelData.version : "")
            }
        }
    }
}
