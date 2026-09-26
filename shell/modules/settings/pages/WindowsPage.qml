// Windows: gaps, corners, border, animation speed, focus behaviour.
// Applied live (theme/build.py → Hyprland + shell).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Windows"
    subtitle: "How windows sit on the desktop and how they move. Changes apply immediately."

    readonly property var prefs: Theme.tokens.prefs ?? ({})
    function set(k, v) { SettingsState.lumen(["set", k, v]); }

    Group {
        title: "Layout"
        SetRow {
            icon: "space_dashboard"
            title: "Gaps"
            description: "Space between windows and around the edges"
            Segmented {
                width: 300
                options: [{ id: "compact", label: "Compact" }, { id: "normal", label: "Normal" }, { id: "roomy", label: "Roomy" }]
                current: prefs.gaps ?? "normal"
                onPicked: id => set("gaps", id)
            }
        }
        SetRow {
            icon: "rounded_corner"
            title: "Corners"
            description: "Windows and cards"
            Segmented {
                width: 300
                options: [{ id: "square", label: "Square" }, { id: "soft", label: "Soft" }, { id: "round", label: "Round" }]
                current: prefs.corners ?? "soft"
                onPicked: id => set("corners", id)
            }
        }
        SetRow {
            icon: "border_style"
            title: "Focus border"
            description: "The accent line around the active window"
            Segmented {
                width: 300
                options: [{ id: "off", label: "Off" }, { id: "thin", label: "Thin" }, { id: "normal", label: "Normal" }]
                current: prefs.border ?? "normal"
                onPicked: id => set("border", id)
            }
        }
    }

    Group {
        title: "Motion & focus"
        SetRow {
            icon: "speed"
            title: "Animation speed"
            description: "All animations — windows, workspaces and the shell"
            Segmented {
                width: 300
                options: [{ id: "fast", label: "Fast" }, { id: "normal", label: "Normal" }, { id: "relaxed", label: "Relaxed" }]
                current: prefs.anim_speed ?? "normal"
                onPicked: id => set("anim_speed", id)
            }
        }
        SetRow {
            icon: "mouse"
            title: "Focus follows the pointer"
            description: "Windows take focus when the pointer moves over them"
            LSwitch { checked: (prefs.follow_mouse ?? "on") === "on"; onToggled: set("follow_mouse", checked ? "off" : "on") }
        }
    }

    // ── Workspace snapshots (scripts/snapshot.sh) ──
    property var snapshots: []
    Process {
        id: snapList
        running: true
        command: [Theme.lumenRoot + "/scripts/snapshot.sh", "list"]
        stdout: StdioCollector { onStreamFinished: { try { page.snapshots = JSON.parse(text); } catch (e) {} } }
    }
    function snap(cmd, name) {
        Quickshell.execDetached([Theme.lumenRoot + "/scripts/snapshot.sh", cmd, name]);
        relist.restart();
    }
    Timer { id: relist; interval: 1500; onTriggered: snapList.running = true }

    Group {
        title: "Snapshots"
        SetRow {
            icon: "bookmark_add"
            title: "Save this setup"
            description: "Apps and their workspaces, floating windows, terminal folders, Focus mode and wallpaper"
            LField { width: 220; icon: "edit"; placeholder: "Name, e.g. “Study”"; onAccepted: t => { if (t.trim()) page.snap("save", t.trim()); } }
        }
        Repeater {
            model: page.snapshots
            delegate: SetRow {
                required property var modelData
                icon: "bookmark"
                title: modelData.name.replace(/_/g, " ")
                description: modelData.windows + " windows · " + modelData.apps.slice(0, 5).join(", ") + " · saved " + Qt.formatDateTime(new Date(modelData.saved * 1000), "d MMM, " + Theme.timeFormatFull)
                Row {
                    spacing: Theme.space.s2
                    Button { primary: true; text: "Restore"; onActivated: page.snap("restore", modelData.name) }
                    Button { icon: "delete"; text: ""; onActivated: page.snap("delete", modelData.name) }
                }
            }
        }
        SetRow { visible: page.snapshots.length === 0; icon: "info"; title: "No snapshots yet"; description: "Also from search: type “save study”, later “restore study” — or `lumen snapshot restore study`" }
    }
}
