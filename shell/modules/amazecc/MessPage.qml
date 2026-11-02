import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Mess menu"
    subtitle: "A day at a time, with the menu exactly as published"
    SystemClock { id: clock; precision: SystemClock.Minutes }
    property int dayOffset: 0
    readonly property date day: new Date(clock.date.getFullYear(),clock.date.getMonth(),clock.date.getDate()+dayOffset)
    readonly property var schedule: Amazecc.campusData.mess ?? ({})
    readonly property var menu: (schedule.rows ?? []).find(r=>String(r.Day).toLowerCase() === Qt.formatDate(day,"dddd").toLowerCase()) ?? ({})
    property bool editing: !Amazecc.campusProfile.gender || !Amazecc.campusProfile.mess
    headerRight: CollegeButton { text: Amazecc.campusSyncing ? "Refreshing…" : "Refresh"; icon: "sync"; enabled: !Amazecc.campusSyncing; onActivated: Amazecc.refreshCampus() }
    Component.onCompleted: if (!Amazecc.campusData.updated) Amazecc.refreshCampus()
    Flow {
        width: parent.width; spacing: Theme.space.s2
        CollegeButton { text: "Previous day"; icon: "chevron_left"; onActivated: page.dayOffset-- }
        CollegeButton { text: page.dayOffset === 0 ? "Today" : Qt.formatDate(page.day,"ddd, d MMM"); selected: true; onActivated: page.dayOffset = 0 }
        CollegeButton { text: "Next day"; icon: "chevron_right"; onActivated: page.dayOffset++ }
        CollegeButton { text: "Hostel & mess"; icon: "tune"; selected: page.editing; onActivated: page.editing = !page.editing }
    }
    CampusProfile { visible: page.editing; width: parent.width }
    LText { width: parent.width; wrapMode: Text.Wrap; role: "bodyStrong"; color: Theme.accent; text: Qt.formatDate(page.day,"dddd, d MMMM") + " · Week " + Math.min(4,Math.ceil(page.day.getDate()/7)) + (Amazecc.campusProfile.mess ? " · " + Amazecc.campusProfile.mess : "") }
    LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: "Week 1 is days 1–7; week 4 covers day 22 onward. Week qualifiers in the menu are kept so you can check the rotation." }
    Grid {
        width: parent.width; columns: width < 650 ? 1 : 2; spacing: Theme.space.s4
        Repeater {
            model: [{id:"Breakfast",icon:"bakery_dining"},{id:"Lunch",icon:"lunch_dining"},{id:"Snacks",icon:"local_cafe"},{id:"Dinner",icon:"dinner_dining"}]
            Card {
                required property var modelData
                width: (parent.width-parent.spacing*(parent.columns-1))/parent.columns
                height: Math.max(implicitHeight, 240)
                title: modelData.id; icon: modelData.icon
                LText { width: parent.width; wrapMode: Text.Wrap; color: page.menu[modelData.id] ? Theme.text : Theme.textMuted; text: page.menu[modelData.id] || "No menu published. Choose your hostel group and mess type, then refresh." }
            }
        }
    }
    ScheduleSource { schedule: page.schedule }
}
