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
    // Arrow keys: the containing grid decides where focus goes (if it can)
    Keys.onPressed: event => {
        const d = { [Qt.Key_Left]: [-1, 0], [Qt.Key_Right]: [1, 0], [Qt.Key_Up]: [0, -1], [Qt.Key_Down]: [0, 1] }[event.key];
        if (d && typeof parent.moveFocus === "function") { parent.moveFocus(root, d[0], d[1]); event.accepted = true; }
    }

    Rectangle {
        id: disc
        width: 52; height: 52; radius: 26
        anchors.horizontalCenter: parent.horizontalCenter
        color: root.active && !root.action ? Theme.accent
             : area.containsMouse ? Theme.surfaceHover : Theme.surfaceElevated
        border.width: 1
        border.color: root.active && !root.action ? "transparent" : Theme.border
        scale: area.pressed ? 0.92 : 1
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.OutBack } }

        // Keyboard focus: a soft accent halo around the disc
        Rectangle {
            anchors.centerIn: parent
            width: parent.width + 8; height: width; radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: Theme.withAlpha(Theme.accent, 0.7)
            opacity: root.activeFocus ? 1 : 0
            scale: root.activeFocus ? 1 : 0.9
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            Behavior on scale { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.OutBack } }
        }
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
