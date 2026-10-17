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
            property bool lockScreen: true                // next class on the lock screen (no attendance details)
            property bool haloContext: true               // Halo may read this for questions about classes, attendance, marks, exams
            property bool calendarFile: true              // ~/Notes/Calendar/VIT.ics: classes, exams, holidays for the phone's calendar
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
    function args() {
        return [script, "--api", cfg.api, "--semester", cfg.semester, "--threshold", String(cfg.threshold)]
            .concat(cfg.calendarFile ? ["--ics", calendarPath] : []);
    }
    // The timetable as a calendar file in the Notes folder, so Syncthing takes it to the phone
    readonly property string calendarPath: Notes.dir + "/Calendar/VIT.ics"
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

    // ── extras: grades/CGPA, circulars, class messages, fees, library, proctor ──
    // (amazecc.py extras, at most every 6 hours, after a sync)
    property var extra: ({})
    FileView {
        id: extraFile
        path: Persist.dir + "/amazecc-extra.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { root.extra = JSON.parse(text()); } catch (e) {} }
        onLoadFailed: root.extra = ({})
    }
    function syncExtras() {
        if (extrasProc.running || !cfg.enabled || !hasLogin) return;
        extrasProc.command = args().concat(["extras"]);
        extrasProc.running = true;
    }
    Process {
        id: extrasProc
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}; try { r = JSON.parse(text); } catch (e) { return; }
                if (!r.ok || !Persist.automates) return;
                extraFile.reload();
                for (const c of r.new?.circulars ?? [])
                    Halo.say({ key: "circular:" + c.id, icon: "campaign", title: "New circular", text: c.title + (c.office ? "\n" + c.office : ""), level: "important", duration: 14000 });
                for (const m of r.new?.messages ?? []) {
                    const vals = Object.values(m).filter(v => typeof v === "string" && v.trim());
                    Halo.say({ key: "classmsg:" + vals.join("|").slice(0, 60), icon: "forum", title: "Message from your faculty", text: vals.join(" · ").slice(0, 300), level: "important", duration: 20000 });
                }
            }
        }
    }

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
        if (Date.now() - (extra.updated ?? 0) > 6 * 3600000) syncExtras();
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
                ? c.pct + "% (" + c.attended + "/" + c.total + ") — under " + cfg.threshold + "%. Attend the next " + needed(course) + " to get back"
                  + (cfg.threshold <= 75 ? " — below 75% on the day before an exam means you're debarred from it." : ".")
                : c.pct + "% (" + c.attended + "/" + c.total + ") — " + (skippable(course) === 0 ? "don't miss the next one" : "you can miss " + skippable(course) + " more");
            notify("warning", "Attendance · " + courseName(Object.assign({ kind: c.kindOf }, c)), body);
            toPhone("Attendance — " + courseName(Object.assign({ kind: c.kindOf }, c)) + ": " + body);
        } else if (c.kind === "exam" && cfg.examReminders) {
            const when = Planner.whenLabel(c.when, !c.timed);
            const title = c.what === "seat" ? "Seat allotted · " + c.title : c.what === "moved" ? "Exam moved · " + c.title : c.examKind + " scheduled · " + c.title;
            const body = [when, c.venue, c.seat].filter(x => x).join(" · ");
            notify("event", title, body);
            toPhone(title + " — " + body);
        }
    }

    // ── attendance maths ──
    // "Database Systems (lab)": theory and lab of one course are counted separately
    function courseName(c) { return (c?.title ?? "") + (c?.kind === "lab" ? " (lab)" : ""); }
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

    // ── attendance trend (from the history each sync keeps on this computer) ──
    // Change since about a week ago, in points (null: no history yet)
    function trend(c) {
        const w = (data.weekAgo ?? {})[c?.id];
        return w && c.pct !== null ? c.pct - w[2] : null;
    }
    function trendText(c) {
        const t = trend(c);
        return t === null || Math.abs(t) < 0.5 ? "" : (t > 0 ? " · ↑" : " · ↓") + Math.abs(t).toFixed(0) + " this week";
    }

    // ── exam countdown ──
    readonly property var nextExam: { clock.date; return exams.find(e => e.when > Date.now()) ?? null; }
    function daysTo(ms) {
        const a = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate()).getTime();
        const d = new Date(ms); const b = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        return Math.round((b - a) / 86400000);
    }
    // "FAT · Models of Computation in 4 days" — within a week
    readonly property string examCountdown: {
        const e = nextExam;
        if (!e || !cfg.enabled) return "";
        const n = daysTo(e.when);
        if (n > 7) return "";
        return e.kind + " · " + e.title + (n === 0 ? " today" : n === 1 ? " tomorrow" : " in " + n + " days");
    }
    // A revision checklist in Notes (and so on the phone)
    function revisionNote(e) {
        const title = "Revision — " + e.kind + " " + e.title;
        const body = "**" + e.kind + " · " + Planner.whenLabel(e.when, !e.timed) + "**" + (e.venue ? " · " + e.venue : "") + (e.seat ? " · seat " + e.seat : "") + "\n\n"
                   + "## Syllabus\n" + [1, 2, 3, 4, 5, 6, 7].map(i => "- [ ] Module " + i).join("\n") + "\n\n"
                   + "## Past papers\n- [ ] \n\n## Weak spots\n- \n";
        Quickshell.execDetached(["sh", "-c", 'f=$("$1" --dir "$2" new "$3") && printf "%s" "$4" >> "$2/$f" && exec "$5" notes note "$f"',
                                 "sh", Theme.lumenRoot + "/scripts/notes.py", Notes.dir, title, body, Theme.lumenRoot + "/bin/lumen-shell-ipc"]);
    }
    // A week before each exam (from 6 pm, once): the island offers the note
    Timer {
        interval: 600000; repeat: true; triggeredOnStart: true
        running: Persist.automates && root.cfg.enabled && root.cfg.examReminders && root.ready
        onTriggered: {
            if (new Date().getHours() < 18) return;
            for (const e of root.exams) {
                const n = root.daysTo(e.when);
                if (n < 1 || n > 7 || !root.remindFlag("exam-week:" + e.kind + ":" + e.code)) continue;
                Island.device("exam-week:" + e.code, {
                    icon: "edit_note", badge: e.kind,
                    title: e.title + " in " + n + (n === 1 ? " day" : " days"),
                    detail: Planner.whenLabel(e.when, !e.timed) + (e.venue ? " · " + e.venue : ""),
                    actions: [{ icon: "checklist", label: "Make revision note", cmd: ["sh", "-c", 'exec "$0" amazecc revise "$1"', Theme.lumenRoot + "/bin/lumen-shell-ipc", e.code + "|" + e.kind] }]
                });
                break;
            }
        }
    }

    // ── what if I skip a day ──
    // Each slot is one class in VTOP's count, so a 2-hour lab (L1+L2) is two.
    function slotsIn(c) { return Math.max(1, Math.round((c.end - c.start) / 50)); }
    // [{ course, n, before, after, below, wasBelow }] for the classes on `date`
    function skipImpact(date) {
        const by = {};
        for (const c of classesOn(date)) by[c.id] = (by[c.id] ?? 0) + slotsIn(c);
        const t = cfg.threshold;
        return Object.keys(by).map(id => {
            const course = courses.find(x => x.id === id);
            if (!course?.total) return null;
            const n = by[id];
            const after = 100 * course.attended / (course.total + n);
            return { course, n, before: course.pct, after, below: after < t, wasBelow: course.pct < t };
        }).filter(x => x).sort((a, b) => a.after - b.after);
    }
    // "today" · "tomorrow" · "fri" · "friday" · "2026-10-16" → a date with classes (within 7 days)
    function parseDay(word) {
        const w = (word ?? "").trim().toLowerCase(), now = clock.date;
        const base = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        if (!w || w === "today") return base;
        if (/^(tomorrow|tmr|tmrw)$/.test(w)) return new Date(base.getTime() + 86400000);
        const i = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"].findIndex(d => w.startsWith(d));
        if (i >= 0) { let k = (i - base.getDay() + 7) % 7; return new Date(base.getTime() + k * 86400000); }
        const d = new Date(w + "T00:00");
        return isNaN(d.getTime()) ? null : d;
    }
    // At 9 pm: would skipping tomorrow put a course under the minimum?
    Timer {
        interval: 60000; repeat: true
        running: Persist.automates && root.cfg.enabled && root.cfg.attendanceAlerts && root.ready
        onTriggered: {
            const now = new Date();
            if (now.getHours() !== 21) return;
            const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
            const risky = root.skipImpact(tomorrow).filter(x => x.below);
            if (!risky.length || !root.remindFlag("skipwarn:" + root.dateKey(tomorrow))) return;
            const names = risky.map(x => root.courseName(x.course) + " (" + x.before + "% → " + x.after.toFixed(1) + "%)").join(", ");
            root.notify("event_busy", "Tomorrow: don't skip " + (risky.length === 1 ? "this" : "these"), names);
            if (root.cfg.phoneReminders) Link.notify("Tomorrow, don't skip: " + names);
        }
    }

    // ── FAT targets ──
    // VIT FFCS Academic Regulations v4.0 §9.1–9.5: a theory course is CAT-I 15 +
    // CAT-II 15 + digital assignments 30 (3×10) + FAT 40 (the paper is out of 100).
    // To pass: at least 40/100 in the FAT itself, and a total of 50 (relative
    // grading may set the pass mark lower, never higher). Grades above E are
    // relative to the class (B centred on the average) when it has more than 10
    // students, so the absolute bands (90/80/70/60/55/50) here are a guide.
    // Internals not yet posted count from "full" to "at your rate so far".
    readonly property var grades: [["S", 90], ["A", 80], ["B", 70], ["C", 60], ["D", 55], ["E", 50]]
    readonly property int fatWeight: 40
    readonly property int fatMin: 40                 // marks out of 100 in the FAT itself, to pass
    function targets(m) {
        const posted = (m?.assessments ?? []).filter(a => a.scored !== null && a.weight);
        if (!posted.length || m.kind === "lab") return null;
        const fatDone = posted.find(a => /\bFAT\b|final assessment/i.test(a.title));
        const internal = posted.filter(a => a !== fatDone);
        const earned = internal.reduce((x, a) => x + (a.weightMark ?? 0), 0);
        const weighed = internal.reduce((x, a) => x + a.weight, 0);
        const rate = weighed ? earned / weighed : 0;                    // 0–1
        const left = Math.max(0, 100 - fatWeight - weighed);              // internals still to come
        const expected = earned + left * rate;
        // Two ends: the internals still to come at your rate so far (need), or full (needFull)
        const need = {}, needFull = {};
        for (const [g, cut] of grades) {
            need[g] = Math.ceil((cut - expected) / fatWeight * 100);
            needFull[g] = Math.ceil((cut - earned - left) / fatWeight * 100);
        }
        // Whatever the internals, the FAT itself needs 40 / 100 (§9.4 a)
        need.E = Math.max(fatMin, need.E);
        needFull.E = Math.max(fatMin, needFull.E);
        return { earned, weighed, rate, left, expected, need, needFull, done: !!fatDone,
                 total: fatDone ? expected + (fatDone.weightMark ?? 0) : null };
    }
    // "Pass: FAT 14–53 · A in reach: 89+" — a range from full assignments to your rate so far
    function fatRange(t, g) {
        const lo = Math.max(0, t.needFull[g]), hi = t.need[g];
        if (lo > 100) return "out of reach";
        return lo === hi || t.left === 0 ? String(Math.min(lo, 100)) : lo + "–" + (hi > 100 ? "100+" : Math.max(0, hi));
    }
    function targetLine(m) {
        const t = targets(m);
        if (!t) return "";
        if (t.done) return "Total " + fmt(t.total) + " / 100";
        const best = grades.find(([g]) => t.needFull[g] <= 100);
        if (!best) return "Even full marks miss 50 on the absolute scale — relative grading decides";
        return "Pass: FAT " + fatRange(t, "E") + (best[0] !== "E" ? " · " + best[0] + ": " + fatRange(t, best[0]) : "");
    }


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
        const today = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate()).getTime();
        const out = [];
        if (cfg.examsInAgenda)
            for (const e of exams)
            {
                // A FAT says what it needs: "Pass: FAT 14–53"
                const m = /FAT/i.test(e.kind) ? marks.find(x => x.code === e.code && x.kind !== "lab") : null;
                const need = m ? targetLine(m).replace(/ · .*$/, "") : "";
                out.push({ title: e.kind + " · " + e.title, when: e.when, allDay: !e.timed,
                           external: true, source: "amazecc", detail: [e.venue, e.seat, need].filter(x => x).join(" · ") });
            }
        if (cfg.holidaysInAgenda) {
            // "Holiday · (Deepavali)" → "Deepavali"; a weekend with no name isn't news;
            // a run of the same holiday (an 8-day break) is one line
            let run = null;
            const flush = () => {
                if (!run) return;
                const until = run.last !== run.first ? " · till " + Qt.formatDate(new Date(run.last + "T12:00"), "ddd d MMM") : "";
                // A break that has already begun shows from today, and stays until its last day
                const first = new Date(run.first + "T00:00").getTime(), last = new Date(run.last + "T00:00").getTime();
                out.push({ title: run.name + " — no classes" + until, when: Math.max(first, Math.min(last, today)), until: last,
                           allDay: true, external: true, source: "amazecc" });
                run = null;
            };
            for (const d of data.days ?? []) {
                if (d.order) {
                    flush();
                    out.push({ title: "Classes follow " + dayNames[d.order] + "'s timetable", when: new Date(d.date + "T00:00").getTime(), allDay: true, external: true, source: "amazecc" });
                    continue;
                }
                if (d.kind !== "holiday") { flush(); continue; }
                const name = /\(([^)]+)\)/.exec(d.text)?.[1]?.trim() ?? "";
                const dow = new Date(d.date + "T12:00").getDay();
                if (!name && (dow === 0 || dow === 6)) continue;          // an ordinary weekend
                const label = name || "Holiday";
                const prev = run ? new Date(new Date(run.last + "T12:00").getTime() + 86400000) : null;
                if (run && run.name === label && Qt.formatDate(prev, "yyyy-MM-dd") === d.date) run.last = d.date;
                else { flush(); run = { name: label, first: d.date, last: d.date }; }
            }
            flush();
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
                // Attendance on the line: say so (Halo's college sense)
                const co = courses.find(x => x.id === c.id);
                const att = co?.total ? (co.pct < cfg.threshold ? co.pct + "% — needs this one" : co.pct < cfg.threshold + 5 ? co.pct + "% — don't skip" : "") : "";
                if (cfg.classReminders && !asleep)
                    Island.push({ kind: "device", key: "amazecc:class", priority: Island.priority.system, duration: 9000, queueable: true,
                                  data: { icon: c.kind === "lab" ? "science" : "school", title: c.title,
                                          badge: c.kind === "lab" ? "Lab" : "", detail: [c.venue, when, "till " + clockLabel(c.end), att].filter(x => x).join(" · "),
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
        // "BACSE202|FAT" → a revision note for that exam
        function revise(which: string): void {
            const [code, kind] = which.split("|");
            const e = root.exams.find(x => x.code === code && (!kind || x.kind === kind));
            if (e) root.revisionNote(e);
        }
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
