// Study: everything for your courses in one place — what's coming, each
// course's folder, past papers, lecture plan, attendance and what you need in
// the FAT; classes you missed (with their topics); recent files; the vault
// backup. Data from services/Study.qml (scripts/study.py) and AmazeCC.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Study"
    subtitle: Study.courses.length ? Study.courses.length + " courses · " + Study.papers.filter(p => p.exists).length + " past papers in your folders"
                                   : "Your courses appear here after AmazeCC's first sync"
    signal go(string page)
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Component.onCompleted: Study.refresh()

    headerRight: [
        CollegeButton { text: Study.syncing ? "Fetching…" : "Fetch new papers"; icon: "download"; enabled: !Study.syncing; onActivated: Study.syncPapers(true) },
        CollegeButton { text: "Refresh"; icon: "refresh"; onActivated: Study.refresh() }
    ]

    function ago(ms) {
        const m = Math.round((Date.now() - ms) / 60000);
        return !ms ? "never" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
    }
    function teacher(f) { return (f ?? "").replace(/^\d+\s*/, "").replace(/\s+(SCOPE|SELECT|SENSE|SMEC|SAS|ACAD|VITBS|SSL)$/i, "").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()); }
    function att(code) { return Study.attendance.filter(a => a.code === code); }

    // What you need in the FAT for each grade (VIT's absolute scale: S 90, A 80,
    // B 70, C 60, D 55, E 50 out of 100; relative grading can move these).
    function goal(code) {
        const m = Amazecc.marks.find(x => x.code === code && x.kind === "theory");
        if (!m) return null;
        const as = m.assessments ?? [];
        if (as.some(a => /final|fat/i.test(a.title))) return null;          // the FAT is already in
        const have = as.reduce((s, a) => s + (a.weightMark ?? 0), 0), weighed = as.reduce((s, a) => s + (a.weight ?? 0), 0);
        const fatW = Math.max(0, 100 - weighed);                           // what's left: usually the FAT's 40
        if (fatW < 10) return null;
        return [["S", 90], ["A", 80], ["B", 70], ["C", 60]].map(([g, cut]) => {
            const need = (cut - have) / fatW * 100;
            return { grade: g, need: Math.max(0, Math.ceil(need)), reachable: need <= 100 };
        }).concat([{ have: Math.round(have * 10) / 10, of: weighed, fat: fatW }]);
    }

    // ── what's coming ──
    readonly property var soon: { clock.date; return Amazecc.exams.filter(e => (e.end ?? e.when) > Date.now()).slice(0, 6); }
    Card {
        width: parent.width; title: "Coming up"; icon: "event_upcoming"
        Column {
            width: parent.width; spacing: Theme.space.s2
            LText { visible: page.soon.length === 0; color: Theme.textMuted; text: "No exams on VTOP's schedule." }
            Repeater {
                model: page.soon
                Item {
                    id: ex
                    required property var modelData
                    readonly property int days: Amazecc.daysTo(modelData.when)
                    readonly property var ps: Study.papersFor(modelData.code, Study.examType(modelData.kind))
                    width: parent.width; height: 52
                    Column {
                        width: 74; anchors.verticalCenter: parent.verticalCenter
                        LText { role: "heading"; color: ex.days <= 2 ? Theme.warning : Theme.accent; text: ex.days === 0 ? "Today" : ex.days === 1 ? "Tomorrow" : ex.days + " days" }
                        LText { role: "caption"; color: Theme.textMuted; text: Qt.formatDate(new Date(ex.modelData.when), "ddd d MMM") }
                    }
                    Column {
                        x: 84; width: parent.width - 84 - btns.width - Theme.space.s3; anchors.verticalCenter: parent.verticalCenter
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: ex.modelData.kind + " · " + ex.modelData.title }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                text: [ex.modelData.time, ex.modelData.venue, ex.modelData.seat ? "seat " + ex.modelData.seat : "",
                                       ex.ps.length ? ex.ps.filter(p => p.done).length + "/" + ex.ps.length + " past papers done" : "no past papers found"].filter(x => x).join(" · ") }
                    }
                    Row {
                        id: btns; spacing: Theme.space.s2
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        CollegeButton { visible: ex.ps.length > 0; text: "Papers"; icon: "quiz"; onActivated: page.go("papers:" + ex.modelData.code) }
                        CollegeButton { text: "Revise 45 min"; icon: "timer"; onActivated: Study.startSession(ex.modelData.code, 45) }
                    }
                }
            }
        }
    }

    // ── each course ──
    Repeater {
        model: Study.courses
        Card {
            id: cc
            required property var modelData
            readonly property var g: page.goal(modelData.code)
            width: parent.width
            title: modelData.title
            icon: "menu_book"
            headerRight: LText { role: "caption"; color: Theme.textMuted; text: cc.modelData.code + " · " + page.teacher(cc.modelData.faculty) }
            Column {
                width: parent.width; spacing: Theme.space.s2
                // the numbers
                Flow {
                    width: parent.width; spacing: Theme.space.s4
                    Repeater {
                        model: [
                            { icon: "quiz", text: cc.modelData.papers ? cc.modelData.papersDone + " / " + cc.modelData.papers + " papers done" : "No past papers yet" },
                            { icon: "event_note", text: cc.modelData.lectures ? cc.modelData.lecturesDone + " / " + cc.modelData.lectures + " lectures covered" : "No lecture plan on VTOP" },
                            { icon: "timer", text: cc.modelData.weekMinutes ? Math.round(cc.modelData.weekMinutes) + " min studied this week" : "Not studied this week" }
                        ].concat(page.att(cc.modelData.code).map(a => ({ icon: "how_to_reg", tone: a.pct < 75 ? "bad" : a.pct < 76 ? "warn" : "",
                                 text: (a.kind === "lab" ? "Lab " : "Theory ") + a.pct + "%" + (a.left > 0 ? " · " + (a.needAll ? "attend every class" : "can miss " + a.canMiss + " of " + a.left) : "") })))
                        Row {
                            required property var modelData
                            spacing: 5
                            LIcon { icon: parent.modelData.icon; size: 15; color: parent.modelData.tone === "bad" ? Theme.error : parent.modelData.tone === "warn" ? Theme.warning : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; color: parent.modelData.tone === "bad" ? Theme.error : Theme.textSecondary; text: parent.modelData.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                LText { visible: !!cc.modelData.lastTopic; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: "Last class: " + cc.modelData.lastTopic }
                // what the FAT needs
                Row {
                    visible: !!cc.g
                    spacing: Theme.space.s3
                    LText { role: "caption"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                            text: cc.g ? "You have " + cc.g[4].have + " / " + cc.g[4].of + " · in the FAT (" + cc.g[4].fat + " %) you need:" : "" }
                    Repeater {
                        model: cc.g ? cc.g.slice(0, 4) : []
                        Rectangle {
                            required property var modelData
                            width: gl.implicitWidth + 16; height: 22; radius: 11
                            color: modelData.reachable ? Theme.withAlpha(Theme.accent, 0.12) : Theme.withAlpha(Theme.text, 0.05)
                            LText { id: gl; anchors.centerIn: parent; role: "caption"; color: modelData.reachable ? Theme.text : Theme.textMuted
                                    text: modelData.grade + " " + (modelData.reachable ? modelData.need + "/100" : "out of reach") }
                        }
                    }
                }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    CollegeButton { visible: !!cc.modelData.folder; text: "Open folder"; icon: "folder_open"; onActivated: Quickshell.execDetached(["xdg-open", cc.modelData.folder]) }
                    CollegeButton { visible: cc.modelData.papers > 0; text: "Past papers"; icon: "quiz"; onActivated: page.go("papers:" + cc.modelData.code) }
                    CollegeButton { text: "Lectures"; icon: "event_note"; onActivated: page.go("lectures:" + cc.modelData.code) }
                    CollegeButton { text: "Flashcards"; icon: "style"; onActivated: page.go("cards:" + cc.modelData.code) }
                    CollegeButton { text: "Revise 45 min"; icon: "timer"; onActivated: Study.startSession(cc.modelData.code, 45) }
                }
            }
        }
    }

    // ── classes you missed ──
    Card {
        visible: Study.missed.length > 0
        width: parent.width; title: "Classes you missed"; icon: "event_busy"
        headerRight: LText { role: "caption"; color: Theme.textMuted; text: "since " + (Study.missed.length ? Qt.formatDate(new Date(Study.missed[0].from), "d MMM") : "") }
        Column {
            width: parent.width; spacing: 6
            Repeater {
                model: Study.missed.slice().reverse().slice(0, 10)
                Row {
                    required property var modelData
                    width: parent.width; spacing: Theme.space.s3
                    LText { width: 64; role: "caption"; color: Theme.textMuted; text: Qt.formatDate(new Date(modelData.to), "ddd d MMM") }
                    LText { width: 150; elide: Text.ElideRight; role: "caption"; text: modelData.course }
                    LText { width: parent.width - 240; elide: Text.ElideRight; role: "caption"; color: modelData.topics.length ? Theme.text : Theme.textMuted
                            text: modelData.topics.length ? modelData.topics.join(" · ") : "topic not on VTOP" }
                }
            }
        }
    }

    // ── recent files ──
    Card {
        visible: Study.recent.length > 0
        width: parent.width; title: "Recently opened"; icon: "history"
        Column {
            width: parent.width; spacing: 2
            Repeater {
                model: Study.recent.slice(0, 8)
                HoverTarget {
                    required property var modelData
                    width: parent.width; height: 32; radius: Theme.radius.sm
                    onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                        spacing: Theme.space.s3
                        LIcon { icon: /\.pdf$/i.test(parent.parent.modelData.name) ? "picture_as_pdf" : "description"; size: 16; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        LText { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.modelData.name; width: Math.min(implicitWidth, 420); elide: Text.ElideMiddle }
                        LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted; text: parent.parent.modelData.course.replace(/^[A-Z0-9]+ - /, "") }
                    }
                }
            }
        }
    }

    // ── the vault ──
    Card {
        visible: !!Study.backup.repo
        width: parent.width; title: "Academics backup"; icon: Study.backup.stale || Study.backup.logFailed ? "cloud_off" : "cloud_done"
        Column {
            width: parent.width; spacing: 4
            LText { color: Study.backup.stale || Study.backup.logFailed ? Theme.warning : Theme.text
                    text: Study.backup.logFailed ? "Last night's backup reported an error"
                        : "Last backup " + page.ago(Study.backup.lastCommit ?? 0) + (Study.backup.stale ? " — the 23:00 job may not be running" : " · every night at 23:00") }
            LText { role: "caption"; color: Theme.textMuted
                    text: Math.round((Study.backup.gitBytes ?? 0) / 1048576) + " MB of history · " + (Study.backup.pending ?? 0) + " changes waiting for tonight" }
        }
    }

    // ── a new semester ──
    Card {
        id: sem
        width: parent.width; title: "New semester"; icon: "create_new_folder"
        property var plan: null
        property bool armed: false
        Column {
            width: parent.width; spacing: Theme.space.s2
            LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                    text: "When VTOP shows your next semester's courses, make their folders in one go — the same subfolders you use now — and the current one stops being \"(Current)\"." }
            Row {
                spacing: Theme.space.s2
                LField { id: semName; width: 300; icon: "edit"; placeholder: "e.g. Semester 4 - Winter 2026-27"; clearOnAccept: false
                         onAccepted: t => Study.run(["newsem", t], r => { sem.plan = r; sem.armed = false; }) }
                CollegeButton { text: "Preview"; icon: "visibility"; onActivated: Study.run(["newsem", semName.text], r => { sem.plan = r; sem.armed = false; }) }
            }
            LText { visible: !!sem.plan; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: sem.plan?.ok ? Theme.textSecondary : Theme.error
                    text: !sem.plan ? "" : !sem.plan.ok ? sem.plan.error : sem.plan.applied ? "Done — " + sem.plan.folders.length + " folders made."
                        : sem.plan.folders.length + " folders in \"" + sem.plan.root.replace(/^.*\//, "") + "\"" + (sem.plan.renameOld ? "; the current semester loses \"(Current)\"" : "") + "." }
            // creating is safe; renaming the old semester asks twice (DESIGN §0)
            CollegeButton { visible: !!sem.plan?.ok && !sem.plan?.applied; text: sem.armed ? "Click again to create them" : "Create the folders"; icon: "create_new_folder"; selected: sem.armed
                            onActivated: { if (!sem.armed) { sem.armed = true; return; } Study.run(["newsem", semName.text, "--apply"], r => { sem.plan = r; sem.armed = false; Study.refresh(); }); } }
        }
    }
}
