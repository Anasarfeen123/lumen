// Security: a read-only check-up of this computer, in plain words, with the
// fix for anything that needs attention. Nothing here changes your system;
// scripts/security-check.sh gathers it (no root).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Security"
    subtitle: "A quick check-up. Green is fine; amber has a suggestion."

    property var items: []
    property var updates: ({ count: 0, security: 0 })
    Process {
        id: check
        command: [Theme.lumenRoot + "/scripts/security-check.sh"]
        stdout: StdioCollector { onStreamFinished: { try { page.items = JSON.parse(text); } catch (e) {} } }
    }
    FileView {
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-updates.json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: { try { page.updates = JSON.parse(text()); } catch (e) {} }
    }
    Component.onCompleted: check.running = true

    readonly property var names: ({ firewall: "Firewall", ssh: "Remote login (SSH)", secureboot: "Secure Boot",
                                    encryption: "Disk encryption", selinux: "App confinement", logins: "Failed logins", firmware: "Firmware updates" })
    readonly property var icons: ({ firewall: "local_fire_department", ssh: "lan", secureboot: "verified_user",
                                    encryption: "lock", selinux: "policy", logins: "person_alert", firmware: "memory" })
    readonly property int warnings: items.filter(i => i.state === "warn").length + (updates.security > 0 ? 1 : 0)

    // Summary
    Rectangle {
        width: parent.width
        height: 88
        radius: Theme.radius.lg
        readonly property bool ok: page.warnings === 0
        color: ok ? Theme.withAlpha(Theme.success, 0.08) : Theme.withAlpha(Theme.warning, 0.08)
        border.width: 1; border.color: ok ? Theme.withAlpha(Theme.success, 0.3) : Theme.withAlpha(Theme.warning, 0.3)
        Row {
            anchors { left: parent.left; leftMargin: Theme.space.s5; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s4
            LIcon { icon: parent.parent.ok ? "verified_user" : "shield"; size: 38; fill: 1
                    color: parent.parent.ok ? Theme.success : Theme.warning; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                LText { role: "title"; text: page.items.length === 0 ? "Checking…" : parent.parent.parent.ok ? "Looking good" : page.warnings + (page.warnings === 1 ? " suggestion" : " suggestions") }
                LText { role: "caption"; color: Theme.textSecondary; text: "Checked just now · read-only" }
            }
        }
        Button { anchors { right: parent.right; rightMargin: Theme.space.s5; verticalCenter: parent.verticalCenter }
                 icon: "refresh"; text: "Check again"; onActivated: check.running = true }
    }

    Group {
        title: "This computer"
        Repeater {
            model: page.items
            delegate: SetRow {
                required property var modelData
                icon: page.icons[modelData.id] ?? "shield"
                title: page.names[modelData.id] ?? modelData.id
                description: modelData.hint
                Rectangle {
                    height: 24; radius: 12
                    width: stLbl.implicitWidth + 20
                    color: modelData.state === "good" ? Theme.withAlpha(Theme.success, 0.16)
                         : modelData.state === "warn" ? Theme.withAlpha(Theme.warning, 0.18) : Theme.withAlpha(Theme.text, 0.07)
                    LText { id: stLbl; anchors.centerIn: parent; role: "caption"
                            color: modelData.state === "good" ? Theme.success : modelData.state === "warn" ? Theme.warning : Theme.textSecondary
                            text: modelData.value }
                }
            }
        }
        SetRow {
            icon: "system_update"
            title: "Updates"
            description: (page.updates.count ?? 0) === 0 ? "Up to date" : "Install from Settings → Updates"
            Button { text: (page.updates.count ?? 0) === 0 ? "Open" : (page.updates.count + (page.updates.security > 0 ? " · " + page.updates.security + " security" : "") ); onActivated: SettingsState.page = "updates" }
        }
    }

    Group {
        title: "Lumen"
        SetRow { icon: "lock"; title: "Screen lock"; description: "After " + ((Theme.tokens.idle ?? {}).lock === "never" ? "— (never on its own)" : ((Theme.tokens.idle ?? {}).lock ?? "5") + " minutes idle, and always before sleep")
                 Button { text: "Change"; onActivated: SettingsState.page = "power" } }
        SetRow { icon: "face"; title: "Face ID"; description: "Unlocks the lock screen only — never sudo, logins or admin prompts. Your password always works." }
        SetRow { icon: "admin_panel_settings"; title: "Admin prompts"; description: "Drawn by Lumen, checked by polkit; each shows exactly what's being allowed" }
        SetRow { icon: "notifications"; title: "Notifications on the lock screen"; description: "A count and app names only — never what they say" }
        SetRow { icon: "auto_awesome"; title: "AI"; description: Ai.provider === "off" ? "Off — nothing is sent anywhere" : Ai.provider === "ollama" ? "Local (Ollama) — nothing leaves this computer" : "Claude — only what you send, when you press Enter" }
    }
}
