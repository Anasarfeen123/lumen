// Frosted glass for the lock screen. The lock surface sits above the
// compositor's blur, so the shell makes its own: `frost` is a heavily
// blurred copy of the backdrop, and each pane shows exactly the slice of it
// that lies underneath — real frosted glass, not a flat tint.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme

Item {
    id: root
    required property Item frost
    property real radius: Theme.radius.lg
    property color tint: Theme.withAlpha(Theme.surface, 0.34)
    property color edge: Theme.border
    default property alias content: inner.data

    // This pane's rectangle in frost's coordinates. The dependency list makes
    // it re-evaluate whenever this pane or its containers move.
    readonly property rect area: {
        x; y; width; height;
        parent?.x; parent?.y; parent?.width;
        parent?.parent?.x; parent?.parent?.y;
        frost.width; frost.height;
        const p = mapToItem(frost, 0, 0);
        return Qt.rect(p.x, p.y, width, height);
    }

    RectangularShadow {
        anchors.fill: parent
        radius: root.radius
        offset.y: 10
        blur: 36
        color: Qt.rgba(0, 0, 0, 0.28)
        cached: true
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.frost
            sourceRect: root.area
            live: true
        }
        Rectangle { anchors.fill: parent; color: root.tint }
        // A whisper of top light: glass catches it at the upper edge
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: "transparent"
        border.width: 1
        border.color: root.edge
    }

    Item { id: inner; anchors.fill: parent }
}
