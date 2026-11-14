// Past papers: the MIC PYQs Lumen downloaded into each course's
// "Exams & Question Papers/PYQs" and the papers you had already, by course and
// exam; tick what you've practised; which lecture topics come up most; ask Halo.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property string course: ""             // a course code, or "" for all
    property string exam: ""                // "", "CAT 1", "CAT 2", "FAT"
    property var topics: null
    property bool topicsBusy: false
    title: "Past papers"
    subtitle: "From the Microsoft Innovations Club's collection and your own folders · fetched " + fetched
    readonly property string fetched: {
        const t = Study.overview.pyqFetchedAt ?? 0, m = Math.round((Date.now() - t) / 60000);
        return !t ? "never" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
    }
    readonly property var list: Study.papers.filter(p => p.exists && (!course || p.code === course) && (!exam || p.exam === exam))
                                            .sort((a, b) => a.code.localeCompare(b.code) || a.exam.localeCompare(b.exam) || String(b.year).localeCompare(String(a.year)))
    onCourseChanged: { topics = null; }
    Component.onCompleted: if (!Study.papers.length) Study.refresh()

    headerRight: [
        CollegeButton { text: Study.syncing ? "Fetching…" : "Fetch new"; icon: "download"; enabled: !Study.syncing; onActivated: Study.syncPapers(true) }
    ]

    // filters
    Flow {
        width: parent.width; spacing: Theme.space.s2
        CollegeButton { text: "All courses"; selected: page.course === ""; onActivated: page.course = "" }
        Repeater {
            model: Study.courses.filter(c => Study.papers.some(p => p.code === c.code))
            CollegeButton { required property var modelData; text: modelData.title.replace(/^Fundamentals of /, ""); selected: page.course === modelData.code; onActivated: page.course = modelData.code }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Repeater {
            model: ["", "CAT 1", "CAT 2", "FAT"]
            CollegeButton { required property string modelData; text: modelData || "Every exam"; selected: page.exam === modelData; onActivated: page.exam = modelData }
        }
        LText { anchors.verticalCenter: parent.verticalCenter; leftPadding: Theme.space.s3; role: "caption"; color: Theme.textMuted
                text: page.list.length + " papers · " + page.list.filter(p => p.done).length + " done" }
    }

    // which topics come up (one course)
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
                    text: "Matches the topics in your teacher's lecture plan against the text of these papers (scanned ones are read with OCR), to show what's asked most." }
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

    // the papers
    Card {
        width: parent.width; title: page.list.length ? "Papers" : "No papers"; icon: "description"
        Column {
            width: parent.width; spacing: 2
            LText { visible: page.list.length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                    text: "Nothing for this course yet — the collection has no papers for it. Lumen checks every day and adds new ones to your folder." }
            Repeater {
                model: page.list
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
                                    text: row.modelData.exam + (row.modelData.year ? " " + row.modelData.year : "") + (row.modelData.slot ? " · slot " + row.modelData.slot : "") + (page.course ? "" : " · " + row.modelData.course) }
                            LText { width: parent.width; elide: Text.ElideMiddle; role: "caption"; color: Theme.textMuted
                                    text: row.modelData.source === "your folder" ? row.modelData.path.replace(/^.*\/Exams & Question Papers\//, "Your folder · ")
                                                                                : (row.modelData.sourceTitle ? row.modelData.sourceTitle + " (" + row.modelData.sourceCode + ") · " : "") + row.modelData.source }
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
