// Quiet system readout, one line: CPU · memory · temperature · GPU · disk.
// A small "dGPU" tag appears while the NVIDIA card is awake. Hover a value for
// its name. Sampling runs only while this is visible.
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    implicitHeight: 40
    radius: Theme.radius.md
    color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
    border.width: 1
    border.color: Theme.border

    // A request per screen (a Binding here would fight the sidebars on other screens)
    readonly property bool wantsSamples: root.visible && Sidebar.open
    readonly property string sysKey: "stats:" + Math.random().toString(36).slice(2)
    onWantsSamplesChanged: Sysinfo.request(sysKey, wantsSamples ? "detail" : "")
    // as RibbonChips does: a sidebar already open when this is built never
    // changes wantsSamples, so the change handler above would never fire
    Component.onCompleted: Sysinfo.request(sysKey, wantsSamples ? "detail" : "")
    Component.onDestruction: Sysinfo.request(sysKey, "")

    // Click for the full picture (Settings → System)
    HoverTarget {
        anchors.fill: parent
        radius: parent.radius
        z: -1
        onClicked: { Sidebar.hide(); SettingsState.launch("system"); }
    }

    component Stat: Item {
        id: st
        property string icon
        property string value
        property string name
        property color tone: Theme.text
        width: (row.width - row.spacing * 4) / 5
        height: parent.height
        Row {
            anchors.centerIn: parent
            spacing: 5
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: st.icon; size: 15; color: Theme.textMuted }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; color: st.tone; text: hover.hovered ? st.name : st.value }
        }
        HoverHandler { id: hover }
    }

    Row {
        id: row
        anchors { fill: parent; leftMargin: Theme.space.s2; rightMargin: Theme.space.s2 }
        spacing: 2
        Stat { icon: "developer_board"; name: "CPU"; value: Math.round(Sysinfo.cpu * 100) + "%" }
        Stat { icon: "memory_alt"; name: "RAM"; value: Sysinfo.memUsed.toFixed(1) + "G" }
        Stat {
            icon: "thermostat"; name: "Temp"
            value: Math.round(Sysinfo.cpuTemp) + "°"
            tone: Sysinfo.cpuTemp >= 90 ? Theme.error : Sysinfo.cpuTemp >= 80 ? Theme.warning : Theme.text
        }
        Stat { icon: "speed"; name: Sysinfo.dgpu === "active" ? "dGPU on" : "GPU"; value: Math.round(Sysinfo.igpu * 100) + "%"
               tone: Sysinfo.dgpu === "active" ? Theme.success : Theme.text }
        Stat { icon: "hard_drive"; name: "Disk"; value: Math.round(Sysinfo.disk * 100) + "%" }
    }
}
