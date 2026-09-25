// Quiet system readout. Sampling runs only while this is visible.
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    implicitHeight: col.height + Theme.space.s3 * 2
    radius: Theme.radius.md
    color: Theme.surfaceElevated
    border.width: 1
    border.color: Theme.border

    Binding { target: Sysinfo; property: "active"; value: root.visible && Sidebar.open }

    component Stat: Column {
        property string label
        property string value
        property color tone: Theme.text
        width: (grid.width - grid.spacing * 3) / 4
        LText { role: "caption"; color: Theme.textMuted; text: parent.label }
        LText { role: "bodyStrong"; color: parent.tone; text: parent.value }
    }

    Column {
        id: col
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s3 }
        spacing: Theme.space.s2

        Row {
            id: grid
            width: parent.width
            spacing: Theme.space.s2
            Stat { label: "CPU"; value: Math.round(Sysinfo.cpu * 100) + "%" }
            Stat { label: "Memory"; value: Sysinfo.memUsed.toFixed(1) + " GB" }
            Stat {
                label: "Temp"
                value: Math.round(Sysinfo.cpuTemp) + "°"
                tone: Sysinfo.cpuTemp >= 90 ? Theme.error : Sysinfo.cpuTemp >= 80 ? Theme.warning : Theme.text
            }
            Stat { label: "GPU"; value: Math.round(Sysinfo.igpu * 100) + "%" }
        }
        LText {
            role: "caption"
            color: Theme.textMuted
            text: {
                const d = Sysinfo.dgpu === "active" ? "NVIDIA active" : Sysinfo.dgpu === "suspended" ? "NVIDIA asleep" : "";
                const disk = `Disk ${Math.round(Sysinfo.disk * 100)}% used`;
                return d ? `${d} · ${disk}` : disk;
            }
        }
    }
}
