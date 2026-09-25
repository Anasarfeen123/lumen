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
                                : Math.min(8, count) * 48 + Theme.space.s2 * 2
    Behavior on implicitHeight { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

    readonly property int count: list.count
    property int armedIndex: -1
    signal done()

    function move(d) {
        if (count === 0) return;
        list.currentIndex = (list.currentIndex + d + count) % count;
        armedIndex = -1;
    }
    function activate(i) {
        const idx = i ?? list.currentIndex;
        const r = Search.results[idx];
        if (!r) return;
        if (r.destructive && armedIndex !== idx) { armedIndex = idx; disarm.restart(); return; }
        armedIndex = -1;
        r.run();
        done();
    }
    function removeCurrent() {
        const r = Search.results[list.currentIndex];
        if (r?.kind === "clipboard") Clipboard.remove(r.id);
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
        delegate: ResultRow {
            width: ListView.view.width
            selected: index === list.currentIndex
            armed: index === root.armedIndex
            onActivated: root.activate(index)
            onHovered: if (list.currentIndex !== index) { list.currentIndex = index; root.armedIndex = -1; }
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
