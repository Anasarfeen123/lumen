// A quiet pulse beside the status pill: a CPU line of the last minute and
// memory in use. Muted unless something is straining. Click: Settings → System.
import QtQuick
import qs.theme
import qs.components
import qs.services

HoverTarget {
    id: root
    property bool shown: false
    property var history: []            // CPU 0–1, oldest first
    readonly property bool hot: Sysinfo.cpu > 0.8
    readonly property real memPct: Sysinfo.memTotal > 0 ? Sysinfo.memUsed / Sysinfo.memTotal : 0

    width: row.implicitWidth + 16
    height: Theme.barHeight - 12
    radius: height / 2
    opacity: shown && history.length > 1 ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    onClicked: SettingsState.launch("system")

    Connections {
        target: Sysinfo
        function onCpuChanged() { root.history = root.history.concat([Sysinfo.cpu]).slice(-24); line.requestPaint(); }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Canvas {
            id: line
            width: 42; height: 14
            anchors.verticalCenter: parent.verticalCenter
            onPaint: {
                const c = getContext("2d");
                c.reset();
                const h = root.history;
                if (h.length < 2) return;
                const step = width / 23;
                c.beginPath();
                for (let i = 0; i < h.length; i++) {
                    const x = width - (h.length - 1 - i) * step, y = height - 1 - h[i] * (height - 2);
                    if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
                }
                c.lineWidth = 1.5;
                c.lineJoin = "round";
                c.strokeStyle = root.hot ? Theme.warning : Theme.withAlpha(Theme.accent, 0.85);
                c.stroke();
            }
        }
        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            color: root.hot ? Theme.warning : Theme.textSecondary
            text: Math.round(Sysinfo.cpu * 100) + "%"
        }
        Rectangle { width: 1; height: 12; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            color: root.memPct > 0.9 ? Theme.warning : Theme.textSecondary
            text: Sysinfo.memUsed.toFixed(1) + "G"
        }
    }
}
