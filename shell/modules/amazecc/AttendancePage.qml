// Attendance: every course as a ring, with what you can miss (or must
// attend), its trend this week, and "what if I skip …" for the next days.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Attendance"
    subtitle: "Minimum " + Amazecc.cfg.threshold + "% · theory and lab are counted separately"
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property var skipDay: null
    readonly property var impact: skipDay ? Amazecc.skipImpact(skipDay) : []
    function impactOf(c) { return impact.find(x => x.course.id === c.id) ?? null; }

    // What if I skip …
    Row {
        spacing: Theme.space.s2
        LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; text: "What if I skip"; rightPadding: Theme.space.s1 }
        Repeater {
            model: {
                clock.date;
                const out = [], base = new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate());
                for (let i = 0; out.length < 5 && i < 10; i++) {
                    const d = new Date(base.getTime() + i * 86400000);
                    if (Amazecc.classesOn(d).length) out.push({ d, label: i === 0 ? "today" : i === 1 ? "tomorrow" : Qt.formatDate(d, "dddd") });
                }
                return out;
            }
            HoverTarget {
                required property var modelData
                readonly property bool on: page.skipDay && page.skipDay.getTime() === modelData.d.getTime()
                width: lbl.implicitWidth + 24; height: 30; radius: 15
                onClicked: page.skipDay = on ? null : modelData.d
                Rectangle { anchors.fill: parent; radius: 15; z: -1; color: parent.on ? Theme.withAlpha(Theme.warning, 0.16) : "transparent"
                            border.width: 1; border.color: parent.on ? Theme.withAlpha(Theme.warning, 0.5) : Theme.border }
                LText { id: lbl; anchors.centerIn: parent; color: parent.on ? Theme.warning : Theme.textSecondary; text: modelData.label }
            }
        }
    }

    Grid {
        width: parent.width
        columns: width > 900 ? 3 : 2
        columnSpacing: Theme.space.s4
        rowSpacing: Theme.space.s4
        Repeater {
            model: Amazecc.courses.slice().sort((a, b) => (a.pct ?? 101) - (b.pct ?? 101))
            Card {
                id: cc
                required property var modelData
                readonly property var hit: page.impactOf(modelData)
                readonly property real shownPct: hit ? hit.after : (modelData.pct ?? 0)
                readonly property string tone: shownPct < Amazecc.cfg.threshold ? "error" : shownPct < Amazecc.cfg.threshold + 5 ? "warning" : "normal"
                width: (parent.width - parent.columnSpacing * (parent.columns - 1)) / parent.columns
                border.color: hit ? Theme.withAlpha(Theme.warning, 0.5) : Theme.border
                Row {
                    width: parent.width
                    spacing: Theme.space.s4
                    Ring {
                        width: 86; height: 86
                        value: cc.shownPct / 100
                        label: cc.modelData.total ? (cc.hit ? cc.hit.after.toFixed(1) : Math.round(cc.modelData.pct)) + "%" : "–"
                        labelSize: 17
                        color: cc.tone === "error" ? Theme.error : cc.tone === "warning" ? Theme.warning : Theme.accent
                    }
                    Column {
                        width: parent.width - 86 - parent.spacing
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        LText { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; role: "bodyStrong"; text: Amazecc.courseName(cc.modelData) }
                        LText { role: "caption"; color: Theme.textMuted; text: cc.modelData.code + (cc.modelData.total ? " · " + cc.modelData.attended + " of " + cc.modelData.total : "") }
                        LText {
                            width: parent.width; wrapMode: Text.Wrap; role: "caption"
                            color: cc.tone === "error" ? Theme.error : cc.tone === "warning" ? Theme.warning : Theme.success
                            text: !cc.modelData.total ? "No classes counted yet"
                                  : cc.hit ? "Skipping " + cc.hit.n + (cc.hit.n === 1 ? " class" : " classes") + ": " + cc.hit.before + "% → " + cc.hit.after.toFixed(1) + "%"
                                  : cc.modelData.pct < Amazecc.cfg.threshold ? "Attend the next " + Amazecc.needed(cc.modelData)
                                  : Amazecc.skippable(cc.modelData) === 0 ? "Don't miss the next one" : "Can miss " + Amazecc.skippable(cc.modelData)
                        }
                        LText { visible: text !== ""; role: "caption"; color: Theme.textMuted; text: Amazecc.trendText(cc.modelData).replace(/^ · /, "") }
                    }
                }
            }
        }
    }
}
