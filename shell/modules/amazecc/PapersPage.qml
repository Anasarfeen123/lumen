// Past papers: every paper Lumen found for your courses (four collections) and
// the ones in your own folders. Search, filter by subject, exam, year, source
// and what you've done; sort; tick practised papers; add your own (button or
// drop files on the page); count which topics come up; ask Halo.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property string course: ""             // a course code, or "" for all
    property string exam: ""                // "", "CAT 1", "CAT 2", "FAT", "Other"
    property string year: ""
    property string source: ""              // "", "mine", "MIC", "ExamCooker", "GitHub"
    property string status: ""              // "", "todo", "done"
    property bool keysOnly: false
    property string sort: "newest"          // newest | oldest | exam
    property string query: ""
    property var topics: null
    property bool topicsBusy: false
    property string note: ""
    title: "Past papers"
    subtitle: Study.papers.filter(p => p.exists).length + " papers · " + Study.papers.filter(p => p.exists && p.done).length + " practised · collections checked " + fetched
    readonly property string fetched: {
        const t = Study.overview.pyqFetchedAt ?? 0, m = Math.round((Date.now() - t) / 60000);
        return !t ? "never" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
    }
    function srcKind(p) { return p.source === "your folder" ? "mine" : /exam ?cooker/i.test(p.source) ? "ExamCooker" : /github/i.test(p.source) ? "GitHub" : "MIC"; }
    function examKind(p) { return ["CAT 1", "CAT 2", "FAT"].includes(p.exam) ? p.exam : "Other"; }
    readonly property var all: Study.papers.filter(p => p.exists)
    // each filter's options count what the OTHER filters leave, so a chip never leads to nothing
    function pass(p, skip) {
        const q = page.query.trim().toLowerCase();
        return (skip === "course" || !course || p.code === course)
            && (skip === "exam" || !exam || examKind(p) === exam)
            && (skip === "year" || !year || String(p.year) === year)
            && (skip === "source" || !source || srcKind(p) === source)
            && (skip === "status" || !status || (status === "done") === !!p.done)
            && (!keysOnly || !!p.key)
            && (!q || q.split(/\s+/).every(w => [p.exam, p.year, p.slot, p.course, p.code, p.source, p.sourceTitle ?? "", p.path.replace(/^.*\//, "")].join(" ").toLowerCase().includes(w)));
    }
    readonly property var list: all.filter(p => pass(p, "")).sort((a, b) =>
        sort === "exam" ? (a.code.localeCompare(b.code) || examKind(a).localeCompare(examKind(b)) || String(b.year).localeCompare(String(a.year)))
        : sort === "oldest" ? (String(a.year || "9").localeCompare(String(b.year || "9")) || a.exam.localeCompare(b.exam))
        : (String(b.year).localeCompare(String(a.year)) || a.exam.localeCompare(b.exam)))
    readonly property var years: [...new Set(all.filter(p => pass(p, "year")).map(p => String(p.year)).filter(y => y))].sort().reverse()
    function count(f, v) { return all.filter(p => pass(p, f) && (f === "course" ? (!v || p.code === v) : f === "exam" ? (!v || examKind(p) === v) : f === "source" ? (!v || srcKind(p) === v) : f === "status" ? (!v || (v === "done") === !!p.done) : true)).length; }
    function clear() { course = ""; exam = ""; year = ""; source = ""; status = ""; keysOnly = false; query = ""; search.text = ""; }
    readonly property bool filtered: !!(course || exam || year || source || status || keysOnly || query)
    onCourseChanged: topics = null
    Component.onCompleted: if (!Study.papers.length) Study.refresh()

    // adding your own papers: to the chosen course, or ask which
    property var pending: []
    function add(paths) {
        const files = paths.map(p => p.replace(/^file:\/\//, "")).map(p => decodeURIComponent(p)).filter(p => /\.(pdf|png|jpe?g)$/i.test(p));
        if (!files.length) { note = "Only PDFs and photos can be added."; return; }
        if (!course) { pending = files; note = "Which subject are these for? Pick one above, then they're added."; return; }
        Study.run(["addpaper", course].concat(files), r => { page.note = r.ok ? r.added.length + " added to " + (Study.courses.find(c => c.code === page.course)?.title ?? "") + " · Exams & Question Papers/Added" : (r.error ?? "Couldn't add them"); Study.refresh(); });
        pending = [];
    }
    Connections { target: page; function onCourseChanged() { if (page.pending.length && page.course) page.add(page.pending); } }

    headerRight: [
        CollegeButton { text: "Add papers"; icon: "upload_file"; onActivated: Study.run(["pick", "Add past papers"], r => { if (r.paths?.length) page.add(r.paths); }) },
        CollegeButton { text: Study.syncing ? "Checking…" : "Check collections"; icon: "download"; enabled: !Study.syncing; onActivated: Study.syncPapers(true) }
    ]

    // drop files anywhere on the page
    DropArea {
        z: 10
        parent: page
        anchors.fill: parent
        keys: ["text/uri-list"]
        onEntered: page.note = "Drop to add " + (page.course ? "to " + (Study.courses.find(c => c.code === page.course)?.title ?? "") : "— then pick the subject")
        onExited: page.note = ""
        onDropped: d => page.add(d.urls.map(u => u.toString()))
    }

    // search
    Row {
        width: parent.width; spacing: Theme.space.s2
        LField { id: search; width: Math.min(460, parent.width - 160); icon: "search"; placeholder: "Search: 2025, slot B2, FAT, ExamCooker, a file name…"; clearOnAccept: false
                 input.onTextEdited: page.query = text; onAccepted: t => page.query = t }
        CollegeButton { visible: page.filtered; text: "Clear filters"; icon: "filter_alt_off"; onActivated: page.clear() }
    }
    LText { visible: page.note !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.accent; text: page.note }

    // filters — every subject is here, with how many papers it has
    component Label: LText { role: "caption"; color: Theme.textMuted; width: 64; topPadding: 9 }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Label { text: "Subject" }
        CollegeButton { text: "All · " + page.count("course", ""); selected: page.course === ""; onActivated: page.course = "" }
        Repeater {
            model: Study.courses
            CollegeButton { required property var modelData; text: modelData.title.replace(/^Fundamentals of /, "").replace(/ Practice I$/, "") + " · " + page.count("course", modelData.code)
                            selected: page.course === modelData.code; onActivated: page.course = modelData.code }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Label { text: "Exam" }
        Repeater {
            model: ["", "CAT 1", "CAT 2", "FAT", "Other"]
            CollegeButton { required property string modelData; text: (modelData || "Any") + " · " + page.count("exam", modelData); selected: page.exam === modelData; onActivated: page.exam = modelData }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Label { text: "Year" }
        CollegeButton { text: "Any"; selected: page.year === ""; onActivated: page.year = "" }
        Repeater {
            model: page.years
            CollegeButton { required property string modelData; text: modelData; selected: page.year === modelData; onActivated: page.year = page.year === modelData ? "" : modelData }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Label { text: "From" }
        Repeater {
            model: [{ id: "", t: "Anywhere" }, { id: "mine", t: "Your folders" }, { id: "MIC", t: "MIC / vhelp" }, { id: "ExamCooker", t: "ExamCooker" }, { id: "GitHub", t: "GitHub" }]
            CollegeButton { required property var modelData; text: modelData.t + " · " + page.count("source", modelData.id); selected: page.source === modelData.id; onActivated: page.source = modelData.id }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Label { text: "Show" }
        Repeater {
            model: [{ id: "", t: "All" }, { id: "todo", t: "To practise" }, { id: "done", t: "Practised" }]
            CollegeButton { required property var modelData; text: modelData.t + " · " + page.count("status", modelData.id); selected: page.status === modelData.id; onActivated: page.status = modelData.id }
        }
        CollegeButton { text: "With answer key"; icon: "key"; selected: page.keysOnly; onActivated: page.keysOnly = !page.keysOnly }
        Item { width: Theme.space.s4; height: 1 }
        Label { text: "Sort" }
        Repeater {
            model: [{ id: "newest", t: "Newest" }, { id: "oldest", t: "Oldest" }, { id: "exam", t: "By exam" }]
            CollegeButton { required property var modelData; text: modelData.t; selected: page.sort === modelData.id; onActivated: page.sort = modelData.id }
        }
    }

    // which topics come up (one subject)
    Card {
        visible: !!page.course
        width: parent.width; title: "What comes up"; icon: "insights"
        headerRight: Row {
            spacing: Theme.space.s2
            CollegeButton { text: page.topicsBusy ? "Reading the papers…" : page.topics ? "Count again" : "Count topics"; icon: "bar_chart"; enabled: !page.topicsBusy
                            onActivated: { page.topicsBusy = true; Study.run(["topics", page.course], r => { page.topics = r; page.topicsBusy = false; }); } }
            CollegeButton { text: "Ask Halo"; icon: "auto_awesome"; enabled: page.list.length > 0
                            onActivated: { Ai.askAboutFiles(page.list.slice(0, 5).map(p => p.path));
                                           Qt.callLater(() => Ai.send("These are past exam papers for " + (Study.courses.find(c => c.code === page.course)?.title ?? "my course") + ". Which topics and question types come up most often? Then give me a short revision checklist, most likely first.")); } }
        }
        Column {
            width: parent.width; spacing: 5
            LText { visible: !page.topics; width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                    text: "Matches the topics in your teacher's lecture plan against the text of this subject's papers (scanned ones are read with OCR), to show what's asked most." }
            LText { visible: !!page.topics && page.topics.topics.length === 0; color: Theme.textMuted
                    text: "No lecture plan on VTOP for this course to compare with — Ask Halo reads the papers instead." }
            Repeater {
                model: page.topics ? page.topics.topics.slice(0, 12) : []
                Row {
                    required property var modelData
                    width: parent.width; spacing: Theme.space.s3
                    Rectangle {
                        width: 120; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: Theme.withAlpha(Theme.text, 0.07)
                        Rectangle { width: parent.width * Math.min(1, modelData.papers / Math.max(1, page.topics.papersRead)); height: parent.height; radius: 4; color: Theme.accent }
                    }
                    LText { width: 60; role: "caption"; color: Theme.textMuted; text: modelData.papers + " / " + page.topics.papersRead; anchors.verticalCenter: parent.verticalCenter }
                    LText { width: parent.width - 200; elide: Text.ElideRight; text: modelData.topic; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // the papers, grouped by subject
    LText { visible: page.list.length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
            text: page.filtered ? "Nothing matches these filters." : page.course ? "No papers for this subject in any collection yet — Lumen checks every day. Add your own with Add papers, or drop files here."
                                : "No papers yet — Check collections." }
    Repeater {
        model: [...new Set(page.list.map(p => p.code))]
        Card {
            id: grp
            required property string modelData
            readonly property var rows: page.list.filter(p => p.code === modelData)
            width: parent.width
            title: Study.courses.find(c => c.code === modelData)?.title ?? modelData
            icon: "description"
            headerRight: LText { role: "caption"; color: Theme.textMuted; text: grp.rows.length + " papers · " + grp.rows.filter(p => p.done).length + " practised" }
            Column {
                width: parent.width; spacing: 2
                Repeater {
                    model: grp.rows
                    Item {
                        id: row
                        required property var modelData
                        width: parent.width; height: 40
                        HoverTarget {
                            id: tick
                            width: 28; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
                            onClicked: Study.setDone(row.modelData, !row.modelData.done)
                            LIcon { anchors.centerIn: parent; icon: row.modelData.done ? "check_circle" : "radio_button_unchecked"; fill: row.modelData.done ? 1 : 0; size: 20
                                    color: row.modelData.done ? Theme.success : Theme.textMuted }
                        }
                        HoverTarget {
                            anchors { left: tick.right; leftMargin: Theme.space.s2; right: acts.left; rightMargin: Theme.space.s2; top: parent.top; bottom: parent.bottom }
                            radius: Theme.radius.sm
                            onClicked: Quickshell.execDetached(["xdg-open", row.modelData.path])
                            Column {
                                anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter; right: parent.right }
                                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; color: row.modelData.done ? Theme.textMuted : Theme.text
                                        text: row.modelData.exam + (row.modelData.year ? " " + row.modelData.year : "") + (row.modelData.slot ? " · slot " + row.modelData.slot : "") }
                                LText { width: parent.width; elide: Text.ElideMiddle; role: "caption"; color: Theme.textMuted
                                        text: row.modelData.source === "your folder" ? "Your folder · " + row.modelData.path.replace(/^.*\/Exams & Question Papers\//, "")
                                                                                    : (row.modelData.sourceTitle ? row.modelData.sourceTitle.replace(/^.*\//, "") + " · " : "") + row.modelData.source }
                            }
                        }
                        Row {
                            id: acts
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s1
                            CollegeButton { visible: !!row.modelData.key; text: "Answer key"; icon: "key"; onActivated: Quickshell.execDetached(["xdg-open", row.modelData.key]) }
                            HoverTarget { width: 30; height: 30; radius: 15; onClicked: Quickshell.execDetached(["xdg-open", row.modelData.path.replace(/\/[^/]*$/, "")])
                                          LIcon { anchors.centerIn: parent; icon: "folder_open"; size: 17; color: Theme.textSecondary } }
                            HoverTarget { width: 30; height: 30; radius: 15
                                          onClicked: { Ai.askAboutFiles([row.modelData.path]); Qt.callLater(() => Ai.send("Help me practise this past paper: for each question give the key idea and a short solution sketch.")); }
                                          LIcon { anchors.centerIn: parent; icon: "auto_awesome"; size: 17; color: Theme.textSecondary } }
                        }
                    }
                }
            }
        }
    }
}
