pragma Singleton
// Caffeine: keep the computer awake — no dim, lock, screen-off or sleep.
//   start(minutes)   0 = until you switch it off; otherwise it ends by itself
//   lid              also keep running with the lid closed (downloads, music
//                    on a speaker, a build) — logind's lid action is held off
// Two locks while on, so it holds even when the bar is hidden (fullscreen):
// the bar's Wayland idle inhibitor (modules/bar/Bar.qml) and a logind "idle"
// inhibitor (systemd-inhibit), which hypridle honours too. Sleeping by hand
// (power menu, Super+Shift+L) always still works.
// Safety: it switches itself off on battery at 10%, so a forgotten Caffeine
// can't drain the laptop flat. Session-only on purpose: never survives a restart.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool on: false
    property double until: 0                 // ms epoch; 0 = no end
    property bool lid: false                 // keep running with the lid closed
    property int chosen: 0                   // the duration picked (minutes; 0 = until off)
    property double now: Date.now()
    readonly property int remaining: until > 0 ? Math.max(0, Math.round((until - now) / 1000)) : 0   // seconds
    readonly property string remainingText: until <= 0 ? "" : fmt(remaining)
    readonly property string label: !on ? "Off" : until > 0 ? remainingText + " left" : "Until you turn it off"

    function fmt(s) {
        const h = Math.floor(s / 3600), m = Math.ceil((s % 3600) / 60);
        return h > 0 ? h + "h " + (m === 60 ? 0 : m) + "m" : Math.max(1, m) + " min";
    }
    function nice(min) { return min <= 0 ? "until you turn it off" : min < 60 ? "for " + min + " min" : "for " + (min / 60) + (min === 60 ? " hour" : " hours"); }

    // ── controls ──
    function toggle() { if (on) stop(false); else start(0); }
    function start(minutes) {
        until = minutes > 0 ? Date.now() + minutes * 60000 : 0;
        chosen = Math.max(0, minutes);
        now = Date.now();
        on = true;
        Island.system("coffee", "Staying awake", (minutes > 0 ? nice(minutes) : "Until you turn it off") + (lid ? " · even with the lid closed" : ""));
    }
    function extend(minutes) { if (!on) { start(minutes); return; } until = (until > 0 ? until : Date.now()) + minutes * 60000; now = Date.now(); Island.system("coffee", "Staying awake", remainingText + " left"); }
    function stop(why) {
        if (!on) return;
        on = false; until = 0;
        Island.system("bedtime", "Caffeine off", why || "The screen can sleep again");
    }
    function setLid(v) { lid = v; }

    // Countdown and expiry (ticks only while a timer runs)
    Timer {
        interval: root.remaining > 120 ? 30000 : 1000
        repeat: true
        running: root.on && root.until > 0
        onTriggered: { root.now = Date.now(); if (root.remaining <= 0) root.stop("Your time was up"); }
    }
    // A forgotten Caffeine never drains the battery flat
    Connections {
        target: Battery
        function onPercentageChanged() {
            if (root.on && Battery.available && !Battery.pluggedIn && Battery.percentage <= 0.10)
                root.stop("Battery at " + Math.round(Battery.percentage * 100) + "% — sleeping is allowed again");
        }
    }

    // The logind lock: idle (always) and the lid switch (if asked). It lives
    // exactly as long as Caffeine is on; ending the process releases it.
    // A lid change needs a new lock: drop the current one, then re-bind
    onLidChanged: if (inhibit.running) { inhibit.running = false; Qt.callLater(() => inhibit.running = Qt.binding(() => root.on && Persist.automates)); }
    Process {
        id: inhibit
        running: root.on && Persist.automates
        command: ["systemd-inhibit", "--what=" + (root.lid ? "idle:handle-lid-switch" : "idle"), "--who=Lumen",
                  "--why=Caffeine: keeping the computer awake", "--mode=block", "sleep", "infinity"]
    }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.toggle(); }
        function off(): void { root.stop(false); }
        function minutes(n: int): void { root.start(n); }
        function lid(v: bool): void { root.setLid(v); }
        function state(): string { return JSON.stringify({ on: root.on, remaining: root.remaining, lid: root.lid }); }
    }
}
