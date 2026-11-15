// Lost mode (services/FindMy.qml): on the lock screen, first, for whoever finds
// the laptop — your message and how to reach you. While the alarm rings, Stop.
import QtQuick
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 420
    implicitHeight: col.implicitHeight + Theme.space.s5 * 2

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Theme.space.s5 }
        spacing: Theme.space.s2
        Row {
            spacing: Theme.space.s2
            LIcon { icon: FindMy.ringing ? "crisis_alert" : "travel_explore"; size: 22; fill: 1; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "heading"; text: "This laptop is lost"; anchors.verticalCenter: parent.verticalCenter }
        }
        LText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; role: "body"; text: FindMy.lost.message ?? "" }
        LText { visible: (FindMy.lost.phone ?? "") !== ""; width: parent.width; role: "title"; text: "Please call " + (FindMy.lost.phone ?? "") }
        HoverTarget {
            visible: FindMy.ringing
            width: stopText.implicitWidth + 40; height: 38; radius: 19
            onClicked: FindMy.stop()
            Rectangle { anchors.fill: parent; radius: 19; color: Theme.text }
            LText { id: stopText; anchors.centerIn: parent; color: Theme.bg; role: "bodyStrong"; text: "Stop the sound" }
        }
    }
}
