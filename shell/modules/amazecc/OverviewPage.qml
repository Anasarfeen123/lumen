// Overview: what's next, the three numbers that matter (attendance, CGPA, the
// next exam), the day's classes, what needs care, and the latest circulars.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    signal go(string page)
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property int hour: clock.date.getHours()
    title: (hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening") + (Amazecc.username ? "" : "")
    subtitle: Amazecc.headline || Qt.formatDate(clock.date, "dddd, d MMMM")

    readonly property var ex: Amazecc.extra ?? {}
    readonly property var counted: Amazecc.courses.filter(c => c.total)
    readonly property real avg: counted.length ? counted.reduce((n, c) => n + c.pct, 0) / counted.length : 0
    readonly property var day: {
        clock.date;
        if (Amazecc.next || Amazecc.current) return { label: "Today", date: clock.date, list: Amazecc.today };
        const nd = Amazecc.nextDay;
        return nd ? { label: nd.date.getTime() - new Date(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate()).getTime() === 86400000 ? "Tomorrow" : Qt.formatDate(nd.date, "dddd"),
                      date: nd.date, list: Amazecc.classesOn(nd.date) } : { label: "Today", date: clock.date, list: Amazecc.today };
    }

    // ── three numbers ──
    Row {
        width: parent.width
        spacing: Theme.space.s4
        readonly property real w: (width - spacing * 2) / 3
        Stat {
            width: parent.w
            onClicked: page.go("attendance")
            Ring { value: page.avg / 100; label: Math.round(page.avg) + "%"; width: 78; height: 78; anchors.verticalCenter: parent.verticalCenter
                   color: page.avg < Amazecc.cfg.threshold ? Theme.error : page.avg < Amazecc.cfg.threshold + 5 ? Theme.warning : Theme.accent }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                LText { role: "bodyStrong"; text: "Attendance" }
                LText { role: "caption"; color: Amazecc.attention.length ? Theme.warning : Theme.textMuted
                        text: Amazecc.attention.length ? Amazecc.attention.length + " need care" : "All above " + Amazecc.cfg.threshold + "%" }
            }
        }
        Stat {
            width: parent.w
            onClicked: page.go("grades")
            Column {
                anchors.verticalCenter: parent.verticalCenter
                LText { text: page.ex.cgpa?.cgpa ?? "–"; font.pixelSize: 40; font.weight: Font.DemiBold; color: Theme.accent; font.features: ({ "tnum": 1 }) }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                LText { role: "bodyStrong"; text: "CGPA" }
                LText { role: "caption"; color: Theme.textMuted; text: page.ex.cgpa ? Number(page.ex.cgpa.creditsEarned) + " credits" : "after a sync" }
            }
        }
        Stat {
            width: parent.w
            id: examStat
            onClicked: page.go("exams")
            readonly property var e: Amazecc.nextExam
            readonly property int n: e ? Amazecc.daysTo(e.when) : 0
            Ring { value: examStat.e ? Math.max(0.03, 1 - examStat.n / 30) : 0; label: examStat.e ? String(examStat.n) : "–"; sublabel: examStat.e ? (examStat.n === 1 ? "day" : "days") : ""
                   width: 78; height: 78; labelSize: 22; anchors.verticalCenter: parent.verticalCenter
                   color: examStat.e && examStat.n <= 3 ? Theme.warning : Theme.accent }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 78 - Theme.space.s3 * 3
                LText { role: "bodyStrong"; text: examStat.e ? examStat.e.kind : "No exams"; elide: Text.ElideRight; width: parent.width }
                LText { role: "caption"; color: Theme.textMuted; width: parent.width; elide: Text.ElideRight; text: examStat.e ? examStat.e.title : "nothing scheduled" }
            }
        }
    }

    // ── the day ──
    Row {
        width: parent.width
        spacing: Theme.space.s4
        Card {
            width: (parent.width - parent.spacing) * 0.58
            title: page.day.label + "'s classes"
            icon: "schedule"
            headerRight: LText { role: "caption"; color: Theme.textMuted; text: page.day.list.length + (page.day.list.length === 1 ? " class" : " classes") }
            Column {
                width: parent.width
                spacing: 2
                LText { visible: page.day.list.length === 0; color: Theme.textMuted; text: Amazecc.dayInfo(page.day.date)?.text || "No classes." }
                Repeater {
                    model: page.day.list
                    delegate: Item {
                        required property var modelData
                        readonly property bool now: page.day.label === "Today" && Amazecc.isCurrent(modelData)
                        readonly property bool past: page.day.label === "Today" && modelData.end <= Amazecc.nowMin
                        width: parent.width; height: 46
                        opacity: past ? 0.45 : 1
                        Rectangle { anchors.fill: parent; radius: Theme.radius.sm; color: parent.now ? Theme.withAlpha(Theme.accent, 0.12) : "transparent" }
                        Rectangle { x: 8; width: 3; height: 28; radius: 1.5; anchors.verticalCenter: parent.verticalCenter; color: parent.now ? Theme.accent : Theme.withAlpha(Theme.textMuted, 0.5) }
                        LText { id: t; x: 20; width: 74; anchors.verticalCenter: parent.verticalCenter; role: "caption"; font.features: ({ "tnum": 1 })
                                color: parent.now ? Theme.accent : Theme.textSecondary; text: Amazecc.clockLabel(modelData.start) }
                        Column {
                            anchors { left: t.right; right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: modelData.title }
                            LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                    text: [modelData.venue, modelData.kind === "lab" ? "Lab" : "", parent.parent.now ? "till " + Amazecc.clockLabel(modelData.end) : ""].filter(x => x).join(" · ") }
                        }
                    }
                }
            }
        }
        Card {
            width: (parent.width - parent.spacing) * 0.42
            title: "Needs care"
            icon: "warning"
            Column {
                width: parent.width
                spacing: Theme.space.s2
                LText { visible: Amazecc.attention.length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                        text: "Every course is comfortably above " + Amazecc.cfg.threshold + "%." }
                Repeater {
                    model: Amazecc.attention.slice(0, 5)
                    delegate: Row {
                        required property var modelData
                        width: parent.width; spacing: Theme.space.s3
                        Ring { width: 40; height: 40; thickness: 4; labelSize: 11; value: modelData.pct / 100; label: Math.round(modelData.pct) + ""
                               color: modelData.pct < Amazecc.cfg.threshold ? Theme.error : Theme.warning }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 52
                            LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: Amazecc.courseName(modelData) }
                            LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                    text: modelData.pct < Amazecc.cfg.threshold ? "attend the next " + Amazecc.needed(modelData)
                                          : Amazecc.skippable(modelData) === 0 ? "don't miss the next one" : "can miss " + Amazecc.skippable(modelData) }
                        }
                    }
                }
            }
        }
    }

    // ── the latest from campus ──
    Card {
        visible: (page.ex.circulars ?? []).length > 0
        width: parent.width
        title: "Latest circulars"
        icon: "campaign"
        headerRight: HoverTarget { width: allLbl.implicitWidth + 16; height: 24; onClicked: page.go("campus")
                                   LText { id: allLbl; anchors.centerIn: parent; role: "caption"; color: Theme.accent; text: "All →" } }
        Column {
            width: parent.width
            Repeater {
                model: (page.ex.circulars ?? []).slice(0, 4)
                delegate: Row {
                    required property var modelData
                    width: parent.width; height: 28; spacing: Theme.space.s3
                    LText { width: 64; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                            text: modelData.date ? Qt.formatDate(new Date(modelData.date), "d MMM") : "" }
                    LText { width: parent.width - 76; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: modelData.title }
                }
            }
        }
    }

    // a clickable summary tile
    component Stat: HoverTarget {
        id: st
        default property alias inner: statRow.data
        height: 112
        radius: Theme.radius.lg
        Rectangle { anchors.fill: parent; radius: Theme.radius.lg; z: -1; color: Theme.withAlpha(Theme.surfaceElevated, st.containsMouse ? 0.95 : 0.75)
                    border.width: 1; border.color: st.containsMouse ? Theme.borderStrong : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        Row { id: statRow; anchors { fill: parent; margins: Theme.space.s4 } spacing: Theme.space.s3 }
        LIcon { anchors { right: parent.right; top: parent.top; margins: Theme.space.s3 } icon: "arrow_outward"; size: 15; color: Theme.textMuted; opacity: st.containsMouse ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } } }
    }
}
