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
    LText { visible: field.text.length >= 2 && !page.busy && page.results.length === 0; color: Theme.textMuted; text: "Nothing found." }

    Repeater {
        model: page.results
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
