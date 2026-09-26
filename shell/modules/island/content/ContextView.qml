// context — hover the resting island while you work (services/Context):
//   development   project · git branch, ahead/behind, changes · CPU RAM GPU
//   gaming        the game · GPU load, temperature, power · CPU · power mode
// Numbers are sampled only while this card is open.
import QtQuick
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: Theme.island.expandedWidth - Theme.space.s4 * 2
    implicitHeight: col.implicitHeight
    readonly property bool dev: Context.kind === "dev"
    readonly property bool nvidia: Sysinfo.dgpu === "active" && Sysinfo.dgpuUtil >= 0
    readonly property real gpu: nvidia ? Sysinfo.dgpuUtil : Sysinfo.igpu

    component Meter: Column {
        id: m
        property string label
        property string value
        property real frac: 0
        property color tone: Theme.accent
        width: (col.width - Theme.space.s3 * 3) / 4
        spacing: 4
        LText { role: "caption"; color: Theme.textMuted; text: m.label }
        LText { role: "bodyStrong"; font.features: { "tnum": 1 }; text: m.value }
        Rectangle {
            width: parent.width; height: 3; radius: 1.5
            color: Theme.withAlpha(Theme.text, 0.12)
            Rectangle { height: parent.height; radius: 1.5; color: m.tone; width: parent.width * Math.max(0, Math.min(1, m.frac))
                        Behavior on width { NumberAnimation { duration: Theme.motion.normal } } }
        }
    }

    Column {
        id: col
        width: parent.width
        spacing: Theme.space.s3

        // Header
        Item {
            width: parent.width; height: 26
            Row {
                spacing: Theme.space.s2
                anchors.verticalCenter: parent.verticalCenter
                LIcon { icon: root.dev ? "code_blocks" : "sports_esports"; size: 18; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyStrong"
                    width: Math.min(implicitWidth, col.width * 0.55)
                    elide: Text.ElideRight
                    text: root.dev ? (Context.projectDir ? Context.projectDir.split("/").pop() : "Development") : (Context.title || "Gaming")
                }
            }
            // git chip
            Rectangle {
                visible: root.dev && Context.git !== null
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: 22; radius: 11
                width: gitRow.implicitWidth + 16
                color: Theme.withAlpha(Theme.text, 0.06); border.width: 1; border.color: Theme.border
                Row {
                    id: gitRow
                    anchors.centerIn: parent
                    spacing: 5
                    LIcon { icon: "account_tree"; size: 13; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "caption"; text: Context.git?.branch ?? ""; anchors.verticalCenter: parent.verticalCenter }
                    LText { visible: (Context.git?.ahead ?? 0) > 0; role: "caption"; color: Theme.accent; text: "↑" + (Context.git?.ahead ?? 0); anchors.verticalCenter: parent.verticalCenter }
                    LText { visible: (Context.git?.behind ?? 0) > 0; role: "caption"; color: Theme.warning; text: "↓" + (Context.git?.behind ?? 0); anchors.verticalCenter: parent.verticalCenter }
                    LText { visible: (Context.git?.changed ?? 0) > 0; role: "caption"; color: Theme.textMuted; text: "· " + (Context.git?.changed ?? 0) + " changed"; anchors.verticalCenter: parent.verticalCenter }
                    LText { visible: Context.git !== null && Context.git.changed === 0 && Context.git.ahead === 0; role: "caption"; color: Theme.success; text: "· clean"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            // gaming: power profile chip
            Rectangle {
                visible: !root.dev
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                height: 22; radius: 11; width: pw.implicitWidth + 16
                color: Theme.withAlpha(Theme.accent, 0.14)
                LText { id: pw; anchors.centerIn: parent; role: "caption"; color: Theme.accent
                        text: PowerProfiles.profile === PowerProfile.Performance ? "Performance" : PowerProfiles.profile === PowerProfile.PowerSaver ? "Saver" : "Balanced" }
            }
        }

        // Meters
        Row {
            width: parent.width
            spacing: Theme.space.s3
            Meter { label: "CPU"; value: Math.round(Sysinfo.cpu * 100) + "%"; frac: Sysinfo.cpu }
            Meter { label: "Memory"; value: Sysinfo.memUsed.toFixed(1) + " GB"; frac: Sysinfo.memTotal > 0 ? Sysinfo.memUsed / Sysinfo.memTotal : 0 }
            Meter { label: root.nvidia ? "GPU (NVIDIA)" : "GPU"; value: Math.round(root.gpu * 100) + "%"; frac: root.gpu }
            Meter {
                readonly property real t: root.nvidia ? Sysinfo.dgpuTemp : Sysinfo.cpuTemp
                label: root.nvidia ? "GPU temp" : "CPU temp"
                value: Math.round(t) + "°"
                frac: t / 100
                tone: t >= 85 ? Theme.error : t >= 75 ? Theme.warning : Theme.accent
            }
        }
    }
}
