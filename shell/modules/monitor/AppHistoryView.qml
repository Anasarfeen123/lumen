// App history: how much CPU (and GPU) time each app used — today, yesterday or
// the last 7 days. The shell notes it every 5 minutes (monitor.py usage-snap);
// a browser's helper processes count as the browser. Kept 35 days, on this computer.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: view
    property string range: "today"
    Component.onCompleted: SystemMonitor.loadUsage()
    Timer { interval: 60000; repeat: true; running: true; onTriggered: SystemMonitor.loadUsage() }

    readonly property var rows: {
        const days = SystemMonitor.usage ?? {};
        const keys = Object.keys(days).sort();
        const today = Qt.formatDate(new Date(), "yyyy-MM-dd");
        const yesterday = Qt.formatDate(new Date(Date.now() - 86400000), "yyyy-MM-dd");
        const pick = range === "today" ? [today] : range === "yesterday" ? [yesterday] : keys.slice(-7);
        const sum = {};
        for (const d of pick) for (const app in days[d] ?? {}) {
            const v = days[d][app];
            sum[app] = sum[app] ?? [0, 0];
            sum[app][0] += v[0]; sum[app][1] += v[1];
        }
        return Object.keys(sum).map(app => ({ app, cpu: sum[app][0], gpu: sum[app][1] }))
                   .filter(r => r.cpu >= 1 || r.gpu >= 1).sort((a, b) => b.cpu - a.cpu);
    }
    readonly property real peak: Math.max(1, ...rows.map(r => r.cpu))
    readonly property real total: rows.reduce((a, r) => a + r.cpu, 0)
    function dur(sec) { return sec < 60 ? Math.round(sec) + " s" : sec < 3600 ? Math.round(sec / 60) + " min" : (sec / 3600).toFixed(1) + " h"; }

    Row {
        id: bar
        x: Theme.space.s5
        spacing: Theme.space.s3
        Segmented {
            width: 300
            options: [{ id: "today", label: "Today" }, { id: "yesterday", label: "Yesterday" }, { id: "week", label: "7 days" }]
            current: view.range
            onPicked: id => view.range = id
        }
        LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                text: view.rows.length ? view.dur(view.total) + " of CPU time across " + view.rows.length + " apps (one core fully busy for an hour = 1 h)" : "" }
    }
    LText {
        visible: view.rows.length === 0
        anchors.centerIn: parent
        role: "body"; color: Theme.textMuted
        text: "Nothing recorded yet — Lumen notes app usage every 5 minutes."
    }
    ListView {
        anchors { top: bar.bottom; topMargin: Theme.space.s3; bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s4 }
        clip: true; spacing: 2
        model: view.rows
        boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: QQC.ScrollBar { width: 10; padding: 2; background: null
            contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.25) } }
        delegate: Item {
            id: row
            required property var modelData
            width: ListView.view.width; height: 46
            readonly property string icon: { const e = DesktopEntries.heuristicLookup(modelData.app); return e?.icon ? Quickshell.iconPath(e.icon, true) : ""; }
            Image { id: ic; x: Theme.space.s2; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; sourceSize: Qt.size(44, 44)
                    source: row.modelData.app === "Lumen" ? "file://" + Theme.lumenRoot + "/assets/lumen.svg" : row.icon; visible: status === Image.Ready; asynchronous: true }
            LIcon { visible: ic.status !== Image.Ready; x: Theme.space.s2 + 3; anchors.verticalCenter: parent.verticalCenter; icon: "apps"; size: 16; color: Theme.textMuted }
            LText { id: nm; x: 40; width: 240; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; role: "bodyStrong"; text: row.modelData.app }
            Rectangle {
                id: track
                anchors { left: nm.right; leftMargin: Theme.space.s3; right: nums.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                height: 8; radius: 4; color: Theme.withAlpha(Theme.text, 0.06)
                Rectangle { height: parent.height; radius: 4; color: Theme.accent; width: parent.width * row.modelData.cpu / view.peak }
            }
            Row {
                id: nums
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s4
                LText { width: 90; horizontalAlignment: Text.AlignRight; role: "body"; font.features: { "tnum": 1 }; text: view.dur(row.modelData.cpu) + " CPU" }
                LText { width: 90; horizontalAlignment: Text.AlignRight; role: "body"; color: Theme.textMuted; font.features: { "tnum": 1 }
                        text: row.modelData.gpu >= 1 ? view.dur(row.modelData.gpu) + " GPU" : "–" }
            }
        }
    }
}
