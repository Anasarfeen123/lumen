import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import "../../services/CollegeMath.js" as CollegeMath

AppPage {
    id: page
    title: "Laundry"
    subtitle: "Your room's next collection, with the whole month in view"
    readonly property var profile: Amazecc.campusProfile
    readonly property var schedule: Amazecc.campusData.laundry ?? ({})
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int monthOffset: 0
    readonly property date month: new Date(clock.date.getFullYear(), clock.date.getMonth()+monthOffset, 1)
    readonly property int start: (month.getDay()+6)%7
    readonly property int days: new Date(month.getFullYear(), month.getMonth()+1, 0).getDate()
    property int selectedDay: clock.date.getDate()
    property bool editing: !profile.gender || !profile.block || !profile.room
    readonly property var selectedRows: Amazecc.laundryRows.filter(r => Number(r.Date) === selectedDay)
    readonly property date selectedDate: new Date(month.getFullYear(), month.getMonth(), selectedDay)
    readonly property string selectedKey: CollegeMath.dateKey(selectedDate)
    readonly property string selectedOverride: (Amazecc.cfg.laundryOverrides ?? {})[selectedKey] ?? ""
    readonly property bool ownDays: CollegeMath.ownDays(Amazecc.cfg.laundryDays).length > 0
    function isMine(d) { return CollegeMath.isLaundryDay(Amazecc.laundryRows, profile.room, d, Amazecc.cfg.laundryOverrides, Amazecc.cfg.laundryDays); }
    headerRight: CollegeButton { text: Amazecc.campusSyncing ? "Refreshing…" : "Refresh"; icon: "sync"; enabled: !Amazecc.campusSyncing; onActivated: Amazecc.refreshCampus() }
    Component.onCompleted: if (!Amazecc.campusData.updated) Amazecc.refreshCampus()
    onMonthOffsetChanged: selectedDay = Math.min(selectedDay, days)

    Card {
        width: parent.width
        Row {
            width: parent.width; spacing: Theme.space.s4
            Rectangle { width: 64; height: 64; radius: Theme.radius.lg; color: Theme.withAlpha(Theme.accent, 0.12); LIcon { anchors.centerIn: parent; icon: "local_laundry_service"; size: 32; color: Theme.accent } }
            Column {
                width: parent.width - 80; spacing: Theme.space.s1
                LText { role: "caption"; color: Theme.accent; text: "NEXT COLLECTION"; font.letterSpacing: 1 }
                LText { width: parent.width; wrapMode: Text.Wrap; role: "title"; text: Amazecc.nextLaundry ? (Amazecc.nextLaundry.date === CollegeMath.dateKey(clock.date) ? "Today" : Qt.formatDate(new Date(Amazecc.nextLaundry.when), "ddd, d MMM")) : !profile.room ? "Choose your room" : "No matching slot published" }
                LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary; text: [profile.block ? "Block " + profile.block : "", profile.room ? "Room " + profile.room : "", Amazecc.nextLaundry?.rooms ? "Rooms " + Amazecc.nextLaundry.rooms : ""].filter(x=>x).join(" · ") }
            }
        }
    }
    // laundry given in on a laundry day, waiting to be picked up
    Card {
        visible: !!Amazecc.laundryWaiting
        width: parent.width
        Row {
            width: parent.width; spacing: Theme.space.s4
            Rectangle { width: 48; height: 48; radius: Theme.radius.lg; color: Theme.withAlpha(Theme.warning, 0.14); anchors.verticalCenter: parent.verticalCenter
                        LIcon { anchors.centerIn: parent; icon: "checkroom"; size: 26; color: Theme.warning } }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 48 - pickBtn.width - 2 * Theme.space.s4
                LText { role: "bodyStrong"; text: Amazecc.laundryWaiting?.days === 1 ? "Your laundry is ready to pick up" : "Your laundry is still waiting" }
                LText { role: "caption"; color: Theme.textSecondary
                        text: Amazecc.laundryWaiting ? "Given in " + Qt.formatDate(new Date(Amazecc.laundryWaiting.when), "dddd, d MMM") + (Amazecc.cfg.laundryReminders ? " · reminding you every few hours" : "") : "" }
            }
            CollegeButton { id: pickBtn; anchors.verticalCenter: parent.verticalCenter; text: "Picked it up"; icon: "check"; onActivated: Amazecc.pickedUp() }
        }
    }
    Flow {
        width: parent.width; spacing: Theme.space.s2
        CollegeButton { text: page.editing ? "Hide hostel details" : "Change hostel details"; icon: "tune"; selected: page.editing; onActivated: page.editing = !page.editing }
        CollegeButton { text: Amazecc.cfg.laundryReminders ? "Reminders on · laundry day and pickup" : "Remind me on laundry day and to pick it up"; icon: "notifications"; selected: Amazecc.cfg.laundryReminders; onActivated: Amazecc.cfg.laundryReminders = !Amazecc.cfg.laundryReminders }
    }
    CampusProfile { visible: page.editing; width: parent.width }
    // the published schedule wrong for you altogether: your own days instead
    Card {
        width: parent.width; title: "Your own laundry days"; icon: "edit_calendar"
        Column {
            width: parent.width; spacing: Theme.space.s2
            LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                    text: "If the hostel's schedule is wrong for your room, type the days of the month you actually go (e.g. 3, 17) and press Enter. Leave it empty to follow the published schedule." }
            Row {
                spacing: Theme.space.s2
                LField { width: 220; icon: "event_repeat"; placeholder: "e.g. 3, 17"; text: Amazecc.cfg.laundryDays; clearOnAccept: false
                         onAccepted: t => Amazecc.cfg.laundryDays = CollegeMath.ownDays(t).join(", ") }
                CollegeButton { visible: page.ownDays; text: "Use the published schedule"; icon: "undo"; onActivated: Amazecc.cfg.laundryDays = "" }
            }
        }
    }
    Card {
        width: parent.width; title: Qt.formatDate(page.month, "MMMM yyyy"); icon: "calendar_month"
        headerRight: Row { spacing: Theme.space.s2
            CollegeButton { text: "Previous month"; icon: "chevron_left"; enabled: page.monthOffset > -12; onActivated: page.monthOffset-- }
            CollegeButton { text: "Today"; onActivated: { page.monthOffset = 0; page.selectedDay = clock.date.getDate(); } }
            CollegeButton { text: "Next month"; icon: "chevron_right"; enabled: page.monthOffset < 12; onActivated: page.monthOffset++ }
        }
        Column {
            width: parent.width; spacing: Theme.space.s2
            Row { width: parent.width; Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; LText { required property string modelData; width: parent.width/7; horizontalAlignment: Text.AlignHCenter; role: "caption"; color: Theme.textMuted; text: modelData } } }
            Grid {
                width: parent.width; columns: 7; spacing: Theme.space.s1
                Repeater {
                    model: 42
                    CollegeButton {
                        required property int index
                        readonly property int day: index-page.start+1
                        readonly property bool valid: day > 0 && day <= page.days
                        readonly property date date: new Date(page.month.getFullYear(), page.month.getMonth(), day)
                        readonly property bool yours: valid && page.isMine(date)
                        readonly property string fix: valid ? ((Amazecc.cfg.laundryOverrides ?? {})[CollegeMath.dateKey(date)] ?? "") : ""
                        readonly property bool today: valid && day === clock.date.getDate() && page.monthOffset === 0
                        width: (parent.width - parent.spacing*6)/7; height: 46
                        text: valid ? String(day) : ""; visible: true; opacity: valid ? 1 : 0; enabled: valid
                        selected: valid && day === page.selectedDay
                        onActivated: page.selectedDay = day
                        Rectangle { visible: parent.yours; width: 5; height: 5; radius: 3; color: Theme.accent; anchors { bottom: parent.bottom; bottomMargin: 4; horizontalCenter: parent.horizontalCenter } }
                        // a day you corrected: a small ring in the corner
                        Rectangle { visible: parent.fix !== ""; width: 7; height: 7; radius: 4; color: "transparent"; border.width: 1.5
                                    border.color: parent.fix === "add" ? Theme.accent : Theme.textMuted; anchors { top: parent.top; right: parent.right; margins: 5 } }
                        Rectangle { visible: parent.today; anchors { top: parent.top; topMargin: 3; horizontalCenter: parent.horizontalCenter } width: 14; height: 2; radius: 1; color: Theme.accent }
                        Accessible.name: valid ? Qt.formatDate(new Date(page.month.getFullYear(),page.month.getMonth(),day), "dddd, d MMMM") + (yours ? ", collection for your room" : "") : ""
                    }
                }
            }
            LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary
                    text: (page.ownDays ? "Dots mark your own days (" + CollegeMath.ownDays(Amazecc.cfg.laundryDays).join(", ") + " each month)." : "Dots mark your room's collection days, from the hostel's day-of-month schedule.")
                          + " A small ring marks a day you corrected. Pick a day to change it." }
        }
    }
    Card {
        width: parent.width; title: Qt.formatDate(page.selectedDate, "dddd, d MMMM") + (page.isMine(page.selectedDate) ? " · your laundry day" : ""); icon: "meeting_room"
        Column {
            width: parent.width; spacing: Theme.space.s2
            // the schedule wrong for this day? say so — it wins everywhere (next collection, planner, reminders)
            Flow {
                width: parent.width; spacing: Theme.space.s2
                CollegeButton { text: "My laundry day"; icon: "check_circle"; selected: page.selectedOverride === "add"
                                onActivated: Amazecc.setLaundryOverride(page.selectedKey, page.selectedOverride === "add" ? "" : "add") }
                CollegeButton { text: "Not my day"; icon: "do_not_disturb_on"; selected: page.selectedOverride === "skip"
                                onActivated: Amazecc.setLaundryOverride(page.selectedKey, page.selectedOverride === "skip" ? "" : "skip") }
                CollegeButton { visible: page.selectedOverride !== ""; text: page.ownDays ? "As my days say" : "As published"; icon: "undo"
                                onActivated: Amazecc.setLaundryOverride(page.selectedKey, "") }
            }
            LText { visible: page.selectedRows.length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted; text: "No collection listed for this day." }
            Repeater { model: page.selectedRows; LText { required property var modelData; width: parent.width; wrapMode: Text.Wrap; role: "bodyStrong"; color: CollegeMath.roomMatches(page.profile.room,modelData.RoomNumber) ? Theme.accent : Theme.text; text: modelData.RoomNumber + (CollegeMath.roomMatches(page.profile.room,modelData.RoomNumber) ? " · includes your room" : "") } }
        }
    }
    ScheduleSource { schedule: page.schedule }
}
