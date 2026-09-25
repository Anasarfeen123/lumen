// Clickable area with the standard hover/press feedback: a surface-hover
// capsule that fades in (motion-micro). Children are laid over it.
import QtQuick
import qs.theme

MouseArea {
    id: root
    property real radius: height / 2
    property bool highlighted: false
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surfaceHover
        opacity: root.pressed ? 1 : (root.containsMouse || root.highlighted) ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
    }
}
