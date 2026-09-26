// A month at a glance at the foot of the control centre.
//   ‹ › step months · the title returns to today · weekends are quieter
//   today: accent pill · weeks start on Monday
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    required property date today
    property int shift: 0                     // months away from today
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + shift, 1)
    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property bool thisMonth: shift === 0
    readonly property real cellW: (width - Theme.space.s3 * 2) / 7

    implicitHeight: col.implicitHeight + Theme.space.s3 * 2
    radius: Theme.radius.md
    color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
    border.width: 1
    border.color: Theme.border

    Connections { target: Sidebar; function onOpenChanged() { if (Sidebar.open) root.shift = 0; } }

    Column {
        id: col
        x: Theme.space.s3; y: Theme.space.s3
        width: parent.width - Theme.space.s3 * 2
        spacing: Theme.space.s1

        Item {
            width: parent.width; height: 28
            HoverTarget {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                width: title.implicitWidth + Theme.space.s3 * 2; height: 28
                onClicked: root.shift = 0
                LText { id: title; anchors.centerIn: parent; role: "bodyStrong"
                        text: Qt.formatDate(root.shown, root.year === root.today.getFullYear() ? "MMMM" : "MMMM yyyy") }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                HoverTarget { width: 28; height: 28; onClicked: root.shift--
                              LIcon { anchors.centerIn: parent; icon: "chevron_left"; size: 18; color: Theme.textSecondary } }
                HoverTarget { width: 28; height: 28; onClicked: root.shift++
                              LIcon { anchors.centerIn: parent; icon: "chevron_right"; size: 18; color: Theme.textSecondary } }
            }
        }

        Row {
            Repeater {
                model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                delegate: LText {
                    required property string modelData
                    required property int index
                    width: root.cellW; height: 18
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"
                    color: index >= 5 ? Theme.withAlpha(Theme.textMuted, 0.7) : Theme.textMuted
                    text: modelData
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: Math.ceil((root.offset + root.days) / 7) * 7   // only the weeks this month needs
                delegate: Item {
                    required property int index
                    readonly property int day: index - root.offset + 1
                    readonly property bool inMonth: day >= 1 && day <= root.days
                    readonly property bool isToday: root.thisMonth && day === root.today.getDate()
                    readonly property bool weekend: index % 7 >= 5
                    width: root.cellW; height: 24
                    Rectangle {
                        anchors.centerIn: parent
                        width: 28; height: 22; radius: 11
                        visible: parent.isToday
                        color: Theme.accent
                    }
                    LText {
                        anchors.centerIn: parent
                        visible: parent.inMonth
                        role: parent.isToday ? "bodyStrong" : "body"
                        color: parent.isToday ? Theme.onAccent : parent.weekend ? Theme.textMuted : Theme.textSecondary
                        text: parent.day
                    }
                }
            }
        }
    }
}
