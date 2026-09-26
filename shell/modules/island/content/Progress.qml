// progress — something long is happening: icon · title · thin accent bar · %.
// Fed by `lumen progress`, `lumen run -- <cmd>`, downloads. value < 0 means
// "unknown": the bar becomes a slow sweep instead of a fill.
import QtQuick
import qs.theme
import qs.components

Item {
    id: root
    required property var info
    readonly property real value: info.value ?? -1
    implicitWidth: 300
    implicitHeight: Theme.island.height

    Row {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.space.s2
        LIcon { id: glyph; icon: root.info.icon || "progress_activity"; size: Theme.size.iconSmall; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        Column {
            width: row.width - glyph.width - pct.width - row.spacing * 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; font.pixelSize: 12
                    text: root.info.title ?? "" }
            Rectangle {
                id: track
                width: parent.width; height: 3; radius: 1.5
                color: Theme.withAlpha(Theme.text, 0.14)
                clip: true
                Rectangle {
                    height: parent.height; radius: 1.5
                    color: Theme.accent
                    width: root.value >= 0 ? parent.width * Math.min(1, root.value / 100) : parent.width * 0.3
                    Behavior on width { enabled: root.value >= 0; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
                    // Unknown length: a slow sweep (it explains "working, no estimate")
                    SequentialAnimation on x {
                        running: root.value < 0 && !Theme.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { from: -track.width * 0.3; to: track.width; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
        LText { id: pct; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                font.features: { "tnum": 1 }
                text: root.info.detail || (root.value >= 0 ? Math.round(root.value) + "%" : "") }
    }
}
