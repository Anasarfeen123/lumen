// Notes: Lumen Notes' folder, and syncing it with your phone through
// Syncthing (scripts/notes-sync.py) — device to device, encrypted, no account
// or cloud. Pairing: the phone scans this computer's code, you accept the
// phone here, the phone accepts the "Notes" folder.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Notes"
    subtitle: "Plain Markdown files in one folder (Super+O to open, Super+Shift+O for a new one). Sync them with your phone and edit on either — straight from device to device, no cloud."
    Component.onCompleted: { Notes.watchingSync = true; Notes.refreshSync(); }
    Component.onDestruction: Notes.watchingSync = false

    readonly property var s: Notes.sync
    readonly property string myId: s.myId ?? ""

    Group {
        title: "Your notes"
        SetRow {
            icon: "edit_note"
            title: "Notes app"
            description: "Write in Markdown, read it formatted, search inside every note, pin the ones you need"
            Button { text: "Open Notes"; primary: true; onActivated: SettingsState.shellCall("notes", "open") }
        }
        SetRow {
            icon: "folder"
            title: Notes.dir.replace(Quickshell.env("HOME"), "~")
            description: "One .md file per note — Obsidian, Markor or any editor can open them too. The planner's scratchpad is Scratchpad.md here."
            Button { text: "Show folder"; onActivated: Quickshell.execDetached(["xdg-open", Notes.dir]) }
        }
    }

    Group {
        title: "Halo"
        SetRow {
            icon: "auto_awesome"
            title: "Let Halo read notes you name"
            description: "\"Summarise my DBMS notes\" attaches the notes whose titles match (up to three), "
                         + (Ai.provider === "anthropic" ? "sent to Anthropic with your question" : "for that question only")
            LSwitch { checked: Notes.cfg.haloContext; onToggled: Notes.cfg.haloContext = !checked }
        }
    }

    Group {
        title: "Sync with your phone"
        SetRow {
            visible: !(page.s.installed ?? true)
            icon: "error"
            title: "Syncthing isn't installed"
            description: "Install it once: sudo dnf install syncthing"
        }
        SetRow {
            visible: (page.s.installed ?? false) && !Notes.syncOn
            icon: "sync"
            title: "Sync notes with your phone"
            description: Notes.syncBusy ? "Starting Syncthing…"
                       : Notes.syncError !== "" ? Notes.syncError
                       : "Starts Syncthing for you (and at every login) and shares the Notes folder. Nothing leaves your devices: they talk to each other directly, encrypted."
            Button { text: Notes.syncBusy ? "Setting up…" : "Set up"; primary: true; enabled: !Notes.syncBusy; onActivated: Notes.setupSync() }
        }
    }

    // ── Pairing ──
    Group {
        title: "Add your phone"
        visible: Notes.syncOn && Notes.phones.length === 0
        SetRow {
            icon: "counter_1"
            title: "Install Syncthing on the phone"
            description: "Android: “Syncthing-Fork” (F-Droid or Play Store). iPhone: “Möbius Sync”."
        }
        SetRow {
            icon: "counter_2"
            title: "Add this computer"
            description: "In the app: Devices → + → scan this code (or paste the ID)."
            minHeight: 230
            Row {
                spacing: Theme.space.s3
                Rectangle {
                    width: 196; height: 196; radius: Theme.radius.sm
                    color: "white"
                    Image {
                        anchors { fill: parent; margins: 8 }
                        source: Notes.qrVersion > 0 ? "file://" + Notes.qrPath : ""    // (a "?v=" query would make Qt fail to open the file)
                        cache: false
                        smooth: false
                        fillMode: Image.PreserveAspectFit
                    }
                    LText { anchors.centerIn: parent; visible: Notes.qrVersion === 0; role: "caption"; color: "#555"; text: "Making the code…" }
                }
            }
        }
        SetRow {
            icon: "fingerprint"
            title: "This computer's ID"
            description: page.myId
            Button { text: "Copy"; onActivated: Quickshell.execDetached(["wl-copy", page.myId]) }
        }
        SetRow {
            icon: "counter_3"
            title: (page.s.pending ?? []).length ? "Your phone is asking to connect" : "Waiting for your phone…"
            description: (page.s.pending ?? []).length ? "Accept it below — then, on the phone, accept the “Notes” folder and pick where to keep it (e.g. Documents/Notes)."
                                                       : "It appears here a few seconds after you add this computer on the phone. Both need to be online (any network)."
        }
    }

    Group {
        title: "Devices asking to connect"
        visible: Notes.syncOn && (page.s.pending ?? []).length > 0
        Repeater {
            model: page.s.pending ?? []
            delegate: SetRow {
                required property var modelData
                icon: "smartphone"
                title: modelData.name
                description: modelData.id.slice(0, 23) + "…" + (modelData.address ? " · " + modelData.address : "")
                Row {
                    spacing: Theme.space.s2
                    Button { text: "Ignore"; onActivated: Notes.forgetDevice(modelData.id) }
                    Button { text: "Accept"; primary: true; enabled: !Notes.syncBusy; onActivated: Notes.acceptPhone(modelData.id, modelData.name) }
                }
            }
        }
    }

    Group {
        title: "Syncing with"
        visible: Notes.syncOn && Notes.phones.length > 0
        Repeater {
            model: Notes.phones
            delegate: SetRow {
                required property var modelData
                icon: modelData.connected ? "mobile_friendly" : "smartphone"
                title: modelData.name
                description: modelData.connected
                    ? "Connected" + (modelData.completion !== null && modelData.completion !== undefined && modelData.completion < 100 ? " · syncing, " + modelData.completion + "%" : " · up to date")
                    : "Away — notes sync as soon as it's back online" + (modelData.lastSeen && !modelData.lastSeen.startsWith("1970") ? " · last seen " + Qt.formatDateTime(new Date(modelData.lastSeen), "d MMM, " + Theme.timeFormatFull) : "")
                Button { text: "Forget"; onActivated: Notes.forgetDevice(modelData.id) }
            }
        }
        SetRow {
            icon: "info"
            title: "If the phone shows “Notes” as new"
            description: "Accept it there and choose a folder. Edit on either side; a note changed in both places at once keeps both versions."
        }
    }

    Group {
        title: "Advanced"
        visible: Notes.syncOn
        SetRow {
            icon: "add_link"
            title: "Add a device by ID"
            description: "For a second phone or a tablet, if it doesn't show up by itself"
            Row {
                spacing: Theme.space.s2
                LField { id: idField; width: 260; icon: "fingerprint"; placeholder: "XXXXXXX-XXXXXXX-…"; clearOnAccept: false
                         onAccepted: t => { Notes.acceptPhone(t.trim(), ""); idField.text = ""; } }
                Button { text: "Add"; onActivated: idField.accepted(idField.text) }
            }
        }
        SetRow { visible: Notes.syncError !== ""; icon: "error"; title: Notes.syncError }
        SetRow {
            icon: "history"
            title: "Older versions"
            description: "Syncthing keeps the last 10 versions of a changed or deleted note on this computer, in " + Notes.dir.replace(Quickshell.env("HOME"), "~") + "/.stversions"
        }
        SetRow {
            icon: "sync_disabled"
            title: "Stop syncing"
            description: "Stops Syncthing on this computer. Your notes stay where they are, here and on the phone."
            Button { text: "Stop"; onActivated: Notes.stopSync() }
        }
    }
}
