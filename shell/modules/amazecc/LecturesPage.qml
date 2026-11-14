// Lectures: your teacher's lecture plan from VTOP (each class's date and
// topic), what's been covered, the classes you missed and their topics; the
// syllabus PDFs; a module checklist for revision.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property string course: Study.courses[0]?.code ?? ""
    property var plan: ({})                 // lectures.json
    property var syllabi: []
    readonly property var c: Study.courses.find(x => x.code === course) ?? null
    readonly property var allRows: plan[course]?.rows ?? []
    property string show: ""                 // "" | covered | coming | missed | theory | lab
    property string query: ""
    readonly property var rows: allRows.filter(r => {
        const q = query.trim().toLowerCase();
        return (!q || q.split(/\s+/).every(w => (r.topic + " " + r.slot + " " + r.date).toLowerCase().includes(w)))
            && (show === "" || (show === "covered" && r.date <= today) || (show === "coming" && r.date > today)
                || (show === "missed" && missedTopics.includes(r.topic)) || (show === r.kind));
    })
    readonly property var missedTopics: [].concat(...Study.missed.filter(m => m.code === course).map(m => m.topics))
    readonly property var modules: c?.modules ?? ({})
    title: "Lectures"
    subtitle: c ? c.title + " · " + (allRows.length ? allRows.filter(r => r.date <= today).length + " of " + allRows.length + " classes covered" : (plan[course]?.missing ?? "No lecture plan yet")) : ""
    readonly property string today: Qt.formatDate(new Date(), "yyyy-MM-dd")
    onCourseChanged: findSyllabi()
    onCChanged: findSyllabi()                // (the course list loads a moment after the page)
    Component.onCompleted: { load(); findSyllabi(); }
    function load() { reader.running = true; }
    function findSyllabi() {
        if (!c?.folder) { syllabi = []; return; }
        finder.command = ["sh", "-c", 'ls -1 "$1"/Syllabus/*.pdf 2>/dev/null', "sh", c.folder];
        finder.running = true;
    }
    Process {
        id: reader
        command: ["cat", (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/study/lectures.json"]
        stdout: StdioCollector { onStreamFinished: { try { page.plan = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: finder
        stdout: StdioCollector { onStreamFinished: page.syllabi = text.split("\n").filter(x => x) }
    }

    headerRight: [
        CollegeButton { text: "Update from VTOP"; icon: "sync"; onActivated: Study.run(["lectures", "sync"], () => page.load()) }
    ]

    Flow {
        width: parent.width; spacing: Theme.space.s2
        Repeater {
            model: Study.courses
            CollegeButton { required property var modelData; text: modelData.title.replace(/^Fundamentals of /, ""); selected: page.course === modelData.code; onActivated: page.course = modelData.code }
        }
    }

    // syllabus + modules
    Card {
        width: parent.width; title: "Syllabus"; icon: "list_alt"
        Column {
            width: parent.width; spacing: Theme.space.s2
            Flow {
                width: parent.width; spacing: Theme.space.s2
                LText { visible: page.syllabi.length === 0; color: Theme.textMuted; text: "No syllabus PDF in this course's Syllabus folder yet — Update from VTOP fetches it." }
                Repeater {
                    model: page.syllabi
                    CollegeButton { required property string modelData; icon: "picture_as_pdf"; text: modelData.replace(/^.*\//, "").replace(/\.pdf$/, ""); onActivated: Quickshell.execDetached(["xdg-open", modelData]) }
                }
            }
            LText { role: "caption"; color: Theme.textMuted; text: "Modules revised — tick them as you go:" }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                Repeater {
                    model: 7
                    CollegeButton {
                        required property int index
                        readonly property bool on: !!page.modules[String(index + 1)]
                        text: "Module " + (index + 1); icon: on ? "check_circle" : "radio_button_unchecked"; selected: on
                        onActivated: Study.run(on ? ["module", page.course, String(index + 1), "--undo"] : ["module", page.course, String(index + 1)], () => Study.refresh())
                    }
                }
            }
        }
    }

    // search and filter the plan
    Row {
        visible: page.allRows.length > 0
        width: parent.width; spacing: Theme.space.s2
        LField { width: 300; icon: "search"; placeholder: "Search topics: normalization, B+ tree…"; clearOnAccept: false; input.onTextEdited: page.query = text }
        Repeater {
            model: [{ id: "", t: "All" }, { id: "covered", t: "Covered" }, { id: "coming", t: "Coming" }, { id: "missed", t: "You missed" }, { id: "theory", t: "Theory" }, { id: "lab", t: "Lab" }]
            CollegeButton { required property var modelData; anchors.verticalCenter: parent.verticalCenter; text: modelData.t; selected: page.show === modelData.id; onActivated: page.show = modelData.id }
        }
    }
    // the plan
    Card {
        width: parent.width; title: page.rows.length === page.allRows.length ? "Lecture plan" : page.rows.length + " of " + page.allRows.length + " classes"; icon: "event_note"
        headerRight: LText { role: "caption"; color: Theme.textMuted; visible: page.missedTopics.length > 0; text: page.missedTopics.length + " missed — marked" }
        Column {
            width: parent.width; spacing: 1
            LText { visible: page.allRows.length > 0 && page.rows.length === 0; color: Theme.textMuted; text: "Nothing matches." }
            LText { visible: page.allRows.length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                    text: page.plan[page.course]?.missing ? page.plan[page.course].missing + " — your syllabus and past papers are still here." : "Not fetched yet — Update from VTOP." }
            Repeater {
                model: page.rows
                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool past: modelData.date <= page.today
                    readonly property bool missed: page.missedTopics.includes(modelData.topic)
                    width: parent.width; height: Math.max(30, tl.implicitHeight + 10); radius: Theme.radius.sm
                    color: missed ? Theme.withAlpha(Theme.warning, 0.1) : index % 2 ? Theme.withAlpha(Theme.text, 0.025) : "transparent"
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.space.s2; right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: Theme.space.s3
                        LText { width: 88; role: "caption"; color: Theme.textMuted; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd d MMM") }
                        LText { width: 46; role: "caption"; color: Theme.textMuted; text: modelData.slot }
                        LText { id: tl; width: parent.width - 88 - 46 - 90 - 3 * Theme.space.s3; wrapMode: Text.Wrap; role: "body"
                                color: past ? Theme.text : Theme.textMuted; text: modelData.topic }
                        LText { width: 90; role: "caption"; horizontalAlignment: Text.AlignRight
                                color: missed ? Theme.warning : Theme.textMuted; text: missed ? "you missed it" : modelData.kind === "lab" ? "lab" : "" }
                    }
                }
            }
        }
    }
}
