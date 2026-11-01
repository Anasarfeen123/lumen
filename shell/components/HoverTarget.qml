// Clickable area with the standard hover/press feedback: a surface-hover
// capsule that fades in (motion-micro). Children are laid over it.
import QtQuick
import qs.theme

MouseArea {
    id: root
    property real radius: height / 2
    property bool highlighted: false
    property bool hoverFeedback: true   // false: the item draws its own selection (no second highlight under a resting pointer)
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Theme.surfaceHover
        opacity: root.pressed ? 1 : ((root.containsMouse && root.hoverFeedback) || root.highlighted) ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
    }
}
