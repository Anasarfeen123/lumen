pragma Singleton

// Night light via hyprsunset. The process exists only while night light is
// on; stopping it hands the screen back to normal colours.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Singleton {
    id: root
    readonly property bool enabled: Persist.data.nightLight
    readonly property int temperature: Persist.data.nightLightTemp

    function toggle() { Persist.data.nightLight = !Persist.data.nightLight; }

    // ── Automatic (Settings → Display) ──
    //   sun: on at sunset, off at sunrise (services/Sun) · custom: your hours
    // Acts only when the wanted state changes, so switching it by hand holds
    // until the next edge. The shell does this, never the Settings app.
    readonly property string auto: Persist.data.nightLightAuto ?? "off"
    function mins(hhmm) { const m = /^(\d{1,2}):(\d{2})$/.exec(hhmm ?? ""); return m ? (+m[1]) * 60 + (+m[2]) : -1; }
    function wanted() {
        const d = new Date(), now = d.getHours() * 60 + d.getMinutes();
        let from, to;
        if (auto === "sun") { from = Sun.sunset.getHours() * 60 + Sun.sunset.getMinutes(); to = Sun.sunrise.getHours() * 60 + Sun.sunrise.getMinutes(); }
        else if (auto === "custom") { from = mins(Persist.data.nightLightFrom); to = mins(Persist.data.nightLightTo); }
        else return null;
        if (from < 0 || to < 0) return null;
        return from <= to ? now >= from && now < to : now >= from || now < to;
    }
    property var lastWanted: null
    onAutoChanged: lastWanted = null
    Timer {
        interval: 30000; running: root.auto !== "off" && Persist.automates; repeat: true; triggeredOnStart: true
        onTriggered: {
            const w = root.wanted();
            if (w === null || w === root.lastWanted) return;
            root.lastWanted = w;
            if (w !== root.enabled) {
                Persist.data.nightLight = w;
                Island.system("nightlight", w ? "Night light on" : "Night light off", root.auto === "sun" ? (w ? "Sunset" : "Sunrise") : "Scheduled");
            }
        }
    }

    // Restarted automatically if it dies (e.g. across suspend/resume)
    SupervisedProcess {
        wanted: root.enabled
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
}
