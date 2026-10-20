// Exams: the schedule by series (CAT 1, CAT 2, FAT), each with a countdown,
// the time, when to report, the room and your seat; past ones fade.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Exams"
    subtitle: Amazecc.nextExam ? "Next: " + Amazecc.nextExam.kind + " · " + Amazecc.nextExam.title : "Nothing coming up"
    SystemClock { id: clock; precision: SystemClock.Minutes }
    // what's still to come first; finished series after
    readonly property var kinds: {
        clock.date;
        const ks = [...new Set(Amazecc.exams.map(e => e.kind))], now = Date.now();
        const done = k => Amazecc.exams.filter(e => e.kind === k).every(e => (e.end ?? e.when) < now);
        return ks.filter(k => !done(k)).concat(ks.filter(done));
    }

    Repeater {
        model: page.kinds
        Column {
            id: series
            required property string modelData
            readonly property var list: Amazecc.exams.filter(e => e.kind === modelData)
            readonly property bool allPast: list.every(e => (e.end ?? e.when) < clock.date.getTime())
            width: parent.width
            spacing: Theme.space.s2
            Row {
                spacing: Theme.space.s2
                LText { role: "caption"; color: series.allPast ? Theme.textMuted : Theme.accent; font.weight: Font.DemiBold; font.letterSpacing: 1; text: series.modelData.toUpperCase() }
                LText { role: "caption"; color: Theme.textMuted; text: series.allPast ? "· done" : "· " + series.list.length + (series.list.length === 1 ? " exam" : " exams") }
            }
            Repeater {
                model: series.list
                Rectangle {
                    id: ex
                    required property var modelData
                    readonly property bool past: (modelData.end ?? modelData.when) < clock.date.getTime()
                    readonly property int n: Amazecc.daysTo(modelData.when)
                    width: series.width; height: 70
                    radius: Theme.radius.lg
                    opacity: past ? 0.5 : 1
                    color: !past && n <= 3 ? Theme.withAlpha(Theme.warning, 0.08) : Theme.withAlpha(Theme.surfaceElevated, 0.75)
                    border.width: 1; border.color: !past && n <= 3 ? Theme.withAlpha(Theme.warning, 0.35) : Theme.border
                    // the date block
                    Column {
                        id: dateBlock
                        x: Theme.space.s4; anchors.verticalCenter: parent.verticalCenter
                        width: 52
                        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.accent; font.weight: Font.DemiBold
                                text: Qt.formatDate(new Date(ex.modelData.when), "MMM").toUpperCase() }
                        LText { anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 24; font.weight: Font.DemiBold
                                text: Qt.formatDate(new Date(ex.modelData.when), "d") }
                    }
                    Rectangle { x: dateBlock.x + dateBlock.width + Theme.space.s3; width: 1; height: parent.height - 24; anchors.verticalCenter: parent.verticalCenter; color: Theme.border }
                    Column {
                        anchors { left: dateBlock.right; leftMargin: Theme.space.s3 * 2 + 1; right: when.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: ex.modelData.title }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                text: [Qt.formatDate(new Date(ex.modelData.when), "dddd"), ex.modelData.time, ex.modelData.reporting ? "report by " + ex.modelData.reporting : "",
                                       ex.modelData.venue, ex.modelData.seat ? "seat " + ex.modelData.seat : ""].filter(x => x).join(" · ") }
                    }
                    Row {
                        id: when
                        anchors { right: parent.right; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                        spacing: Theme.space.s3
                        LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; color: ex.past ? Theme.textMuted : ex.n <= 3 ? Theme.warning : Theme.accent
                                text: ex.past ? "done" : ex.n === 0 ? "today" : ex.n === 1 ? "tomorrow" : "in " + ex.n + " days" }
                        HoverTarget {
                            visible: !ex.past
                            anchors.verticalCenter: parent.verticalCenter
                            width: revRow.implicitWidth + 20; height: 30; radius: 15
                            onClicked: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "amazecc", "revise", ex.modelData.code + "|" + ex.modelData.kind])
                            Rectangle { anchors.fill: parent; radius: 15; z: -1; color: "transparent"; border.width: 1; border.color: Theme.border }
                            Row { id: revRow; anchors.centerIn: parent; spacing: 5
                                  LIcon { icon: "checklist"; size: 15; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                  LText { role: "caption"; text: "Revision note"; anchors.verticalCenter: parent.verticalCenter } }
                        }
                    }
                }
            }
            Item { width: 1; height: Theme.space.s2 }
        }
    }
    LText { visible: Amazecc.exams.length === 0; color: Theme.textMuted; text: "No exams on VTOP's schedule yet." }
}
