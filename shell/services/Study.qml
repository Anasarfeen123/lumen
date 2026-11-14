pragma Singleton
// Study: your Academics folder, past papers and VTOP's lecture plans, kept up
// to date in the background and brought up when they matter
// (scripts/study.py does the work; the AmazeCC app's Study pages show it).
//   daily     new past papers (MIC PYQs) for your courses → "3 new DBMS papers"
//   weekly    VTOP's lecture plans and syllabus PDFs
//   6-hourly  the search index of your notes and papers (incremental)
//   before an exam   "FAT in 4 days — 8 past FAT papers, 2 done"
//   mornings  a study card: exams coming, papers to practise, flashcards due
//   downloads a course file lands in Downloads → "File into DBMS → Lecture Slides?"
//   backup    the nightly vault backup hasn't run, or failed → say so
// Only while AmazeCC is set up; never in a test session (Persist.automates).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property bool on: Amazecc.cfg?.enabled === true
    readonly property bool automates: Persist.automates && on
    readonly property string script: Theme.lumenRoot + "/scripts/study.py"

    // ── data (also read by the app's pages) ──
    property var overview: ({})          // study.py overview
    property var papers: []              // study.py pyq list
    property var attendance: []          // study.py attendance
    property var missed: []              // study.py missed
    property var events: []
    property var backup: ({})
    property var recent: []
    property bool syncing: false
    property string lastError: ""
    readonly property var courses: overview.courses ?? []

    function run(args, done) {
        const p = runner.createObject(root, { command: [script].concat(args), done: done ?? null });
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: proc
            property var done: null
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {};
                    try { r = JSON.parse(text); } catch (e) {}
                    if (proc.done) proc.done(r);
                    proc.destroy();
                }
            }
        }
    }

    function refresh() {
        run(["overview"], r => { if (r.ok) root.overview = r; });
        run(["pyq", "list"], r => { if (r.ok) root.papers = r.papers; });
        run(["attendance"], r => { if (r.ok) root.attendance = r.courses; });
        run(["missed"], r => { if (r.ok) root.missed = r.missed; });
        run(["recent", "10"], r => { if (r.ok) root.recent = r.files; });
        run(["backup"], r => { root.backup = r; });
    }
    Component.onCompleted: if (on) refresh()
    onOnChanged: if (on) refresh()

    // a course from loose words: "dbms", "os", "moc", "java", "database systems", "BACSE202"
    function match(words) {
        const w = (words ?? "").toLowerCase().replace(/[^a-z0-9 ]/g, " ").trim();
        if (!w) return null;
        for (const c of courses) {
            const folder = (c.folder ?? "").replace(/^.*\//, "").toLowerCase();
            const abbr = (folder.match(/\(([a-z-]{2,8})\)/)?.[1] ?? "").replace(/-/g, "");
            const initials = c.title.split(/\s+/).filter(x => /^[A-Z]/.test(x)).map(x => x[0]).join("").toLowerCase();
            const title = c.title.toLowerCase();
            if (w.replace(/\s/g, "") === c.code.toLowerCase() || (abbr && w.replace(/\s/g, "") === abbr) || (initials.length >= 2 && w === initials)
                || title.includes(w) || folder.includes(w) || w.split(" ").some(x => x.length > 3 && (title.includes(x) || folder.includes(x)) && !["systems", "using", "skills", "fundamentals"].includes(x)))
                return c;
        }
        return null;
    }
    // the launcher's "s <words>": files in Academics, by name and contents
    property string findQuery: ""
    property var found: []
    function find(q) { findQuery = q; if (q.trim().length < 2) { found = []; return; } findSoon.restart(); }
    Timer { id: findSoon; interval: 220; onTriggered: { const q = root.findQuery; root.run(["search"].concat(q.trim().split(/\s+/)), r => { if (root.findQuery === q && r.ok) root.found = r.results; }); } }

    function papersFor(code, exam) {
        return papers.filter(p => p.code === code && (!exam || p.exam === exam));
    }
    function setDone(p, d) {
        run(d ? ["done", p.id] : ["done", p.id, "--undo"], () => run(["pyq", "list"], r => { if (r.ok) root.papers = r.papers; }));
        papers = papers.map(x => x.id === p.id ? Object.assign({}, x, { done: d }) : x);
    }

    // ── background fetches ──
    function syncPapers(force) {
        if (syncing) return;
        syncing = true;
        run(force ? ["pyq", "sync", "--force"] : ["pyq", "sync"], r => {
            root.syncing = false;
            root.lastError = r.ok ? "" : (r.error ?? "");
            if ((r.new ?? []).length) {
                const by = {};
                for (const p of r.new) by[p.course] = (by[p.course] ?? 0) + 1;
                Halo.say({ key: "study-pyq", icon: "quiz", title: r.new.length + " new past paper" + (r.new.length === 1 ? "" : "s"),
                           text: Object.keys(by).map(c => by[c] + " · " + c).join("\n"), level: "important", duration: 15000, speak: false,
                           actions: [{ label: "Open", icon: "quiz", run: () => Amazecc.launch("papers") }] });
            }
            root.refresh();
        });
    }
    function syncLectures() { run(["lectures", "sync"], () => root.refresh()); }
    function reindex() { run(["index"]); }

    Timer {   // 10 minutes after start, then every 6 hours: each job decides if it's due
        interval: 6 * 3600000; repeat: true; running: root.automates
        triggeredOnStart: false
        onTriggered: root.daily()
    }
    Timer { interval: 10 * 60000; running: root.automates; onTriggered: root.daily() }
    function daily() {
        const now = Date.now();
        if (now - (overview.pyqFetchedAt ?? 0) > 20 * 3600000) syncPapers(false);
        if (now - (overview.lecturesAt ?? 0) > 3 * 86400000) syncLectures();
        reindex();
        run(["events"], r => { if (r.ok) root.events = r.events; });
        backupCheck();
    }

    // ── the nightly vault backup ──
    function backupCheck() {
        run(["backup"], r => {
            root.backup = r;
            if (!r.repo || !(r.stale || r.logFailed)) return;
            if (!once("backup:" + Qt.formatDate(new Date(), "yyyy-MM-dd"))) return;
            Halo.say({ key: "study-backup", icon: "cloud_off", tone: "concerned", level: "important", duration: 15000, speak: false,
                       title: r.logFailed ? "Your Academics backup failed" : "Your Academics backup hasn't run",
                       text: r.logFailed ? "Last night's run reported an error — see Academics/.backup.log."
                                         : "Last backup: " + Qt.formatDateTime(new Date(r.lastCommit), "ddd d MMM, h:mm AP") + ". The 23:00 job may not be running." });
        });
    }

    // things said once (kept across reloads)
    function once(key) {
        const s = Persist.data.studySaid ?? [];
        if (s.includes(key)) return false;
        Persist.data.studySaid = s.concat([key]).slice(-80);
        return true;
    }

    // ── before an exam: the past papers for it ──
    function examType(kind) { return /fat/i.test(kind) ? "FAT" : /cat.?1|cat\s*i\b/i.test(kind) ? "CAT 1" : /cat.?2|cat\s*ii/i.test(kind) ? "CAT 2" : ""; }
    Timer {
        interval: 3600000; repeat: true; running: root.automates; triggeredOnStart: true
        onTriggered: {
            const h = new Date().getHours();
            if (h < 8 || h >= 22 || Lock.locked || Focus.mode === "sleep") return;
            for (const e of Amazecc.exams ?? []) {
                const days = Amazecc.daysTo(e.when);
                if (e.when < Date.now() || days > 6) continue;
                const t = root.examType(e.kind), ps = root.papersFor(e.code, t), left = ps.filter(p => !p.done).length;
                if (!ps.length || !root.once("exam-pyq:" + e.code + ":" + e.kind + ":" + Qt.formatDate(new Date(), "yyyy-MM-dd"))) continue;
                Halo.say({ key: "study-exam", icon: "edit_note", level: "important", duration: 20000, speak: false,
                           title: e.kind + " " + (days === 0 ? "today" : days === 1 ? "tomorrow" : "in " + days + " days") + " · " + e.title,
                           text: ps.length + " past " + t + " paper" + (ps.length === 1 ? "" : "s") + (left < ps.length ? ", " + (ps.length - left) + " done" : "") + ". Practise one now?",
                           actions: [{ label: "Past papers", icon: "quiz", run: () => Amazecc.launch("papers:" + e.code) },
                                     { label: "Revise 45 min", icon: "timer", run: () => root.startSession(e.code, 45) }] });
                break;      // one exam card an hour is plenty
            }
        }
    }

    // ── a morning card on study days ──
    Connections {
        target: Lock
        function onLockedChanged() { if (!Lock.locked) morningSoon.restart(); }
    }
    Timer { id: morningSoon; interval: 4000; onTriggered: root.morning() }
    function morning() {
        const now = new Date(), h = now.getHours();
        if (!automates || h < 6 || h >= 12 || !once("study-morning:" + Qt.formatDate(now, "yyyy-MM-dd"))) return;
        const lines = [];
        const soon = (Amazecc.exams ?? []).filter(e => e.when > Date.now() && Amazecc.daysTo(e.when) <= 7);
        for (const e of soon.slice(0, 2))
            lines.push(e.kind + " · " + e.title + " — " + (Amazecc.daysTo(e.when) === 0 ? "today" : "in " + Amazecc.daysTo(e.when) + " d") + (e.venue ? " · " + e.venue : ""));
        if (soon.length) {
            const e = soon[0], ps = papersFor(e.code, examType(e.kind)).filter(p => !p.done);
            if (ps.length) lines.push("Practise: " + ps[0].exam + " " + ps[0].year + (ps[0].slot ? " (slot " + ps[0].slot + ")" : ""));
        }
        const labs = (Amazecc.today ?? []).filter(c => c.kind === "lab");
        if (labs.length) lines.push("Lab today: " + labs.map(c => c.title).join(", ") + " — bring your record");
        if (!lines.length) return;
        Halo.say({ key: "study-morning", icon: "school", title: "Today's study", text: lines.join("\n"), level: "asked", duration: 20000, speak: false,
                   actions: [{ label: "Study", icon: "school", run: () => Amazecc.launch("study") }] });
    }

    // ── a session: focus, a timer, the course folder; logged at the end ──
    property string sessionCode: ""
    property real sessionStart: 0
    property bool sessionMusic: false        // this session started the music, so its end pauses it
    function startSession(code, minutes) {
        const c = courses.find(x => x.code === code);
        sessionCode = code;
        sessionStart = Date.now();
        if (Focus.mode !== "study") Focus.set("study");
        Countdown.startTimer(minutes * 60000, "Study · " + (c?.title ?? code));
        // your music, if a player is open and paused (Settings → Sound)
        sessionMusic = (Persist.data.studyMusic ?? true) && Media.present && !Media.playing && (Media.active?.canPlay ?? false);
        if (sessionMusic) Media.active.play();
        if (c?.folder) Quickshell.execDetached(["xdg-open", c.folder]);
    }
    Connections {
        target: Countdown
        function onActiveChanged() { if (!Countdown.active && root.sessionCode) root.endSession(); }
    }
    function endSession() {
        const mins = Math.round((Date.now() - sessionStart) / 60000);
        if (mins >= 5) run(["log", sessionCode, String(mins)], () => run(["overview"], r => { if (r.ok) root.overview = r; }));
        sessionCode = "";
        if (sessionMusic && Media.playing && (Media.active?.canPause ?? false)) Media.active.pause();
        sessionMusic = false;
    }

    // ── a course file lands in Downloads: offer to file it ──
    Connections {
        target: Downloads
        enabled: root.automates
        function onLanded(path) {
            if (!/\.(pdf|pptx?|docx?|xlsx?|png|jpe?g|md|txt|zip)$/i.test(path)) return;
            root.run(["classify", path], r => {
                if (!r.ok || !r.code || r.confidence < 0.3) return;
                Halo.say({ key: "study-file", icon: "drive_file_move", level: "asked", duration: 20000, speak: false,
                           title: "File into " + r.course + "?",
                           text: path.replace(/^.*\//, "") + " → " + r.sub,
                           actions: [{ label: "File it", icon: "drive_file_move", run: () => root.run(["file", path, r.code, r.sub], x => {
                                         if (x.ok) Island.system("drive_file_move", "Filed", x.path.replace(/^.*\/Academics\//, ""));
                                         else Island.system("error", "Couldn't file it", x.error ?? "", "warning"); }) },
                                     { label: "Leave it", icon: "close", run: () => {} }] });
            });
        }
    }

    IpcHandler {
        target: "study"
        function refresh(): void { root.refresh(); }
        function papers(): void { root.syncPapers(true); }
        function lectures(): void { root.syncLectures(); }
        function session(code: string, minutes: int): void { root.startSession(code, minutes); }
        function morning(): void { Persist.data.studySaid = (Persist.data.studySaid ?? []).filter(k => !k.startsWith("study-morning:")); root.morning(); }
        function state(): string { return JSON.stringify({ courses: root.courses.length, papers: root.papers.length, missed: root.missed.length }); }
    }
}
