// A small pill button under a list row: Disconnect, Forget, Pair…
import QtQuick
import qs.theme
import qs.components

HoverTarget {
    id: chip
    property string icon
    property string label
    property bool danger: false
    width: chipRow.implicitWidth + 20; height: 28
    Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                color: chip.danger ? Theme.withAlpha(Theme.error, 0.12) : Theme.withAlpha(Theme.text, 0.06)
                border.width: 1; border.color: chip.danger ? Theme.withAlpha(Theme.error, 0.35) : Theme.border }
    Row { id: chipRow; anchors.centerIn: parent; spacing: 5
          LIcon { icon: chip.icon; size: 14; color: chip.danger ? Theme.error : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
          LText { role: "caption"; text: chip.label; color: chip.danger ? Theme.error : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
}
