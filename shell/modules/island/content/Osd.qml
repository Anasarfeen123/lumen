// osd — volume / brightness / mic: glyph + inline bar + value.
// value < 0 means "no bar" (mic on/off just shows its label).
import QtQuick
import qs.theme
import qs.components

Item {
    id: root
    required property var info
    readonly property bool hasBar: (info.value ?? -1) >= 0

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s3

        LIcon {
            icon: root.info.icon ?? ""
            size: Theme.size.icon
            fill: 1
            color: Theme.text
            anchors.verticalCenter: parent.verticalCenter
        }
        LText {
            visible: text !== ""
            role: "body"
            color: Theme.textSecondary
            text: root.info.label ?? ""
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 140)
            anchors.verticalCenter: parent.verticalCenter
        }
        Rectangle {
            visible: root.hasBar
            width: 128
            height: 4
            radius: 2
            color: Theme.surfaceHover
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, root.info.value ?? 0))
                height: parent.height
                radius: parent.radius
                color: Theme.text
                Behavior on width { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
            }
        }
        LText {
            id: pctText
            visible: root.hasBar
            role: "bodyStrong"
            horizontalAlignment: Text.AlignRight
            width: pct.width
            text: Math.round((root.info.value ?? 0) * 100)
            anchors.verticalCenter: parent.verticalCenter
            TextMetrics { id: pct; font: pctText.font; text: "100" }
        }
    }
}
