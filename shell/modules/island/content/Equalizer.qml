// Four accent bars bouncing out of phase — the "music is playing" mark.
// Runs only while visible; freezes to a static mark under reduced motion.
import QtQuick
import qs.theme

Row {
    id: root
    spacing: 2
    height: 12

    Repeater {
        model: [0.55, 1.0, 0.7, 0.85]
        delegate: Rectangle {
            required property real modelData
            required property int index
            width: 2
            radius: 1
            color: Theme.accent
            anchors.bottom: parent.bottom
            height: root.height * modelData

            SequentialAnimation on height {
                running: root.visible && !Theme.reducedMotion
                loops: Animation.Infinite
                NumberAnimation { to: root.height * 0.25; duration: 260 + index * 70; easing.type: Easing.InOutSine }
                NumberAnimation { to: root.height * modelData; duration: 300 + index * 50; easing.type: Easing.InOutSine }
            }
        }
    }
}
