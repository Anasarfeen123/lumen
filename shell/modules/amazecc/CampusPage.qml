// Campus: circulars and messages from faculty, your proctor, fees and the
// library (what you owe, and a search of the catalogue with where each book
// is shelved), and the on-duty leave you've taken this semester.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

AppPage {
    id: page
    title: "Campus"
    subtitle: "Circulars, your proctor, fees, the library and ODs"
    readonly property var ex: Amazecc.extra ?? {}

    Row {
        width: parent.width
        spacing: Theme.space.s4
        readonly property real w: (width - spacing * 2) / 3
        // your proctor
        Card {
            width: parent.w
            id: proctorCard
            title: "Proctor"
            icon: "person"
            readonly property var p: page.ex.proctor
            Column {
                width: parent.width
                spacing: 3
                LText { visible: !proctorCard.p; color: Theme.textMuted; text: "After a sync" }
                LText { visible: !!proctorCard.p; width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: proctorCard.p?.name ?? "" }
                LText { visible: !!proctorCard.p?.designation; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: proctorCard.p?.designation ?? "" }
                LText { visible: !!proctorCard.p?.cabin; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: "Cabin " + (proctorCard.p?.cabin ?? "") }
                Row {
                    visible: !!proctorCard.p
                    spacing: Theme.space.s2; topPadding: Theme.space.s1
                    Pill { visible: !!proctorCard.p?.email; icon: "mail"; text: "Email"; onClicked: Qt.openUrlExternally("mailto:" + proctorCard.p.email) }
                    Pill { visible: !!proctorCard.p?.phone; icon: "content_copy"; text: "Phone"; onClicked: Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", proctorCard.p.phone]) }
                }
            }
        }
        // fees and dues
        Card {
            width: parent.w
            id: feeCard
            title: "Fees & dues"
            icon: "payments"
            readonly property var f: page.ex.fees ?? {}
            readonly property var lib: page.ex.library ?? {}
            Column {
                width: parent.width
                spacing: 3
                LText { visible: !!feeCard.f.tuitionFee; role: "bodyStrong"
                        text: "Tuition ₹" + Number(feeCard.f.tuitionFee ?? 0).toLocaleString(Qt.locale("en_IN"), "f", 0) }
                LText { visible: !!feeCard.f.dueDateWithoutLateFee; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary
                        text: "Due " + (feeCard.f.dueDateWithoutLateFee ?? "") + (feeCard.f.dueDateWithLateFee ? " (late fee till " + feeCard.f.dueDateWithLateFee + ")" : "") }
                LText { role: "caption"; color: feeCard.lib.due ? Theme.warning : Theme.textMuted
                        text: "Library: " + (feeCard.lib.due ? "₹" + feeCard.lib.due + " due" : "nothing due") }
            }
        }
        // ODs
        Card {
            width: parent.w
            id: odCard
            title: "On duty"
            icon: "badge"
            readonly property var od: page.ex.od
            Column {
                width: parent.width
                spacing: 3
                LText { text: odCard.od ? odCard.od.count + (odCard.od.count === 1 ? " OD" : " ODs") : "–"; font.pixelSize: 26; font.weight: Font.DemiBold; color: Theme.accent }
                LText { role: "caption"; color: Theme.textMuted; text: "this semester" }
                Repeater {
                    model: (odCard.od?.records ?? []).slice().reverse().slice(0, 2)
                    LText { required property var modelData; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary
                            text: modelData.date.replace(/ to .*$/, "") + " · " + (modelData.remarks || modelData.reason).replace(/[⁠•]/g, " ").replace(/\s+/g, " ") }
                }
            }
        }
    }

    // the library catalogue
    Card {
        width: parent.width
        title: "Find a book"
        icon: "local_library"
        Column {
            width: parent.width
            spacing: Theme.space.s3
            LField {
                id: q
                width: parent.width
                icon: "search"
                placeholder: "Title or author — “operating system concepts”, “silberschatz”"
                onAccepted: t => lib.search(t)
            }
            LText { visible: lib.running || lib.msg !== ""; color: Theme.textMuted; text: lib.running ? "Looking in the library…" : lib.msg }
            Repeater {
                model: lib.books
                Item {
                    required property var modelData
                    readonly property var inNow: modelData.copies.filter(c => /available/i.test(c.status))
                    width: parent.width; height: 52
                    Rectangle {
                        id: avail
                        width: 44; height: 44; radius: 10; anchors.verticalCenter: parent.verticalCenter
                        color: parent.inNow.length ? Theme.withAlpha(Theme.success, 0.15) : Theme.withAlpha(Theme.warning, 0.15)
                        Column { anchors.centerIn: parent
                                 LText { anchors.horizontalCenter: parent.horizontalCenter; role: "bodyStrong"; text: proctorCard.parent.inNow.length + "/" + proctorCard.parent.modelData.copies.length }
                                 LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; font.pixelSize: 9; color: Theme.textMuted; text: "in" } }
                    }
                    Column {
                        anchors { left: avail.right; leftMargin: Theme.space.s3; right: callNo.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: lib.pretty(modelData.title) }
                        LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                text: lib.pretty(modelData.author) + " · " + (parent.parent.inNow.length ? [...new Set(parent.parent.inNow.map(c => c.where))].slice(0, 2).join("; ")
                                                                                                        : "all out" + ((modelData.copies.find(c => c.due) ?? {}).due ? " · back by " + modelData.copies.find(c => c.due).due : "")) }
                    }
                    Pill { id: callNo; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                           visible: !!modelData.copies[0]?.call; icon: "content_copy"; text: modelData.copies[0]?.call ?? ""
                           onClicked: Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", modelData.copies[0].call]) }
                }
            }
        }
        QtObject {
            id: lib
            property var books: []
            property string msg: ""
            property bool running: libProc.running
            function pretty(t) { return (t ?? "").toLowerCase().replace(/\b\w/g, c => c.toUpperCase()); }
            function search(t) {
                if (!t.trim() || libProc.running) return;
                msg = ""; books = [];
                libProc.command = [Amazecc.script, "--api", Amazecc.cfg.api, "library"].concat(t.trim().split(/\s+/));
                libProc.running = true;
            }
        }
        Process {
            id: libProc
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {}; try { r = JSON.parse(text); } catch (e) {}
                    lib.books = (r.books ?? []).slice(0, 6);
                    lib.msg = !r.ok ? "Couldn't reach the library — is amazecc-api running?" : lib.books.length ? "" : "Nothing in the catalogue for that.";
                }
            }
        }
    }

    // circulars and messages
    Row {
        width: parent.width
        spacing: Theme.space.s4
        Card {
            width: (parent.width - parent.spacing) * 0.6
            title: "Circulars"
            icon: "campaign"
            Column {
                width: parent.width
                LText { visible: (page.ex.circulars ?? []).length === 0; color: Theme.textMuted; text: "None yet." }
                Repeater {
                    model: (page.ex.circulars ?? []).slice(0, 14)
                    Item {
                        required property var modelData
                        required property int index
                        width: parent.width; height: 40
                        Rectangle { visible: index > 0; width: parent.width; height: 1; color: Theme.border }
                        LText { id: cd; width: 60; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                                text: modelData.date ? Qt.formatDate(new Date(modelData.date), "d MMM") : "" }
                        Column {
                            anchors { left: cd.right; right: parent.right; verticalCenter: parent.verticalCenter }
                            LText { width: parent.width; elide: Text.ElideRight; text: modelData.title }
                            LText { visible: !!modelData.office; width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: modelData.office }
                        }
                    }
                }
            }
        }
        Card {
            width: (parent.width - parent.spacing) * 0.4
            title: "From your faculty"
            icon: "forum"
            Column {
                width: parent.width
                spacing: Theme.space.s2
                LText { visible: (page.ex.messages ?? []).length === 0; width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted; text: "No class messages." }
                Repeater {
                    model: (page.ex.messages ?? []).slice(0, 8)
                    Column {
                        required property var modelData
                        width: parent.width
                        LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: modelData.course ?? modelData.faculty ?? modelData.from ?? "" }
                        LText { width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary
                                text: modelData.message ?? modelData.text ?? JSON.stringify(modelData) }
                    }
                }
            }
        }
    }

    component Pill: HoverTarget {
        id: pl
        property string icon
        property string text
        width: plRow.implicitWidth + 18; height: 28; radius: 14
        Rectangle { anchors.fill: parent; radius: 14; z: -1; color: pl.containsMouse ? Theme.surfaceHover : "transparent"; border.width: 1; border.color: Theme.border }
        Row { id: plRow; anchors.centerIn: parent; spacing: 5
              LIcon { icon: pl.icon; size: 14; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: pl.text; anchors.verticalCenter: parent.verticalCenter } }
    }
}
