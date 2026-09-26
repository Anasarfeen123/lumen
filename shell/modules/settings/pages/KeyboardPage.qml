// Keyboard & Gestures — every shortcut, live from Hyprland (services/Keybinds),
// so this page is always exactly what your keys do. Type to filter.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Keyboard & Gestures"
    subtitle: "Every shortcut, read live from Hyprland. Tap Super for search; Super+/ shows this as an overlay."

    property string filter: ""
    readonly property var shown: {
        const q = filter.trim().toLowerCase();
        const all = Keybinds.sections;
        if (q === "") return all;
        return all.map(s => ({ title: s.title, binds: s.binds.filter(b =>
                    b.desc.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q) || s.title.toLowerCase().includes(q)) }))
                  .filter(s => s.binds.length > 0);
    }
    Component.onCompleted: Keybinds.refresh()

    Row {
        width: parent.width
        spacing: Theme.space.s3

        // Filter
        Rectangle {
            width: parent.width - cheat.width - parent.spacing
            height: 40
            radius: height / 2
            color: Theme.withAlpha(Theme.text, 0.06)
            border.width: 1
            border.color: field.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
            LIcon { id: searchIcon; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    icon: "search"; size: 18; color: Theme.textMuted }
            TextInput {
                id: field
                anchors { left: searchIcon.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 14
                onTextChanged: page.filter = text
                Keys.onEscapePressed: text = ""
            }
            LText { anchors { left: field.left; verticalCenter: parent.verticalCenter }
                    visible: field.text === ""; color: Theme.textMuted; text: "Filter — e.g. “screenshot”, “Super+Shift”, “workspace”" }
        }
        Button { id: cheat; icon: "keyboard"; text: "Overlay  (Super+/)"; onActivated: SettingsState.shellCall("cheatsheet", "open") }
    }

    Repeater {
        model: page.shown
        delegate: Group {
            required property var modelData
            width: page.width - Theme.space.s8 * 2
            title: modelData.title
            Repeater {
                model: modelData.binds
                delegate: SetRow {
                    required property var modelData
                    minHeight: 42
                    title: modelData.desc
                    Row {
                        spacing: 4
                        Repeater {
                            model: modelData.keys
                            delegate: Rectangle {
                                required property string modelData
                                height: 26
                                width: Math.max(26, capLabel.implicitWidth + 14)
                                radius: 7
                                color: Theme.withAlpha(Theme.text, 0.07)
                                border.width: 1
                                border.color: Theme.border
                                // a keycap's bottom edge
                                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 } height: 2; radius: 1
                                            color: Theme.withAlpha("black", 0.25) }
                                LText { id: capLabel; anchors.centerIn: parent; role: "caption"; color: Theme.text; text: modelData }
                            }
                        }
                    }
                }
            }
        }
    }

    LText {
        visible: page.shown.length === 0
        color: Theme.textMuted
        text: Keybinds.sections.length === 0 ? "Reading your shortcuts…" : "Nothing matches “" + page.filter + "”."
    }
}
