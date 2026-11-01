// An example sidebar card: three rings — CPU, memory, temperature.
// Everything comes from `lumen` (docs/WIDGETS.md); only QtQuick is imported.
import QtQuick
import QtQuick.Shapes

Rectangle {
    id: root
    property var lumen: null
    readonly property var t: lumen ? lumen.theme : null
    implicitHeight: 112
    radius: 16
    color: t ? t.withAlpha(t.surfaceElevated, 0.85) : "#222"
    border.width: 1
    border.color: t ? t.border : "#444"

    component Ring: Item {
        id: ring
        property real value: 0          // 0–1
        property string label
        property string text
        property color tone: root.t ? root.t.accent : "orange"
        width: 76; height: 92
        Shape {
            width: 64; height: 64; anchors.horizontalCenter: parent.horizontalCenter
            preferredRendererType: Shape.CurveRenderer
            ShapePath { strokeWidth: 6; strokeColor: root.t ? root.t.withAlpha(root.t.text, 0.1) : "#333"; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 32; centerY: 32; radiusX: 27; radiusY: 27; startAngle: 0; sweepAngle: 360 } }
            ShapePath { strokeWidth: 6; strokeColor: ring.tone; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 32; centerY: 32; radiusX: 27; radiusY: 27; startAngle: -90; sweepAngle: 360 * Math.max(0.01, Math.min(1, ring.value))
                                       Behavior on sweepAngle { NumberAnimation { duration: 400 } } } }
        }
        Text { y: 22; anchors.horizontalCenter: parent.horizontalCenter; text: ring.text; color: root.t ? root.t.text : "white"; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter } text: ring.label; color: root.t ? root.t.textMuted : "gray"; font.pixelSize: 12 }
    }

    Row {
        anchors.centerIn: parent
        spacing: 18
        Ring { label: "CPU"; value: lumen ? lumen.sysinfo.cpu : 0; text: Math.round(value * 100) + "%" }
        Ring { label: "Memory"; value: lumen ? lumen.sysinfo.memUsed / Math.max(1, lumen.sysinfo.memTotal || 16) : 0; text: lumen ? lumen.sysinfo.memUsed.toFixed(1) + "G" : "" }
        Ring { label: "Temp"; value: lumen ? lumen.sysinfo.cpuTemp / 100 : 0; text: lumen ? Math.round(lumen.sysinfo.cpuTemp) + "°" : ""
               tone: lumen && lumen.sysinfo.cpuTemp >= 85 ? root.t.warning : (root.t ? root.t.accent : "orange") }
    }
}
