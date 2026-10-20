// The AmazeCC app window (shell/amazecc.qml): your college at a glance and in
// depth, from the same data Halo, the planner and the lock screen use
// (services/Amazecc.qml — VTOP through your own amazecc-api).
//   sidebar   Overview · Timetable · Attendance · Marks · Exams · Grades · Campus
//             your account and semester, when it last synced, Sync
//   ↑/↓ change page (sidebar) · Ctrl+R sync · Esc or Ctrl+W closes
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

FloatingWindow {
    id: win
    title: "AmazeCC"
    property string page: "overview"
    implicitWidth: 1120
    implicitHeight: 780
    minimumSize: Qt.size(900, 600)
    color: Theme.withAlpha(Theme.bg, 0.9)
    visible: true
    onVisibleChanged: if (!visible) Qt.quit()

    readonly property var pages: [
        { id: "overview",   icon: "space_dashboard", label: "Overview" },
        { id: "timetable",  icon: "calendar_view_week", label: "Timetable" },
        { id: "attendance", icon: "how_to_reg",      label: "Attendance" },
        { id: "marks",      icon: "grading",         label: "Marks" },
        { id: "exams",      icon: "edit_note",       label: "Exams" },
        { id: "grades",     icon: "school",          label: "Grades" },
        { id: "campus",     icon: "account_balance", label: "Campus" }
    ]
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string ago: {
        clock.date;
        const m = Math.round((Date.now() - Amazecc.updated) / 60000);
        return !Amazecc.updated ? "never" : m < 1 ? "just now" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
    }
    property bool syncAsked: false
    function syncNow() { syncAsked = true; syncDone.restart(); Amazecc.requestSync(); }
    Timer { id: syncDone; interval: 45000; onTriggered: win.syncAsked = false }
    Connections { target: Amazecc; function onUpdatedChanged() { win.syncAsked = false; } }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const i = win.pages.findIndex(p => p.id === win.page);
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape || (e.key === Qt.Key_W && ctrl)) Qt.quit();
            else if (e.key === Qt.Key_Down && i < win.pages.length - 1) win.page = win.pages[i + 1].id;
            else if (e.key === Qt.Key_Up && i > 0) win.page = win.pages[i - 1].id;
            else if (e.key === Qt.Key_R && ctrl) win.syncNow();
            else return;
            e.accepted = true;
        }

        // ── Sidebar ──
        Rectangle {
            id: sidebar
            width: 236
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Theme.withAlpha(Theme.surface, 0.55)
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Theme.border }

            Column {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s4; topMargin: Theme.space.s6 }
                spacing: 2
                Row {
                    spacing: Theme.space.s2
                    leftPadding: Theme.space.s2
                    bottomPadding: Theme.space.s5
                    Rectangle {
                        width: 32; height: 32; radius: 10
                        color: Theme.withAlpha(Theme.accent, 0.18)
                        LIcon { anchors.centerIn: parent; icon: "school"; size: 19; fill: 1; color: Theme.accent }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        LText { role: "heading"; text: "AmazeCC" }
                        LText { role: "caption"; color: Theme.textMuted; text: Amazecc.semesterName(Amazecc.data.semester ?? Amazecc.defaultSemester) || "VIT Chennai" }
                    }
                }
                Repeater {
                    model: win.pages
                    delegate: HoverTarget {
                        required property var modelData
                        readonly property bool on: win.page === modelData.id
                        width: parent.width; height: 40
                        radius: Theme.radius.sm
                        highlighted: on
                        onClicked: win.page = modelData.id
                        Rectangle { visible: parent.on; anchors { left: parent.left; verticalCenter: parent.verticalCenter } width: 3; height: 18; radius: 2; color: Theme.accent }
                        Row {
                            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s3
                            LIcon { icon: modelData.icon; size: Theme.size.iconSmall; fill: parent.parent.on ? 1 : 0; color: parent.parent.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: parent.parent.on ? "bodyStrong" : "body"; text: modelData.label; color: parent.parent.on ? Theme.text : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // you, and the sync
            Column {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s4 }
                spacing: Theme.space.s2
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Row {
                    spacing: Theme.space.s2
                    topPadding: Theme.space.s1
                    LIcon { icon: "account_circle"; size: 20; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        LText { role: "bodyStrong"; text: Amazecc.username || "Not signed in" }
                        LText { role: "caption"; color: Amazecc.error ? Theme.error : Theme.textMuted
                                text: Amazecc.syncing || win.syncAsked ? "Syncing…" : Amazecc.error ? "Couldn't sync" : "Updated " + win.ago }
                    }
                }
                HoverTarget {
                    width: parent.width; height: 34; radius: 17
                    enabled: Amazecc.hasLogin && !win.syncAsked
                    onClicked: win.syncNow()
                    Rectangle { anchors.fill: parent; radius: 17; z: -1; color: Theme.withAlpha(Theme.accent, 0.14); border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.4) }
                    Row {
                        anchors.centerIn: parent; spacing: 6
                        LIcon { icon: "sync"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter
                                RotationAnimation on rotation { running: Amazecc.syncing || win.syncAsked; loops: Animation.Infinite; from: 360; to: 0; duration: 1100 } }
                        LText { role: "bodyStrong"; color: Theme.accent; text: "Sync now"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // ── Content ──
        Item {
            id: content
            anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right }
            clip: true

            // Not connected: one clear way in
            Column {
                visible: !Amazecc.ready
                anchors.centerIn: parent
                spacing: Theme.space.s3
                width: 420
                LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "link"; size: 40; color: Theme.accent }
                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "title"; text: Amazecc.hasLogin ? "Waiting for the first sync" : "Connect VTOP" }
                LText { width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.textSecondary
                        text: Amazecc.hasLogin ? "Your timetable, attendance and marks appear here once AmazeCC has synced (about half a minute)."
                                               : "Sign in once in Settings → AmazeCC. Your password stays in this computer's keyring." }
                HoverTarget {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: goRow.implicitWidth + 28; height: 38; radius: 19
                    onClicked: Amazecc.hasLogin ? win.syncNow() : SettingsState.launch("amazecc")
                    Rectangle { anchors.fill: parent; radius: 19; z: -1; color: Theme.accent }
                    Row { id: goRow; anchors.centerIn: parent; spacing: 6
                          LIcon { icon: Amazecc.hasLogin ? "sync" : "settings"; size: 17; color: Theme.onAccent; anchors.verticalCenter: parent.verticalCenter }
                          LText { role: "bodyStrong"; color: Theme.onAccent; text: Amazecc.hasLogin ? "Sync now" : "Open Settings → AmazeCC"; anchors.verticalCenter: parent.verticalCenter } }
                }
            }

            Loader {
                id: pageLoader
                anchors.fill: parent
                visible: Amazecc.ready
                property string shown: win.page
                sourceComponent: ({ overview: overviewC, timetable: timetableC, attendance: attendanceC, marks: marksC,
                                    exams: examsC, grades: gradesC, campus: campusC })[shown] ?? overviewC
                transform: Translate { id: shift }
                Connections { target: win; function onPageChanged() { swap.restart(); } }
                SequentialAnimation {
                    id: swap
                    NumberAnimation { target: pageLoader; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 90 }
                    ScriptAction { script: { pageLoader.shown = win.page; shift.y = 14; } }
                    ParallelAnimation {
                        NumberAnimation { target: pageLoader; property: "opacity"; to: 1; duration: Theme.motion.normal }
                        NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                    }
                }
            }
        }
    }

    Component { id: overviewC; OverviewPage { onGo: p => win.page = p } }
    Component { id: timetableC; TimetablePage {} }
    Component { id: attendanceC; AttendancePage {} }
    Component { id: marksC; MarksPage {} }
    Component { id: examsC; ExamsPage {} }
    Component { id: gradesC; GradesPage {} }
    Component { id: campusC; CampusPage {} }
}
