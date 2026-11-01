pragma Singleton

// Night light via hyprsunset. The process exists only while night light is
// on; stopping it hands the screen back to normal colours.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
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
    // Colour-accurate apps (Settings → Display): night light steps aside while
    // one of them is the window you're using, and comes back when you leave it
    readonly property var exceptions: Persist.data.nightLightExcept ?? ["gimp", "krita", "inkscape", "darktable", "rawtherapee", "figma", "blender", "photoshop", "affinity", "digikam", "kdenlive", "davinci", "resolve"]
    readonly property string focusedClass: (Hyprland.activeToplevel?.lastIpcObject?.class ?? "").toLowerCase()
    readonly property bool excepted: focusedClass !== "" && exceptions.some(e => e && focusedClass.includes(e.toLowerCase()))
    // One hyprsunset for both night light and extra dim (Brightness.extraDim:
    // the picture dimmed below the backlight's lowest). hyprsunset 0.4.0
    // crashes when told a new value over its socket (CHyprsunset::reload →
    // commitCTMs, SIGSEGV), so a change restarts it with the new values —
    // after a short pause, so a burst of key presses is one restart.
    readonly property bool warm: root.enabled && !root.excepted
    readonly property int gamma: Brightness.extraDim
    readonly property var args: warm ? ["hyprsunset", "-t", String(root.temperature), "-g", String(root.gamma)]
                                     : ["hyprsunset", "-i", "-g", String(root.gamma)]
    readonly property bool need: (warm || gamma < 100) && Quickshell.env("LUMEN_SETTINGS_APP") !== "1"
    // driven in steps, never by bindings racing each other: settle → (stop →
    // wait for it to exit →) start with the values of now
    property var cmd: args
    property bool want: false
    property bool startAfterExit: false
    onArgsChanged: settle.restart()
    onNeedChanged: settle.restart()
    Component.onCompleted: settle.restart()
    Timer {
        id: settle; interval: 180
        onTriggered: {
            if (!root.need) { root.startAfterExit = false; root.want = false; return; }
            const same = JSON.stringify(root.cmd) === JSON.stringify(root.args);
            if (sunset.running && same) return;
            if (sunset.running) { root.startAfterExit = true; root.want = false; return; }
            root.cmd = root.args; root.want = true;
        }
    }
    SupervisedProcess {
        id: sunset
        wanted: root.want
        command: root.cmd
        onRunningChanged: if (!running && root.startAfterExit) { root.startAfterExit = false; settle.restart(); }
    }
}
