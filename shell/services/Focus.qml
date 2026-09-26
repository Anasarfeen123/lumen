pragma Singleton
// Focus modes — one choice sets several things, and undoing it restores them.
//
//   off      as you left things
//   dnd      Do Not Disturb only
//   work     Do Not Disturb (allowed apps still get through)
//   game     Game mode: effects off, notifications held
//   sleep    Do Not Disturb + night light
//
// Schedules (Settings → Notifications): Sleep and Work can switch on and off
// by the clock. A mode you pick by hand stays until the next schedule edge.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower

Singleton {
    id: root
    property string mode: "off"
    readonly property var modes: [
        { id: "off",   icon: "do_not_disturb_off", label: "Off",            detail: "Everything can reach you" },
        { id: "dnd",   icon: "do_not_disturb_on",  label: "Do Not Disturb", detail: "Only urgent alerts" },
        { id: "deep",  icon: "psychology",         label: "Deep work",      detail: "25-minute focus rounds, quiet, calmer desktop",
          does: ["Notifications held (allowed apps still reach you)", "Pomodoro: 25 min focus · 5 min break", "Wallpaper dimmed", "Caffeine on — no sleep mid-thought"] },
        { id: "study", icon: "school",             label: "Study",          detail: "50/10 rounds, quiet, your agenda at hand",
          does: ["Notifications held (allowed apps still reach you)", "Pomodoro: 50 min focus · 10 min break", "Wallpaper dimmed", "Planner opens with your agenda"] },
        { id: "work",  icon: "work",               label: "Work",           detail: "Quiet, except apps you allow",
          does: ["Notifications held (allowed apps still reach you)"] },
        { id: "game",  icon: "sports_esports",     label: "Game",           detail: "Effects off, notifications held",
          does: ["Animations, blur and shadows off", "Performance power mode", "Notifications held"] },
        { id: "sleep", icon: "bedtime",            label: "Sleep",          detail: "Quiet and warm light",
          does: ["Notifications held (critical still come)", "Night light on"] },
    ]
    readonly property var current: modes.find(m => m.id === mode) ?? modes[0]
    readonly property var allow: Persist.data.focusAllow ?? []
    readonly property bool dimWallpaper: mode === "deep" || mode === "study"

    // What we changed, so turning a mode off puts it back
    property var saved: null

    function set(m) {
        if (m === mode) return;
        // Undo the previous mode
        if (mode === "game" && GameMode.on) GameMode.toggle();
        if ((mode === "deep" || mode === "study") && Countdown.cycle) Countdown.stop();
        if (saved) {
            if (saved.caffeine !== undefined && Caffeine.on !== saved.caffeine) Caffeine.toggle();
            if (saved.profile !== undefined) PowerProfiles.profile = saved.profile;
            if (saved.nightLight !== undefined && NightLight.enabled !== saved.nightLight) NightLight.toggle();
            if (Notifications.dnd !== saved.dnd) Notifications.setDnd(saved.dnd, true);
            saved = null;
        }
        mode = m;
        if (m === "off") { Island.system("do_not_disturb_off", "Focus off", "Everything can reach you"); return; }
        saved = { dnd: Notifications.dnd, nightLight: NightLight.enabled, caffeine: Caffeine.on, profile: PowerProfiles.profile };
        if (m === "game") {
            if (!GameMode.on) GameMode.toggle();                 // GameMode announces itself
            PowerProfiles.profile = PowerProfile.Performance;
            return;
        }
        if (m === "deep" || m === "study") {
            if (!Caffeine.on) Caffeine.toggle();
            Countdown.startCycle(m === "deep" ? 25 : 50, m === "deep" ? 5 : 10);
            if (m === "study") Planner.open = true;
        }
        Notifications.setDnd(true, true);          // the mode announces itself
        if (m === "sleep" && !NightLight.enabled) NightLight.toggle();
        Island.system(current.icon, current.label + " on", current.detail);
    }

    // Allowed apps break through Work (not Sleep, not Game)
    function lets(appName) { return ["work", "deep", "study"].includes(mode) && allow.includes(appName); }

    // ── schedule ──
    function minutes(hhmm) { const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm ?? ""); return m ? (+m[1]) * 60 + (+m[2]) : -1; }
    function within(now, from, to) { return from <= to ? now >= from && now < to : now >= from || now < to; }
    function scheduled() {
        const s = Persist.data.focusSchedule ?? {};
        const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
        if (s.sleep?.on && within(now, minutes(s.sleep.from), minutes(s.sleep.to))) return "sleep";
        const weekday = d.getDay() >= 1 && d.getDay() <= 5;
        if (s.work?.on && (!s.work.weekdays || weekday) && within(now, minutes(s.work.from), minutes(s.work.to))) return "work";
        return "off";
    }
    property string lastScheduled: ""
    Timer {
        // Only the shell applies schedules (never the separate Settings app)
        interval: 30000; running: Persist.automates; repeat: true; triggeredOnStart: true
        onTriggered: {
            const want = root.scheduled();
            // Act only on an edge, so a hand-picked mode isn't overridden every minute
            if (want !== root.lastScheduled) {
                if (root.lastScheduled !== "" || want !== "off") root.set(want);
                root.lastScheduled = want;
            }
        }
    }

    GlobalShortcut { appid: "lumen"; name: "focusCycle"; description: "Cycle Focus modes"; onPressed: root.set(root.modes[(root.modes.findIndex(m => m.id === root.mode) + 1) % root.modes.length].id) }
    IpcHandler {
        target: "focus"
        function set(m: string): void { if (root.modes.some(x => x.id === m)) root.set(m); }
        function get(): string { return root.mode; }
    }
}
