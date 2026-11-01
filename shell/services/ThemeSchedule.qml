pragma Singleton
// Theme by time of day (Settings → Appearance): your day theme from sunrise,
// your night theme from sunset (services/Sun, from the weather place), or by
// your own hours. Like night light it acts only when the wanted theme
// changes, so picking one by hand holds until the next sunrise or sunset.
// The main shell does this, never the Settings app.
import QtQuick
import Quickshell
import qs.theme

Singleton {
    id: root
    readonly property string auto: Persist.data.themeAuto ?? "off"        // "off" | "sun" | "custom"
    readonly property string day: Persist.data.themeDay ?? "light"
    readonly property string night: Persist.data.themeNight ?? "oled"
    readonly property bool active: auto !== "off"
    function mins(hhmm) { const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm ?? ""); return m ? (+m[1]) * 60 + (+m[2]) : -1; }
    // true: night now · false: day · null: can't tell (no place yet)
    function isNight() {
        const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
        let from, to;
        if (auto === "sun") {
            if (!Sun.known) return null;
            from = Sun.sunset.getHours() * 60 + Sun.sunset.getMinutes();
            to = Sun.sunrise.getHours() * 60 + Sun.sunrise.getMinutes();
        } else if (auto === "custom") {
            from = mins(Persist.data.themeNightFrom ?? "19:00"); to = mins(Persist.data.themeDayFrom ?? "07:00");
        } else return null;
        if (from < 0 || to < 0) return null;
        return from <= to ? now >= from && now < to : now >= from || now < to;
    }
    property var last: null
    onAutoChanged: last = null
    onDayChanged: last = null
    onNightChanged: last = null
    Timer {
        interval: 30000; repeat: true; triggeredOnStart: true
        running: root.active && Persist.automates
        onTriggered: {
            const n = root.isNight();
            if (n === null || n === root.last) return;
            root.last = n;
            const want = n ? root.night : root.day;
            if ((Theme.tokens.theme ?? "dark") === want) return;
            Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "theme", want]);
            Island.system(n ? "dark_mode" : "light_mode", (n ? "Night" : "Day") + " theme", root.auto === "sun" ? (n ? "Sunset" : "Sunrise") : "Scheduled");
        }
    }
}
