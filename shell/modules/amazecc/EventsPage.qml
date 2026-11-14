// Events & buses: what's on around campus (VTOP's events, through your
// AmazeCC API) and which bus stops where.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    property var events: Study.events
    property var buses: []
    property string kind: ""
    title: "Events & buses"
    subtitle: events.length + " upcoming events"
    Component.onCompleted: {
        Study.run(["events"], r => { if (r.ok) { page.events = r.events; Study.events = r.events; } });
        Study.run(["buses"], r => { if (r.ok) page.buses = r.buses; });
    }
    readonly property var kinds: [...new Set(events.map(e => e.type).filter(x => x))].slice(0, 6)

    Card {
        width: parent.width; title: "Events"; icon: "event"
        Column {
            width: parent.width; spacing: Theme.space.s2
            Flow {
                width: parent.width; spacing: Theme.space.s2
                CollegeButton { text: "All"; selected: page.kind === ""; onActivated: page.kind = "" }
                Repeater { model: page.kinds; CollegeButton { required property string modelData; text: modelData; selected: page.kind === modelData; onActivated: page.kind = modelData } }
            }
            LText { visible: page.events.length === 0; color: Theme.textMuted; text: "No upcoming events (or the API couldn't be reached)." }
            Repeater {
                model: page.events.filter(e => !page.kind || e.type === page.kind).slice(0, 30)
                Row {
                    required property var modelData
                    width: parent.width; spacing: Theme.space.s3
                    Column {
                        width: 58
                        LText { role: "caption"; color: Theme.accent; font.weight: Font.DemiBold; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "MMM").toUpperCase() }
                        LText { role: "heading"; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "d") }
                    }
                    Column {
                        width: parent.width - 58 - Theme.space.s3
                        LText { width: parent.width; wrapMode: Text.Wrap; role: "bodyStrong"; text: modelData.title }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                text: [modelData.where, modelData.type, modelData.price && modelData.price !== "0" ? "₹" + modelData.price : "free"].filter(x => x).join(" · ") }
                    }
                }
            }
        }
    }

    Card {
        width: parent.width; title: "Buses"; icon: "directions_bus"
        Column {
            width: parent.width; spacing: Theme.space.s2
            LField { id: stop; width: 320; icon: "search"; placeholder: "A stop, e.g. Vadapalani"; clearOnAccept: false }
            Repeater {
                model: page.buses.filter(b => !stop.text.trim() || (b.route + " " + b.stops.join(" ")).toLowerCase().includes(stop.text.trim().toLowerCase())).slice(0, 20)
                Column {
                    required property var modelData
                    width: parent.width
                    LText { role: "bodyStrong"; text: modelData.route + (modelData.type ? " · " + modelData.type : "") }
                    LText { width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted; text: modelData.stops.join(" → ") }
                }
            }
        }
    }
}
