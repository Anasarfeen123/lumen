// The Lumen mark: the island, glowing — a white pill with light radiating
// from behind it, on a dark squircle. The glow is the accent colour, so the
// mark follows the theme. (Static version: assets/lumen.svg.)
import QtQuick
import qs.theme

Item {
    id: root
    property real size: 64
    property color tint: Theme.accent
    width: size
    height: size

    Rectangle {
        id: tile
        anchors.fill: parent
        radius: root.size * 0.28
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#1f2a36" }
            GradientStop { position: 1.0; color: "#0b1016" }
        }
        border.width: Math.max(1, root.size * 0.012)
        border.color: Qt.rgba(1, 1, 1, 0.12)
        clip: true

        // Light behind the island: stacked soft ellipses fake a radial glow
        Repeater {
            model: 6
            delegate: Rectangle {
                required property int index
                readonly property real k: 1 - index / 6
                anchors.centerIn: parent
                width: root.size * (0.30 + 0.62 * k)
                height: width * 0.8
                radius: height / 2
                color: Qt.rgba(root.tint.r, root.tint.g, root.tint.b, 0.10 + 0.07 * index)
            }
        }
    }

    // The island
    Rectangle {
        anchors.centerIn: parent
        width: root.size * 0.55
        height: root.size * 0.19
        radius: height / 2
        color: "white"
        Rectangle {
            width: parent.height * 0.34
            height: width
            radius: width / 2
            color: "#0b1016"
            opacity: 0.85
            anchors { right: parent.right; rightMargin: parent.height * 0.33; verticalCenter: parent.verticalCenter }
        }
    }
}
