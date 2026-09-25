// This month at a glance; today is the accent dot. Weeks start on Monday.
import QtQuick
import qs.theme
import qs.components

FrostPane {
    id: root
    required property date today
    implicitWidth: 248
    implicitHeight: 176

    readonly property int year: today.getFullYear()
    readonly property int month: today.getMonth()
    readonly property int offset: (new Date(year, month, 1).getDay() + 6) % 7    // Monday-first
    readonly property int days: new Date(year, month + 1, 0).getDate()
    readonly property int cellW: 30
    readonly property int cellH: 18

    Column {
        anchors { fill: parent; margins: Theme.space.s4 }
        spacing: Theme.space.s1

        LText { role: "bodyStrong"; text: Qt.formatDate(root.today, "MMMM yyyy") }

        Row {
            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]
                delegate: LText {
                    required property string modelData
                    width: root.cellW; height: root.cellH
                    horizontalAlignment: Text.AlignHCenter
                    role: "caption"; color: Theme.textMuted; text: modelData
                }
            }
        }

        Grid {
            columns: 7
            Repeater {
                model: root.offset + root.days
                delegate: Item {
                    required property int index
                    readonly property int day: index - root.offset + 1
                    readonly property bool isToday: day === root.today.getDate()
                    width: root.cellW; height: root.cellH
                    Rectangle {
                        anchors.centerIn: parent
                        width: 22; height: 18; radius: 9
                        visible: parent.isToday
                        color: Theme.accent
                    }
                    LText {
                        anchors.centerIn: parent
                        visible: parent.day > 0
                        role: parent.isToday ? "bodyStrong" : "caption"
                        font.pixelSize: Theme.size.caption
                        color: parent.isToday ? Theme.onAccent : Theme.textSecondary
                        text: parent.day
                    }
                }
            }
        }
    }
}
