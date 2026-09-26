// Left sidebar — your day: weather, agenda, to-dos, notes (Super+Shift+A).
// Mirrors the right sidebar's glass and motion, sliding in from the left.
// Esc or clicking elsewhere closes it. Data: services/Planner, services/Weather.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Planner.open && isFocused
    readonly property int panelWidth: 380

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true }
    margins.top: Theme.edgeGap + Theme.barHeight
    implicitWidth: panelWidth + Theme.edgeGap + Theme.space.s8
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-planner"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: panel }

    HyprlandFocusGrab { active: win.showing; windows: [win]; onCleared: Planner.open = false }
    SystemClock { id: clock; precision: SystemClock.Minutes }

    component Card: Rectangle {
        id: card
        property string title: ""
        property string icon: ""
        default property alias body: inner.data
        property alias headerRight: right.data
        width: parent.width
        implicitHeight: head.height + inner.childrenRect.height + Theme.space.s3 * 2 + Theme.space.s2
        radius: Theme.radius.md
        color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
        border.width: 1; border.color: Theme.border
        Item {
            id: head
            x: Theme.space.s3; y: Theme.space.s3
            width: parent.width - Theme.space.s3 * 2; height: 24
            Row {
                spacing: Theme.space.s2
                anchors.verticalCenter: parent.verticalCenter
                LIcon { icon: card.icon; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "bodyStrong"; text: card.title; anchors.verticalCenter: parent.verticalCenter }
            }
            Row { id: right; anchors { right: parent.right; verticalCenter: parent.verticalCenter } spacing: Theme.space.s1 }
        }
        Item {
            id: inner
            x: Theme.space.s3
            anchors.top: head.bottom; anchors.topMargin: Theme.space.s2
            width: parent.width - Theme.space.s3 * 2
            height: childrenRect.height
        }
    }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: win.panelWidth
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; topMargin: Theme.edgeGap; bottomMargin: Theme.edgeGap; leftMargin: Theme.edgeGap }
        opacity: win.showing ? 1 : 0
        transform: Translate { x: win.showing ? 0 : -24; Behavior on x { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } } }
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }
        focus: win.showing
        Keys.onEscapePressed: Planner.open = false

        Column {
            id: col
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s4 }
            spacing: Theme.space.s3

            // ── Date ──
            Column {
                width: parent.width
                LText { role: "caption"; color: Theme.textMuted; text: Qt.formatDate(clock.date, "dddd").toUpperCase(); font.letterSpacing: 1.2 }
                LText { role: "title"; font.pixelSize: 24; text: Qt.formatDate(clock.date, "d MMMM") }
            }

            // ── Weather ──
            Card {
                title: Weather.place ? Weather.place.name : "Weather"
                icon: "location_on"
                headerRight: [
                    HoverTarget { visible: Weather.place !== null; width: 26; height: 26; onClicked: Weather.refresh()
                                  LIcon { anchors.centerIn: parent; icon: "refresh"; size: 16; color: Theme.textMuted } },
                    HoverTarget { visible: Weather.place !== null; width: 26; height: 26; onClicked: Weather.clearPlace()
                                  LIcon { anchors.centerIn: parent; icon: "edit_location_alt"; size: 16; color: Theme.textMuted } }
                ]
                Column {
                    width: parent.width
                    spacing: Theme.space.s2
                    // Not set yet
                    LField {
                        visible: Weather.place === null
                        width: parent.width
                        icon: "search"
                        placeholder: "Your city, e.g. “Delhi” — then weather appears here"
                        onAccepted: t => Weather.setPlace(t)
                    }
                    LText { visible: Weather.error !== ""; role: "caption"; color: Theme.error; text: Weather.error }
                    // Now
                    Row {
                        visible: Weather.ready
                        spacing: Theme.space.s3
                        LIcon { icon: Weather.icon(Weather.now?.code ?? 0, Weather.now?.isDay); size: 44; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            LText { role: "title"; font.pixelSize: 28; text: Math.round(Weather.now?.temp ?? 0) + "°" }
                            LText { role: "caption"; color: Theme.textSecondary
                                    text: Weather.describe(Weather.now?.code ?? 0) + " · feels " + Math.round(Weather.now?.feels ?? 0) + "° · wind " + Math.round(Weather.now?.wind ?? 0) + " km/h" }
                        }
                    }
                    // Next days
                    Row {
                        visible: Weather.ready
                        width: parent.width
                        Repeater {
                            model: Weather.days.slice(1, 5)
                            delegate: Column {
                                required property var modelData
                                width: parent.width / 4
                                spacing: 2
                                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted
                                        text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd") }
                                LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: Weather.icon(modelData.code, true); size: 20; color: Theme.textSecondary }
                                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"
                                        text: Math.round(modelData.max) + "° / " + Math.round(modelData.min) + "°" }
                            }
                        }
                    }
                }
            }

            // ── Agenda ──
            Card {
                title: "Agenda"
                icon: "event"
                Column {
                    width: parent.width
                    spacing: Theme.space.s1
                    Repeater {
                        model: Planner.upcoming.slice(0, 5)
                        delegate: Item {
                            required property var modelData
                            width: parent.width; height: 38
                            readonly property bool soon: !modelData.allDay && modelData.when - clock.date.getTime() < 60 * 60 * 1000
                            Rectangle { width: 3; height: 26; radius: 1.5; anchors.verticalCenter: parent.verticalCenter
                                        color: parent.soon ? Theme.accent : Theme.withAlpha(Theme.textMuted, 0.5) }
                            Column {
                                anchors { left: parent.left; leftMargin: Theme.space.s3; right: del.left; verticalCenter: parent.verticalCenter }
                                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: modelData.title }
                                LText { role: "caption"; color: parent.parent.soon ? Theme.accent : Theme.textMuted; text: Planner.whenLabel(modelData.when, modelData.allDay) }
                            }
                            HoverTarget { id: del; width: 24; height: 24; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                          onClicked: Planner.removeEvent(modelData.index)
                                          LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textMuted } }
                        }
                    }
                    LText { visible: Planner.upcoming.length === 0; role: "caption"; color: Theme.textMuted; text: "Nothing coming up." }
                    LField {
                        id: eventField
                        width: parent.width
                        icon: "add"
                        placeholder: "Add: “tomorrow 9:30 Standup”, “fri 6pm Gym”"
                        onAccepted: t => { if (!Planner.addEvent(t) && t.trim()) { eventField.text = t; hint.bad = true; } }
                    }
                    // Live preview of what will be added
                    LText {
                        id: hint
                        property bool bad: false
                        readonly property var parsed: Planner.parse(eventField.text)
                        visible: eventField.text !== ""
                        onParsedChanged: bad = false
                        role: "caption"
                        color: bad ? Theme.error : Theme.textMuted
                        text: parsed ? "→ " + parsed.title + " · " + Planner.whenLabel(parsed.when, parsed.allDay) : "Type a title (and optionally a day and time)"
                    }
                }
            }

            // ── To-do ──
            Card {
                title: "To-do"
                icon: "checklist"
                headerRight: [
                    HoverTarget { visible: Planner.todos.some(t => t.done); width: clearLbl.implicitWidth + 16; height: 24; onClicked: Planner.clearDone()
                                  LText { id: clearLbl; anchors.centerIn: parent; role: "caption"; color: Theme.textMuted; text: "Clear done" } }
                ]
                Column {
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: Planner.todos
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: parent.width; height: 32
                            HoverTarget {
                                anchors.fill: parent
                                radius: Theme.radius.sm
                                onClicked: Planner.toggleTodo(index)
                                Rectangle {
                                    id: box
                                    width: 18; height: 18; radius: 6
                                    anchors { left: parent.left; leftMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                                    color: modelData.done ? Theme.accent : "transparent"
                                    border.width: modelData.done ? 0 : 1.5; border.color: Theme.textMuted
                                    LIcon { anchors.centerIn: parent; visible: modelData.done; icon: "check"; size: 14; color: Theme.onAccent }
                                }
                                LText { anchors { left: box.right; leftMargin: Theme.space.s2; right: x.left; verticalCenter: parent.verticalCenter }
                                        elide: Text.ElideRight; text: modelData.text
                                        color: modelData.done ? Theme.textMuted : Theme.text; font.strikeout: modelData.done }
                                HoverTarget { id: x; width: 22; height: 22; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                              onClicked: Planner.removeTodo(index)
                                              LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textMuted } }
                            }
                        }
                    }
                    LField { width: parent.width; icon: "add"; placeholder: "Add a to-do"; onAccepted: t => Planner.addTodo(t) }
                }
            }
        }

        // ── Notes: whatever height is left ──
        Rectangle {
            anchors { top: col.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.space.s4; topMargin: Theme.space.s3 }
            radius: Theme.radius.md
            color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
            border.width: 1; border.color: Theme.border
            visible: height > 70
            Row {
                id: notesHead
                x: Theme.space.s3; y: Theme.space.s3
                spacing: Theme.space.s2
                LIcon { icon: "edit_note"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "bodyStrong"; text: "Notes"; anchors.verticalCenter: parent.verticalCenter }
            }
            QQC.ScrollView {
                anchors { top: notesHead.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; margins: Theme.space.s3; topMargin: Theme.space.s2 }
                QQC.TextArea {
                    text: Planner.notes
                    onTextChanged: Planner.setNotes(text)
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    placeholderText: "Jot something down…  (saved as you type)"
                    placeholderTextColor: Theme.textMuted
                    selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                    font.family: Theme.fontUi
                    font.pixelSize: 13
                    background: null
                    padding: 0
                }
            }
        }
    }
}
