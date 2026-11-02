import QtQuick
import qs.theme
import qs.components

HoverTarget {
    id: root
    property string text: ""
    property string icon: ""
    property bool selected: false
    signal activated()
    implicitWidth: label.implicitWidth + Theme.space.s4 * 2
    implicitHeight: 36
    width: implicitWidth; height: implicitHeight
    radius: Theme.radius.md
    highlighted: selected
    activeFocusOnTab: true
    acceptedButtons: Qt.LeftButton
    opacity: enabled ? 1 : 0.45
    onClicked: activated()
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()
    Keys.onSpacePressed: activated()
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: activated()
    Rectangle { anchors.fill: parent; radius: root.radius; color: root.selected ? Theme.withAlpha(Theme.accent, 0.12) : "transparent"; border.width: 1; border.color: root.activeFocus ? Theme.accent : root.selected ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border }
    Row {
        id: label; anchors.centerIn: parent; spacing: Theme.space.s2
        LIcon { visible: root.icon !== ""; icon: root.icon; size: 16; color: root.selected ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        LText { text: root.text; role: "bodyStrong"; color: root.selected ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    }
}
