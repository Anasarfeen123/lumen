// Face ID ring around the avatar.
//   scanning  an accent arc sweeps around (the camera is looking)
//   matched   the ring closes in success green
//   failed    a brief red pulse, then it fades (type your password)
//   ready/off nothing — the avatar stays clean
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.services

Item {
    id: root
    property real size: 88
    width: size
    height: size
    readonly property string st: Lock.faceStatus
    readonly property real r: size / 2 - 3

    opacity: st === "scanning" || st === "matched" || pulse.running ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }

    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        rotation: 0
        ShapePath {
            strokeColor: root.st === "matched" ? Theme.success : root.st === "failed" ? Theme.error : Theme.accent
            strokeWidth: 3
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root.size / 2; centerY: root.size / 2
                radiusX: root.r; radiusY: root.r
                startAngle: -90
                sweepAngle: root.st === "scanning" ? 110 : 360
                Behavior on sweepAngle { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
        }
        RotationAnimation on rotation {
            running: root.st === "scanning" && !Theme.reducedMotion
            from: 0; to: 360; duration: 1100; loops: Animation.Infinite
        }
    }

    // Soft breathing glow while scanning
    Rectangle {
        anchors.centerIn: parent
        width: root.size - 10; height: width; radius: width / 2
        color: "transparent"
        border.width: 6
        border.color: Theme.withAlpha(root.st === "matched" ? Theme.success : Theme.accent, 0.18)
        visible: root.st === "scanning" || root.st === "matched"
        SequentialAnimation on scale {
            running: root.st === "scanning" && !Theme.reducedMotion
            loops: Animation.Infinite
            NumberAnimation { to: 1.06; duration: 700; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
        }
    }

    // Matched: a check badge on the ring
    Rectangle {
        visible: root.st === "matched"
        anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
        width: 24; height: 24; radius: 12
        color: Theme.success
        scale: visible ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack } }
        Text { anchors.centerIn: parent; text: "check"; font.family: Theme.fontIcon; font.pixelSize: 16; color: Theme.bg; font.variableAxes: ({ "FILL": 1, "wght": 600 }) }
    }

    // Failed: one red pulse
    SequentialAnimation {
        id: pulse
        NumberAnimation { target: arc; property: "scale"; from: 1; to: 1.08; duration: 120 }
        NumberAnimation { target: arc; property: "scale"; to: 1; duration: 220; easing.type: Easing.OutBack }
        PauseAnimation { duration: 500 }
    }
    onStChanged: if (st === "failed") pulse.restart()
}
