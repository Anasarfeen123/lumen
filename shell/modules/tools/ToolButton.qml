import QtQuick
import QtQuick.Controls.Basic as QQC
import qs.theme
import qs.components

QQC.AbstractButton {
    id: root
    property string glyph: ""
    property string label: ""
    property bool primary: false
    property bool flat: false           // no box at rest (in the bar): a round hover, like the bar's other controls
    implicitWidth: row.implicitWidth + Theme.space.s3 * 2
    implicitHeight: Theme.space.s8 + Theme.space.s2
    padding: Theme.space.s3
    hoverEnabled: true
    activeFocusOnTab: true
    Accessible.name: label
    background: Rectangle {
        radius: root.flat ? height / 2 : Theme.radius.sm
        color: root.down ? Theme.surfaceHover : root.primary ? Theme.withAlpha(Theme.accent, .14) : root.hovered ? Theme.surfaceHover : root.flat ? "transparent" : Theme.surfaceElevated
        border.width: root.activeFocus ? 2 : (root.flat && !root.primary ? 0 : 1)
        border.color: root.activeFocus ? Theme.accent : root.primary ? Theme.withAlpha(Theme.accent, .35) : Theme.border
        opacity: root.enabled ? 1 : .4
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
    }
    contentItem: Row {
        id: row
        spacing: Theme.space.s2
        opacity: root.enabled ? 1 : .45
        LIcon { visible: root.glyph !== ""; icon: root.glyph; size: Theme.size.heading; color: root.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        LText { textFormat: Text.PlainText; text: root.label; role: "bodyStrong"; color: root.primary ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    }
}
