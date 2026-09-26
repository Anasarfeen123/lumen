// Halo's mark: a ring of light. Breathes while Halo is working.
import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root
    property bool active: false
    property real size: 20
    width: size; height: size

    Rectangle {
        id: ring
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: Math.max(2, root.size * 0.14)
        border.color: Theme.accent
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.8; shadowOpacity: root.active ? 0.9 : 0.5; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    // A bright point travelling round the ring
    Item {
        anchors.fill: parent
        visible: root.active
        RotationAnimation on rotation { from: 0; to: 360; duration: 1400; loops: Animation.Infinite; running: root.active && !Theme.reducedMotion }
        Rectangle {
            width: ring.border.width + 1; height: width; radius: width / 2
            x: (root.size - width) / 2; y: -0.5
            color: Qt.tint(Theme.accent, "#99ffffff")
        }
    }
    SequentialAnimation on scale {
        running: root.active && !Theme.reducedMotion
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation { to: 1.08; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
    }
}
