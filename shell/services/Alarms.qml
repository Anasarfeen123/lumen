pragma Singleton
// Alarms: a time, the days it repeats (none = once), a label. When one goes
// off it rings — the chime every few seconds, a card with Snooze and Stop,
// your phone too (Lumen Link) — until you answer, or for five minutes.
//   Halo: "wake me up at 6:30", "alarm every weekday at 7", "alarm at 9pm for
//   the match", "my alarms", "turn off my alarms", "snooze" · search: "alarm 7:30"
// Also the world clock: "what time is it in London" (the system's time zones).
// The computer has to be awake (or locked) to ring; a suspended laptop can't.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    // [{ id, time: "HH:mm", days: [0–6, Sunday = 0] (empty: once), label, on }]
    readonly property var list: Persist.data.alarms ?? []
    property var ringing: null          // the alarm going off now
    property real ringStart: 0
    property var snoozed: []            // [{ at, alarm }]
    readonly property int snoozeMin: 10

    function save(l) { Persist.data.alarms = l.slice().sort((a, b) => a.time.localeCompare(b.time)); }
    function add(time, days, label) {
        const a = { id: Date.now().toString(36), time, days: days ?? [], label: label ?? "", on: true };
        save(list.filter(x => !(x.time === time && JSON.stringify(x.days) === JSON.stringify(a.days))).concat([a]));
        return a;
    }
    function remove(id) { save(list.filter(a => a.id !== id)); }
    function setOn(id, on) { save(list.map(a => a.id === id ? Object.assign({}, a, { on }) : a)); }
    function allOff() { save(list.map(a => Object.assign({}, a, { on: false }))); snoozed = []; }

    // ── words ──
    readonly property var dayShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    function daysText(days) {
        const d = (days ?? []).slice().sort();
        if (!d.length) return "once";
        if (d.length === 7) return "every day";
        if (JSON.stringify(d) === "[1,2,3,4,5]") return "weekdays";
        if (JSON.stringify(d) === "[0,6]") return "weekends";
        return d.map(i => dayShort[i]).join(", ");
    }
    function timeText(t) { const [h, m] = t.split(":").map(Number); const d = new Date(); d.setHours(h, m, 0, 0); return Theme.timeDigits(d) + (Theme.clock12h ? " " + Theme.timePeriod(d) : ""); }
    function describe(a) { return timeText(a.time) + " · " + daysText(a.days) + (a.label ? " · " + a.label : ""); }
    // when it next goes off
    function nextAt(a, from) {
        const now = from ?? new Date(), [h, m] = a.time.split(":").map(Number);
        for (let i = 0; i <= 7; i++) {
            const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, h, m, 0, 0);
            if (d <= now) continue;
            if (!a.days?.length || a.days.includes(d.getDay())) return d;
        }
        return null;
    }
    function inText(d) {
        const min = Math.round((d - Date.now()) / 60000);
        return min < 60 ? "in " + min + " min" : "in " + Math.floor(min / 60) + " h" + (min % 60 ? " " + (min % 60) + " min" : "");
    }
    readonly property var upcoming: list.filter(a => a.on).map(a => ({ a, at: nextAt(a) })).filter(x => x.at).sort((x, y) => x.at - y.at)

    // ── ringing ──
    function ring(a) {
        ringing = a; ringStart = Date.now();
        Halo.react("happy", 6000);              // wide awake for it, even if it was dozing
        Sounds.play("alarm", true);
        Halo.say({ key: "alarm", icon: "alarm", title: a.label || "Alarm", text: timeText(a.time) + (a.days?.length ? " · " + daysText(a.days) : ""),
                   level: "urgent", duration: 300000, speak: false,
                   actions: [{ label: "Snooze " + snoozeMin + " min", icon: "snooze", run: () => root.snooze() },
                             { label: "Stop", icon: "alarm_off", run: () => root.stop() }] });
        Link.notify("⏰ " + (a.label || "Alarm") + " · " + timeText(a.time));
        if (!a.days?.length && a.id) save(list.map(x => x.id === a.id ? Object.assign({}, x, { on: false }) : x));   // a one-off is done
    }
    function stop() { ringing = null; if (Island.active?.key === "halo:alarm") Island.dismiss(); }
    function snooze() {
        if (!ringing) return;
        snoozed = snoozed.concat([{ at: Date.now() + snoozeMin * 60000, alarm: Object.assign({}, ringing, { id: "", days: [] }) }]);
        Island.system("snooze", "Snoozed", "Again at " + Qt.formatTime(new Date(Date.now() + snoozeMin * 60000), Theme.clock12h ? "h:mm AP" : "HH:mm"));
        stop();
    }
    // the chime again every few seconds, five minutes at most
    Timer {
        interval: 4000; repeat: true; running: !!root.ringing
        onTriggered: { if (Date.now() - root.ringStart > 300000) root.stop(); else Sounds.play("alarm", true); }
    }

    // ── checking the time ── (the main shell only, so the Settings app doesn't ring too)
    property string lastKey: ""
    Timer {
        interval: 5000; repeat: true; triggeredOnStart: true
        running: Persist.automates && (root.list.length > 0 || root.snoozed.length > 0)
        onTriggered: {
            const now = new Date(), hm = Qt.formatTime(now, "HH:mm"), key = Qt.formatDate(now, "yyyy-MM-dd") + " " + hm;
            const due = root.snoozed.filter(s => s.at <= now.getTime());
            if (due.length) { root.snoozed = root.snoozed.filter(s => s.at > now.getTime()); root.ring(due[0].alarm); return; }
            if (key === root.lastKey) return;
            const a = root.list.find(x => x.on && x.time === hm && (!x.days?.length || x.days.includes(now.getDay())));
            if (a) { root.lastKey = key; root.ring(a); }
        }
    }

    // ── what you say ── ("7", "7:30", "6.45am", "9 pm", "21:00") → "HH:mm"
    function parseTime(s) {
        const m = /\b(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?\b/i.exec(s ?? "");
        if (!m) return "";
        let h = +m[1]; const mm = +(m[2] ?? 0), ap = (m[3] ?? "").toLowerCase();
        if (h > 23 || mm > 59) return "";
        if (ap.startsWith("p") && h < 12) h += 12;
        if (ap.startsWith("a") && h === 12) h = 0;
        if (!ap && h <= 12 && /\b(evening|tonight|night)\b/.test(s)) h = h === 12 ? 12 : h + 12;
        return String(h).padStart(2, "0") + ":" + String(mm).padStart(2, "0");
    }
    function parseDays(s) {
        if (/\b(every ?day|daily)\b/.test(s)) return [0, 1, 2, 3, 4, 5, 6];
        if (/\bweekdays?\b/.test(s)) return [1, 2, 3, 4, 5];
        if (/\bweekends?\b/.test(s)) return [0, 6];
        const names = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"], out = [];
        if (/\bevery\b/.test(s)) names.forEach((n, i) => { if (new RegExp("\\b" + n).test(s)) out.push(i); });
        return out;
    }

    // ── world clock ──
    function timeIn(place, cb) {
        const p = zoneProc.createObject(root, { cb });
        p.command = ["python3", "-c", root.zonePy, place];
        p.running = true;
    }
    readonly property string zonePy: 'import sys, zoneinfo, datetime as d\n'
        + 'q = sys.argv[1].lower().strip().replace(" ", "_")\n'
        + 'A = {"nyc": "America/New_York", "new_york": "America/New_York", "us": "America/New_York", "usa": "America/New_York", "america": "America/New_York",\n'
        + '     "la": "America/Los_Angeles", "sf": "America/Los_Angeles", "san_francisco": "America/Los_Angeles", "california": "America/Los_Angeles", "seattle": "America/Los_Angeles",\n'
        + '     "uk": "Europe/London", "england": "Europe/London", "britain": "Europe/London", "india": "Asia/Kolkata", "bangalore": "Asia/Kolkata", "bengaluru": "Asia/Kolkata",\n'
        + '     "mumbai": "Asia/Kolkata", "delhi": "Asia/Kolkata", "chennai": "Asia/Kolkata", "hyderabad": "Asia/Kolkata", "kerala": "Asia/Kolkata", "japan": "Asia/Tokyo",\n'
        + '     "china": "Asia/Shanghai", "beijing": "Asia/Shanghai", "germany": "Europe/Berlin", "france": "Europe/Paris", "australia": "Australia/Sydney", "canada": "America/Toronto",\n'
        + '     "korea": "Asia/Seoul", "uae": "Asia/Dubai", "abu_dhabi": "Asia/Dubai", "saudi": "Asia/Riyadh", "saudi_arabia": "Asia/Riyadh", "qatar": "Asia/Qatar", "doha": "Asia/Qatar",\n'
        + '     "russia": "Europe/Moscow", "italy": "Europe/Rome", "spain": "Europe/Madrid", "brazil": "America/Sao_Paulo", "texas": "America/Chicago", "chicago": "America/Chicago",\n'
        + '     "boston": "America/New_York", "washington": "America/New_York", "toronto": "America/Toronto", "vancouver": "America/Vancouver", "kl": "Asia/Kuala_Lumpur", "malaysia": "Asia/Kuala_Lumpur"}\n'
        + 'z = A.get(q) or next((t for t in sorted(zoneinfo.available_timezones()) if t.lower().split("/")[-1] == q), None)\n'
        + 'if z:\n'
        + '    t = d.datetime.now(zoneinfo.ZoneInfo(z)); here = d.datetime.now().astimezone()\n'
        + '    diff = (t.utcoffset() - here.utcoffset()).total_seconds() / 3600\n'
        + '    print(t.strftime("%H:%M") + "|" + t.strftime("%A") + "|" + ("%+g" % diff) + "|" + z)\n'
    Component {
        id: zoneProc
        Process {
            id: zp
            property var cb
            stdout: StdioCollector { onStreamFinished: { const f = text.trim().split("|"); zp.cb(f.length === 4 ? { time: f[0], day: f[1], diff: +f[2], zone: f[3] } : null); zp.destroy(); } }
        }
    }

    IpcHandler {
        target: "alarms"
        function add(time: string, days: string, label: string): string { const t = root.parseTime(time); if (!t) return "couldn't read " + time; root.add(t, days ? days.split(",").map(Number) : [], label); return t; }
        function list(): string { return JSON.stringify(root.list); }
        function ringNow(label: string): void { root.ring({ id: "", time: Qt.formatTime(new Date(), "HH:mm"), days: [], label }); }
        function stop(): void { root.stop(); }
        function snooze(): void { root.snooze(); }
    }
}
