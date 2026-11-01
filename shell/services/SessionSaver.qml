pragma Singleton
// Your windows, kept: every 5 minutes the main shell saves what's open as the
// snapshot "last-session" (scripts/snapshot.sh). After a fresh login or a shell
// crash, if several of those windows aren't open, the island offers to reopen
// them — only what's missing, onto the same workspaces. It doesn't save during
// its first two minutes, so a near-empty new session can't replace your last one.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/snapshot.sh"
    readonly property bool on: Persist.automates && (Persist.data.sessionRestore ?? true)
    readonly property int openWindows: Hyprland.toplevels.values.filter(t => (t.lastIpcObject?.workspace?.id ?? 0) > 0).length
    property bool offered: false

    // the first look, a little after the shell starts (apps that autostart get to appear)
    Timer {
        interval: 20000; running: root.on; onTriggered: lister.running = true
    }
    Process {
        id: lister
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = []; try { list = JSON.parse(text); } catch (e) {}
                const last = list.find(s => s.name === "last-session");
                if (!last || root.offered) return;
                const missing = (last.windows ?? 0) - root.openWindows;
                if (missing < 2) return;
                root.offered = true;
                Island.push({ kind: "halo", key: "halo:restore", priority: Island.priority.system, duration: 30000, force: true,
                              data: { key: "restore", icon: "restore_page", title: "Reopen what you had open?",
                                      text: last.windows + " windows from your last session", level: "asked", duration: 30000,
                                      actions: [{ label: "Reopen", icon: "restore", run: () => Quickshell.execDetached([root.script, "restore", "last-session"]) },
                                                { label: "No", icon: "close", run: () => {} }] } });
            }
        }
    }
    // every 5 minutes, after the first two
    Timer {
        id: saver
        interval: 300000; repeat: true
        running: root.on && warm.done
        onTriggered: if (root.openWindows > 0) Quickshell.execDetached([root.script, "save", "last-session"])
    }
    Timer { id: warm; property bool done: false; interval: 120000; running: root.on; onTriggered: done = true }
}
