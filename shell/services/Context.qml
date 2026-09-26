pragma Singleton
// What are you doing right now? Read from the focused window, never from
// anything you type or see. Used for:
//   • the island's context card (hover the resting island): development
//     (project, git branch, CPU/RAM/GPU) or gaming (GPU, temperature)
//   • presentation mode: a fullscreen slideshow or PDF presentation holds
//     notifications, keeps the screen awake at full brightness, and undoes
//     all of it when you leave fullscreen
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    readonly property var top: Hyprland.activeToplevel
    readonly property var win: top?.lastIpcObject ?? ({})
    // appId/title come live from the toplevel; pid/fullscreen from Hyprland's
    // client info, refreshed whenever focus moves
    readonly property string cls: top?.wayland?.appId || win.class || ""
    readonly property string title: top?.title ?? win.title ?? ""
    onTopChanged: Hyprland.refreshToplevels()
    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "fullscreen") Hyprland.refreshToplevels(); }
    }
    readonly property bool fullscreen: (win.fullscreen ?? 0) > 0

    readonly property string kind: {
        if (GameMode.on || /^(steam_app_\d+|gamescope|.*\.exe|minecraft.*|com\.mojang.*|heroic)$/i.test(cls)) return "game";
        if (fullscreen && (/(libreoffice-impress|soffice|org\.kde\.okular|evince|org\.gnome\.papers|zathura|sioyek)/i.test(cls)
                           || /(slide ?show|presentation|presenting)/i.test(title))) return "present";
        if (fullscreen && /(mpv|vlc|celluloid|haruna|totem|firefox|brave|chrom|zen)/i.test(cls)) return "video";
        if (/^(code|code-oss|codium|vscodium|jetbrains-.*|dev\.zed\.zed|zed|org\.kde\.kate|neovide|kitty|foot|alacritty|org\.wezfurlong\.wezterm|com\.mitchellh\.ghostty|konsole|org\.kde\.konsole|lumen-dropterm)$/i.test(cls)) return "dev";
        return "";
    }
    readonly property string label: ({ dev: "Development", game: "Gaming", present: "Presenting", video: "Watching" })[kind] ?? ""

    // ── Development: which project, and its git state ──
    property string projectDir: ""
    property var git: null               // { branch, ahead, behind, changed }
    function refreshDev() {
        if (kind !== "dev") { projectDir = ""; git = null; return; }
        if (!win.pid) { devSettle.restart(); return; }       // client info not refreshed yet
        devProbe.command = ["sh", "-c", `
            pid=$1; title=$2
            # a terminal: the cwd of its (newest) shell — not its helper processes
            for c in $(pgrep -P "$pid" 2>/dev/null); do
                case $(cat "/proc/$c/comm" 2>/dev/null) in bash|zsh|fish|sh|dash|nu|xonsh|elvish|tcsh|ksh) child=$c ;; esac
            done
            [ -n "$child" ] && dir=$(readlink "/proc/$child/cwd" 2>/dev/null)
            # an editor: "file — folder — Visual Studio Code" → ~/Projects/folder
            if [ -z "$dir" ] || [ "$dir" = "$HOME" ]; then
                dir=$(printf '%s\\n' "$title" | sed 's/ [—–-] /\\n/g' | while IFS= read -r p; do
                    [ -n "$p" ] && [ -d "$HOME/Projects/$p" ] && { printf '%s' "$HOME/Projects/$p"; break; }
                done)
            fi
            [ -n "$dir" ] || exit 0
            top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { echo "dir=$dir"; exit 0; }
            echo "dir=$top"
            git -C "$top" status --porcelain=v2 --branch 2>/dev/null | awk '
                /^# branch.head/ {print "branch=" $3}
                /^# branch.ab/   {print "ahead=" substr($3,2); print "behind=" substr($4,2)}
                /^[12u?] /       {n++}
                END              {print "changed=" n+0}'`, "sh", String(win.pid ?? 0), title];
        devProbe.running = true;
    }
    Process {
        id: devProbe
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) kv[l.slice(0, i)] = l.slice(i + 1); }
                root.projectDir = kv.dir ?? "";
                root.git = kv.branch ? { branch: kv.branch, ahead: +(kv.ahead ?? 0), behind: +(kv.behind ?? 0), changed: +(kv.changed ?? 0) } : null;
            }
        }
    }
    onKindChanged: refreshDev()
    onTitleChanged: devSettle.restart()                 // cd / file switches change the title
    Timer { id: devSettle; interval: 600; onTriggered: root.refreshDev() }
    // While the card is open, keep git fresh
    Timer { interval: 5000; repeat: true; triggeredOnStart: true; running: Island.variant === "context" && root.kind === "dev"; onTriggered: root.refreshDev() }
    Binding { target: Sysinfo; property: "islandActive"; value: Island.variant === "context" }

    // ── Presentation mode (real session only) ──
    property var saved: null
    readonly property bool presenting: kind === "present"
    onPresentingChanged: {
        if (!Persist.automates) return;
        if (presenting && !saved) {
            saved = { dnd: Notifications.dnd, caffeine: Caffeine.on, brightness: Brightness.value };
            Notifications.setDnd(true, true);
            if (!Caffeine.on) Caffeine.toggle();
            if (Brightness.available) Brightness.set(1);
            Island.system("co_present", "Presentation mode", "Notifications held until you're done");
        } else if (!presenting && saved) {
            if (Notifications.dnd !== saved.dnd) Notifications.setDnd(saved.dnd, true);
            if (Caffeine.on !== saved.caffeine) Caffeine.toggle();
            if (Brightness.available) Brightness.set(saved.brightness);
            saved = null;
            Island.system("co_present", "Presentation over", "Back to normal");
        }
    }
}
