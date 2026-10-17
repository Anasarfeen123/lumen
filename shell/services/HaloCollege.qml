pragma Singleton
// Halo, on college (AmazeCC's data, services/Amazecc.qml) — answered at once,
// on this computer, no model needed:
//   "what's my next class" · "where is my next class" · "classes tomorrow" ·
//   "classes on friday" · "attendance" · "attendance in DBMS" ·
//   "can I skip tomorrow" / "should I bunk friday" · "marks in OS" ·
//   "what do I need in the FAT for an A in OS" · "exams" / "when is my next exam"
// Each answer is a Halo card with what you'd do next (a reminder before the
// class, a revision note, today's plan). The agent uses text() for the same
// facts (services/Agent.qml).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property bool on: Amazecc.cfg?.enabled && Amazecc.ready

    // ── finding a course by what you call it ("dbms", "os lab", "BCSE302") ──
    function course(name) {
        const q = (name ?? "").toLowerCase().replace(/\b(the|my|course|subject|class)\b/g, "").trim();
        if (!q) return null;
        const lab = /\blab\b/.test(q), clean = q.replace(/\blab\b/, "").trim();
        const initials = t => t.split(/[\s&,-]+/).filter(w => w.length > 2 && !/^(and|of|for|to|the|in)$/i.test(w)).map(w => w[0]).join("").toLowerCase();
        // what students call them
        const alias = ({ dbms: "database", db: "database", os: "operating system", cn: "computer network", dsa: "data structure", ds: "data structure",
                         daa: "algorithm", oop: "object oriented", oops: "object oriented", ai: "artificial intelligence", ml: "machine learning",
                         toc: "computation", moc: "models of computation", arvr: "augmented", "ar vr": "augmented", ar: "augmented", vr: "virtual reality",
                         java: "java", python: "python", maths: "math", math: "math", physics: "physics", chem: "chemistry", qqs: "qualitative", aptitude: "qualitative",
                         se: "software engineering", coa: "computer architecture", ca: "computer architecture", dld: "digital logic", de: "digital" })[clean];
        let best = null, score = 0;
        for (const c of Amazecc.courses) {
            const t = (c.title ?? "").toLowerCase();
            let s = Math.max(Fuzzy.score(clean, t), alias && t.includes(alias) ? 1800 : 0, (c.code ?? "").toLowerCase() === clean ? 2000 : 0,
                             initials(c.title ?? "") === clean.replace(/\s/g, "") ? 1500 : 0);
            if (lab === (c.kind === "lab")) s += 100;
            if (s > score) { score = s; best = c; }
        }
        return score >= 500 ? best : null;
    }
    function marksFor(c) { return c ? Amazecc.marks.find(m => m.code === c.code || m.title === c.title) ?? null : null; }
    function attLine(c) {
        if (!c?.total) return "no attendance yet";
        const t = Amazecc.cfg.threshold;
        return c.pct + "% (" + c.attended + "/" + c.total + ")" + (c.pct >= t ? " · can miss " + Amazecc.skippable(c) : " · needs the next " + Amazecc.needed(c)) + Amazecc.trendText(c);
    }
    function classTime(d, c) { const x = new Date(d); x.setHours(Math.floor(c.start / 60), c.start % 60, 0, 0); return x; }
    function until(ms) {
        const m = Math.round((ms - Date.now()) / 60000);
        return m <= 0 ? "now" : m < 60 ? "in " + m + " min" : "in " + Math.floor(m / 60) + " h " + (m % 60) + " min";
    }
    function courseOf(cls) { return Amazecc.courses.find(c => c.id === cls.id) ?? null; }
    function card(icon, title, text, actions, tone) {
        return { glyph: icon, title, own: () => Halo.say({ key: "college", icon, title, text, level: "asked", duration: 14000, tone: tone ?? "normal", actions: actions ?? [] }) };
    }
    function needsSetup() {
        return { glyph: "school", title: "College", own: () => Halo.say({ key: "college", icon: "school", title: "AmazeCC isn't set up", text: "Sign in under Settings → AmazeCC and I can answer about classes, attendance, marks and exams.",
                                                                             level: "asked", actions: [{ label: "Settings → AmazeCC", icon: "settings", run: () => SettingsState.launch("amazecc") }] }) };
    }

    // ── what Halo can answer (returns an intent for Halo.handle, or null) ──
    function intent(q) {
        const l = q.toLowerCase().replace(/[?.!]+$/, "").trim();
        const collegey = /\b(class(es)?|lecture|lab|attendance|bunk|skip|marks?|grades?|fat|cat|exams?|timetable|semester|revision|study plan|c?gpa|sgpa|proctor|circulars?|fees?|library|dues?|faculty)\b/.test(l);
        if (!collegey) return null;
        if (!on) return needsSetup();
        let m;
        if (/\b(study|revision) (plan|schedule|timetable)\b|^plan (my )?(study|studies|revision|exam prep)|^(make|build|create) (me )?a (study|revision) (plan|schedule)/.test(l)) return studyPlanCard();
        if (/\bbunk budget\b|^how many (classes )?can i (bunk|skip|miss)( this week)?$/.test(l)) return budgetCard();
        const ex = Amazecc.extra ?? {};
        // CGPA, and what this semester needs for a target
        if ((m = /\b(?:need|get|reach|for)\b.*?\b(\d{1,2}(?:\.\d{1,2})?)\s*(?:c?gpa|pointer)\b|\bc?gpa\b.*\bto (?:reach|get|be)\s+(\d{1,2}(?:\.\d{1,2})?)/.exec(l)) && ex.cgpa) {
            const target = +(m[1] ?? m[2]), cur = +ex.cgpa.cgpa, done = +ex.cgpa.creditsEarned || +ex.cgpa.creditsRegistered;
            const sem = 22;                         // a typical semester's credits (not on VTOP's page)
            const need = (target * (done + sem) - cur * done) / sem;
            return card(need > 10 ? "block" : "target", "For a " + target.toFixed(2) + " CGPA",
                        need > 10 ? "Not reachable this semester — even a perfect 10 SGPA takes you to " + ((cur * done + 10 * sem) / (done + sem)).toFixed(2) + ". It would take a few semesters."
                        : need <= 0 ? "You're already there (" + cur.toFixed(2) + ")."
                        : "You'd need an SGPA of about " + need.toFixed(2) + " this semester (assuming ~" + sem + " credits; now " + cur.toFixed(2) + " over " + done + " credits).",
                        [], need > 10 ? "concerned" : "normal");
        }
        if (/\b(my )?c?gpa\b|\bcumulative\b|\bgrade (distribution|history)\b|^my grades$/.test(l) && ex.cgpa) {
            const g = ex.cgpa.grades ?? {};
            return card("school", "CGPA " + ex.cgpa.cgpa + " · " + Number(ex.cgpa.creditsEarned) + " credits",
                        "Grades so far: " + Object.keys(g).filter(k => g[k]).map(k => k + " ×" + g[k]).join(" · ")
                        + ((ex.grades ?? []).length ? "\n" + ex.grades.slice(0, 8).map(x => x.grade + " — " + x.title).join("\n") : ""));
        }
        // your proctor
        if (/\bproctor\b/.test(l) && ex.proctor) {
            const p = ex.proctor;
            return card("person", p.name + (p.designation ? " · " + p.designation : ""), [p.cabin, p.email, p.phone ? "☎ " + p.phone : "", p.facultyIntercom ? "intercom " + p.facultyIntercom : ""].filter(x => x).join("\n"),
                        [p.email ? { label: "Email", icon: "mail", run: () => Accounts.compose(p.email, "", "") } : null,
                         p.phone ? { label: "Copy number", icon: "content_copy", run: () => Ai.copy(p.phone) } : null].filter(a => a));
        }
        // circulars
        if (/\bcirculars?\b/.test(l) && ex.circulars) {
            const list = ex.circulars.slice(0, 6);
            return card("campaign", list.length ? "Latest circulars" : "No circulars", list.map(c => (c.date ? Qt.formatDate(new Date(c.date), "d MMM") + " — " : "") + c.title).join("\n"));
        }
        // fees and dues
        if (/\b(fees?|dues?|library)\b/.test(l) && (ex.fees || ex.library)) {
            const f = ex.fees ?? {}, lib = ex.library ?? {};
            return card("payments", "Fees & dues", [f.tuitionFee ? "Tuition ₹" + Number(f.tuitionFee).toLocaleString(Qt.locale("en_IN"), "f", 0) + (f.dueDateWithoutLateFee ? " · due " + f.dueDateWithoutLateFee + (f.dueDateWithLateFee ? " (with late fee till " + f.dueDateWithLateFee + ")" : "") : "") : "",
                                                        "Library: " + (lib.due ? "₹" + lib.due + " due" : "nothing due")].filter(x => x).join("\n"));
        }

        // next class
        if (/\b(next|upcoming) (class|lecture|lab)\b|^where('?s| is) my (next )?class|what('?s| is) next\b/.test(l)) {
            const now = new Date();
            const c = Amazecc.current, n = Amazecc.next;
            if (n) {
                const at = classTime(now, n), co = courseOf(n);
                const risky = co && Amazecc.attendanceTone(co) !== "normal";
                return card(n.kind === "lab" ? "science" : "school", n.title + (n.kind === "lab" ? " (lab)" : "") + " " + until(at.getTime()),
                            [Amazecc.clockLabel(n.start) + "–" + Amazecc.clockLabel(n.end), n.venue, co ? "attendance " + attLine(co) : ""].filter(x => x).join(" · ")
                            + (risky ? ". Don't skip this one." : "") + (c ? " (Now: " + c.title + " till " + Amazecc.clockLabel(c.end) + ".)" : ""),
                            [{ label: "Remind me 10 min before", icon: "alarm", run: () => Halo.addReminder(at.getTime() - 600000, n.title + (n.venue ? " at " + n.venue : "")) },
                             { label: "Today's classes", icon: "event_note", run: () => { Planner.open = true; } }], risky ? "concerned" : "normal");
            }
            const nd = Amazecc.nextDay;
            if (nd) return card("event_available", "No more classes today", "Next: " + nd.first.title + " at " + Amazecc.clockLabel(nd.first.start) + ", " + Qt.formatDate(nd.date, "dddd")
                                + (nd.first.venue ? " (" + nd.first.venue + ")" : "") + " · " + nd.count + (nd.count === 1 ? " class" : " classes") + " that day.");
            return card("event_available", "No classes coming up", "Nothing on the timetable this week.");
        }

        // classes on a day
        if ((m = /\b(?:classes|timetable|schedule|lectures)\b(?: (?:for|on))? ?(today|tomorrow|tmrw|mon\w*|tue\w*|wed\w*|thu\w*|fri\w*|sat\w*|sun\w*)?/.exec(l)) && !/\b(skip|bunk|miss|attendance)\b/.test(l)) {
            const word = m[1] ?? (/\btomorrow\b/.test(l) ? "tomorrow" : "today");
            const d = Amazecc.parseDay(word);
            if (!d) return null;
            const list = Amazecc.classesOn(d), info = Amazecc.dayInfo(d);
            const label = word === "today" ? "Today" : word.startsWith("tom") || word === "tmrw" ? "Tomorrow" : Qt.formatDate(d, "dddd");
            if (!list.length) return card("event_available", "No classes " + label.toLowerCase(), info?.kind === "holiday" ? (info.text || "A holiday") : "Nothing on the timetable.");
            return card("calendar_month", label + ": " + list.length + (list.length === 1 ? " class" : " classes"),
                        list.map(c => Amazecc.clockLabel(c.start) + " " + c.title + (c.kind === "lab" ? " (lab)" : "") + (c.venue ? " · " + c.venue : "")).join("\n")
                        + (info?.order ? "\n(follows " + info.order + "'s timetable)" : ""));
        }

        // can I skip …
        if ((m = /\b(?:can i|should i|could i|is it ok(?:ay)? to|what if i) (?:skip|bunk|miss)\b(?: (?:class(?:es)? )?(?:on )?)?(today|tomorrow|tmrw|mon\w*|tue\w*|wed\w*|thu\w*|fri\w*|sat\w*)?/.exec(l)) || /\b(skip|bunk)\b.*\b(today|tomorrow|mon|tue|wed|thu|fri|sat)/.test(l)) {
            const word = (m?.[1]) ?? ((/\b(today|tomorrow|mon\w*|tue\w*|wed\w*|thu\w*|fri\w*|sat\w*)\b/.exec(l) ?? [])[1] ?? "tomorrow");
            const d = Amazecc.parseDay(word);
            if (!d) return null;
            const impact = Amazecc.skipImpact(d);
            const label = word === "today" ? "today" : word.startsWith("tom") || word === "tmrw" ? "tomorrow" : Qt.formatDate(d, "dddd");
            if (!impact.length) return card("event_available", "No classes " + label, "Nothing to skip.");
            const bad = impact.filter(x => x.below);
            return card(bad.length ? "block" : "check_circle",
                        bad.length ? "Better not skip " + label : "You can skip " + label,
                        impact.map(x => Amazecc.courseName(x.course) + ": " + x.before + "% → " + x.after.toFixed(1) + "%" + (x.below ? " (below " + Amazecc.cfg.threshold + "%)" : "")).join("\n")
                        + (bad.length ? "" : "\nEverything stays at or above " + Amazecc.cfg.threshold + "%."),
                        [], bad.length ? "concerned" : "happy");
        }

        // attendance
        if (/\battendance\b|\bhow many (classes )?can i (miss|skip|bunk)\b/.test(l)) {
            const named = l.replace(/.*\b(attendance|miss|skip|bunk)\b\s*(in|for|of)?\s*/, "").trim();
            const c = named ? course(named) : null;
            if (c) return card(Amazecc.attendanceTone(c) === "normal" ? "check_circle" : "warning", Amazecc.courseName(c) + ": " + c.pct + "%",
                               attLine(c), [], Amazecc.attendanceTone(c) === "normal" ? "normal" : "concerned");
            const all = Amazecc.courses.filter(c => c.total).sort((a, b) => a.pct - b.pct);
            const low = all.filter(c => c.pct < Amazecc.cfg.threshold);
            return card(low.length ? "warning" : "check_circle",
                        low.length ? low.length + (low.length === 1 ? " course is" : " courses are") + " below " + Amazecc.cfg.threshold + "%" : "All courses at or above " + Amazecc.cfg.threshold + "%",
                        all.slice(0, 8).map(c => Amazecc.courseName(c) + " · " + attLine(c)).join("\n"), [], low.length ? "concerned" : "normal");
        }

        // FAT targets: "what do I need in the FAT for an A in OS"
        if ((m = /\b(?:need|get|score)\b.*\bfat\b.*\b(?:for|to get)\s+(?:an?\s+)?([sabcde])\b(?:\s+(?:grade\s+)?in\s+(.+))?/.exec(l)) || (m = /\bfat\b.*\btargets?\b(?:\s+(?:for|in)\s+(.+))?/.exec(l))) {
            const grade = m[2] !== undefined || /\b[sabcde]\b/.test(m[1] ?? "") ? (m[1] ?? "").toUpperCase() : "";
            const name = m[2] ?? (grade ? "" : m[1]) ?? "";
            const c = course(name);
            const mk = c ? marksFor(c) : null;
            if (!c || !mk) return card("help", "Which course?", "Say it like “what do I need in the FAT for an A in OS”.");
            const t = Amazecc.targets(mk);
            if (!t) return card("info", c.title, "No internal marks posted yet (or it's a lab).");
            if (t.done) return card("task_alt", c.title + ": FAT done", "Total " + Amazecc.fmt(t.total) + " / 100.");
            const rows = (grade ? Amazecc.grades.filter(([g]) => g === grade) : Amazecc.grades).map(([g, cut]) => g + " (" + cut + "): FAT " + Amazecc.fatRange(t, g) + " / 100");
            return card("target", (grade ? grade + " in " : "FAT targets · ") + c.title,
                        rows.join("\n") + "\nInternals so far: " + Amazecc.fmt(t.earned) + " of " + t.weighed + ". Pass needs 40 in the FAT itself; grades above E are relative, so this is a guide.");
        }

        // marks
        if ((m = /\b(?:marks|grades?|scores?)\b(?:\s+(?:in|for|of)\s+(.+))?/.exec(l))) {
            const c = m[1] ? course(m[1]) : null;
            const list = c ? [marksFor(c)].filter(x => x) : Amazecc.marks;
            if (!list.length) return card("info", "No marks yet", c ? "Nothing posted for " + c.title + "." : "Nothing posted this semester.");
            return card("grading", c ? "Marks · " + c.title : "Your marks",
                        list.slice(0, 8).map(mk => mk.title + ": " + (mk.assessments.filter(a => a.scored !== null).map(a => a.title + " " + a.scored + "/" + a.max).join(", ") || "none yet")
                                              + (Amazecc.targetLine(mk) ? " — " + Amazecc.targetLine(mk) : "")).join("\n"));
        }

        // exams
        if (/\b(exams?|cat|fat)\b/.test(l)) {
            const ex = Amazecc.exams.filter(e => e.when > Date.now() - 86400000).slice(0, 6);
            if (!ex.length) return card("event_available", "No exams scheduled", "Nothing on VTOP's exam schedule yet.");
            const first = ex[0];
            return card("edit_note", Amazecc.examCountdown || (first.kind + " · " + first.title),
                        ex.map(e => e.kind + " · " + e.title + " — " + Planner.whenLabel(e.when, !e.timed) + (e.venue ? " · " + e.venue : "") + (e.seat ? " · seat " + e.seat : "")).join("\n"),
                        [{ label: "Make revision note", icon: "checklist", run: () => Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "amazecc", "revise", first.code + "|" + first.kind]) }]);
        }
        return null;
    }

    // ── a study plan, worked out here (no model): sooner and weaker first ──
    // Each day until the exams: up to two courses, not the same one two days
    // running unless it's the eve of its exam (then only that one).
    function plan(days) {
        const now = new Date(), today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const horizon = today.getTime() + (days ?? 21) * 86400000;
        const exams = Amazecc.exams.filter(e => e.when > Date.now() && e.when < horizon).sort((a, b) => a.when - b.when);
        if (!exams.length) return null;
        const info = exams.map(e => {
            const c = Amazecc.courses.find(x => x.code === e.code) ?? course(e.title);
            const t = marksFor(c) ? Amazecc.targets(marksFor(c)) : null;
            return { e, name: e.title, rate: t ? t.rate : 0.6, day: new Date(new Date(e.when).getFullYear(), new Date(e.when).getMonth(), new Date(e.when).getDate()).getTime() };
        });
        const out = [];
        let yesterday = [];
        for (let d = today.getTime(); d < info[info.length - 1].day; d += 86400000) {
            const open = info.filter(x => x.day > d);
            if (!open.length) break;
            const eve = open.find(x => x.day - d === 86400000);
            let pick;
            if (eve) pick = [eve];
            else {
                const scored = open.map(x => ({ x, p: (1.6 - x.rate) / Math.max(1, (x.day - d) / 86400000) - (yesterday.includes(x.name) ? 0.15 : 0) }))
                                   .sort((a, b) => b.p - a.p);
                pick = scored.slice(0, 2).map(y => y.x);
            }
            const exam = info.find(x => x.day === d);
            out.push({ day: d, items: pick.map(x => x.name), eve: !!eve, exam: exam ? exam.e : null });
            yesterday = pick.map(x => x.name);
        }
        return { exams: info.map(x => x.e), days: out };
    }
    function planText(p) {
        return p.days.map(d => Qt.formatDate(new Date(d.day), "ddd d MMM") + ": " + (d.eve ? "final revision — " + d.items[0] + " (past papers, formulas, weak topics)" : d.items.join(" · "))
                                   + (d.exam ? "  [exam: " + d.exam.title + "]" : "")).join("\n");
    }
    function studyPlanCard() {
        if (!on) return needsSetup();
        const p = plan(45);
        if (!p) return card("event_available", "No exams in the next six weeks", "Nothing to plan for yet — I'll keep an eye on VTOP's schedule.");
        const first = p.days[0]?.items[0] ?? p.exams[0].title;
        const text = planText(p);
        return { glyph: "edit_calendar", title: "Revision plan", own: () => Halo.say({ key: "college", icon: "edit_calendar",
            title: "Revision plan · " + p.exams.length + (p.exams.length === 1 ? " exam" : " exams") + " in " + p.days.length + " days",
            text: text, level: "asked", duration: 20000, actions: [
                { label: "Study " + (first.length > 24 ? first.slice(0, 22).trim() + "…" : first) + " now", icon: "play_arrow", run: () => { Focus.set("study"); Countdown.startTimer(50 * 60000, "Study: " + first); } },
                { label: "Save as a note", icon: "note_add", run: () => root.savePlan(p) },
                { label: "Add evenings to calendar", icon: "event", run: () => {
                    for (const d of p.days) Planner.addEventAt("Study: " + d.items.join(" + "), d.day + 19 * 3600000, false);
                    Halo.say({ key: "college", icon: "event", title: "Added " + p.days.length + " study evenings (7 PM)", text: "In the planner's calendar.", level: "asked", tone: "happy", duration: 4000 });
                } }] }) };
    }
    function savePlan(p) {
        const body = "Exams: " + p.exams.map(e => e.kind + " " + e.title + " — " + Planner.whenLabel(e.when, !e.timed)).join("; ") + "\n\n"
                   + p.days.map(d => "- [ ] " + Qt.formatDate(new Date(d.day), "ddd d MMM") + ": " + (d.eve ? "final revision — " + d.items[0] : d.items.join(" · "))).join("\n");
        saver.command = ["sh", "-c", 'f=$("$1" --dir "$2" new "$3") && printf "%s\\n" "$4" >> "$2/$f" && echo "$f"',
                         "sh", Theme.lumenRoot + "/scripts/notes.py", Notes.dir, "Revision plan " + Qt.formatDate(new Date(), "d MMM"), body];
        saver.running = true;
    }
    Process {
        id: saver
        stdout: StdioCollector { onStreamFinished: { Notes.refresh(); if (text.trim()) Halo.say({ key: "college", icon: "note_add", title: "Saved to Notes", text: text.trim(), level: "asked", tone: "happy", duration: 5000,
                                                       actions: [{ label: "Open", icon: "open_in_new", run: () => Notes.launch(text.trim()) }] }); } }
    }

    // ── bunk budget: what each course can spare, this week ──
    function budgetCard() {
        if (!on) return needsSetup();
        const all = Amazecc.courses.filter(c => c.total).sort((a, b) => Amazecc.skippable(a) - Amazecc.skippable(b));
        const total = all.reduce((n, c) => n + Amazecc.skippable(c), 0);
        return card("savings", "Bunk budget · " + total + " class" + (total === 1 ? "" : "es") + " to spare",
                    all.map(c => Amazecc.courseName(c) + ": " + (c.pct < Amazecc.cfg.threshold ? "none — attend the next " + Amazecc.needed(c) : Amazecc.skippable(c) + " left")).join("\n"),
                    [], all.some(c => c.pct < Amazecc.cfg.threshold) ? "concerned" : "normal");
    }

    // ── the morning guardian: a class you can't afford to miss today ──
    property string guarded: ""
    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true
        running: Persist.automates && root.on
        onTriggered: {
            const now = new Date(), key = Qt.formatDate(now, "yyyy-MM-dd");
            if (root.guarded === key || now.getHours() < 7 || now.getHours() >= 11) return;
            const risky = Amazecc.today.map(c => ({ c, co: root.courseOf(c) })).filter(x => x.co?.total && x.co.pct < Amazecc.cfg.threshold + 2 && x.c.start > Amazecc.nowMin);
            root.guarded = key;
            if (!risky.length) return;
            const x = risky[0];
            Halo.say({ key: "guardian", icon: "shield", title: "Don't skip " + x.c.title + " today", tone: "concerned", level: "important", throughQuiet: true, duration: 15000,
                       text: Amazecc.clockLabel(x.c.start) + (x.c.venue ? " · " + x.c.venue : "") + " · attendance " + root.attLine(x.co)
                             + (risky.length > 1 ? " · also " + risky.slice(1).map(y => y.c.title).join(", ") : ""),
                       actions: [{ label: "Remind me 15 min before", icon: "alarm", run: () => Halo.addReminder(root.classTime(new Date(), x.c).getTime() - 900000, x.c.title + (x.c.venue ? " at " + x.c.venue : "")) }] });
        }
    }

    // ── deadlines in notifications: "Assignment due Friday 5 PM" → the planner ──
    Connections {
        target: Notifications
        function onArrived(appName, summary, body) {
            if (!Persist.automates) return;
            const text = (summary + " " + Notifications.plain(body)).replace(/\s+/g, " ").trim();
            if (!/\b(assignment|deadline|due|submit|submission|quiz|lab record|report|DA\s?\d|digital assignment|project review)\b/i.test(text)) return;
            if (!/\b(due|by|before|deadline|on|until|till)\b/i.test(text)) return;
            const ev = Planner.parse(text);
            Halo.say({ key: "deadline:" + summary, icon: "assignment_late", title: "Looks like a deadline", text: summary + (body ? " — " + Notifications.plain(body).slice(0, 120) : ""),
                       level: "important", duration: 15000,
                       actions: [ev ? { label: "Add “" + ev.title.slice(0, 24) + "” · " + Planner.whenLabel(ev.when, ev.allDay), icon: "event", run: () => Planner.addEventAt(ev.title, ev.when, ev.allDay) } : null,
                                 { label: "Add a to-do", icon: "checklist", run: () => Planner.addTodo(summary) }].filter(a => a) });
        }
    }

    // For the agent: the facts as text
    function text(topic) {
        if (!on) return "AmazeCC (college data) isn't set up.";
        const it = intent(topic || "attendance");
        if (!it?.own) return "Nothing found for: " + topic;
        // run the card builder without showing it: capture what it would say
        let said = null;
        try { Halo.capture = c => said = c; it.own(); } finally { Halo.capture = null; }
        return said ? said.title + "\n" + (said.text ?? "") : "Nothing found for: " + topic;
    }
}
