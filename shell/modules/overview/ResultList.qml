// Result panel. Keyboard selection lives here; destructive actions need a
// second Enter within 3 s (DESIGN.md §0: never destroy on one keystroke).
import QtQuick
import qs.theme
import qs.components
import qs.services

GlassSurface {
    id: root
    level: "panel"
    radius: Theme.radius.lg
    implicitWidth: 600
    implicitHeight: count === 0 ? emptyLabel.implicitHeight + Theme.space.s6 * 2
                                : Math.min(list.contentHeight, 470) + Theme.space.s2 * 2    // rows + group labels, up to ~8 rows
    Behavior on implicitHeight { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

    readonly property int count: list.count
    property int armedIndex: -1
    signal done()

    function move(d) {
        if (count === 0) return;
        list.currentIndex = (list.currentIndex + d + count) % count;
        armedIndex = -1;
    }
    function activate(i, mode) {
        const idx = i ?? list.currentIndex;
        const r = Search.results[idx];
        if (!r) return;
        if (r.destructive && armedIndex !== idx) { armedIndex = idx; disarm.restart(); return; }
        armedIndex = -1;
        done();              // close first: a paste goes to the app underneath
        r.run(mode);
    }
    function removeCurrent() {
        const r = Search.results[list.currentIndex];
        if (r?.kind === "clipboard") Clipboard.remove(r.id);
        else if (r?.kind === "clipPin") Clipboard.unpin(r.pinIndex);
    }
    function togglePin() {
        const r = Search.results[list.currentIndex];
        if (r?.kind === "clipboard") Clipboard.pin(r.entry);
        else if (r?.kind === "clipPin") Clipboard.unpin(r.pinIndex);
    }

    Timer { id: disarm; interval: 3000; onTriggered: root.armedIndex = -1 }

    Connections {
        target: Search
        function onResultsChanged() { list.currentIndex = 0; root.armedIndex = -1; }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.space.s2
        clip: true
        model: Search.results
        currentIndex: 0
        highlightMoveDuration: 0
        boundsBehavior: Flickable.StopAtBounds
        delegate: Column {
            id: cell
            required property var modelData
            required property int index
            width: ListView.view.width
            // A small group label ("Applications", "Commands", …) where the kind changes
            readonly property string group: modelData.group ?? ""
            readonly property bool firstOfGroup: group !== "" && (index === 0 || (Search.results[index - 1]?.group ?? "") !== group)
            LText {
                visible: cell.firstOfGroup && Overview.mode === "search"
                leftPadding: Theme.space.s3
                topPadding: cell.index === 0 ? Theme.space.s1 : Theme.space.s3
                bottomPadding: Theme.space.s1
                role: "caption"
                color: Theme.textMuted
                font.letterSpacing: 0.8
                text: cell.group.toUpperCase()
            }
            ResultRow {
                modelData: cell.modelData
                index: cell.index
                width: parent.width
                selected: cell.index === list.currentIndex
                armed: cell.index === root.armedIndex
                onActivated: root.activate(cell.index)
                onHovered: if (list.currentIndex !== cell.index) { list.currentIndex = cell.index; root.armedIndex = -1; }
            }
        }
    }

    LText {
        id: emptyLabel
        anchors.centerIn: parent
        visible: root.count === 0
        role: "body"
        color: Theme.textMuted
        text: Overview.mode === "clipboard" ? "Clipboard history is empty"
            : Overview.mode === "emoji" ? (Emoji.all.length ? "No emoji found" : "Preparing emoji…")
            : "No results"
    }
}
