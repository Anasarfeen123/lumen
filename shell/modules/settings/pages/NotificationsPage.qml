// Notifications: Focus, banners, sounds, per-app mute, history.
import QtQuick
import Quickshell
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

    Group {
        title: "Behaviour"
        SetRow {
            icon: "do_not_disturb_on"
            title: "Focus (Do Not Disturb)"
            description: "Hold everything except critical alerts. Super+Alt+N"
            LSwitch { checked: Notifications.dnd; onToggled: Notifications.setDnd(!Notifications.dnd) }
        }
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
    }

    Group {
        title: "Apps"
        visible: page.apps.length > 0
        Repeater {
            model: page.apps
            delegate: SetRow {
                required property var modelData
                title: modelData.name
                description: page.isMuted(modelData.name) ? "Muted — kept in history only" : "Banners and sound"
                icon: "apps"
                LSwitch { checked: !page.isMuted(modelData.name); onToggled: page.setMuted(modelData.name, checked) }
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
