// Rounded screen corners (Settings → Bar & Island): the screen's four corners
// drawn round in black, like a phone's display. Clicks pass straight through.
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

PanelWindow {
    id: win
    readonly property real r: Persist.data.screenCornerRadius ?? 14
    visible: Persist.data.screenCorners ?? false
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-screen-corners"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}                     // takes no input anywhere

    Repeater {
        model: 4
        Shape {
            required property int index
            readonly property bool atRight: index % 2 === 1
            readonly property bool atBottom: index >= 2
            width: win.r; height: win.r
            x: atRight ? win.width - width : 0
            y: atBottom ? win.height - height : 0
            rotation: [0, 90, 270, 180][index]
            preferredRendererType: Shape.CurveRenderer
            // a square with a quarter circle cut out of it
            ShapePath {
                fillColor: Theme.scrim
                strokeColor: "transparent"
                startX: 0; startY: 0
                PathLine { x: win.r; y: 0 }
                PathArc { x: 0; y: win.r; radiusX: win.r; radiusY: win.r; direction: PathArc.Counterclockwise }
                PathLine { x: 0; y: 0 }
            }
        }
    }
}
