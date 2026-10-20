// Timetable: the week as a grid — each class where it sits in the day, labs
// tinted, today's column lit, a line at the time now. Click a class for its
// faculty, slots and attendance.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Timetable"
    subtitle: (Amazecc.todayInfo?.order ? "Today follows " + Amazecc.dayNames[Amazecc.todayInfo.order] + "'s timetable · " : "") + "Click a class for details"
    SystemClock { id: clock; precision: SystemClock.Minutes }

    readonly property var week: Amazecc.data.week ?? {}
    readonly property var days: ["MON", "TUE", "WED", "THU", "FRI", "SAT"].filter(d => (week[d] ?? []).length > 0)
    readonly property string todayKey: Amazecc.todayInfo?.order ?? ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][clock.date.getDay()]
    readonly property var all: [].concat(...days.map(d => week[d]))
    readonly property int from: all.length ? Math.floor(Math.min(...all.map(c => c.start)) / 60) * 60 : 480
    readonly property int to: all.length ? Math.ceil(Math.max(...all.map(c => c.end)) / 60) * 60 : 1140
    property var picked: null

    Rectangle {
        id: grid
        width: parent.width
        height: 620
        radius: Theme.radius.lg
        color: Theme.withAlpha(Theme.surfaceElevated, 0.55)
        border.width: 1; border.color: Theme.border
        clip: true
        readonly property real gutter: 64
        readonly property real headH: 40
        readonly property real colW: (width - gutter) / Math.max(1, page.days.length)
        readonly property real k: (height - headH - 10) / Math.max(60, page.to - page.from)

        // hour lines and labels
        Repeater {
            model: Math.max(0, (page.to - page.from) / 60 + 1)
            Item {
                required property int index
                y: grid.headH + index * 60 * grid.k
                width: grid.width
                Rectangle { x: grid.gutter; width: parent.width - grid.gutter; height: 1; color: Theme.withAlpha(Theme.text, 0.06) }
                LText { x: 10; y: -8; width: grid.gutter - 16; horizontalAlignment: Text.AlignRight; role: "caption"; color: Theme.textMuted
                        font.features: ({ "tnum": 1 }); text: Amazecc.clockLabel(page.from + index * 60) }
            }
        }
        // the days
        Repeater {
            model: page.days
            Item {
                id: dayCol
                required property string modelData
                required property int index
                readonly property bool isToday: modelData === page.todayKey
                x: grid.gutter + index * grid.colW
                width: grid.colW; height: grid.height
                Rectangle { anchors.fill: parent; color: dayCol.isToday ? Theme.withAlpha(Theme.accent, 0.05) : "transparent" }
                Rectangle { width: 1; height: parent.height; color: Theme.withAlpha(Theme.text, 0.05) }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    LText { anchors.horizontalCenter: parent.horizontalCenter; role: dayCol.isToday ? "bodyStrong" : "body"
                            color: dayCol.isToday ? Theme.accent : Theme.textSecondary; text: (Amazecc.dayNames[dayCol.modelData] ?? dayCol.modelData).slice(0, 3) }
                }
                Repeater {
                    model: page.week[dayCol.modelData] ?? []
                    HoverTarget {
                        id: blk
                        required property var modelData
                        readonly property bool lab: modelData.kind === "lab"
                        readonly property bool now: dayCol.isToday && Amazecc.isCurrent(modelData)
                        readonly property bool sel: page.picked && page.picked.id === modelData.id && page.picked.start === modelData.start
                        x: 4; width: dayCol.width - 8
                        y: grid.headH + (modelData.start - page.from) * grid.k + 1
                        height: Math.max(22, (modelData.end - modelData.start) * grid.k - 3)
                        radius: Theme.radius.sm
                        onClicked: page.picked = sel ? null : modelData
                        Rectangle {
                            anchors.fill: parent; radius: Theme.radius.sm; z: -1
                            color: blk.now ? Theme.withAlpha(Theme.accent, 0.32) : blk.lab ? Theme.withAlpha(Theme.accent, 0.12) : Theme.withAlpha(Theme.text, blk.containsMouse ? 0.12 : 0.08)
                            border.width: blk.sel || blk.now ? 2 : 1
                            border.color: blk.sel ? Theme.text : blk.now ? Theme.accent : Theme.withAlpha(Theme.text, 0.06)
                            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                        }
                        Rectangle { x: 0; width: 3; height: parent.height - 8; anchors.verticalCenter: parent.verticalCenter; radius: 1.5
                                    color: blk.lab ? Theme.withAlpha(Theme.accent, 0.6) : Theme.accent }
                        Column {
                            anchors { left: parent.left; leftMargin: 9; right: parent.right; rightMargin: 4; top: parent.top; topMargin: 4 }
                            LText { width: parent.width; elide: Text.ElideRight; font.pixelSize: 12; font.weight: Font.DemiBold; text: blk.modelData.title }
                            LText { visible: blk.height > 38; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                    text: blk.modelData.venue + (blk.lab ? " · Lab" : "") }
                        }
                    }
                }
                // now
                Rectangle {
                    visible: dayCol.isToday && Amazecc.nowMin >= page.from && Amazecc.nowMin <= page.to
                    y: grid.headH + (Amazecc.nowMin - page.from) * grid.k
                    width: parent.width; height: 2; color: Theme.error
                    Rectangle { x: -4; y: -3; width: 8; height: 8; radius: 4; color: Theme.error }
                }
            }
        }
    }

    // what you clicked
    Card {
        visible: !!page.picked
        width: parent.width
        readonly property var course: page.picked ? Amazecc.courses.find(c => c.id === page.picked.id) : null
        title: page.picked ? Amazecc.courseName(course ?? page.picked) : ""
        icon: page.picked?.kind === "lab" ? "science" : "menu_book"
        headerRight: LText { role: "caption"; color: Theme.textMuted; text: page.picked ? Amazecc.clockLabel(page.picked.start) + " – " + Amazecc.clockLabel(page.picked.end) : "" }
        Flow {
            width: parent.width
            spacing: Theme.space.s5
            Fact { k: "Code"; v: parent.parent.course?.code ?? page.picked?.code ?? "" }
            Fact { k: "Room"; v: page.picked?.venue ?? "" }
            Fact { k: "Faculty"; v: (parent.parent.course?.faculty ?? "").replace(/^\d+\s+/, "").replace(/\s+[A-Z]{3,}$/, "") }
            Fact { k: "Slots"; v: (parent.parent.course?.slots ?? []).join(" + ") }
            Fact { k: "Attendance"; v: parent.parent.course?.total ? parent.parent.course.pct + "% (" + parent.parent.course.attended + "/" + parent.parent.course.total + ")" : "–" }
        }
    }

    component Fact: Column {
        property string k
        property string v
        visible: v !== ""
        LText { role: "caption"; color: Theme.textMuted; text: parent.k }
        LText { role: "bodyStrong"; text: parent.v }
    }
}
