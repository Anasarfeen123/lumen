pragma Singleton
// AmazeCC — your VIT day from VTOP: timetable, attendance, marks and exams,
// through an AmazeCC API (your own, on this computer, by default) and
// scripts/amazecc.py, which keeps the VTOP login in the system keyring.
//   today       the classes on today's timetable (holidays and "Monday Day
//               Order" Saturdays from the academic calendar included)
//   reminders   the island, and your phone over Lumen Link, a few minutes
//               before each class, the evening before an exam, and an hour
//               before you have to report for it
//   alerts      a new mark, attendance slipping towards (or under) the
//               minimum, an exam scheduled or a seat allotted — as
//               notifications (so Focus and Do Not Disturb apply), and on
//               your phone
//   agenda      exams and holidays appear in the planner's Agenda
// Settings: ~/.local/state/lumen/amazecc.json · data: amazecc-data.json
// (mode 600). Only the main shell syncs and announces (Persist.automates).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    readonly property string script: Theme.lumenRoot + "/scripts/amazecc.py"
    readonly property string webUrl: "https://amazecc.com"

    // ── settings ──
    readonly property alias cfg: adapter
    FileView {
        path: Persist.dir + "/amazecc.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property bool enabled: true
            property string api: "http://127.0.0.1:3000"   // your own amazecc-api
            property string semester: ""                  // empty: the one AmazeCC opens by default
            property int syncMinutes: 60
            property bool islandNext: true                // next class when you hover the island
            property bool classReminders: true
            property int reminderMinutes: 10
            property bool examReminders: true
            property bool attendanceAlerts: true
            property int threshold: 75                    // VIT's minimum, in %
            property bool marksAlerts: true
            property bool examsInAgenda: true
            property bool holidaysInAgenda: true
            property bool phoneAlerts: true               // alerts also on your phone (Lumen Link)
            property bool phoneReminders: true            // class and exam reminders on your phone
            property var reminded: ({})                   // reminder key → when, so a restart doesn't repeat one
        }
    }

    // ── the snapshot amazecc.py writes ──
    property var data: ({})
    FileView {
        id: dataFile
        path: Persist.dir + "/amazecc-data.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.data = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: root.data = ({})
    }
    readonly property var courses: data.courses ?? []
    readonly property var marks: data.marks ?? []
    readonly property var exams: data.exams ?? []
    readonly property real updated: data.updated ?? 0
    readonly property bool ready: courses.length > 0

    // ── status ──
    property bool hasLogin: false
    property string username: ""
    property bool apiUp: false
    property string semesterId: ""
    property string defaultSemester: ""
    property var semesters: []                    // every semester AmazeCC knows, oldest first
    property bool syncing: false
    property string error: ""
    // "CH20262701" → "Fall 2026-27" (AmazeCC's own naming)
    function semesterName(id) {
        const s = String(id ?? "").toUpperCase();
        if (!/^CH\d{8}$/.test(s)) return s;
        const term = ({ "01": "Fall", "05": "Winter", "07": "Summer" })[s.slice(8)] ?? "Term " + s.slice(8);
        return term + " " + s.slice(2, 6) + "-" + s.slice(6, 8);
    }
    // Newest first, for pickers; "" means follow AmazeCC's current semester
    readonly property var semesterOptions: [{ id: "", label: defaultSemester ? "Current · " + semesterName(defaultSemester) : "Current semester" }]
        .concat(semesters.slice().reverse().map(s => ({ id: s, label: semesterName(s), detail: s })))
    function setSemester(id) {
        if (cfg.semester === id) return;
        cfg.semester = id;
        refreshStatus();
        if (hasLogin) requestSync();       // the new semester's timetable, now
    }
    function refreshStatus() { if (!statusProc.running) statusProc.running = true; }
    function args() { return [script, "--api", cfg.api, "--semester", cfg.semester, "--threshold", String(cfg.threshold)]; }
    Process {
        id: statusProc
        running: true
        command: root.args().concat(["status"])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.hasLogin = s.hasLogin; root.username = s.username;
                    root.apiUp = s.apiUp; root.semesterId = s.semester;
                    root.defaultSemester = s.defaultSemester ?? s.semester; root.semesters = s.semesters ?? [];
                } catch (e) {}
            }
        }
    }

    // ── sign in / out (the password goes to amazecc.py on stdin, then the keyring) ──
    property bool signingIn: false
    property string signInError: ""
    function signIn(user, password) {
        if (signingIn || !user.trim() || !password) return;
        signingIn = true; signInError = "";
        loginProc.command = args().concat(["set-login", user.trim()]);
        loginProc.running = true;
        loginProc.write(password + "\n");
    }
    Process {
        id: loginProc
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                root.signingIn = false;
                let r; try { r = JSON.parse(text); } catch (e) { root.signInError = "Signing in failed"; return; }
                if (!r.ok) { root.signInError = r.error; return; }
                root.hasLogin = true; root.username = r.username;
                root.requestSync();
            }
        }
        onExited: { root.signingIn = false; root.refreshStatus(); }
    }
    function signOut() { Quickshell.execDetached(args().concat(["forget"])); hasLogin = false; username = ""; data = ({}); statusSoon.restart(); }
    Timer { id: statusSoon; interval: 1500; onTriggered: root.refreshStatus() }

    // ── sync ──
    // From the Settings app (a separate process), ask the shell, so it's the
    // shell that announces what changed.
    function requestSync() {
        if (Persist.automates) sync(true);
        else Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "amazecc", "sync"]);
    }
    function sync(manual) {
        if (syncProc.running || !cfg.enabled) return;
        syncing = true;
        syncProc.manual = manual === true;
        syncProc.command = args().concat(["sync"]);
        syncProc.running = true;
    }
    Process {
        id: syncProc
        property bool manual: false
        stdout: StdioCollector { onStreamFinished: root.synced(text, syncProc.manual) }
        onExited: root.syncing = false
    }
    function synced(text, manual) {
        syncing = false;
        let r;
        try { r = JSON.parse(text); } catch (e) { error = "The sync helper didn't answer"; return; }
        if (!r.ok) {
            if (r.error === "nologin") { hasLogin = false; error = ""; return; }
            error = r.error ?? "Sync failed";
            if (manual) Island.system("sync_problem", "AmazeCC couldn't sync", error, "warning");
            return;
        }
        error = "";
        dataFile.reload();
        if (manual) Island.system("cloud_done", "AmazeCC is up to date",
                                  r.partial?.length ? "Couldn't get " + r.partial.join(" or ") + " this time" : "Timetable, attendance, marks and exams");
        if (Persist.automates) for (const c of r.changes ?? []) announce(c);
    }
    // Every hour (from 6 in the morning to midnight), and soon after Lumen
    // starts if the snapshot is older than that
    Timer {
        interval: Math.max(15, root.cfg.syncMinutes) * 60000
        repeat: true
        running: Persist.automates && root.cfg.enabled && root.hasLogin
        onTriggered: if (new Date().getHours() >= 6) root.sync(false)
    }
    Timer {
        interval: 20000
        running: Persist.automates && root.cfg.enabled && root.hasLogin
        onTriggered: if (Date.now() - root.updated > root.cfg.syncMinutes * 60000) root.sync(false)
    }

    // ── announcing changes ──
    function fmt(n) { return n === null || n === undefined ? "–" : Number.isInteger(n) ? String(n) : n.toFixed(1); }
    function notify(icon, title, body) { Quickshell.execDetached(["notify-send", "-a", "AmazeCC", "-i", icon, title, body]); }
    function toPhone(text) { if (cfg.phoneAlerts) Link.notify(text); }
    function announce(c) {
        if (c.kind === "mark" && cfg.marksAlerts) {
            const pct = c.max ? Math.round(100 * c.scored / c.max) : null;
            const body = c.assessment + " · " + fmt(c.scored) + " / " + fmt(c.max) + (pct !== null ? " (" + pct + "%)" : "")
                       + (c.weightMark !== null && c.weight ? " · " + fmt(c.weightMark) + " of " + fmt(c.weight) + " weightage" : "");
            notify("grading", (c.updated ? "Mark updated · " : "New mark · ") + c.title, body);
            toPhone((c.updated ? "Mark updated: " : "New mark: ") + c.title + " — " + body);
        } else if (c.kind === "attendance" && cfg.attendanceAlerts) {
            const course = courses.find(x => x.id === c.id) ?? c;
            const body = c.state === "below"
                ? c.pct + "% (" + c.attended + "/" + c.total + ") — under " + cfg.threshold + "%. Attend the next " + needed(course) + " to get back."
                : c.pct + "% (" + c.attended + "/" + c.total + ") — " + (skippable(course) === 0 ? "don't miss the next one" : "you can miss " + skippable(course) + " more");
            notify("warning", "Attendance · " + c.title, body);
            toPhone("Attendance — " + c.title + ": " + body);
        } else if (c.kind === "exam" && cfg.examReminders) {
            const when = Planner.whenLabel(c.when, !c.timed);
            const title = c.what === "seat" ? "Seat allotted · " + c.title : c.what === "moved" ? "Exam moved · " + c.title : c.examKind + " scheduled · " + c.title;
            const body = [when, c.venue, c.seat].filter(x => x).join(" · ");
            notify("event", title, body);
            toPhone(title + " — " + body);
        }
    }

    // ── attendance maths ──
    // How many more you can miss and stay at or above the minimum, and how
    // many in a row you need to get back to it (VTOP's own percentages shown).
    function skippable(c) {
        const t = cfg.threshold / 100;
        if (!c?.total) return 0;
        return Math.max(0, Math.floor(c.attended / t - c.total + 1e-9));
    }
    function needed(c) {
        const t = cfg.threshold / 100;
        if (!c?.total) return 0;
        return Math.max(0, Math.ceil((t * c.total - c.attended) / (1 - t) - 1e-9));
    }
    function attendanceTone(c) {
        if (c?.pct === null || c?.pct === undefined) return "normal";
        return c.pct < cfg.threshold ? "error" : c.pct < cfg.threshold + 5 ? "warning" : "normal";
    }
    // Courses that need care, worst first
    readonly property var attention: courses.filter(c => c.pct !== null && c.pct < cfg.threshold + 5).sort((a, b) => a.pct - b.pct)

    // ── the day ──
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var dayNames: ({ MON: "Monday", TUE: "Tuesday", WED: "Wednesday", THU: "Thursday", FRI: "Friday", SAT: "Saturday", SUN: "Sunday" })
    function dateKey(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    function dayInfo(d) { const k = dateKey(d); return (data.days ?? []).find(x => x.date === k) ?? null; }
    function classesOn(d) {
        const info = dayInfo(d);
        if (info?.kind === "holiday") return [];
        const order = info?.order ?? ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][d.getDay()];
        return (data.week ?? {})[order] ?? [];
    }
    readonly property var todayInfo: dayInfo(clock.date)
    readonly property var today: classesOn(clock.date)
    readonly property int nowMin: clock.date.getHours() * 60 + clock.date.getMinutes()
    readonly property var current: today.find(c => c.start <= nowMin && nowMin < c.end) ?? null
    readonly property var next: today.find(c => c.start > nowMin) ?? null
    // By value: views get copies (Repeater models), so identity can't be trusted
    function isCurrent(c) { return !!current && !!c && current.id === c.id && current.start === c.start; }
    // When today is done: the first class of the next day that has any
    readonly property var nextDay: {
        if (next || !ready) return null;
        for (let i = 1; i <= 7; i++) {
            const d = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate() + i);
            const list = classesOn(d);
            if (list.length) return { date: d, first: list[0], count: list.length };
        }
        return null;
    }
    function clockLabel(min) {
        const d = new Date(2000, 0, 1, Math.floor(min / 60), min % 60);
        return Qt.formatTime(d, Theme.timeFormatFull);
    }
    function inLabel(min) {
        const m = min - nowMin;
        return m <= 0 ? "now" : m < 60 ? "in " + m + " min" : "in " + Math.floor(m / 60) + " h" + (m % 60 ? " " + (m % 60) + " min" : "");
    }
    // One line for the island and the bar: what's on now / next
    readonly property string headline: {
        if (!cfg.enabled || !ready) return "";
        if (current) return current.title + " · " + (current.venue || "now") + " · till " + clockLabel(current.end);
        if (next) return next.title + " · " + (next.venue ? next.venue + " · " : "") + inLabel(next.start);
        return "";
    }

    // ── the planner's Agenda: exams, holidays and changed day orders ──
    readonly property var agenda: {
        if (!cfg.enabled) return [];
        const out = [];
        if (cfg.examsInAgenda)
            for (const e of exams)
                out.push({ title: e.kind + " · " + e.title, when: e.when, allDay: !e.timed,
                           external: true, source: "amazecc", detail: [e.venue, e.seat].filter(x => x).join(" · ") });
        if (cfg.holidaysInAgenda)
            for (const d of data.days ?? []) {
                if (d.kind !== "holiday" && !d.order) continue;
                const text = d.order ? "Classes follow " + dayNames[d.order] + "'s timetable"
                                     : (d.text.split(" · ")[0] || "Holiday").replace(/\s*-\s*holiday$/i, "") + " — no classes";
                out.push({ title: text, when: new Date(d.date + "T00:00").getTime(), allDay: true, external: true, source: "amazecc" });
            }
        return out;
    }

    // ── reminders (main shell only) ──
    function remindFlag(key) {
        if ((cfg.reminded ?? {})[key]) return false;
        const now = Date.now(), r = {};
        for (const k in cfg.reminded ?? {}) if (now - cfg.reminded[k] < 3 * 86400000) r[k] = cfg.reminded[k];
        r[key] = now;
        cfg.reminded = r;
        return true;
    }
    Timer {
        interval: 30000; repeat: true; triggeredOnStart: true
        running: Persist.automates && root.cfg.enabled && root.ready
        onTriggered: root.remind()
    }
    function remind() {
        const now = new Date(), nowMs = now.getTime();
        const dayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const asleep = Focus.mode === "sleep";
        if (cfg.classReminders || cfg.phoneReminders)
            for (const c of today) {
                const lead = dayStart + c.start * 60000 - nowMs;
                if (lead > cfg.reminderMinutes * 60000 || lead < -2 * 60000) continue;
                if (!remindFlag("class:" + dateKey(now) + ":" + c.id + ":" + c.start)) continue;
                const mins = Math.max(0, Math.round(lead / 60000));
                const when = mins === 0 ? "Starting now" : "In " + mins + " min";
                if (cfg.classReminders && !asleep)
                    Island.push({ kind: "device", key: "amazecc:class", priority: Island.priority.system, duration: 9000, queueable: true,
                                  data: { icon: c.kind === "lab" ? "science" : "school", title: c.title,
                                          badge: c.kind === "lab" ? "Lab" : "", detail: [c.venue, when, "till " + clockLabel(c.end)].filter(x => x).join(" · "),
                                          actions: [{ icon: "event_note", label: "Today", cmd: [Theme.lumenRoot + "/bin/lumen-shell-ipc", "planner", "open"] }] } });
                if (cfg.phoneReminders) Link.notify(c.title + " — " + (c.venue ? c.venue + ", " : "") + when.toLowerCase());
            }
        if (cfg.examReminders)
            for (const e of exams) {
                const lead = e.when - nowMs;
                // The evening before (from 6 pm), and an hour before
                const tomorrow = Qt.formatDate(new Date(nowMs + 86400000), "yyyy-MM-dd") === e.date;
                if (tomorrow && now.getHours() >= 18 && remindFlag("exam-eve:" + e.code + ":" + e.date)) {
                    const body = [e.kind, e.time || "", e.venue, e.seat].filter(x => x).join(" · ");
                    notify("event", "Exam tomorrow · " + e.title, body);
                    if (cfg.phoneReminders) Link.notify("Exam tomorrow: " + e.title + " — " + body);
                }
                if (e.timed && lead > 0 && lead <= 60 * 60000 && remindFlag("exam-hour:" + e.code + ":" + e.date)) {
                    const body = [e.reporting ? "Report by " + e.reporting : "", e.venue, e.seat].filter(x => x).join(" · ");
                    Island.push({ kind: "device", key: "amazecc:exam", priority: Island.priority.system, duration: 12000, queueable: true,
                                  data: { icon: "edit_note", title: e.kind + " · " + e.title, badge: "Exam", detail: body, actions: [] } });
                    if (cfg.phoneReminders) Link.notify(e.kind + " " + e.title + " in an hour — " + body);
                }
            }
    }

    IpcHandler {
        target: "amazecc"
        function sync(): void { root.sync(true); }
        function next(): string { return root.headline; }
        function state(): string {
            return JSON.stringify({ enabled: root.cfg.enabled, hasLogin: root.hasLogin, syncing: root.syncing, error: root.error,
                                    updated: root.updated, courses: root.courses.length, today: root.today.length, headline: root.headline });
        }
    }

    // ── dev (LUMEN_DEV): sample data and every kind of moment, without VTOP ──
    IpcHandler {
        target: "amazeccTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void {
            const m = new Date().getHours() * 60 + new Date().getMinutes();
            const day = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][new Date().getDay()];
            const c1 = { id: "C1", code: "BCSE304L", title: "Models of Computation", kind: "theory", venue: "AB1-301", slots: [], attended: 20, total: 27, pct: 74, type: "Embedded Theory" };
            const c2 = { id: "C2", code: "BCSE302P", title: "Database Systems Lab", kind: "lab", venue: "AB1-607B", slots: [], attended: 9, total: 10, pct: 90, type: "Embedded Lab" };
            const c3 = { id: "C3", code: "BMAT202L", title: "Probability and Statistics", kind: "theory", venue: "AB2-105", slots: [], attended: 25, total: 32, pct: 78, type: "Theory Only" };
            const week = {}; week[day] = [
                Object.assign({ start: m - 30, end: m + 20 }, c1),
                Object.assign({ start: m + 8, end: m + 108 }, c2),
                Object.assign({ start: m + 180, end: m + 230 }, c3)];
            const ex = new Date(); ex.setDate(ex.getDate() + 3); ex.setHours(9, 30, 0, 0);
            root.data = { version: 1, updated: Date.now(), courses: [c1, c2, c3], week,
                          marks: [{ id: "C1", code: "BCSE304L", title: "Models of Computation", kind: "theory", assessments: [
                              { title: "CAT - I", max: 50, scored: 29, weight: 15, weightMark: 8.7 }, { title: "CAT - II", max: 50, scored: 12, weight: 15, weightMark: 3.6 }] }],
                          exams: [{ kind: "FAT", code: "BCSE304L", title: "Models of Computation", date: Qt.formatDate(ex, "yyyy-MM-dd"), when: ex.getTime(), timed: true,
                                    reporting: "09:00 AM", time: "09:30 AM - 12:30 PM", venue: "AB1-102", seat: "R3 · 14" }],
                          days: [] };
        }
        function mark(): void { root.announce({ kind: "mark", id: "C1", title: "Models of Computation", assessment: "CAT - II", scored: 12, max: 50, weightMark: 3.6, weight: 15 }); }
        function attendance(): void { root.announce({ kind: "attendance", id: "C1", title: "Models of Computation", pct: 74, attended: 20, total: 27, state: "below" }); }
        function exam(): void { root.announce(Object.assign({}, root.exams[0] ?? {}, { kind: "exam", examKind: "FAT", what: "seat" })); }
        function remind(): void { root.cfg.reminded = ({}); root.remind(); }
        function real(): void { dataFile.reload(); }
    }
}
