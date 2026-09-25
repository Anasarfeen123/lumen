// Text button. `primary` fills with the accent; otherwise a quiet outline.
import QtQuick
import qs.theme
import qs.components

HoverTarget {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    signal activated()

    width: row.implicitWidth + Theme.space.s4 * 2
    height: 34
    radius: 17
    activeFocusOnTab: true
    onClicked: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.primary ? (root.containsMouse ? Theme.accentHover : Theme.accent) : "transparent"
        border.width: root.primary ? 0 : 1
        border.color: root.activeFocus ? Theme.accent : Theme.borderStrong
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
    }
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s1
        LIcon { visible: root.icon !== ""; icon: root.icon; size: Theme.size.iconSmall; color: root.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        LText { role: "bodyStrong"; text: root.text; color: root.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    }
}
