// Keyboard & gestures cheatsheet (Super+/). Read live from Hyprland
// (`hyprctl binds -j`): every bind in hypr/keybinds.lua carries a
// "Section: Label" description, so the sheet can never drift from reality.
//
//   ╭────────────────────────────────────────────────────────────╮
//   │ Keyboard & gestures                          [⌕ Filter   ] │
//   │ ┌──────────────┐  ┌─ Apps ────────────┐ ┌─ Windows ──────┐ │
//   │ │ ▣ All     143│  │ Terminal  Super ⏎ │ │ Close  Super Q │ │
//   │ │ EVERYDAY     │  │ …                 │ │ …              │ │
//   │ │ ▢ Apps     14│  └───────────────────┘ └────────────────┘ │
//   │ │ ▢ Halo      7│                                           │
//   │ │ CREATE …     │                                           │
//   ╰────────────────────────────────────────────────────────────╯
// The rail groups sections into families; "All" shows every section as cards
// in two balanced columns, one section shows just it, larger.
// Type to filter (all sections) · ↑/↓ or Tab: section · Esc clears, then closes.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: CheatsheetState.open && isFocused

    readonly property var sections: Keybinds.sections
    property string filter: ""
    property string chosen: ""          // "" = all

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: if (showing) { filter = ""; input.text = ""; chosen = ""; input.forceActiveFocus(); Keybinds.refresh(); }

    // ── families and icons for the rail ──
    readonly property var families: [
        { title: "Everyday", sections: ["Apps", "Halo", "Windows", "Arrange", "Switch", "Workspaces"] },
        { title: "Create", sections: ["Capture", "Tools"] },
        { title: "Hardware", sections: ["Media", "Laptop keys", "Control centre", "Scroll & mouse", "Gestures"] },
        { title: "System", sections: ["Look", "Lumen", "Session"] }
    ]
    readonly property var icons: ({
        "Apps": "apps", "Halo": "auto_awesome", "Windows": "select_window", "Arrange": "dashboard_customize",
        "Switch": "swap_horiz", "Workspaces": "view_carousel", "Capture": "screenshot_region", "Tools": "construction",
        "Media": "music_note", "Laptop keys": "laptop_chromebook", "Control centre": "tune", "Scroll & mouse": "mouse",
        "Gestures": "swipe", "Look": "palette", "Lumen": "blur_on", "Session": "power_settings_new"
    })
    function iconFor(t) { return icons[t] ?? "keyboard"; }

    // the rail, in family order; anything new in keybinds.lua lands under "More"
    readonly property var rail: {
        const known = [].concat(...families.map(f => f.sections)), have = sections.map(s => s.title), out = [];
        for (const f of families) {
            const list = f.sections.filter(t => have.includes(t));
            if (list.length) out.push({ title: f.title, sections: list });
        }
        const extra = have.filter(t => !known.includes(t));
        if (extra.length) out.push({ title: "More", sections: extra });
        return out;
    }
    readonly property var railOrder: [].concat(...rail.map(f => f.sections))
    function sectionNamed(t) { return sections.find(s => s.title === t) ?? null; }

    readonly property var filtered: {
        const q = filter.trim().toLowerCase();
        const ordered = (railOrder ?? []).map(t => win.sectionNamed(t)).filter(s => s);
        if (q === "") return ordered;
        return ordered.map(s => ({ title: s.title, binds: s.binds.filter(b =>
            b.desc.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q) || s.title.toLowerCase().includes(q)) }))
            .filter(s => s.binds.length > 0);
    }
    // what the right side shows: one section, or all (filtered)
    readonly property var shownSections: chosen && filter.trim() === "" ? filtered.filter(s => s.title === chosen) : filtered
    readonly property int total: sections.reduce((n, s) => n + s.binds.length, 0)
    function countOf(t) { const s = filtered.find(x => x.title === t); return s ? s.binds.length : 0; }

    // Balance cards across two columns by row count
    readonly property var columns: {
        const cols = [[], []], h = [0, 0];
        for (const s of (shownSections ?? [])) {
            const i = h[0] <= h[1] ? 0 : 1;
            cols[i].push(s);
            h[i] += s.binds.length + 2.5;
        }
        return cols;
    }
    function step(d) {
        const list = [""].concat(railOrder.filter(t => countOf(t) > 0));
        const i = Math.max(0, list.indexOf(chosen));
        chosen = list[(i + d + list.length) % list.length];
        if (filter !== "") { input.text = ""; }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bg, 0.5)
        opacity: panel.opacity
        MouseArea { anchors.fill: parent; onClicked: CheatsheetState.open = false }
    }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(win.width - 2 * Theme.space.s8, 1220)
        height: Math.min(win.height - 2 * Theme.space.s8 - 40, 780)
        anchors.centerIn: parent
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        MouseArea { anchors.fill: parent }

        // ── header ──
        Item {
            id: head
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s5 }
            height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.s3
                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: Theme.withAlpha(Theme.accent, 0.16)
                    LIcon { anchors.centerIn: parent; icon: "keyboard"; size: 20; color: Theme.accent }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    LText { role: "title"; text: "Keyboard & gestures" }
                    LText { role: "caption"; color: Theme.textMuted; text: win.total + " shortcuts · Super+/ any time" }
                }
            }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 300; height: 36; radius: 18
                color: Theme.surfaceElevated
                border.width: 1
                border.color: input.activeFocus ? Theme.accent : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
                LIcon { id: glass; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter } icon: "search"; size: Theme.size.iconSmall; color: Theme.textMuted }
                TextInput {
                    id: input
                    anchors { left: glass.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.size.body
                    clip: true
                    onTextChanged: win.filter = text
                    Keys.onEscapePressed: { if (text !== "") text = ""; else if (win.chosen !== "") win.chosen = ""; else CheatsheetState.open = false; }
                    Keys.onUpPressed: win.step(-1)
                    Keys.onDownPressed: win.step(1)
                    Keys.onTabPressed: win.step(1)
                    Keys.onBacktabPressed: win.step(-1)
                    LText { visible: parent.text === ""; color: Theme.textMuted; text: "Filter — try “screenshot” or “Alt”"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // ── the rail ──
        Flickable {
            id: railView
            anchors { top: head.bottom; topMargin: Theme.space.s5; left: parent.left; leftMargin: Theme.space.s4; bottom: parent.bottom; bottomMargin: Theme.space.s4 }
            width: 214
            contentHeight: railCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: railCol
                width: parent.width
                spacing: 2
                RailItem { title: ""; label: "All"; icon: "select_all"; count: win.filtered.reduce((n, s) => n + s.binds.length, 0) }
                Repeater {
                    model: win.rail
                    delegate: Column {
                        required property var modelData
                        width: railCol.width
                        spacing: 2
                        LText {
                            leftPadding: Theme.space.s3; topPadding: Theme.space.s3; bottomPadding: 2
                            role: "caption"; font.weight: Font.DemiBold; color: Theme.textMuted
                            text: modelData.title.toUpperCase(); font.letterSpacing: 0.8
                        }
                        Repeater {
                            model: modelData.sections
                            delegate: RailItem {
                                required property string modelData
                                title: modelData; label: modelData; icon: win.iconFor(modelData); count: win.countOf(modelData)
                            }
                        }
                    }
                }
            }
        }
        Rectangle { anchors { top: railView.top; bottom: railView.bottom; left: railView.right; leftMargin: Theme.space.s3 } width: 1; color: Theme.border }

        // ── the cards ──
        Flickable {
            id: body
            anchors { top: head.bottom; topMargin: Theme.space.s5; left: railView.right; leftMargin: Theme.space.s6; right: parent.right; rightMargin: Theme.space.s5; bottom: parent.bottom; bottomMargin: Theme.space.s4 }
            contentHeight: cardsRow.implicitHeight + Theme.space.s4
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // a soft change between sections
            property string shownKey: win.chosen + "|" + win.filter
            onShownKeyChanged: { contentY = 0; swap.restart(); }
            SequentialAnimation {
                id: swap
                PropertyAction { target: cardsRow; property: "opacity"; value: 0.35 }
                PropertyAction { target: slide; property: "y"; value: 10 }
                ParallelAnimation {
                    NumberAnimation { target: cardsRow; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : Theme.motion.normal }
                    NumberAnimation { target: slide; property: "y"; to: 0; duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                }
            }

            Row {
                id: cardsRow
                width: body.width
                spacing: Theme.space.s4
                transform: Translate { id: slide }
                readonly property bool single: win.shownSections.length === 1
                Repeater {
                    model: cardsRow.single ? [win.shownSections] : win.columns
                    delegate: Column {
                        required property var modelData
                        width: cardsRow.single ? cardsRow.width : (cardsRow.width - cardsRow.spacing) / 2
                        spacing: Theme.space.s4
                        Repeater {
                            model: parent.modelData
                            delegate: Card { required property var modelData; section: modelData; big: cardsRow.single }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: win.filtered.length === 0
                spacing: Theme.space.s2
                LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "search_off"; size: 32; color: Theme.textMuted }
                LText { color: Theme.textMuted; text: "No shortcut matches “" + win.filter + "”" }
            }
        }
    }

    // ── pieces ──
    component RailItem: HoverTarget {
        id: ri
        property string title
        property string label
        property string icon
        property int count
        readonly property bool on: win.filter.trim() !== "" ? title === "" : win.chosen === title
        width: railCol.width
        height: 36
        radius: Theme.radius.sm
        highlighted: on
        opacity: count > 0 ? 1 : 0.4
        onClicked: { win.chosen = title; input.forceActiveFocus(); }
        Rectangle { visible: ri.on; anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 3; height: 18; radius: 2; color: Theme.accent }
        LIcon { id: riIcon; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                icon: ri.icon; size: Theme.size.iconSmall; fill: ri.on ? 1 : 0; color: ri.on ? Theme.accent : Theme.textSecondary }
        LText { anchors { left: riIcon.right; leftMargin: Theme.space.s3; right: riCount.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                role: ri.on ? "bodyStrong" : "body"; color: ri.on ? Theme.text : Theme.textSecondary; text: ri.label; elide: Text.ElideRight }
        LText { id: riCount; anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                role: "caption"; color: Theme.textMuted; text: ri.count; font.features: ({ "tnum": 1 }) }
    }

    component Card: Column {
        id: card
        property var section
        property bool big: false
        width: parent.width
        spacing: Theme.space.s2
        Row {
            spacing: Theme.space.s2
            leftPadding: Theme.space.s1
            LIcon { icon: win.iconFor(card.section.title); size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "caption"; color: Theme.accent; text: card.section.title.toUpperCase(); font.letterSpacing: 1; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "caption"; color: Theme.textMuted; text: "· " + card.section.binds.length; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle {
            width: parent.width
            height: rows.implicitHeight
            radius: Theme.radius.md
            color: Theme.withAlpha(Theme.surfaceElevated, 0.6)
            border.width: 1
            border.color: Theme.border
            // one section on its own: its rows in two columns when there are many
            Grid {
                id: rows
                width: parent.width
                columns: card.big && card.section.binds.length > 8 ? 2 : 1
                Repeater {
                    model: card.section.binds
                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: rows.width / rows.columns
                        height: card.big ? 42 : 36
                        Rectangle {
                            visible: index >= rows.columns
                            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
                            height: 1; color: Theme.border
                        }
                        LText {
                            anchors { left: parent.left; leftMargin: Theme.space.s4; right: caps.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            role: "body"; color: Theme.text; text: modelData.desc; elide: Text.ElideRight
                        }
                        Row {
                            id: caps
                            anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            spacing: 3
                            Repeater {
                                model: modelData.keys
                                delegate: KeyCap { required property string modelData; text: modelData }
                            }
                        }
                    }
                }
            }
        }
    }

    component KeyCap: Rectangle {
        property alias text: capText.text
        readonly property bool isMod: /^(Super|Ctrl|Alt|Shift)$/.test(capText.text)
        width: Math.max(24, capText.implicitWidth + 12)
        height: 23
        radius: 6
        color: isMod ? Theme.withAlpha(Theme.accent, 0.12) : Theme.surfaceElevated
        border.width: 1
        border.color: isMod ? Theme.withAlpha(Theme.accent, 0.35) : Theme.borderStrong
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: 2; radius: 1
            color: Theme.withAlpha("#000000", 0.25)
        }
        Text {
            id: capText
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            color: parent.isMod ? Theme.accent : Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 11
            font.variableAxes: ({ "wght": 650, "ROND": 60 })
        }
    }
}
