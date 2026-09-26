pragma Singleton

// Laptop battery via UPower (event-driven over D-Bus).
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Io

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real percentage: device?.percentage ?? 1          // 0–1
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool low: available && !pluggedIn && percentage <= 0.2
    readonly property bool critical: available && !pluggedIn && percentage <= 0.1
    readonly property real timeToEmpty: device?.timeToEmpty ?? 0         // seconds
    readonly property real timeToFull: device?.timeToFull ?? 0

    readonly property string icon: {
        if (charging || (pluggedIn && !full)) return "battery_charging_full";
        if (pluggedIn) return "battery_full";
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
                       "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
        return steps[Math.min(7, Math.floor(percentage * 8))];
    }

    function formatDuration(sec) {
        if (!sec || sec <= 0) return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    // ── Forecast ─────────────────────────────────────────────────────────────
    // Learned from this discharge: percentage samples of the last 15 minutes
    // give a rate; it's blended with UPower's estimate (which reacts to load
    // spikes). Right after unplugging, before there's a rate, your usual
    // battery life (hourly averages of the last 7 days) fills in.
    property var samples: []            // [{t: ms, p: 0–100}] on battery only
    property real ratePerHour: 0        // % per hour, learned
    readonly property real forecastMin: {
        if (mock) return mockMin;
        if (!available || pluggedIn) return -1;
        const pct = percentage * 100;
        const ours = ratePerHour > 0.5 ? pct / ratePerHour * 60 : -1;
        const upower = timeToEmpty > 0 ? timeToEmpty / 60 : -1;
        if (ours > 0 && upower > 0) return 0.6 * ours + 0.4 * upower;
        if (ours > 0) return ours;
        if (upower > 0) return upower;
        return usualRate > 0 ? pct / usualRate * 60 : -1;
    }
    readonly property string forecastText: forecastMin > 0 ? formatDuration(forecastMin * 60) : ""
    // "usually lasts 4h 10m" from a full charge, at your typical rate
    readonly property real usualRate: {
        const h = history.hours ?? [];
        const rates = h.filter(x => x.rate > 0.5).map(x => x.rate);
        if (rates.length < 2) return 0;
        rates.sort((a, b) => a - b);
        return rates[Math.floor(rates.length / 2)];      // median: one gaming hour doesn't skew it
    }
    readonly property string usualText: usualRate > 0 ? formatDuration(100 / usualRate * 3600) : ""

    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true
        running: root.available && !root.pluggedIn
        onTriggered: root.sample()
    }
    onPluggedInChanged: {
        if (pluggedIn) { samples = []; ratePerHour = 0; warned45 = false; warned15 = false; }
        else sample();
    }
    function sample() {
        const now = Date.now(), p = percentage * 100;
        const s = samples.filter(x => now - x.t < 15 * 60000).concat([{ t: now, p }]);
        samples = s;
        const first = s[0], mins = (now - first.t) / 60000;
        if (mins >= 4 && first.p > p) ratePerHour = (first.p - p) / mins * 60;
        record(now, p);
        checkForecast();
    }

    // Hourly averages of the drain, 7 days (~/.local/state/lumen/battery-history.json)
    property var hourStart: null        // {t, p} at the start of this hour on battery
    function record(now, p) {
        if (!hourStart || pluggedIn) { hourStart = { t: now, p }; return; }
        const mins = (now - hourStart.t) / 60000;
        if (mins < 60) return;
        const rate = (hourStart.p - p) / mins * 60;
        if (rate > 0) {
            const week = now - 7 * 86400000;
            history.hours = (history.hours ?? []).filter(x => x.t > week).concat([{ t: now, rate: Math.round(rate * 10) / 10 }]);
        }
        hourStart = { t: now, p };
    }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/battery-history.json"
        printErrors: false
        onAdapterUpdated: if (Persist.automates) writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound && Persist.automates) writeAdapter(); }
        JsonAdapter { id: history; property var hours: [] }
    }

    // The island: once below 45 min, again below 15 min, per discharge
    property bool warned45: false
    property bool warned15: false
    function checkForecast() {
        if (!Persist.automates) return;
        const m = forecastMin;
        if (m <= 0 || ratePerHour <= 0) return;
        if (m < 15 && !warned15) {
            warned15 = warned45 = true;
            Island.system("battery_alert", "Plug in within " + Math.max(1, Math.round(m)) + " min", "at this rate", "warning");
        } else if (m < 45 && !warned45) {
            warned45 = true;
            Island.system("battery_3_bar", "Plug in within " + Math.round(m / 5) * 5 + " min", "at this rate", "normal");
        }
    }

    // Reached 100 % with no charge limit set: say once a day that one helps
    property int chargeLimit: 0         // 0 = unsupported
    Process {
        running: root.available
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/charge_control_end_threshold\" ] && cat \"$b/charge_control_end_threshold\" && exit 0; done; echo 0"]
        stdout: StdioCollector { onStreamFinished: root.chargeLimit = parseInt(text) || 0 }
    }
    property real careShown: 0
    onFullChanged: {
        if (!full || !Persist.automates || chargeLimit !== 100 || Date.now() - careShown < 86400000) return;
        careShown = Date.now();
        Island.system("battery_full", "Charged to 100%", "On the charger all day? An 80% limit is gentler — Settings → Power", "normal");
    }

    // Dev only (LUMEN_DEV): a forecast without a discharge
    property bool mock: false
    IpcHandler {
        target: "batteryTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function forecast(min: int): void { root.mock = true; root.warned45 = false; root.warned15 = false; root.mockMin = min; root.checkMock(); }
        function off(): void { root.mock = false; root.mockMin = -1; }
        function state(): string { return JSON.stringify({ forecastMin: root.forecastMin, rate: root.ratePerHour, usual: root.usualText, samples: root.samples.length }); }
    }
    property int mockMin: -1
    function checkMock() {
        const m = mockMin;
        if (m < 15) Island.system("battery_alert", "Plug in within " + Math.max(1, m) + " min", "at this rate", "warning");
        else if (m < 45) Island.system("battery_3_bar", "Plug in within " + Math.round(m / 5) * 5 + " min", "at this rate", "normal");
    }
}
