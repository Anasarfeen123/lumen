// Notifications: Focus modes + schedules, banners, sounds, per-app mute, history.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Notifications"
    subtitle: "Arrivals appear in the island; everything is kept in the control centre (Super+N)."

    // Apps seen in history, most recent first
    readonly property var apps: {
        Notifications.count;
        const seen = [];
        for (let i = 0; i < Notifications.model.count; i++) {
            const e = Notifications.model.get(i);
            if (!seen.some(a => a.name === e.appName)) seen.push({ name: e.appName, icon: e.icon });
        }
        for (const m of (Persist.data.mutedApps ?? []))
            if (!seen.some(a => a.name === m)) seen.push({ name: m, icon: "" });
        return seen;
    }
    function isMuted(app) { return (Persist.data.mutedApps ?? []).includes(app); }
    function setMuted(app, on) {
        const list = (Persist.data.mutedApps ?? []).filter(a => a !== app);
        if (on) list.push(app);
        Persist.data.mutedApps = list;
    }

    // ── Focus: the mode lives in the shell; ask it, and tell it ──
    property string focusMode: "off"
    Process { id: focusGet; running: true; command: [Theme.lumenRoot + "/bin/lumen-shell-ipc", "focus", "get"]
              stdout: StdioCollector { onStreamFinished: if (text.trim()) page.focusMode = text.trim() } }
    function setFocus(m) { focusMode = m; Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "focus", "set", m]); }
    readonly property var sched: Persist.data.focusSchedule ?? ({ sleep: {}, work: {} })
    function setSched(which, key, value) {
        const s = JSON.parse(JSON.stringify(sched));
        s[which] = Object.assign({}, s[which] ?? {}, { [key]: value });
        Persist.data.focusSchedule = s;
    }
    function validTime(t) { return /^([01]?\d|2[0-3]):[0-5]\d$/.test(t.trim()); }

    component TimeField: LField {
        property string which
        property string key
        width: 78
        clearOnAccept: false
        text: page.sched[which]?.[key] ?? ""
        onAccepted: t => { if (page.validTime(t)) page.setSched(which, key, t.trim()); else text = page.sched[which]?.[key] ?? ""; }
        input.onActiveFocusChanged: if (!input.activeFocus) accepted(text)
    }

    Group {
        title: "Focus"
        SetRow {
            icon: "do_not_disturb_on"
            title: "Mode"
            description: ({ off: "Everything can reach you", dnd: "Only urgent alerts", work: "Quiet, except apps you allow below",
                            deep: "25-min focus rounds, quiet, dimmed wallpaper", study: "50/10 rounds, quiet, agenda at hand",
                            game: "Effects off, notifications held", sleep: "Quiet and warm light" })[page.focusMode] ?? ""
            Segmented {
                width: 470
                options: [{ id: "off", label: "Off" }, { id: "dnd", label: "DND" }, { id: "deep", label: "Deep" }, { id: "study", label: "Study" },
                          { id: "work", label: "Work" }, { id: "game", label: "Game" }, { id: "sleep", label: "Sleep" }]
                current: page.focusMode
                onPicked: id => page.setFocus(id)
            }
        }
        SetRow {
            icon: "bedtime"
            title: "Sleep on a schedule"
            description: "Quiet and warm light every night"
            Row {
                spacing: Theme.space.s2
                TimeField { which: "sleep"; key: "from"; enabled: page.sched.sleep?.on ?? false; opacity: enabled ? 1 : 0.5 }
                LText { text: "to"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                TimeField { which: "sleep"; key: "to"; enabled: page.sched.sleep?.on ?? false; opacity: enabled ? 1 : 0.5 }
                LSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.sched.sleep?.on ?? false; onToggled: page.setSched("sleep", "on", !checked) }
            }
        }
        SetRow {
            icon: "work"
            title: "Work on a schedule"
            description: (page.sched.work?.weekdays ?? true) ? "Weekdays only" : "Every day"
            Row {
                spacing: Theme.space.s2
                TimeField { which: "work"; key: "from"; enabled: page.sched.work?.on ?? false; opacity: enabled ? 1 : 0.5 }
                LText { text: "to"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                TimeField { which: "work"; key: "to"; enabled: page.sched.work?.on ?? false; opacity: enabled ? 1 : 0.5 }
                Button { text: (page.sched.work?.weekdays ?? true) ? "Mon–Fri" : "Daily"; onActivated: page.setSched("work", "weekdays", !(page.sched.work?.weekdays ?? true)) }
                LSwitch { anchors.verticalCenter: parent.verticalCenter; checked: page.sched.work?.on ?? false; onToggled: page.setSched("work", "on", !checked) }
            }
        }
    }

    Group {
        title: "Behaviour"
        SetRow {
            icon: "notifications_active"
            title: "Show banners"
            description: "When off, notifications go straight to history without appearing"
            LSwitch { checked: Persist.data.notifBanners; onToggled: Persist.data.notifBanners = !checked }
        }
        SetRow {
            icon: "music_note"
            title: "Sound"
            description: "A soft chime on arrival (UI sounds must be on — Appearance)"
            LSwitch { checked: Persist.data.uiSounds; onToggled: Persist.data.uiSounds = !checked }
        }
        SetRow {
            icon: "lock"
            title: "On the lock screen"
            description: "Only a count and app names — never what they say"
        }
        SetRow {
            icon: "videocam"
            title: "Meeting mode"
            description: "Hold notifications during calls (Meet, Zoom, Teams, Discord… or the camera on), keep the screen awake and pause a focus timer. The island says what waited. A red dot in the Ribbon shows whenever the mic or camera is in use."
            LSwitch { checked: Meeting.enabled; onToggled: Meeting.setEnabled(!checked) }
        }
    }

    Group {
        title: "Apps"
        visible: page.apps.length > 0
        Repeater {
            model: page.apps
            delegate: SetRow {
                required property var modelData
                title: modelData.name
                readonly property bool allowed: (Persist.data.focusAllow ?? []).includes(modelData.name)
                description: page.isMuted(modelData.name) ? "Muted — kept in history only"
                           : allowed ? "Banners and sound · gets through Work focus" : "Banners and sound"
                icon: "apps"
                Row {
                    spacing: Theme.space.s3
                    Button {
                        text: appRow.allowed ? "Allowed in Work" : "Allow in Work"
                        icon: appRow.allowed ? "check" : "work"
                        onActivated: {
                            const l = (Persist.data.focusAllow ?? []).filter(a => a !== modelData.name);
                            if (!appRow.allowed) l.push(modelData.name);
                            Persist.data.focusAllow = l;
                        }
                    }
                    LSwitch { anchors.verticalCenter: parent.verticalCenter; checked: !page.isMuted(modelData.name); onToggled: page.setMuted(modelData.name, checked) }
                }
            }
        }
    }

    Group {
        title: "History"
        SetRow {
            icon: "history"
            title: Notifications.count + (Notifications.count === 1 ? " notification" : " notifications")
            description: "Clear everything in the control centre"
            Button { text: "Clear all"; enabled: Notifications.count > 0; onActivated: Notifications.clearAll() }
        }
    }
}
