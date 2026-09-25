// The Lumen glass material: translucent tint + inner hairline + soft shadow.
// Blur itself is applied by Hyprland to the layer (rules.conf, lumen-* layers).
//   level: "chrome" (bar pills, island) | "panel" (sidebars, launcher)
//   flat:  no material at all — content sits on a surface below (merged bar)
// Switching between these animates (motion-normal), so surfaces can morph.
import QtQuick
import QtQuick.Effects
import qs.theme

Item {
    id: root
    property string level: "chrome"
    property real radius: height / 2
    property bool shadow: true
    property bool flat: false
    default property alias content: body.data

    readonly property color fillColor: level === "panel" ? Theme.glassPanel : Theme.glassChrome

    RectangularShadow {
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.shadow && !root.flat ? 1 : 0
        radius: root.radius
        offset.y: root.level === "panel" ? 8 : 2
        blur: root.level === "panel" ? 32 : 8
        spread: 0
        color: Theme.shadowColor
        cached: true
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: root.radius
        color: root.flat ? "transparent" : root.fillColor
        border.width: 1
        border.color: root.flat ? "transparent" : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.motion.normal } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion.normal } }
    }
}
