// Battery as a ring: fill = charge, colour = state (accent · charging green ·
// low amber · critical red), time remaining underneath.
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 176
    implicitHeight: 176

    readonly property color tone: Battery.critical ? Theme.error : Battery.low ? Theme.warning
                                : Battery.charging ? Theme.success : Theme.accent

    Item {
        id: ring
        width: 104; height: 104
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.space.s5 }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.withAlpha(Theme.text, 0.14)
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: 52; centerY: 52; radiusX: 46; radiusY: 46; startAngle: -90; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: root.tone
                strokeWidth: 8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: 52; centerY: 52; radiusX: 46; radiusY: 46; startAngle: -90
                    sweepAngle: 360 * Math.max(0.01, Battery.percentage)
                    Behavior on sweepAngle { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            LIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Battery.charging || Battery.pluggedIn
                icon: "bolt"; fill: 1; size: 16; color: root.tone
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(Battery.percentage * 100) + "%"
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: 24
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
            }
        }
    }

    LText {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space.s4 }
        role: "caption"
        color: Theme.textSecondary
        text: Battery.charging ? (Battery.timeToFull > 0 ? "Full in " + Battery.formatDuration(Battery.timeToFull) : "Charging")
            : Battery.pluggedIn ? "Plugged in"
            : Battery.timeToEmpty > 0 ? Battery.formatDuration(Battery.timeToEmpty) + " left" : "On battery"
    }
}
