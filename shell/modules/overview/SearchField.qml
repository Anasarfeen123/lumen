// The search pill. Placeholder text changes with the mode so the prefixes
// are discoverable without a help screen.
import QtQuick
import qs.theme
import qs.components
import qs.services

GlassSurface {
    id: root
    property alias input: input
    property real innerOpacity: 1
    Behavior on innerOpacity { NumberAnimation { duration: Theme.motion.micro } }
    level: "panel"
    implicitWidth: 600
    implicitHeight: 48

    LIcon {
        id: glyph
        anchors { left: parent.left; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
        icon: ({ clipboard: "content_paste", emoji: "mood" })[Overview.mode] ?? "search"
        opacity: root.innerOpacity
        color: Theme.textMuted
    }

    TextInput {
        id: input
        anchors { left: glyph.right; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
        color: Theme.text
        selectionColor: Theme.withAlpha(Theme.accent, 0.35)
        selectedTextColor: Theme.text
        font.family: Theme.fontUi
        font.pixelSize: Theme.size.heading
        clip: true
        opacity: root.innerOpacity
        text: Overview.query
        onTextChanged: if (Overview.query !== text) Overview.query = text
        cursorDelegate: Rectangle {
            width: 2; color: Theme.accent
            visible: input.activeFocus
        }

        LText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            role: "heading"
            font.weight: Font.Normal
            color: Theme.textMuted
            text: ({ clipboard: "Search clipboard  ·  ↵ paste  Ctrl+↵ plain  ⇧↵ open link  Alt+P pin",
                     emoji: "Search emoji" })[Overview.mode]
                  ?? "Search apps, windows and actions   ·   = calculate   > run   ? web"
        }
    }
}
