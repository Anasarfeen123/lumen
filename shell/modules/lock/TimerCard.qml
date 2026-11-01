// A timer on the lock screen: start one without unlocking (5 · 10 · 25 min),
// or see the one running — time left as a ring — with pause and stop.
import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 176
    implicitHeight: 176
    readonly property bool running: Countdown.mode === "timer"

    // running: a ring of what's left, the time, pause · stop
    Item {
        visible: root.running
        anchors.fill: parent
        Item {
            id: ring
            width: 96; height: 96
            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Theme.space.s4 }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.withAlpha(Theme.text, 0.14); strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 48; centerY: 48; radiusX: 43; radiusY: 43; startAngle: -90; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Countdown.paused ? Theme.textMuted : Theme.accent; strokeWidth: 7; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 48; centerY: 48; radiusX: 43; radiusY: 43; startAngle: -90; sweepAngle: 360 * Math.max(0.001, 1 - Countdown.progress) }
                }
            }
            LText { anchors.centerIn: parent; role: "heading"; font.features: ({ "tnum": 1 }); text: Countdown.display; color: Countdown.paused ? Theme.textMuted : Theme.text }
        }
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Theme.space.s3 }
            spacing: Theme.space.s2
            IconButton { icon: Countdown.paused ? "play_arrow" : "pause"; tone: Theme.text; iconSize: 20; onActivated: Countdown.toggle() }
            IconButton { icon: "stop"; tone: Theme.text; iconSize: 20; onActivated: Countdown.stop() }
        }
    }

    // idle: three quick starts
    Column {
        visible: !root.running
        anchors.centerIn: parent
        spacing: Theme.space.s2
        LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "timer"; size: 30; color: Theme.accent }
        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textSecondary; text: "Start a timer" }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: [5, 10, 25]
                HoverTarget {
                    required property int modelData
                    width: 44; height: 30; radius: 15
                    onClicked: Countdown.startTimer(modelData * 60000, "")
                    Rectangle { anchors.fill: parent; radius: 15; z: -1; color: Theme.withAlpha(Theme.text, 0.08); border.width: 1; border.color: Theme.border }
                    LText { anchors.centerIn: parent; role: "bodyStrong"; text: modelData + "m" }
                }
            }
        }
    }
}
