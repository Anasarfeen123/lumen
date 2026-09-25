// A Material Symbols Rounded glyph. `fill` animates between outline (0) and
// filled (1) — filled marks an active state (DESIGN.md §9).
import QtQuick
import qs.theme

Text {
    id: root
    property string icon: ""
    property real size: Theme.size.icon
    property real fill: 0

    text: icon
    color: Theme.textSecondary
    font.family: Theme.fontIcon
    font.pixelSize: size
    font.variableAxes: ({ "FILL": fill, "wght": 400, "opsz": size, "GRAD": 0 })
    renderType: Text.NativeRendering
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
    Behavior on fill { NumberAnimation { duration: Theme.motion.micro } }
}
