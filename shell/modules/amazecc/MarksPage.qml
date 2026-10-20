// Marks: each course's assessments — what you scored, what it's worth — the
// running total, and what the FAT needs for a pass and for each grade.
import QtQuick
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Marks"
    subtitle: "Weighted marks so far, and what the FAT needs (absolute grading; relative grading can move the cut-offs)"

    Repeater {
        model: Amazecc.marks
        Card {
            id: mc
            required property var modelData
            readonly property var t: Amazecc.targets(modelData)
            readonly property var posted: (modelData.assessments ?? []).filter(a => a.scored !== null)
            width: parent.width
            title: Amazecc.courseName(modelData)
            icon: modelData.kind === "lab" ? "science" : "menu_book"
            headerRight: [
                LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                        text: mc.posted.length ? Amazecc.fmt(mc.posted.reduce((n, a) => n + (a.weightMark ?? 0), 0)) + " of " + Amazecc.fmt(mc.posted.reduce((n, a) => n + (a.weight ?? 0), 0)) : "nothing posted yet" }
            ]
            Column {
                width: parent.width
                spacing: Theme.space.s2
                Repeater {
                    model: mc.modelData.assessments ?? []
                    Item {
                        required property var modelData
                        readonly property bool has: modelData.scored !== null && modelData.scored !== undefined
                        readonly property real frac: has && modelData.max ? modelData.scored / modelData.max : 0
                        width: parent.width; height: 34
                        LText { id: an; width: parent.width * 0.42; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                                color: parent.has ? Theme.text : Theme.textMuted; text: modelData.title }
                        // the score as a bar
                        Rectangle {
                            id: track
                            anchors { left: an.right; leftMargin: Theme.space.s3; right: nums.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            height: 8; radius: 4; color: Theme.withAlpha(Theme.text, 0.08)
                            Rectangle { width: parent.width * parent.parent.frac; height: parent.height; radius: 4
                                        color: parent.parent.frac < 0.5 ? Theme.warning : Theme.accent
                                        Behavior on width { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } } }
                        }
                        Row {
                            id: nums
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s3
                            LText { width: 70; horizontalAlignment: Text.AlignRight; font.features: ({ "tnum": 1 }); role: "bodyStrong"
                                    text: parent.parent.has ? Amazecc.fmt(modelData.scored) + " / " + Amazecc.fmt(modelData.max) : "–" }
                            LText { width: 92; horizontalAlignment: Text.AlignRight; font.features: ({ "tnum": 1 }); role: "caption"; color: Theme.textMuted
                                    text: parent.parent.has ? Amazecc.fmt(modelData.weightMark) + " of " + Amazecc.fmt(modelData.weight) : modelData.weight ? "worth " + Amazecc.fmt(modelData.weight) : "" }
                        }
                    }
                }
                // what the FAT needs
                Rectangle {
                    visible: !!mc.t
                    width: parent.width; height: needRow.implicitHeight + Theme.space.s3 * 2
                    radius: Theme.radius.md
                    color: Theme.withAlpha(Theme.accent, 0.08)
                    border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.25)
                    Row {
                        id: needRow
                        x: Theme.space.s3; y: Theme.space.s3
                        spacing: Theme.space.s5
                        LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; color: Theme.accent
                                text: mc.t?.done ? "Total " + Amazecc.fmt(mc.t.total) + " / 100" : "FAT needs (of 100)" }
                        Repeater {
                            model: mc.t && !mc.t.done ? Amazecc.grades.filter(([g]) => mc.t.needFull[g] <= 100) : []
                            Column {
                                required property var modelData
                                LText { role: "caption"; color: Theme.textMuted; text: modelData[0] === "E" ? "Pass" : modelData[0] }
                                LText { role: "bodyStrong"; font.features: ({ "tnum": 1 }); text: Amazecc.fatRange(mc.t, modelData[0]) }
                            }
                        }
                    }
                }
            }
        }
    }
    LText { visible: Amazecc.marks.length === 0; color: Theme.textMuted; text: "No marks posted yet." }
}
