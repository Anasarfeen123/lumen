import QtQuick
import qs.theme
import qs.components
import qs.services
import "../../services/CollegeMath.js" as CollegeMath

Card {
    id: root
    title: "Build a GPA scenario"
    icon: "calculate"
    property int revision: 0
    readonly property var rows: { revision; const out = []; for (let i=0;i<plan.count;i++) out.push(Object.assign({},plan.get(i))); return out; }
    ListModel { id: plan }
    readonly property var result: CollegeMath.prediction(rows,Amazecc.extra.cgpa?.cgpa,Amazecc.extra.cgpa?.creditsEarned)
    readonly property int incomplete: rows.filter(r=>!(Number(r.credits)>0) || !["S","A","B","C","D","E","F","N"].includes(r.grade)).length
    function reset() { plan.clear(); for (const c of Amazecc.courses) plan.append({title:Amazecc.courseName(c),credits:"",grade:""}); revision++; }
    function update(index,key,value) { plan.setProperty(index,key,value); revision++; }
    Component.onCompleted: reset()
    Column {
        width: parent.width; spacing: Theme.space.s3
        LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary; text: "Enter each course's credits and expected grade. Unknown credits stay blank. S=10, A=9 … E=5; F/N=0. Pass/fail and non-credit courses should be removed. This scenario does not change your records." }
        Row {
            width: parent.width; spacing: Theme.space.s5
            Column { width: (parent.width-parent.spacing)/2; LText { role: "caption"; color: Theme.textMuted; text: "SCENARIO SGPA" } LText { role: "title"; color: Theme.accent; text: root.rows.length && !root.incomplete ? root.result.sgpa.toFixed(2) : "–"; font.features: ({"tnum":1}) } }
            Column { width: (parent.width-parent.spacing)/2; LText { role: "caption"; color: Theme.textMuted; text: "PROJECTED CGPA" } LText { role: "title"; color: Theme.accent; text: root.rows.length && !root.incomplete && root.result.cgpa !== null ? root.result.cgpa.toFixed(2) : "–"; font.features: ({"tnum":1}) } }
        }
        LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: root.incomplete ? Theme.warning : Theme.textMuted; text: root.incomplete ? "Finish credits and grades for " + root.incomplete + (root.incomplete === 1 ? " course." : " courses.") : root.result.credits + " scenario credits. CGPA adds these to the published earned credits; already-counted courses and replacement grades need different rules." }
        Repeater {
            model: plan
            Column {
                required property int index
                required property var model
                width: parent.width; spacing: Theme.space.s2
                Row {
                    width: parent.width; spacing: Theme.space.s2
                    LField { width: parent.width-150-parent.spacing*2; text: model.title; clearOnAccept: false; placeholder: "Course name"; input.onEditingFinished: root.update(index,"title",text) }
                    LField { width: 100; text: String(model.credits); placeholder: "Credits"; clearOnAccept: false; input.validator: DoubleValidator { bottom: 0.5; top: 30; decimals: 1; locale: "C" } input.onEditingFinished: root.update(index,"credits",text) }
                    CollegeButton { width: 50; text: ""; icon: "close"; Accessible.name: "Remove " + model.title; onActivated: { plan.remove(index); root.revision++; } }
                }
                Flow {
                    id: grades; property int rowIndex: index; property string chosen: model.grade
                    width: parent.width; spacing: Theme.space.s2
                    Repeater { model: ["S","A","B","C","D","E","F","N"]; CollegeButton { required property string modelData; text: modelData; width: 44; selected: grades.chosen === modelData; Accessible.name: "Expected grade " + modelData; onActivated: root.update(grades.rowIndex,"grade",modelData) } }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.border }
            }
        }
        Flow {
            width: parent.width; spacing: Theme.space.s2
            CollegeButton { text: "Add course"; icon: "add"; onActivated: { plan.append({title:"",credits:"",grade:""}); root.revision++; } }
            CollegeButton { text: "Reset to current courses"; icon: "restart_alt"; onActivated: root.reset() }
        }
    }
}
