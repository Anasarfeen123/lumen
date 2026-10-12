// Services: your user services (start · stop · restart, memory, state) and,
// read-only, the system services that are running now.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: view
    property string query: ""
    property string scope: "user"
    property string state: "active"          // "active" | "all"
    Component.onCompleted: SystemMonitor.loadServices()
    Timer { interval: 5000; repeat: true; running: true; onTriggered: SystemMonitor.loadServices() }
    readonly property var items: {
        const q = query.trim().toLowerCase();
        return (SystemMonitor.services[scope] ?? [])
            .filter(u => scope === "system" || state === "all" || u.active !== "inactive")
            .filter(u => !q || (u.id + " " + u.desc).toLowerCase().includes(q));
    }

    Row {
        id: bar
        x: Theme.space.s5
        spacing: Theme.space.s3
        Segmented {
            width: 220
            options: [{ id: "user", label: "Yours" }, { id: "system", label: "System" }]
            current: view.scope
            onPicked: id => view.scope = id
        }
        Segmented {
            visible: view.scope === "user"
            width: 200
            options: [{ id: "active", label: "Running" }, { id: "all", label: "All" }]
            current: view.state
            onPicked: id => view.state = id
        }
        LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                text: view.items.length + " services" + (view.scope === "system" ? " running · managing them needs administrator rights" : "") }
    }
    ListView {
        anchors { top: bar.bottom; topMargin: Theme.space.s3; bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s4 }
        clip: true; spacing: 3
        model: view.items
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { width: 10; padding: 2; background: null
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.25) } }
        delegate: HoverTarget {
            id: u
            required property var modelData
            readonly property bool running: modelData.active === "active"
            readonly property bool failed: modelData.active === "failed"
            width: ListView.view.width; height: 50; radius: Theme.radius.sm
            Rectangle { anchors.fill: parent; radius: parent.radius; z: -1; color: u.containsMouse ? Theme.withAlpha(Theme.text, 0.04) : "transparent" }
            Rectangle { x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter; width: 8; height: 8; radius: 4
                        color: u.failed ? Theme.error : u.running ? Theme.success : Theme.withAlpha(Theme.text, 0.25) }
            Column {
                anchors { left: parent.left; leftMargin: Theme.space.s3 + 20; right: ctl.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: u.modelData.desc || u.modelData.id }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: u.failed ? Theme.error : Theme.textMuted
                        text: u.modelData.id + " · " + u.modelData.sub + (u.modelData.memory ? " · " + SystemMonitor.bytes(u.modelData.memory) : "") + (u.modelData.pid ? " · PID " + u.modelData.pid : "") }
            }
            Row {
                id: ctl
                visible: view.scope === "user"
                anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                spacing: 2
                IconButton { icon: "play_arrow"; visible: !u.running; tone: Theme.success; onActivated: SystemMonitor.service(u.modelData.id, "start") }
                IconButton { icon: "restart_alt"; visible: u.running || u.failed; onActivated: SystemMonitor.service(u.modelData.id, "restart") }
                IconButton { icon: "stop"; visible: u.running; tone: Theme.error; onActivated: SystemMonitor.service(u.modelData.id, "stop") }
            }
        }
    }
}
