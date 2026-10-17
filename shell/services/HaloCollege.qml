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
        const collegey = /\b(class(es)?|lecture|lab|attendance|bunk|skip|marks?|grades?|fat|cat|exams?|timetable|semester)\b/.test(l);
        if (!collegey) return null;
        if (!on) return needsSetup();
        let m;

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
