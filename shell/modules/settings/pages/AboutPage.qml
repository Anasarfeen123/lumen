// About: what this machine is running.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import ".."

Page {
    id: page
    title: "About"

    property var info: ({})
    Process {
        running: true
        command: ["sh", "-c",
            "echo \"os=$(sed 's/ release / /' /etc/fedora-release 2>/dev/null)\";" +
            "echo \"kernel=$(uname -r)\";" +
            "echo \"hyprland=$(Hyprland --version 2>/dev/null | head -1 | cut -d' ' -f2)\";" +
            "echo \"quickshell=$(qs --version 2>/dev/null | head -1 | cut -d' ' -f2)\";" +
            "echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')\";" +
            "echo \"mem=$(awk '/MemTotal/ {printf \"%.1f GB\", $2/1048576}' /proc/meminfo)\";" +
            "echo \"gpu=$(lspci 2>/dev/null | grep -Ei 'vga|3d' | sed -E 's/.*: //; s/Corporation //; s/Advanced Micro Devices, Inc. //' | paste -sd '·')\";" +
            "echo \"host=$(hostname)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const o = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.slice(0, i)] = l.slice(i + 1).trim(); }
                page.info = o;
            }
        }
    }

    Row {
        spacing: Theme.space.s4
        LumenLogo { size: 88; anchors.verticalCenter: parent.verticalCenter }
    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.space.s1
        Text {
            text: "Lumen"
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 44
            font.variableAxes: ({ "wght": 650, "ROND": 100 })
        }
        LText { color: Theme.textSecondary; text: "Extremely capable underneath. Extremely simple on the surface." }
    }
    }

    Group {
        title: "This machine"
        SetRow { icon: "laptop"; title: page.info.host ?? "…"; description: page.info.os ?? "" }
        SetRow { icon: "memory"; title: "Processor"; description: (page.info.cpu ?? "") + (page.info.mem ? "  ·  " + page.info.mem : "") }
        SetRow { icon: "developer_board"; title: "Graphics"; description: page.info.gpu ?? "" }
    }
    Group {
        title: "Software"
        SetRow { icon: "terminal"; title: "Kernel"; description: page.info.kernel ?? "" }
        SetRow { icon: "window"; title: "Hyprland"; description: page.info.hyprland ?? "" }
        SetRow { icon: "widgets"; title: "Quickshell"; description: page.info.quickshell ?? "" }
        SetRow { icon: "folder_code"; title: "Lumen"; description: Theme.lumenRoot + "  ·  see DESIGN.md" }
    }
}
