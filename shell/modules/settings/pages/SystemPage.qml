// System: what this computer is and how it's doing, live while you look.
// CPU · memory · GPUs (NVIDIA details only while it's awake — asking would
// wake it) · disks · battery · versions. Read-only; scripts/inspect.sh.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "System"
    subtitle: "Live while this page is open. Nothing here changes your system."

    property var info: ({ cpu: {}, system: {}, swap: {}, gpus: [], disks: [] })
    Process {
        id: probe
        command: [Theme.lumenRoot + "/scripts/inspect.sh"]
        stdout: StdioCollector { onStreamFinished: { try { page.info = JSON.parse(text); } catch (e) {} } }
    }
    Timer { interval: 3000; running: page.visible; repeat: true; triggeredOnStart: true; onTriggered: probe.running = true }
    Binding { target: Sysinfo; property: "active"; value: page.visible }

    function gb(bytes) { return bytes >= 1e12 ? (bytes / 1e12).toFixed(1) + " TB" : (bytes / 1e9).toFixed(bytes >= 1e11 ? 0 : 1) + " GB"; }
    function dur(s) { const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                      return d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m"; }

    // A tile: label, big number, detail, one meter
    component Tile: Rectangle {
        id: tile
        property string icon
        property string label
        property string value
        property string detail
        property real frac: -1
        property color tone: Theme.accent
        width: (page.width - Theme.space.s8 * 2 - Theme.space.s3) / 2
        implicitHeight: tcol.implicitHeight + Theme.space.s4 * 2
        radius: Theme.radius.md
        color: Theme.surfaceElevated
        border.width: 1; border.color: Theme.border
        Column {
            id: tcol
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            spacing: 6
            Row { spacing: 6
                  LIcon { icon: tile.icon; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                  LText { role: "caption"; color: Theme.textMuted; text: tile.label.toUpperCase(); font.letterSpacing: 0.8; anchors.verticalCenter: parent.verticalCenter } }
            LText { role: "title"; font.pixelSize: 26; font.features: { "tnum": 1 }; text: tile.value }
            LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary; text: tile.detail; visible: text !== "" }
            Rectangle {
                visible: tile.frac >= 0
                width: parent.width; height: 4; radius: 2
                color: Theme.withAlpha(Theme.text, 0.1)
                Rectangle { height: parent.height; radius: 2; color: tile.tone; width: parent.width * Math.max(0, Math.min(1, tile.frac))
                            Behavior on width { NumberAnimation { duration: Theme.motion.normal } } }
            }
        }
    }

    Flow {
        width: parent.width
        spacing: Theme.space.s3
        Tile {
            icon: "developer_board"; label: "Processor"
            value: Math.round(Sysinfo.cpu * 100) + "%"
            frac: Sysinfo.cpu
            detail: (page.info.cpu.model ?? "") + "\n" + (page.info.cpu.cores ?? "?") + " cores · " + (page.info.cpu.threads ?? "?") + " threads · "
                    + ((page.info.cpu.curMhz ?? 0) / 1000).toFixed(1) + " GHz · " + Math.round(Sysinfo.cpuTemp) + "°C"
            tone: Sysinfo.cpuTemp >= 90 ? Theme.error : Sysinfo.cpuTemp >= 80 ? Theme.warning : Theme.accent
        }
        Tile {
            icon: "memory_alt"; label: "Memory"
            value: Sysinfo.memUsed.toFixed(1) + " / " + Sysinfo.memTotal.toFixed(0) + " GB"
            frac: Sysinfo.memTotal > 0 ? Sysinfo.memUsed / Sysinfo.memTotal : 0
            detail: (page.info.swap.total ?? 0) > 0 ? "Swap " + page.gb(page.info.swap.used ?? 0) + " of " + page.gb(page.info.swap.total) : "No swap"
        }
        Repeater {
            model: page.info.gpus ?? []
            delegate: Tile {
                required property var modelData
                readonly property bool nv: modelData.vendor === "0x10de"
                readonly property bool awake: nv ? Sysinfo.dgpu === "active" && Sysinfo.dgpuUtil >= 0 : true
                icon: "speed"
                label: nv ? "NVIDIA GPU" : modelData.vendor === "0x1002" ? "AMD GPU" : modelData.vendor === "0x8086" ? "Intel GPU" : "GPU"
                value: nv ? (awake ? Math.round(Sysinfo.dgpuUtil * 100) + "%" : "Asleep") : (modelData.busy >= 0 ? modelData.busy + "%" : "—")
                frac: nv ? (awake ? Sysinfo.dgpuUtil : -1) : (modelData.busy >= 0 ? modelData.busy / 100 : -1)
                detail: modelData.name.replace(/^(NVIDIA Corporation|Advanced Micro Devices, Inc\. \[AMD\/ATI\]|Intel Corporation) /, "").replace(/ \(rev .*\)$/, "") + "\n"
                    + (nv ? (awake ? "Driver " + Sysinfo.dgpuDriver + " · " + Math.round(Sysinfo.dgpuMemUsed) + " / " + Math.round(Sysinfo.dgpuMemTotal) + " MB · "
                                     + Math.round(Sysinfo.dgpuTemp) + "°C · " + Sysinfo.dgpuPower.toFixed(0) + " W"
                                   : "Sleeping to save battery — it wakes for apps that need it (lumen-dgpu <app>)")
                          : ((modelData.vramTotal > 0 ? Math.round(modelData.vramUsed / 1048576) + " / " + Math.round(modelData.vramTotal / 1048576) + " MB · " : "")
                             + (modelData.temp > -1 ? Math.round(modelData.temp) + "°C" : "")))
            }
        }
        Tile {
            visible: UPower.displayDevice?.isLaptopBattery ?? false
            icon: "battery_full"; label: "Battery"
            readonly property var d: UPower.displayDevice
            value: Math.round((d?.percentage ?? 0) * 100) + "%"
            frac: d?.percentage ?? 0
            tone: (d?.percentage ?? 1) < 0.15 ? Theme.error : Theme.success
            detail: ((d?.healthSupported ?? false) ? "Health " + Math.round(d.healthPercentage) + "% · " : "")
                    + (Math.abs(d?.changeRate ?? 0) > 0.1 ? Math.abs(d.changeRate).toFixed(1) + " W " + (Battery.charging ? "in" : "out") + " · " : "")
                    + (Battery.charging ? "charging" : Battery.pluggedIn ? "plugged in" : Battery.formatDuration(Battery.timeToEmpty) + " left")
        }
    }

    Group {
        title: "Storage"
        Repeater {
            model: page.info.disks ?? []
            delegate: SetRow {
                required property var modelData
                icon: modelData.mount === "/" ? "hard_drive" : "folder"
                title: modelData.mount
                description: page.gb(modelData.used) + " of " + page.gb(modelData.size) + " · " + modelData.fs
                Rectangle {
                    width: 180; height: 6; radius: 3
                    color: Theme.withAlpha(Theme.text, 0.1)
                    readonly property real f: modelData.size > 0 ? modelData.used / modelData.size : 0
                    Rectangle { height: parent.height; radius: 3; width: parent.width * parent.f
                                color: parent.f > 0.9 ? Theme.error : parent.f > 0.75 ? Theme.warning : Theme.accent }
                }
            }
        }
    }

    Group {
        title: "Software"
        SetRow { icon: "computer"; title: page.info.system.os ?? ""; description: (page.info.system.host ?? "") + " · up " + page.dur(page.info.system.uptime ?? 0) }
        SetRow { icon: "terminal"; title: "Linux " + (page.info.system.kernel ?? ""); description: "Kernel" }
        SetRow { icon: "grid_view"; title: "Hyprland " + (page.info.system.hyprland ?? "") + " · Quickshell " + (page.info.system.quickshell ?? ""); description: "Compositor and shell" }
    }
}
