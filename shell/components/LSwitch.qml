// On/off switch. Click, Space or Enter toggles; emits toggled(). The owner
// holds the state (`checked` is bound, never set internally).
import QtQuick
import qs.theme

Item {
    id: root
    property bool checked: false
    signal toggled()

    implicitWidth: 42
    implicitHeight: 24
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: toggled()

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.surfaceHover
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : (root.checked ? "transparent" : Theme.border)
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }

        Rectangle {
            width: 18; height: 18; radius: 9
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.onAccent : Theme.textSecondary
            Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
}
