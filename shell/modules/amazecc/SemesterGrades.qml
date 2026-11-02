import QtQuick
import qs.theme
import qs.components
import qs.services

Card {
    id: root
    title: "Semester history"
    icon: "history_edu"
    readonly property var history: Amazecc.extra.gradeHistory ?? ({})
    readonly property var semesters: Object.keys(history).sort().reverse()
    property string semester: semesters[0] || ""
    property string expanded: ""
    readonly property var semesterData: history[semester] ?? ({})
    property string query: ""
    readonly property var courses: (semesterData.courses ?? []).filter(c=>!query || (c.title+" "+c.code+" "+c.grade).toLowerCase().includes(query.toLowerCase()))
    onSemestersChanged: if (!semesters.includes(semester)) semester = semesters[0] || ""
    Column {
        width: parent.width; spacing: Theme.space.s3
        LText { visible: !root.semesters.length; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted; text: "Sync to read semester grades from VTOP. Unavailable semesters keep their last saved results." }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            Repeater { model: root.semesters; CollegeButton { required property string modelData; text: Amazecc.semesterName(modelData); selected: root.semester === modelData; onActivated: {root.semester = modelData;root.expanded = "";} } }
        }
        Row {
            visible: root.semester !== ""; width: parent.width; spacing: Theme.space.s3
            Column {
                width: 160
                LText { role: "caption"; color: Theme.textMuted; text: "PUBLISHED SGPA" }
                LText { role: "title"; color: Theme.accent; text: root.semesterData.gpa !== null && root.semesterData.gpa !== undefined ? Number(root.semesterData.gpa).toFixed(2) : "Unavailable"; font.features: ({"tnum":1}) }
            }
            LField { width: parent.width-160-parent.spacing; icon: "search"; placeholder: "Find a course, code or grade"; clearOnAccept: false; input.onTextEdited: root.query = text; onAccepted: root.query = text }
        }
        LText { visible: !!root.semesterData.updated; role: "caption"; color: Theme.textMuted; text: root.semesterData.updated ? "Results saved " + Qt.formatDateTime(new Date(root.semesterData.updated),"d MMM, h:mm AP") : "" }
        Repeater {
            model: root.courses
            Column {
                id: course
                required property var modelData
                width: parent.width; spacing: Theme.space.s2
                readonly property bool expanded: root.expanded === modelData.id
                CollegeButton {
                    width: parent.width; height: 64; text: ""
                    selected: course.expanded
                    onActivated: root.expanded = course.expanded ? "" : course.modelData.id
                    Accessible.name: course.modelData.title + ", grade " + course.modelData.grade + ", show assessment details"
                    Rectangle { id: badge; width: 38; height: 38; x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter; radius: Theme.radius.sm; color: Theme.withAlpha(course.modelData.grade === "F" || course.modelData.grade === "N" ? Theme.error : Theme.accent,0.16); LText { anchors.centerIn: parent; role: "heading"; text: course.modelData.grade || "–" } }
                    Column {
                        anchors { left: badge.right; leftMargin: Theme.space.s3; right: total.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: course.modelData.title }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: course.modelData.code + (course.modelData.type ? " · " + course.modelData.type : "") }
                    }
                    LText { id: total; anchors { right: parent.right; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter } color: Theme.accent; text: (course.modelData.total !== null ? Amazecc.fmt(course.modelData.total) + " marks  " : "") + (course.expanded ? "−" : "+") }
                }
                Column {
                    visible: course.expanded; width: parent.width; spacing: Theme.space.s2
                    LText { visible: !(course.modelData.assessments ?? []).length; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: "VTOP did not return an assessment breakdown for this course." }
                    Repeater {
                        model: course.modelData.assessments ?? []
                        Row {
                            required property var modelData
                            width: parent.width; spacing: Theme.space.s3
                            LText { width: parent.width*0.55; wrapMode: Text.Wrap; text: (modelData.segment ? modelData.segment + " · " : "") + modelData.title; role: "caption" }
                            LText { width: parent.width*0.2; text: Amazecc.fmt(modelData.scored) + " / " + Amazecc.fmt(modelData.max); role: "caption"; color: Theme.textSecondary }
                            LText { width: parent.width*0.2-parent.spacing*2; wrapMode: Text.Wrap; text: modelData.weighted !== null ? Amazecc.fmt(modelData.weighted) + " / " + Amazecc.fmt(modelData.weight) + " wt" : modelData.status || ""; role: "caption"; color: Theme.textMuted }
                        }
                    }
                    LText { visible: Object.keys(course.modelData.range ?? {}).length > 0; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: "Published ranges: " + Object.keys(course.modelData.range ?? {}).map(g=>g+": "+course.modelData.range[g]).join(" · ") }
                }
            }
        }
        LText { visible: root.semester !== "" && !root.courses.length; color: Theme.textMuted; text: root.query ? "No matching courses." : "No grades published for this semester." }
    }
}
