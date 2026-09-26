// One Drop Zone target: drop files on it, or click it to use the shelf's files.
// Lights up with the accent while files hover over it.
//   compact: a chip (Open with…, Move to…) instead of a full row
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

HoverTarget {
    id: root
    property string icon: ""
    property string iconSource: ""       // an app icon instead of a symbol
    property string label: ""
    property string sub: ""
    property bool compact: false
    property bool usable: true
    signal activated(var paths)          // [] = click (the zone's subject)
    readonly property bool lit: drop.containsDrag || (containsMouse && usable)

    implicitWidth: compact ? chipRow.implicitWidth + 20 : 260
    implicitHeight: compact ? 30 : 46
    radius: compact ? height / 2 : Theme.radius.md
    enabled: usable
    opacity: usable ? 1 : 0.4
    onClicked: activated([])

    Rectangle {
        anchors.fill: parent
        z: -1
        radius: root.radius
        color: root.lit ? Theme.withAlpha(Theme.accent, drop.containsDrag ? 0.22 : 0.12) : Theme.withAlpha(Theme.text, root.compact ? 0.05 : 0.035)
        border.width: 1
        border.color: root.lit ? Theme.withAlpha(Theme.accent, 0.55) : Theme.border
        scale: drop.containsDrag ? 1.02 : 1
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
    }

    // Full row: icon · label / sub
    Row {
        visible: !root.compact
        anchors { left: parent.left; leftMargin: Theme.space.s3; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: Theme.space.s3
        LIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.icon; fill: root.lit ? 1 : 0; color: root.lit ? Theme.accent : Theme.textSecondary }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - Theme.size.icon - Theme.space.s3 * 2
            LText { width: parent.width; role: "bodyStrong"; text: root.label; elide: Text.ElideRight; color: root.lit ? Theme.accent : Theme.text }
            LText { width: parent.width; visible: text !== ""; role: "caption"; color: Theme.textMuted; text: root.sub; elide: Text.ElideRight }
        }
    }
    // Chip: icon · label
    Row {
        id: chipRow
        visible: root.compact
        anchors.centerIn: parent
        spacing: 6
        IconImage { visible: root.iconSource !== ""; anchors.verticalCenter: parent.verticalCenter; implicitSize: 16; source: root.iconSource }
        LIcon { visible: root.iconSource === ""; anchors.verticalCenter: parent.verticalCenter; icon: root.icon; size: 15; color: root.lit ? Theme.accent : Theme.textSecondary }
        LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; text: root.label; color: root.lit ? Theme.accent : Theme.textSecondary }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        enabled: root.usable
        onEntered: drag => { drag.accept(Qt.CopyAction); DropZone.hovering = DropZone.pathsOf(drag.urls); }
        onDropped: d => {
            const p = DropZone.pathsOf(d.urls);
            d.accept(Qt.CopyAction);
            root.activated(p);
        }
    }
    readonly property alias containsDrag: drop.containsDrag
}
