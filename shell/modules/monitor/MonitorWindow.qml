// Lumen Monitor — the window (Ctrl+Shift+Esc). A rail of views on the left
// (Processes · Performance · Startup · Services), the view on the right, and
// one header: search (Processes), how often to sample, pause.
//   Ctrl+1…4 views · Ctrl+F search · Space pause · Ctrl+W close
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

FloatingWindow {
    id: win
    title: "Lumen Monitor"
    implicitWidth: 1180
    implicitHeight: 760
    minimumSize: Qt.size(860, 560)
    color: Theme.withAlpha(Theme.bg, 0.9)

    property string tab: "processes"
    property string resource: ""            // Performance: which one to show first
    function go(where) {
        const [t, r] = String(where || "processes").split("/");
        if (tabs.some(x => x.id === t)) tab = t;
        resource = r ?? "";
    }
    readonly property var tabs: [
        { id: "processes",   icon: "list_alt",       label: "Processes" },
        { id: "performance", icon: "monitoring",     label: "Performance" },
        { id: "startup",     icon: "rocket_launch",  label: "Startup" },
        { id: "services",    icon: "settings_applications", label: "Services" },
    ]
    Component.onCompleted: { SystemMonitor.active = true; go(Quickshell.env("LUMEN_MONITOR_TAB") || "processes"); }
    property bool shownOnce: false
    onVisibleChanged: { if (visible) shownOnce = true; else if (shownOnce) { SystemMonitor.active = false; Qt.quit(); } }

    // A short line at the bottom after an action
    property string toast: ""
    property bool toastBad: false
    Connections {
        target: SystemMonitor
        function onActed(ok, message) { if (!message) return; win.toast = message; win.toastBad = !ok; toastTimer.restart(); }
    }
    Timer { id: toastTimer; interval: 3200; onTriggered: win.toast = "" }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (ctrl && e.key >= Qt.Key_1 && e.key <= Qt.Key_4) win.tab = win.tabs[e.key - Qt.Key_1].id;
            else if (ctrl && e.key === Qt.Key_W) win.visible = false;
            else if (ctrl && e.key === Qt.Key_F) { win.tab = "processes"; search.input.forceActiveFocus(); }
            else if (e.key === Qt.Key_Space && !search.input.activeFocus) SystemMonitor.paused = !SystemMonitor.paused;
            else return;
            e.accepted = true;
        }

        // ── rail ──
        Rectangle {
            id: rail
            width: 210
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Theme.withAlpha(Theme.surface, 0.55)
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Theme.border }
            Column {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s3; topMargin: Theme.space.s5 }
                spacing: 2
                Row {
                    leftPadding: Theme.space.s2; bottomPadding: Theme.space.s4
                    spacing: Theme.space.s2
                    LIcon { icon: "monitor_heart"; size: 24; color: Theme.accent; fill: 1; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "heading"; text: "Monitor"; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                    model: win.tabs
                    delegate: HoverTarget {
                        required property var modelData
                        required property int index
                        readonly property bool on: win.tab === modelData.id
                        width: parent.width; height: 40; radius: Theme.radius.sm
                        onClicked: win.tab = modelData.id
                        Rectangle { anchors.fill: parent; radius: parent.radius; z: -1; color: parent.on ? Theme.withAlpha(Theme.accent, 0.14) : "transparent" }
                        Rectangle { visible: parent.on; width: 3; height: 18; radius: 1.5; color: Theme.accent; anchors { left: parent.left; verticalCenter: parent.verticalCenter } }
                        Row {
                            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s3
                            LIcon { icon: modelData.icon; size: 18; color: parent.parent.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: parent.parent.on ? "bodyStrong" : "body"; text: modelData.label; anchors.verticalCenter: parent.verticalCenter }
                        }
                        LText { anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                                role: "caption"; color: Theme.textMuted; text: "Ctrl+" + (index + 1) }
                    }
                }
            }
            // Machine at a glance
            Column {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.space.s4 }
                spacing: 3
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: SystemMonitor.info.host ?? "" }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: SystemMonitor.info.os ?? "" }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                        text: SystemMonitor.s.uptime ? "Up " + SystemMonitor.duration(SystemMonitor.s.uptime) : "" }
            }
        }

        // ── header ──
        Item {
            id: header
            anchors { top: parent.top; left: rail.right; right: parent.right; leftMargin: Theme.space.s5; rightMargin: Theme.space.s4; topMargin: Theme.space.s4 }
            height: 40
            LText { anchors.verticalCenter: parent.verticalCenter; role: "title"; font.pixelSize: 22; text: win.tabs.find(t => t.id === win.tab)?.label ?? "" }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                LField {
                    id: search
                    visible: win.tab === "processes" || win.tab === "services" || win.tab === "startup"
                    width: 260
                    icon: "search"
                    placeholder: win.tab === "processes" ? "Name, command or PID" : "Search"
                    clearOnAccept: false
                    input.Keys.onEscapePressed: { search.text = ""; win.contentItem.forceActiveFocus(); }
                }
                Segmented {
                    width: 180
                    anchors.verticalCenter: parent.verticalCenter
                    options: [{ id: "0.5", label: "0.5 s" }, { id: "1", label: "1 s" }, { id: "2", label: "2 s" }, { id: "5", label: "5 s" }]
                    current: String(SystemMonitor.interval)
                    onPicked: id => SystemMonitor.interval = parseFloat(id)
                }
                IconButton {
                    icon: SystemMonitor.paused ? "play_arrow" : "pause"
                    tone: SystemMonitor.paused ? Theme.accent : Theme.textSecondary
                    onActivated: SystemMonitor.paused = !SystemMonitor.paused
                }
            }
        }

        // ── the view ──
        Loader {
            anchors { top: header.bottom; topMargin: Theme.space.s3; bottom: footer.top; left: rail.right; right: parent.right }
            sourceComponent: ({ processes: processesC, performance: performanceC, startup: startupC, services: servicesC })[win.tab]
        }
        Component { id: processesC; ProcessesView { query: search.text } }
        Component { id: performanceC; PerformanceView { pick: win.resource || "cpu" } }
        Component { id: startupC; StartupView { query: search.text } }
        Component { id: servicesC; ServicesView { query: search.text } }

        // ── footer: totals, and what just happened ──
        Item {
            id: footer
            anchors { bottom: parent.bottom; left: rail.right; right: parent.right; leftMargin: Theme.space.s5; rightMargin: Theme.space.s4 }
            height: 32
            readonly property var m: SystemMonitor.s.mem ?? {}
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.s4
                LText { role: "caption"; color: Theme.textMuted; text: (SystemMonitor.s.procs ?? []).length + " processes" }
                LText { role: "caption"; color: Theme.textMuted; text: "CPU " + Math.round(SystemMonitor.s.cpu ?? 0) + "%" }
                LText { role: "caption"; color: Theme.textMuted
                        text: "Memory " + SystemMonitor.bytes((footer.m.total ?? 0) - (footer.m.available ?? 0)) + " of " + SystemMonitor.bytes(footer.m.total ?? 0) }
                LText { role: "caption"; color: Theme.textMuted; text: "Load " + (SystemMonitor.s.load ?? []).map(x => x.toFixed(2)).join(" · ") }
                LText { visible: SystemMonitor.paused; role: "caption"; color: Theme.warning; text: "Paused — Space to resume" }
            }
            LText { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    visible: win.toast !== ""; role: "caption"; color: win.toastBad ? Theme.error : Theme.accent; text: win.toast }
        }
    }
}
