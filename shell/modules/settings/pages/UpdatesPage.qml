// Updates: system packages (dnf) and Flatpak apps. The shell does the work
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
    subtitle: "Checked every few hours. Nothing installs until you press Install — system packages ask for your password."

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
                        : page.st.count > 0 ? page.st.count + (page.st.count === 1 ? " update" : " updates") + " available"
                        : "You're up to date"
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
