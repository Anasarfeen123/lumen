// Your next class (AmazeCC), at a glance: what, where, when. Attendance shows
// only how many courses need care — never which, or the numbers — since the
// lock screen is visible to anyone at the desk.
import QtQuick
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 196
    implicitHeight: 176

    readonly property var cls: Amazecc.current ?? Amazecc.next
    readonly property int behind: Amazecc.courses.filter(c => c.pct !== null && c.pct < Amazecc.cfg.threshold).length
    readonly property bool wanted: Amazecc.cfg.enabled && Amazecc.cfg.lockScreen && Amazecc.ready && (cls !== null || Amazecc.nextDay !== null || behind > 0)

    Column {
        anchors { fill: parent; margins: Theme.space.s4 }
        spacing: Theme.space.s2

        Row {
            spacing: Theme.space.s2
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: root.cls?.kind === "lab" ? "science" : "school"; size: 18; fill: 1; color: Theme.accent }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"; color: Theme.textSecondary
                text: root.cls ? (Amazecc.isCurrent(root.cls) ? "Now · till " + Amazecc.clockLabel(root.cls.end) : "Next · " + Amazecc.clockLabel(root.cls.start))
                    : Amazecc.nextDay ? Qt.formatDate(Amazecc.nextDay.date, "dddd") + " · " + Amazecc.clockLabel(Amazecc.nextDay.first.start) : "No more classes"
            }
        }
        LText {
            width: parent.width
            wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
            role: "heading"; font.weight: Font.Normal
            text: root.cls?.title ?? Amazecc.nextDay?.first.title ?? "Done for today"
        }
        LText {
            visible: text !== ""
            width: parent.width; elide: Text.ElideRight
            role: "body"; color: Theme.textSecondary
            text: root.cls ? (root.cls.venue + (Amazecc.isCurrent(root.cls) ? "" : " · " + Amazecc.inLabel(root.cls.start))).replace(/^ · /, "") : (Amazecc.nextDay?.first.venue ?? "")
        }
        Row {
            visible: root.behind > 0
            spacing: 5
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: "warning"; size: 14; color: Theme.warning }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.warning
                    text: root.behind + (root.behind === 1 ? " course" : " courses") + " under " + Amazecc.cfg.threshold + "%" }
        }
    }
}
