// Default apps: which browser, file manager, editor, terminal and system
// monitor Lumen's keys and actions open. Only apps that are installed are
// offered; "Automatic" keeps Lumen's own order (the first one installed).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Default apps"
    subtitle: "What Lumen opens for the web, files, code, a terminal and the system monitor (Super+W, Super+E, Super+C, Super+Enter, Ctrl+Shift+Esc)."

    readonly property var prefs: Theme.tokens.prefs ?? ({})
    readonly property var kinds: [
        { key: "browser",  icon: "public",          title: "Web browser",     keys: "Super+W", apps: ["brave-origin", "brave-browser", "firefox", "chromium-browser", "chromium", "google-chrome-stable", "zen-browser", "librewolf"] },
        { key: "files",    icon: "folder",          title: "Files",           keys: "Super+E", apps: ["dolphin", "nautilus", "thunar", "nemo", "pcmanfm-qt"] },
        { key: "editor",   icon: "code",            title: "Code editor",     keys: "Super+C", apps: ["code", "codium", "zed", "kate", "gnome-text-editor", "kwrite"] },
        { key: "terminal", icon: "terminal",        title: "Terminal",        keys: "Super+Enter", apps: ["kitty", "foot", "alacritty", "konsole", "wezterm", "ghostty", "ptyxis"] },
        { key: "monitor",  icon: "monitor_heart",   title: "System monitor",  keys: "Ctrl+Shift+Esc", apps: ["plasma-systemmonitor", "gnome-system-monitor", "missioncenter", "resources"] },
    ]
    // Which of the candidates are installed
    property var installed: ({})
    Process {
        running: true
        command: ["sh", "-c", 'for a in "$@"; do command -v "$a" >/dev/null 2>&1 && printf "%s\\n" "$a"; done', "sh"].concat(page.kinds.reduce((all, k) => all.concat(k.apps), []))
        stdout: StdioCollector { onStreamFinished: { const m = {}; text.split("\n").filter(x => x).forEach(a => m[a] = true); page.installed = m; } }
    }
    function nice(a) {
        return ({ "brave-origin": "Brave Origin", "brave-browser": "Brave", "chromium-browser": "Chromium", "google-chrome-stable": "Chrome",
                  "zen-browser": "Zen", "plasma-systemmonitor": "KDE Monitor", "gnome-system-monitor": "GNOME Monitor",
                  "missioncenter": "Mission Center", "gnome-text-editor": "Text Editor", "code": "VS Code", "codium": "VSCodium" })[a]
               ?? a.charAt(0).toUpperCase() + a.slice(1);
    }

    Group {
        title: "Apps"
        Repeater {
            model: page.kinds
            delegate: SetRow {
                id: row
                required property var modelData
                readonly property var options: [{ id: "", label: "Automatic" }].concat(modelData.apps.filter(a => page.installed[a]).slice(0, 4).map(a => ({ id: a, label: page.nice(a) })))
                icon: modelData.icon
                title: modelData.title
                description: modelData.keys + " · " + ((page.prefs["app_" + modelData.key] ?? "") === "" ? "Lumen picks the first one installed" : page.nice(page.prefs["app_" + modelData.key]))
                Segmented {
                    width: Math.min(500, row.options.reduce((w, o) => w + Math.max(84, o.label.length * 8 + 30), 0))
                    options: row.options
                    current: page.prefs["app_" + modelData.key] ?? ""
                    onPicked: id => SettingsState.lumen(["set", "app_" + modelData.key, id])
                }
            }
        }
    }
    Group {
        title: "Files and links"
        SetRow {
            icon: "link"
            title: "Which app opens a file type"
            description: "Opening a PDF, a picture or a link from anywhere follows your desktop's own choices (xdg-mime), shared with KDE"
            Button { text: "Open in KDE settings"; onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "systemsettings kcm_filetypes", "kcmshell6 kcm_filetypes"]) }
        }
    }
}
