// idle + hover — date and time; battery estimate when unplugged.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2

        LText { role: "body"; color: Theme.textSecondary; text: Qt.formatDateTime(clock.date, "ddd d MMM") }
        LText { role: "bodyStrong"; text: Qt.formatDateTime(clock.date, Theme.timeFormatFull) }
        LText {
            visible: Battery.available && !Battery.pluggedIn && text !== ""
            role: "body"
            color: Theme.textMuted
            text: Battery.formatDuration(Battery.timeToEmpty) ? "· " + Battery.formatDuration(Battery.timeToEmpty) + " left" : ""
        }
    }
}
