// Result panel. Keyboard selection lives here; destructive actions need a
// second Enter within 3 s (DESIGN.md §0: never destroy on one keystroke).
import QtQuick
import QtQuick.Effects
import qs.theme
import qs.components
import qs.services

GlassSurface {
    id: root
    level: "panel"
    radius: Theme.radius.lg
    implicitWidth: 600
    implicitHeight: count === 0 ? emptyLabel.implicitHeight + Theme.space.s6 * 2
                                : Math.min(list.contentHeight, 470) + Theme.space.s2 * 2 + (Overview.mode === "clipboard" ? 38 : 0)    // rows + labels (+ filter chips)
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

    // ── the result's menu (right-click, or the Menu key / Shift+F10) ──
    property var menuItems: []
    property int menuIndex: 0
    readonly property bool menuOpen: menuItems.length > 0
    function openMenu(i, at) {
        const r = Search.results[i ?? list.currentIndex];
        const items = Search.actionsFor(r);
        if (!items.length) return;
        menuIndex = 0;
        const row = list.currentItem;
        const p = at ?? (row ? row.mapToItem(root, row.width - 240, row.height) : Qt.point(root.width - 260, 40));
        menu.x = Math.max(8, Math.min(root.width - menu.width - 8, p.x));
        menu.y = Math.max(8, Math.min(root.height - menu.height - 8, p.y));
        menuItems = items;
    }
    function closeMenu() { menuItems = []; }
    function menuMove(d) { if (menuOpen) menuIndex = (menuIndex + d + menuItems.length) % menuItems.length; }
    function menuRun(i) {
        const it = menuItems[i ?? menuIndex];
        closeMenu();
        if (!it) return;
        done();
        it.run();
    }
    Connections { target: Search; function onResultsChanged() { root.closeMenu(); } }

    Connections {
        target: Search
        function onResultsChanged() { list.currentIndex = 0; root.armedIndex = -1; }
    }

    // Clipboard filters (Ctrl+← / Ctrl+→)
    Row {
        id: chips
        visible: Overview.mode === "clipboard"
        x: Theme.space.s3; y: Theme.space.s2
        height: visible ? 30 : 0
        spacing: 6
        Repeater {
            model: [{ id: "all", label: "All" }, { id: "link", label: "Links" }, { id: "code", label: "Code" }, { id: "image", label: "Images" }, { id: "text", label: "Text" }]
            delegate: HoverTarget {
                required property var modelData
                readonly property bool on: Clipboard.filter === modelData.id
                width: cl.implicitWidth + 20; height: 26
                Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                            color: on ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                            border.width: 1; border.color: on ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border }
                LText { id: cl; anchors.centerIn: parent; role: "caption"; color: on ? Theme.accent : Theme.textSecondary; text: modelData.label }
                onClicked: Clipboard.filter = modelData.id
            }
        }
    }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: Theme.space.s2
        anchors.topMargin: chips.visible ? chips.height + Theme.space.s3 : Theme.space.s2
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
                onMenuRequested: (mx, my) => { list.currentIndex = cell.index; root.openMenu(cell.index, mapToItem(root, mx, my)); }
                onHovered: if (list.currentIndex !== cell.index) { list.currentIndex = cell.index; root.armedIndex = -1; }
            }
        }
    }

    // clicking elsewhere closes the menu
    MouseArea { anchors.fill: parent; z: 19; visible: root.menuOpen; acceptedButtons: Qt.AllButtons; onClicked: root.closeMenu() }
    Rectangle {
        id: menu
        z: 20
        visible: opacity > 0.01
        opacity: root.menuOpen ? 1 : 0
        scale: root.menuOpen ? 1 : 0.95
        transformOrigin: Item.TopLeft
        Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        width: 240
        height: menuCol.implicitHeight + 8
        radius: Theme.radius.md
        color: "transparent"

        // Frosted glass: the results behind it, blurred, under a tint — a
        // compositor blur can't reach a piece of one surface, so it's drawn here
        RectangularShadow { anchors.fill: parent; radius: parent.radius; blur: 24; spread: 0; offset.y: 6; color: Theme.withAlpha(Theme.scrim, 0.35) }
        ShaderEffectSource {
            id: behind
            anchors.fill: parent
            sourceItem: list
            sourceRect: Qt.rect(menu.x - list.x, menu.y - list.y, menu.width, menu.height)
            live: root.menuOpen
            visible: false
        }
        Item {
            id: menuMask
            anchors.fill: parent
            layer.enabled: true
            visible: false
            Rectangle { anchors.fill: parent; radius: menu.radius }
        }
        // a near-solid base, so the rows behind show only blurred, never crisp
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.surface, 0.94) }
        MultiEffect {
            anchors.fill: parent
            source: behind
            blurEnabled: true; blur: 1.0; blurMax: 48
            saturation: 0.15
            maskEnabled: true; maskSource: menuMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.withAlpha(Theme.surfaceElevated, 0.5)
            border.width: 1; border.color: Theme.borderStrong
            // a hairline of light along the top, as on Lumen's other glass
            Rectangle { anchors { top: parent.top; topMargin: 1; horizontalCenter: parent.horizontalCenter } width: parent.width - 2 * parent.radius; height: 1; color: Theme.withAlpha(Theme.text, 0.10) }
        }
        Column {
            id: menuCol
            x: 4; y: 4
            width: parent.width - 8
            Repeater {
                model: root.menuItems
                HoverTarget {
                    required property var modelData
                    required property int index
                    width: menuCol.width; height: 32
                    radius: Theme.radius.sm
                    highlighted: index === root.menuIndex
                    onContainsMouseChanged: if (containsMouse) root.menuIndex = index
                    onClicked: root.menuRun(index)
                    Row {
                        anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        spacing: Theme.space.s3
                        LIcon { icon: modelData.icon ?? ""; size: 16; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        LText { text: modelData.label; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
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
