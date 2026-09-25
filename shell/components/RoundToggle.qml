// Round quick toggle (control centre): a 52 px disc with an icon, label
// below. On = accent disc, dark icon (the only accent-filled control). Action
// buttons (screenshot, record …) use the same shape with `action: true` so
// they never look "on".
import QtQuick
import qs.theme

Item {
    id: root
    property string icon: ""
    property string label: ""
    property bool active: false
    property bool action: false
    property bool busy: false
    signal toggled()

    implicitWidth: 76
    implicitHeight: 52 + 6 + 30
    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()

    Rectangle {
        id: disc
        width: 52; height: 52; radius: 26
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.active && !root.action ? Theme.accent
             : area.containsMouse ? Theme.surfaceHover : Theme.surfaceElevated
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : (root.active && !root.action ? "transparent" : Theme.border)
        scale: area.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.OutBack } }

        LIcon {
            anchors.centerIn: parent
            icon: root.icon
            fill: root.active ? 1 : 0
            color: root.active && !root.action ? Theme.onAccent : Theme.text
            opacity: root.busy ? 0.4 : 1
        }
    }
    LText {
        anchors { top: disc.bottom; topMargin: 6; horizontalCenter: parent.horizontalCenter }
        width: root.width
        horizontalAlignment: Text.AlignHCenter
        role: "caption"
        color: root.active && !root.action ? Theme.text : Theme.textSecondary
        text: root.label
        wrapMode: Text.WordWrap
        maximumLineCount: 2
        elide: Text.ElideRight
    }
    MouseArea {
        id: area
        anchors.fill: disc
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
