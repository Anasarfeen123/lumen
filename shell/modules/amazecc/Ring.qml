// A progress ring with a value in the middle (attendance %, a countdown…).
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.components

Item {
    id: ring
    property real value: 0              // 0–1
    property color color: Theme.accent
    property real thickness: 7
    property string label: ""
    property string sublabel: ""
    property real labelSize: width * 0.24
    implicitWidth: 84; implicitHeight: 84
    property real shown: 0
    Component.onCompleted: shown = value
    onValueChanged: shown = value
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : 700; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: Theme.withAlpha(Theme.text, 0.09); strokeWidth: ring.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX; startAngle: 0; sweepAngle: 360 }
        }
        ShapePath {
            strokeColor: ring.color; strokeWidth: ring.thickness; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            PathAngleArc { centerX: ring.width / 2; centerY: ring.height / 2; radiusX: (ring.width - ring.thickness) / 2; radiusY: radiusX
                           startAngle: -90; sweepAngle: 360 * Math.max(0.001, Math.min(1, ring.shown)) }
        }
    }
    Column {
        anchors.centerIn: parent
        LText { anchors.horizontalCenter: parent.horizontalCenter; text: ring.label; font.pixelSize: Math.round(ring.labelSize); font.weight: Font.DemiBold
                font.features: ({ "tnum": 1 }) }
        LText { visible: text !== ""; anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted; text: ring.sublabel }
    }
}
