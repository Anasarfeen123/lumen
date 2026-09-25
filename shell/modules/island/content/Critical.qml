// critical — battery ≤ 5 % on battery. Stays until plugged in or dismissed.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: 48

    LIcon { id: ic; icon: "battery_alert"; size: 28; fill: 1; color: Theme.error; anchors.verticalCenter: parent.verticalCenter }
    Column {
        anchors { left: ic.right; leftMargin: Theme.space.s3; right: btn.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
        spacing: 2
        LText { role: "heading"; text: "Battery critically low" }
        LText { role: "body"; color: Theme.textSecondary; text: Math.round(Battery.percentage * 100) + "% left — plug in now" }
    }
    HoverTarget {
        id: btn
        width: lbl.implicitWidth + Theme.space.s4 * 2; height: 32
        radius: Theme.radius.sm
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        onClicked: Island.dismiss()
        LText { id: lbl; anchors.centerIn: parent; role: "bodyStrong"; text: "Dismiss" }
    }
}
