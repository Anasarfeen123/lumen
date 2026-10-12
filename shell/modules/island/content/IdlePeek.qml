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
        // An exam within the week (AmazeCC)
        Row {
            visible: Amazecc.cfg.enabled && Amazecc.cfg.islandNext && Amazecc.examCountdown !== "" && !(Amazecc.current ?? Amazecc.next)
            spacing: 5
            LText { role: "body"; color: Theme.textMuted; text: "·"; anchors.verticalCenter: parent.verticalCenter }
            LIcon { icon: "edit_note"; size: 15; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "body"; color: Theme.textSecondary
                    width: Math.min(implicitWidth, 300); elide: Text.ElideRight; text: Amazecc.examCountdown }
        }
        // Your class (AmazeCC): the one you're in, else the next today
        Row {
            readonly property var cls: Amazecc.current ?? Amazecc.next
            visible: Amazecc.cfg.enabled && Amazecc.cfg.islandNext && cls !== null
            spacing: 5
            LText { role: "body"; color: Theme.textMuted; text: "·"; anchors.verticalCenter: parent.verticalCenter }
            LIcon { icon: parent.cls?.kind === "lab" ? "science" : "school"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "body"; color: Theme.textSecondary
                width: Math.min(implicitWidth, 260); elide: Text.ElideRight
                text: !parent.cls ? "" : parent.cls.title + (parent.cls.venue ? " · " + parent.cls.venue : "")
                      + " · " + (Amazecc.isCurrent(parent.cls) ? "till " + Amazecc.clockLabel(parent.cls.end) : Amazecc.inLabel(parent.cls.start))
            }
        }
    }
}
