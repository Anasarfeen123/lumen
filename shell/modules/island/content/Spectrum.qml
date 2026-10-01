// Island background equalizer: live spectrum bars along the bottom of the
// pill, under the clock. They stay in the lower third and soft (the album
// colour blended toward the accent), so the time and date always read
// cleanly; inset from the rounded ends so nothing pokes out of the pill.
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
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
        height: root.height * 0.34
        readonly property int n: Math.max(1, Visualizer.levels.length)
        // Span the pill, keeping clear of the rounded ends
        readonly property real pitch: (root.width - root.height * 0.75) / n
        spacing: pitch - bw
        readonly property real bw: Math.max(1.5, pitch * 0.5)

        Repeater {
            model: Visualizer.levels.length
            delegate: Rectangle {
                required property int index
                anchors.bottom: parent.bottom
                width: row.bw
                radius: width / 2
                // Album colour softened toward the accent (bright art stays calm)
                color: Media.hasTint ? Qt.tint(Theme.accent, Theme.withAlpha(Media.tint, 0.6)) : Theme.accent
                opacity: 0.3
                Behavior on color { ColorAnimation { duration: 900 } }
                height: Math.max(2, (Visualizer.levels[index] ?? 0) * row.height)
                Behavior on height { NumberAnimation { duration: 60 } }
            }
        }
    }
}
