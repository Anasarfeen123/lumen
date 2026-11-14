// Find notes: your Academics folder by file name and by what's inside notes and
// PDFs (scanned question papers are read with OCR); read photos of papers.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property var results: []
    property int indexed: 0
    property bool busy: false
    property string status: ""
    property string query: ""                // "find:deadlock" opens with a search
    property string course: ""               // a course folder name, or "" for everything
    property string kind: ""                 // "" | pdf | notes | slides | photos | papers
    property string where: ""                // "" | name | text
    function kindOf(r) {
        const n = r.name.toLowerCase();
        return /\.ocr\.txt$|\.(png|jpe?g)$/.test(n) ? "photos" : /\.(md|txt|docx?)$/.test(n) ? "notes" : /\.(pptx?|key)$/.test(n) ? "slides" : /\.pdf$/.test(n) ? "pdf" : "other";
    }
    readonly property var shown: results.filter(r => (!course || r.course === course) && (!where || r.kind === where)
        && (!kind || (kind === "papers" ? /Exams & Question Papers/.test(r.path) : kindOf(r) === kind)))
    title: "Find notes"
    subtitle: "Everything in ~/Academics — names and contents" + (indexed ? " · " + indexed + " documents read" : "")
    function search(q) {
        if (q.trim().length < 2) { results = []; return; }
        busy = true;
        Study.run(["search"].concat(q.trim().split(/\s+/)), r => { page.busy = false; if (r.ok) { page.results = r.results; page.indexed = r.indexed; } });
    }
    Timer { id: soon; interval: 300; onTriggered: page.search(field.text) }

    headerRight: [
        CollegeButton { text: "Read photos of papers"; icon: "document_scanner"
                        onActivated: { page.status = "Reading photos…"; Study.run(["ocr", Study.overview.semesterDir ?? ""], r => { page.status = r.ok ? r.done + " photos read" : (r.error ?? ""); Study.reindex(); }); } },
        CollegeButton { text: "Update index"; icon: "refresh"; onActivated: { page.status = "Indexing…"; Study.run(["index"], r => page.status = r.ok ? r.files + " documents, " + r.updated + " new or changed" : "Couldn't index"); } }
    ]

    LField {
        id: field
        width: parent.width; icon: "search"; placeholder: "e.g. deadlock, pumping lemma, normal forms…"; clearOnAccept: false
        input.onTextEdited: soon.restart()
        onAccepted: t => page.search(t)
        Component.onCompleted: { input.forceActiveFocus(); if (page.query) { text = page.query; page.search(page.query); } }
    }
    LText { visible: page.status !== ""; role: "caption"; color: Theme.textMuted; text: page.status }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        CollegeButton { text: "Every subject"; selected: page.course === ""; onActivated: page.course = "" }
        Repeater {
            model: Study.courses.filter(c => c.folder)
            CollegeButton { required property var modelData; readonly property string f: modelData.folder.replace(/^.*\//, "")
                            text: modelData.title.replace(/^Fundamentals of /, "").replace(/ Practice I$/, "") + (page.results.length ? " · " + page.results.filter(r => r.course === f).length : "")
                            selected: page.course === f; onActivated: page.course = f }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        Repeater {
            model: [{ id: "", t: "Any file" }, { id: "pdf", t: "PDFs" }, { id: "papers", t: "Question papers" }, { id: "notes", t: "Notes" }, { id: "slides", t: "Slides" }, { id: "photos", t: "Photos" }]
            CollegeButton { required property var modelData; text: modelData.t; selected: page.kind === modelData.id; onActivated: page.kind = modelData.id }
        }
        Item { width: Theme.space.s4; height: 1 }
        Repeater {
            model: [{ id: "", t: "Name or text" }, { id: "name", t: "In the name" }, { id: "text", t: "Inside" }]
            CollegeButton { required property var modelData; text: modelData.t; selected: page.where === modelData.id; onActivated: page.where = modelData.id }
        }
    }
    LText { visible: field.text.length >= 2 && !page.busy && page.shown.length === 0; color: Theme.textMuted; text: page.results.length ? "Nothing with these filters." : "Nothing found." }
    LText { visible: page.shown.length > 0; role: "caption"; color: Theme.textMuted; text: page.shown.length + (page.shown.length === 1 ? " file" : " files") }

    Repeater {
        model: page.shown
        HoverTarget {
            id: r
            required property var modelData
            width: parent.width; height: col.implicitHeight + 14; radius: Theme.radius.md
            onClicked: Quickshell.execDetached(["xdg-open", modelData.path])
            Rectangle { anchors.fill: parent; radius: parent.radius; z: -1; color: Theme.withAlpha(Theme.surfaceElevated, 0.6); border.width: 1; border.color: Theme.border }
            LIcon { id: ic; x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter; size: 20; color: Theme.textSecondary
                    icon: /\.pdf$/i.test(r.modelData.name) ? "picture_as_pdf" : /\.(png|jpe?g)/i.test(r.modelData.name) ? "image" : "description" }
            Column {
                id: col
                anchors { left: ic.right; leftMargin: Theme.space.s3; right: folderBtn.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                LText { width: parent.width; elide: Text.ElideMiddle; role: "bodyStrong"; text: r.modelData.name.replace(/\.ocr\.txt$/, " (photo, read)") }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                        text: (r.modelData.course || "Academics") + (r.modelData.kind === "text" ? " · in the text" : " · in the name") }
                LText { visible: r.modelData.snippet !== ""; width: parent.width; maximumLineCount: 2; wrapMode: Text.Wrap; elide: Text.ElideRight; role: "caption"
                        color: Theme.textSecondary; text: "…" + r.modelData.snippet + "…" }
            }
            HoverTarget { id: folderBtn; width: 30; height: 30; radius: 15; anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                          onClicked: Quickshell.execDetached(["xdg-open", r.modelData.path.replace(/\/[^/]*$/, "")])
                          LIcon { anchors.centerIn: parent; icon: "folder_open"; size: 17; color: Theme.textSecondary } }
        }
    }
}
