// Keyboard & gestures cheatsheet (Super+/). Read live from Hyprland
// (`hyprctl binds -j`): every bind in hypr/keybinds.lua carries a
// "Section: Label" description, so the sheet can never drift from reality.
// Type to filter · Esc clears, then closes.
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

    property var sections: []
    property string filter: ""

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-cheatsheet"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: if (showing) { filter = ""; input.text = ""; input.forceActiveFocus(); binds.running = true; }

    // Live binds → sections. Runs each time the sheet opens.
    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { win.sections = win.build(JSON.parse(text)); } catch (e) {} } }
    }

    readonly property var keyNames: ({
        Return: "Enter", grave: "`", Semicolon: ";", Apostrophe: "'", Page_Up: "PgUp", Page_Down: "PgDn",
        mouse_down: "Scroll ↓", mouse_up: "Scroll ↑", "mouse:272": "Drag", "mouse:273": "Right-drag",
        "mouse:275": "Back", "mouse:276": "Forward", SUPER_L: "(tap)", period: ".", Equal: "=", Minus: "−",
        Space: "Space", Escape: "Esc", Delete: "Del", Print: "PrtSc", left: "←", right: "→", up: "↑", down: "↓",
        Tab: "Tab", Slash: "/"
    })
    function build(list) {
        const order = [], bySection = {};
        for (const b of list) {
            const desc = b.description ?? "";
            const i = desc.indexOf(": ");
            if (i < 0) continue;
            const section = desc.slice(0, i);
            // The key caps show "1…0" / arrows, so the label doesn't repeat them
            const label = desc.slice(i + 2).replace(/\s*(1…0|← → ↑ ↓)/, "");
            const keys = [];
            const m = b.modmask ?? 0;
            if (m & 64) keys.push("Super");
            if (m & 4) keys.push("Ctrl");
            if (m & 8) keys.push("Alt");
            if (m & 1) keys.push("Shift");
            let k = keyNames[b.key] ?? (b.key.length === 1 ? b.key.toUpperCase() : b.key);
            if (/1…0/.test(desc)) k = "1…0";
            if (/← → ↑ ↓/.test(desc)) k = "← → ↑ ↓";
            if (b.key === "SUPER_L") { keys.length = 0; keys.push("Super"); }
            keys.push(k);
            if (!bySection[section]) { bySection[section] = []; order.push(section); }
            if (!bySection[section].some(x => x.desc === label)) bySection[section].push({ keys, desc: label });
        }
        const out = order.map(t => ({ title: t, binds: bySection[t] }));
        out.push({ title: "Gestures", binds: [
            { keys: ["Top-left corner"], desc: "Overview & search" },
            { keys: ["Top-right corner"], desc: "Control centre" },
            { keys: ["4 fingers", "↑ / ↓"], desc: "Open / close overview" },
            { keys: ["4 fingers", "← / →"], desc: "Switch workspace" },
            { keys: ["3 fingers", "drag"], desc: "Move window" },
            { keys: ["3 fingers", "pinch"], desc: "Fullscreen" },
            { keys: ["Scroll", "on the bar"], desc: "Switch workspace" },
            { keys: ["Scroll", "on the island"], desc: "Volume (Shift: brightness)" },
            { keys: ["Right-click", "workspaces / island"], desc: "Apps in the background (tray)" },
            { keys: ["Middle-click", "island"], desc: "Play / pause" },
            { keys: ["Swipe →", "notification"], desc: "Dismiss it" },
        ] });
        return out;
    }

    readonly property var filtered: {
        const q = filter.trim().toLowerCase();
        if (q === "") return sections;
        return sections.map(s => ({ title: s.title, binds: s.binds.filter(b =>
            b.desc.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q) || s.title.toLowerCase().includes(q)) }))
            .filter(s => s.binds.length > 0);
    }
    // Balance sections across three columns by row count
    readonly property var columns: {
        const cols = [[], [], []], h = [0, 0, 0];
        for (const s of filtered) {
            const i = h.indexOf(Math.min(...h));
            cols[i].push(s);
            h[i] += s.binds.length + 2;
        }
        return cols;
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
        width: Math.min(win.width - 2 * Theme.space.s8, 1180)
        height: Math.min(win.height - 2 * Theme.space.s8 - 40, body.implicitHeight + head.height + Theme.space.s5 * 3)
        anchors.centerIn: parent
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.97
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        MouseArea { anchors.fill: parent }

        Item {
            id: head
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s5 }
            height: 36
            LText { anchors.verticalCenter: parent.verticalCenter; role: "title"; text: "Keyboard & gestures" }

            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: 260; height: 34; radius: 17
                color: Theme.surfaceElevated
                border.width: 1
                border.color: input.activeFocus ? Theme.accent : Theme.border
                LIcon { id: glass; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter } icon: "search"; size: Theme.size.iconSmall; color: Theme.textMuted }
                TextInput {
                    id: input
                    anchors { left: glass.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.size.body
                    clip: true
                    onTextChanged: win.filter = text
                    Keys.onEscapePressed: { if (text !== "") text = ""; else CheatsheetState.open = false; }
                    LText { visible: parent.text === ""; color: Theme.textMuted; text: "Filter"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        Flickable {
            anchors { top: head.bottom; topMargin: Theme.space.s5; left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: Theme.space.s5; rightMargin: Theme.space.s5; bottomMargin: Theme.space.s5 }
            contentHeight: body.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Row {
                id: body
                width: parent.width
                spacing: Theme.space.s6
                Repeater {
                    model: win.columns
                    delegate: Column {
                        required property var modelData
                        width: (body.width - 2 * body.spacing) / 3
                        spacing: Theme.space.s5
                        Repeater {
                            model: parent.modelData
                            delegate: Column {
                                required property var modelData
                                width: parent.width
                                spacing: Theme.space.s2
                                LText { role: "caption"; color: Theme.accent; text: modelData.title.toUpperCase(); font.letterSpacing: 1 }
                                Repeater {
                                    model: modelData.binds
                                    delegate: Item {
                                        required property var modelData
                                        width: parent.width
                                        height: 26
                                        LText {
                                            anchors { left: parent.left; right: caps.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                                            role: "body"; color: Theme.textSecondary; text: modelData.desc; elide: Text.ElideRight
                                        }
                                        Row {
                                            id: caps
                                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                            spacing: 3
                                            Repeater {
                                                model: modelData.keys
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    width: Math.max(22, capText.implicitWidth + 12)
                                                    height: 22
                                                    radius: Theme.radius.xs
                                                    color: Theme.surfaceElevated
                                                    border.width: 1
                                                    border.color: Theme.borderStrong
                                                    Rectangle {
                                                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
                                                        height: 2
                                                        radius: 1
                                                        color: Theme.withAlpha("#000000", 0.25)
                                                    }
                                                    Text {
                                                        id: capText
                                                        anchors.centerIn: parent
                                                        text: modelData
                                                        color: Theme.text
                                                        font.family: Theme.fontUi
                                                        font.pixelSize: 11
                                                        font.variableAxes: ({ "wght": 600, "ROND": 60 })
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
