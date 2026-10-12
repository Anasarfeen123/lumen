// Startup: what starts when you log in — desktop autostart entries
// (~/.config/autostart, /etc/xdg/autostart) and your enabled user services —
// each with a switch. Turning a system-wide entry off writes a per-user
// override (Hidden=true); nothing system-wide is touched.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: view
    property string query: ""
    Component.onCompleted: SystemMonitor.loadStartup()
    readonly property var items: SystemMonitor.startup.filter(i => !query.trim() || (i.name + " " + i.comment + " " + i.id).toLowerCase().includes(query.trim().toLowerCase()))

    LText {
        id: intro
        x: Theme.space.s5
        width: parent.width - Theme.space.s5 * 2; wrapMode: Text.Wrap
        role: "caption"; color: Theme.textMuted
        text: SystemMonitor.startup.filter(i => i.enabled).length + " of " + SystemMonitor.startup.length + " start when you log in. Turning one off only affects your account; Lumen's own parts aren't listed."
    }
    ListView {
        anchors { top: intro.bottom; topMargin: Theme.space.s3; bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s4 }
        clip: true; spacing: 4
        model: view.items
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { width: 10; padding: 2; background: null
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.25) } }
        section.property: "kind"
        section.delegate: LText {
            required property string section
            x: Theme.space.s2; height: 32; verticalAlignment: Text.AlignBottom; bottomPadding: 6
            role: "caption"; color: Theme.textMuted; font.letterSpacing: 1
            text: section === "autostart" ? "APPS" : "USER SERVICES"
        }
        delegate: Rectangle {
            id: it
            required property var modelData
            width: ListView.view.width; height: 58; radius: Theme.radius.md
            color: Theme.withAlpha(Theme.surfaceElevated, 0.6); border.width: 1; border.color: Theme.border
            readonly property string iconPath: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
            Image { id: ic; x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; sourceSize: Qt.size(56, 56)
                    source: it.iconPath; visible: status === Image.Ready; asynchronous: true }
            LIcon { visible: ic.status !== Image.Ready; x: Theme.space.s3 + 4; anchors.verticalCenter: parent.verticalCenter
                    icon: it.modelData.kind === "service" ? "settings_applications" : "apps"; size: 20; color: Theme.textMuted }
            Column {
                anchors { left: parent.left; leftMargin: Theme.space.s3 + 40; right: sw.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: it.modelData.name }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                        text: (it.modelData.comment && it.modelData.comment !== it.modelData.name ? it.modelData.comment + " · " : "") + (it.modelData.kind === "service" ? it.modelData.id : it.modelData.exec) }
            }
            LSwitch { id: sw; anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                      checked: it.modelData.enabled; onToggled: SystemMonitor.setStartup(it.modelData, !checked) }
        }
    }
}
