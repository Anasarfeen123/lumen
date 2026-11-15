pragma Singleton
// On battery, two steps (the main shell does this, never the Settings app):
//
// Unplugged, at any charge (Settings → Power → On battery; each part a switch):
//   - the screen dims a step (Persist.batteryDim, 15 % by default); plugging in
//     brings your brightness back, unless you've changed it since
//   - animations calm down (Theme.calm: the same short, plain motion as
//     reduced motion)
//   - heavy background jobs wait (`defer`): past papers, the notes index, VTOP
//     syncs (services/Study.qml); AI limits check every 20 min instead of 5
//   - the music visualiser rests (it runs cava)
// Low (unplugged, 20 % or less), as well: blur drops to one light pass. Your own
// blur settings come back the moment you plug in or it's charged past 20 %.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property bool active: Battery.low && Persist.automates
    property var saved: null            // { passes, size } before lightening

    // ── unplugged, at any charge ──
    readonly property bool inShell: Quickshell.env("LUMEN_SETTINGS_APP") !== "1"
    readonly property bool onBattery: inShell && Persist.automates && Battery.available && !Battery.pluggedIn && (Persist.data.batteryAware ?? true)
    readonly property bool calm: onBattery && (Persist.data.batteryCalm ?? true)
    readonly property bool defer: onBattery && (Persist.data.batteryDefer ?? true)
    readonly property bool restVisualizer: active || (onBattery && (Persist.data.batteryVisualizer ?? true))
    Binding { target: Theme; property: "calm"; value: root.calm }

    property real dimmedFrom: -1        // your brightness before the battery step (-1: not dimmed)
    property real dimmedTo: -1
    onOnBatteryChanged: onBattery ? dim() : undim()
    function dim() {
        const step = (Persist.data.batteryDim ?? 15) / 100;
        if (step <= 0 || dimmedFrom >= 0 || Brightness.value <= 0.05) return;
        dimmedFrom = Brightness.value;
        dimmedTo = Math.max(0.05, Brightness.value - step);
        Brightness.set(dimmedTo);
    }
    function undim() {
        if (dimmedFrom < 0) return;
        // only if it's still where we left it: a change of yours stays
        if (Math.abs(Brightness.value - dimmedTo) < 0.03) Brightness.set(dimmedFrom);
        dimmedFrom = -1; dimmedTo = -1;
    }
    Connections { target: Brightness; function onChangedByUser() { root.dimmedFrom = -1; root.dimmedTo = -1; } }
    IpcHandler {
        target: "lowpower"
        function state(): string { return JSON.stringify({ onBattery: root.onBattery, calm: root.calm, defer: root.defer, low: root.active, dimmedFrom: root.dimmedFrom, visualizerRests: root.restVisualizer }); }
    }

    onActiveChanged: active ? lighten() : restore()
    Component.onCompleted: if (active) lighten()

    function lighten() {
        reader.running = true;          // remember yours first, then lighten
    }
    function restore() {
        if (!saved) return;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { blur = { passes = ${saved.passes}, size = ${saved.size} } } })`]);
        saved = null;
        Island.system("battery_full", "Visuals back to normal", "");
    }
    Process {
        id: reader
        command: ["sh", "-c", 'hyprctl getoption decoration:blur:passes | sed -n "s/^int: //p"; hyprctl getoption decoration:blur:size | sed -n "s/^int: //p"']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/).map(Number);
                if (!root.active || v.length < 2 || isNaN(v[0])) return;
                if (!root.saved) root.saved = { passes: v[0], size: v[1] };
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { passes = 1, size = 4 } } })"]);
                Island.system("battery_saver", "Lighter visuals", "Battery " + Math.round(Battery.percentage * 100) + "% — less blur, the visualiser rests");
            }
        }
    }
}
