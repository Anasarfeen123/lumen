// timer / stopwatch — a ring that empties as time runs out, and the time.
// Click the island to pause or resume; right-click stops.
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2

        Item {
            width: 18; height: 18
            anchors.verticalCenter: parent.verticalCenter
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {           // track
                    strokeColor: Theme.withAlpha(Theme.text, 0.18); strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 9; centerY: 9; radiusX: 7.5; radiusY: 7.5; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {           // remaining
                    strokeColor: Countdown.paused ? Theme.textMuted : Theme.accent; strokeWidth: 2.5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 9; centerY: 9; radiusX: 7.5; radiusY: 7.5; startAngle: -90
                                   sweepAngle: Countdown.mode === "timer" ? 360 * (1 - Countdown.progress) : 360 * ((Countdown.elapsed / 60000) % 1) }
                }
            }
        }
        // Pomodoro phase ("Focus 2" / "Break")
        LText {
            visible: Countdown.cycle !== null
            anchors.verticalCenter: parent.verticalCenter
            role: "caption"
            color: Countdown.cycle?.phase === "break" ? Theme.success : Theme.accent
            text: Countdown.cycle ? (Countdown.cycle.phase === "break" ? "Break" : "Focus " + Countdown.cycle.round) : ""
        }
        LText {
            anchors.verticalCenter: parent.verticalCenter
            role: "bodyStrong"
            font.features: { "tnum": 1 }
            text: Countdown.display
            color: Countdown.paused ? Theme.textMuted : Theme.text
        }
        LIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Countdown.paused ? "play_arrow" : "pause"
            size: Theme.size.iconSmall
            color: Theme.textSecondary
        }
    }
}
