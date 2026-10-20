// Grades: your CGPA and credits, how your grades spread, every graded
// course, and what this semester needs for a CGPA you're aiming at.
import QtQuick
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Grades"
    subtitle: "From VTOP's grade history — read with the other extras"
    readonly property var ex: Amazecc.extra ?? {}
    readonly property var dist: ex.cgpa?.grades ?? {}
    readonly property var letters: ["S", "A", "B", "C", "D", "E", "F"]
    readonly property int most: Math.max(1, ...letters.map(g => dist[g] ?? 0))
    property real target: 8.0
    property int semCredits: 22

    LText { visible: !page.ex.cgpa; color: Theme.textMuted; text: "Grades appear after AmazeCC reads your grade history (Sync)." }

    Row {
        visible: !!page.ex.cgpa
        width: parent.width
        spacing: Theme.space.s4
        Card {
            width: 260
            Column {
                spacing: 2
                LText { role: "caption"; color: Theme.textMuted; text: "CGPA" }
                LText { text: page.ex.cgpa?.cgpa ?? "–"; font.pixelSize: 56; font.weight: Font.DemiBold; color: Theme.accent; font.features: ({ "tnum": 1 }) }
                LText { role: "caption"; color: Theme.textSecondary; text: Number(page.ex.cgpa?.creditsEarned ?? 0) + " credits earned of " + Number(page.ex.cgpa?.creditsRegistered ?? 0) }
            }
        }
        Card {
            width: parent.width - 260 - parent.spacing
            title: "How they spread"
            icon: "bar_chart"
            Row {
                width: parent.width
                height: 120
                Repeater {
                    model: page.letters
                    Item {
                        required property string modelData
                        readonly property int n: page.dist[modelData] ?? 0
                        width: parent.width / page.letters.length; height: parent.height
                        LText { anchors { horizontalCenter: parent.horizontalCenter; bottom: bar.top; bottomMargin: 3 } role: "caption"; color: Theme.textMuted; text: parent.n || "" }
                        Rectangle {
                            id: bar
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: lbl.top; bottomMargin: 4 }
                            width: 26; radius: 6
                            height: Math.max(3, (parent.height - 40) * parent.n / page.most)
                            color: parent.modelData === "F" || parent.modelData === "E" ? Theme.withAlpha(Theme.warning, 0.7) : Theme.accent
                            opacity: parent.n ? 1 : 0.25
                            Behavior on height { NumberAnimation { duration: 700; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                        }
                        LText { id: lbl; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom } role: "bodyStrong"; text: parent.modelData }
                    }
                }
            }
        }
    }

    // what this semester needs
    Card {
        visible: !!page.ex.cgpa
        width: parent.width
        id: aim
        title: "Aim for a CGPA"
        icon: "target"
        readonly property real cur: Number(page.ex.cgpa?.cgpa ?? 0)
        readonly property real done: Number(page.ex.cgpa?.creditsEarned ?? 0)
        readonly property real need: (page.target * (done + page.semCredits) - cur * done) / page.semCredits
        Column {
            width: parent.width
            spacing: Theme.space.s3
            Row {
                spacing: Theme.space.s3
                LText { anchors.verticalCenter: parent.verticalCenter; text: "Target" }
                Stepper { value: page.target; step: 0.25; lo: 5; hi: 10; fmt: v => v.toFixed(2); onChanged: v => page.target = v }
                LText { anchors.verticalCenter: parent.verticalCenter; text: "with"; leftPadding: Theme.space.s3 }
                Stepper { value: page.semCredits; step: 1; lo: 10; hi: 30; fmt: v => v + " credits"; onChanged: v => page.semCredits = v }
                LText { anchors.verticalCenter: parent.verticalCenter; text: "this semester" }
            }
            LText {
                width: parent.width; wrapMode: Text.Wrap
                role: "bodyStrong"
                color: aim.need > 10 ? Theme.error : aim.need <= aim.cur ? Theme.success : Theme.accent
                text: aim.need > 10 ? "Not this semester — even a perfect 10 SGPA reaches " + ((aim.cur * aim.done + 10 * page.semCredits) / (aim.done + page.semCredits)).toFixed(2) + "."
                      : aim.need <= 0 ? "You're already there."
                      : "You'd need an SGPA of " + aim.need.toFixed(2) + " this semester."
            }
        }
    }

    Card {
        visible: (page.ex.grades ?? []).length > 0
        width: parent.width
        title: "Every graded course"
        icon: "list_alt"
        Column {
            width: parent.width
            Repeater {
                model: page.ex.grades ?? []
                Item {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 36
                    Rectangle { visible: index > 0; width: parent.width; height: 1; color: Theme.border }
                    Rectangle {
                        id: gb
                        width: 30; height: 24; radius: 6; anchors.verticalCenter: parent.verticalCenter
                        color: /[SA]/.test(modelData.grade) ? Theme.withAlpha(Theme.accent, 0.2) : /[EF]/.test(modelData.grade) ? Theme.withAlpha(Theme.warning, 0.2) : Theme.withAlpha(Theme.text, 0.08)
                        LText { anchors.centerIn: parent; role: "bodyStrong"; text: modelData.grade }
                    }
                    LText { anchors { left: gb.right; leftMargin: Theme.space.s3; right: cr.left; verticalCenter: parent.verticalCenter } elide: Text.ElideRight; text: modelData.title }
                    LText { id: cr; anchors { right: parent.right; verticalCenter: parent.verticalCenter } role: "caption"; color: Theme.textMuted
                            text: Amazecc.fmt(modelData.credits) + " cr" + (modelData.type ? " · " + modelData.type : "") }
                }
            }
        }
    }

    component Stepper: Row {
        id: sp
        property real value
        property real step
        property real lo
        property real hi
        property var fmt
        signal changed(real v)
        spacing: 4
        HoverTarget { width: 28; height: 28; radius: 14; onClicked: sp.changed(Math.max(sp.lo, sp.value - sp.step))
                      LIcon { anchors.centerIn: parent; icon: "remove"; size: 16; color: Theme.textSecondary } }
        LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; color: Theme.accent; font.features: ({ "tnum": 1 }); text: sp.fmt(sp.value); width: Math.max(implicitWidth, 44); horizontalAlignment: Text.AlignHCenter }
        HoverTarget { width: 28; height: 28; radius: 14; onClicked: sp.changed(Math.min(sp.hi, sp.value + sp.step))
                      LIcon { anchors.centerIn: parent; icon: "add"; size: 16; color: Theme.textSecondary } }
    }
}
