// Flashcards: cards made from your cheat sheets (definitions and sections in
// "Revision & Cheat Sheets") plus any flashcards.json Halo made, reviewed with
// spaced repetition — Again / Hard / Good / Easy decide when it comes back.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property string course: Study.courses[0]?.code ?? ""
    property var deck: ({ cards: [], total: 0, due: 0 })
    property int i: 0
    property bool shown: false
    readonly property var card: deck.cards[i] ?? null
    readonly property var c: Study.courses.find(x => x.code === course) ?? null
    title: "Flashcards"
    subtitle: c ? c.title + " · " + deck.total + " cards from your cheat sheets · " + Math.max(0, deck.due - i) + " due now" : ""
    onCourseChanged: load()
    Component.onCompleted: load()
    function load() { i = 0; shown = false; if (course) Study.run(["cards", course], r => { if (r.ok) page.deck = r; else page.deck = { cards: [], total: 0, due: 0, error: r.error }; }); }
    function grade(g) {
        if (!card) return;
        Study.run(["review", course, card.id, String(g)]);
        shown = false;
        i++;
    }

    Flow {
        width: parent.width; spacing: Theme.space.s2
        Repeater {
            model: Study.courses
            CollegeButton { required property var modelData; text: modelData.title.replace(/^Fundamentals of /, ""); selected: page.course === modelData.code; onActivated: page.course = modelData.code }
        }
    }

    // the card
    Rectangle {
        width: parent.width; height: Math.max(260, cardCol.implicitHeight + 64)
        radius: Theme.radius.lg
        color: Theme.withAlpha(Theme.surfaceElevated, 0.85); border.width: 1; border.color: Theme.border
        Keys.onSpacePressed: page.shown = true
        Column {
            id: cardCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.space.s6 }
            spacing: Theme.space.s4
            LText { visible: !page.card; width: parent.width; wrapMode: Text.Wrap; role: "heading"; horizontalAlignment: Text.AlignHCenter; topPadding: 60
                    text: page.deck.total === 0 ? "No cards yet" : "All done for now 🎉" }
            LText { visible: !page.card; width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary; horizontalAlignment: Text.AlignHCenter
                    text: page.deck.total === 0 ? "Cards come from \"**Term:** meaning\" lines and headed sections in this course's Revision & Cheat Sheets (Markdown). Or ask Halo to quiz you."
                                                : "Cards you got right come back in a few days; the ones you missed, sooner." }
            LText { visible: !!page.card; role: "caption"; color: Theme.textMuted; text: page.card ? "Card " + (page.i + 1) + " of " + page.deck.cards.length + " · from " + page.card.src.replace(/^.*\//, "") : "" }
            LText { visible: !!page.card; width: parent.width; wrapMode: Text.Wrap; role: "heading"; font.pixelSize: 20; text: page.card?.q ?? "" }
            Rectangle { visible: page.shown; width: parent.width; height: 1; color: Theme.border }
            LText { visible: page.shown && !!page.card; width: parent.width; wrapMode: Text.Wrap; textFormat: Text.MarkdownText; text: page.card?.a ?? "" }
        }
    }
    Row {
        visible: !!page.card
        spacing: Theme.space.s2
        CollegeButton { visible: !page.shown; text: "Show answer"; icon: "visibility"; selected: true; onActivated: page.shown = true }
        Repeater {
            model: page.shown ? [{ g: 0, t: "Again", i: "replay" }, { g: 1, t: "Hard", i: "sentiment_dissatisfied" }, { g: 2, t: "Good", i: "sentiment_satisfied" }, { g: 3, t: "Easy", i: "bolt" }] : []
            CollegeButton { required property var modelData; text: modelData.t; icon: modelData.i; onActivated: page.grade(modelData.g) }
        }
    }
    Row {
        spacing: Theme.space.s2
        CollegeButton { text: "Quiz me with Halo"; icon: "auto_awesome"; enabled: !!page.c?.folder
                        onActivated: { const files = [...new Set(page.deck.cards.map(x => x.src))].slice(0, 4);
                                       if (files.length) Ai.askAboutFiles(files); else Ai.show();
                                       Qt.callLater(() => Ai.send("Quiz me on " + (page.c?.title ?? "this course") + " for my exam: ask one question at a time, wait for my answer, then tell me if I'm right and why.")); } }
        CollegeButton { text: "Open cheat sheets"; icon: "folder_open"; enabled: !!page.c?.folder
                        onActivated: Quickshell.execDetached(["xdg-open", page.c.folder + "/Revision & Cheat Sheets"]) }
        CollegeButton { text: "Reload"; icon: "refresh"; onActivated: page.load() }
    }
}
