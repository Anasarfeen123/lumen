// A single-line text field in Lumen style: a recessed pill, placeholder,
// accent edge while focused. Enter emits accepted(text) and clears.
import QtQuick
import qs.theme

Rectangle {
    id: root
    property string placeholder: ""
    property string icon: ""
    property alias text: input.text
    property alias input: input
    property bool clearOnAccept: true
    signal accepted(string text)

    implicitHeight: 36
    radius: height / 2
    color: Theme.withAlpha(Theme.text, 0.05)
    border.width: 1
    border.color: input.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }

    LIcon {
        id: glyph
        visible: root.icon !== ""
        anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        icon: root.icon; size: 16; color: Theme.textMuted
    }
    TextInput {
        id: input
        anchors { left: root.icon !== "" ? glyph.right : parent.left; leftMargin: root.icon !== "" ? Theme.space.s2 : Theme.space.s3
                  right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        color: Theme.text
        selectionColor: Theme.withAlpha(Theme.accent, 0.4)
        font.family: Theme.fontUi
        font.pixelSize: 13
        clip: true
        Keys.onReturnPressed: { root.accepted(text); if (root.clearOnAccept) text = ""; }
        Keys.onEnterPressed: { root.accepted(text); if (root.clearOnAccept) text = ""; }
    }
    LText {
        anchors { left: input.left; right: input.right; verticalCenter: parent.verticalCenter }
        visible: input.text === ""
        elide: Text.ElideRight
        color: Theme.textMuted
        text: root.placeholder
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onPressed: m => { input.forceActiveFocus(); m.accepted = false; } }
}
