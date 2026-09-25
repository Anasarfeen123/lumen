// Island background equalizer: live spectrum bars behind the clock.
// Low-contrast accent so the time stays readable; bars grow from the centre
// line, inset from the rounded ends so nothing pokes out of the pill.
import QtQuick
import qs.theme
import qs.services

Item {
    id: root
    property bool active: false

    opacity: active && Visualizer.levels.length > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }

    Binding { target: Visualizer; property: "wanted"; value: root.active; when: root.active }
    Binding { target: Visualizer; property: "wanted"; value: false; when: !root.active }

    Row {
        id: row
        anchors.centerIn: parent
        readonly property int n: Math.max(1, Visualizer.levels.length)
        // Span the pill, keeping clear of the rounded ends
        readonly property real pitch: (root.width - root.height * 0.75) / n
        spacing: pitch - bw
        readonly property real bw: Math.max(1.5, pitch * 0.5)

        Repeater {
            model: Visualizer.levels.length
            delegate: Rectangle {
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                width: row.bw
                radius: width / 2
                // Album colour when the art has one, else the accent
                color: Media.hasTint ? Media.tint : Theme.accent
                opacity: 0.42
                Behavior on color { ColorAnimation { duration: 900 } }
                height: Math.max(2, (Visualizer.levels[index] ?? 0) * (root.height - 8))
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
