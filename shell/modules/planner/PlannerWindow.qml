// Left sidebar — your day: weather, agenda, to-dos, notes (Super+Shift+A).
// Mirrors the right sidebar's glass and motion, sliding in from the left.
// Esc or clicking elsewhere closes it. Data: services/Planner, services/Weather.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Io
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
        // Scroll with the keyboard too (a text field keeps its own keys)
        Keys.onPressed: e => {
            const page = flick.height * 0.85;
            if (e.key === Qt.Key_PageDown) flick.scrollTo(flick.contentY + page);
            else if (e.key === Qt.Key_PageUp) flick.scrollTo(flick.contentY - page);
            else if (e.key === Qt.Key_Home) flick.scrollTo(0);
            else if (e.key === Qt.Key_End) flick.scrollTo(flick.contentHeight);
            else return;
            e.accepted = true;
        }
        // Opening starts at the top: your day at a glance
        Connections { target: win; function onShowingChanged() { if (win.showing) { flick.cancelFlick(); flick.contentY = 0; } } }

        // ── Date (stays put while the rest scrolls) ──
        Column {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s4 }
            LText { role: "caption"; color: Theme.textMuted; text: Qt.formatDate(clock.date, "dddd").toUpperCase(); font.letterSpacing: 1.2 }
            LText { role: "title"; font.pixelSize: 24; text: Qt.formatDate(clock.date, "d MMMM") }
        }
        // A hairline under the date once the cards have scrolled beneath it
        Rectangle {
            anchors { top: flick.top; left: parent.left; right: parent.right; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
            height: 1; z: 2
            color: Theme.border
            opacity: flick.contentY > 2 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
        }

        Flickable {
            id: flick
            anchors { top: header.bottom; topMargin: Theme.space.s3; bottom: parent.bottom; left: parent.left; right: parent.right }
            clip: true
            contentWidth: width
            contentHeight: col.height + Theme.space.s4
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            maximumFlickVelocity: 3200
            Behavior on contentY { enabled: flick.animating; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutCubic } }
            property bool animating: false
            function scrollTo(y) {
                animating = true;
                contentY = Math.max(0, Math.min(y, contentHeight - height));
                settle.restart();
            }
            Timer { id: settle; interval: Theme.motion.normal + 20; onTriggered: flick.animating = false }
            // Keep a spot (a field you're typing in) on screen
            function ensureVisible(item, y, h) {
                const p = item.mapToItem(col, 0, y);
                const pad = Theme.space.s3;
                if (p.y - pad < contentY) contentY = Math.max(0, p.y - pad);
                else if (p.y + h + pad > contentY + height) contentY = Math.min(contentHeight - height, p.y + h + pad - height);
            }

            QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: bar
                policy: flick.contentHeight > flick.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff
                width: 10
                padding: 2
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: width / 2
                    color: Theme.withAlpha(Theme.text, bar.pressed ? 0.42 : bar.hovered ? 0.3 : 0.18)
                    opacity: bar.active || bar.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                }
                background: null
            }

        Column {
            id: col
            x: Theme.space.s4
            width: flick.width - Theme.space.s4 * 2
            spacing: Theme.space.s3

            // ── Classes (AmazeCC: today's timetable, attendance that needs care) ──
            Card {
                id: classes
                visible: Amazecc.cfg.enabled
                title: Amazecc.todayInfo?.order ? "Classes · " + Amazecc.dayNames[Amazecc.todayInfo.order] + " order" : "Classes"
                icon: "school"
                readonly property string ago: {
                    const m = Math.round((clock.date.getTime() - Amazecc.updated) / 60000);
                    return !Amazecc.updated ? "" : m < 1 ? "just now" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Math.round(m / 1440) + " d ago";
                }
                headerRight: [
                    LText { visible: Amazecc.ready; role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                            text: Amazecc.syncing ? "Syncing…" : classes.ago },
                    HoverTarget { visible: Amazecc.hasLogin; width: 26; height: 26; onClicked: Amazecc.sync(true)
                                  LIcon { id: syncIcon; anchors.centerIn: parent; icon: "sync"; size: 16; color: Theme.textMuted
                                          RotationAnimation on rotation { running: Amazecc.syncing; loops: Animation.Infinite; from: 360; to: 0; duration: 1100 } } }
                ]
                Column {
                    width: parent.width
                    spacing: Theme.space.s1

                    // Not connected yet
                    HoverTarget {
                        visible: !Amazecc.hasLogin && !Amazecc.ready
                        width: parent.width; height: 36; radius: Theme.radius.sm
                        onClicked: { Planner.open = false; SettingsState.launch("amazecc"); }
                        Row {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s2
                            LIcon { icon: "link"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "bodyStrong"; text: "Connect VTOP"; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; color: Theme.textMuted; text: "timetable, attendance, marks"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        LIcon { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                icon: "chevron_right"; size: 16; color: Theme.textMuted }
                    }
                    LText { visible: Amazecc.hasLogin && !Amazecc.ready && Amazecc.error === ""; role: "caption"; color: Theme.textMuted
                            text: Amazecc.syncing ? "Fetching your timetable from VTOP… (about half a minute)" : "Not synced yet" }

                    // A holiday
                    LText { visible: Amazecc.ready && Amazecc.todayInfo?.kind === "holiday"; width: parent.width; wrapMode: Text.Wrap
                            role: "caption"; color: Theme.textSecondary
                            text: "No classes today" + (Amazecc.todayInfo?.text ? " — " + Amazecc.todayInfo.text : "") }

                    // Today's classes
                    Repeater {
                        model: Amazecc.today.slice(0, 7)
                        delegate: Item {
                            id: row
                            required property var modelData
                            readonly property bool now: Amazecc.isCurrent(modelData)
                            readonly property bool past: modelData.end <= Amazecc.nowMin
                            width: parent.width; height: 34
                            opacity: past ? 0.45 : 1
                            Rectangle { width: 3; height: 24; radius: 1.5; anchors.verticalCenter: parent.verticalCenter
                                        color: row.now ? Theme.accent : Theme.withAlpha(Theme.textMuted, 0.5) }
                            LText { id: at; x: Theme.space.s3; width: 58; anchors.verticalCenter: parent.verticalCenter
                                    role: "caption"; color: row.now ? Theme.accent : Theme.textSecondary
                                    font.features: { "tnum": 1 }
                                    text: Amazecc.clockLabel(modelData.start) }
                            Column {
                                anchors { left: at.right; leftMargin: Theme.space.s1; right: parent.right; verticalCenter: parent.verticalCenter }
                                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: modelData.title }
                                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                                        text: [modelData.venue, modelData.kind === "lab" ? "Lab" : "", row.now ? "till " + Amazecc.clockLabel(modelData.end) : ""].filter(x => x).join(" · ") }
                            }
                        }
                    }
                    // Done for the day
                    LText {
                        visible: Amazecc.ready && !Amazecc.next && !Amazecc.current && Amazecc.todayInfo?.kind !== "holiday"
                        width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
                        text: (Amazecc.today.length ? "Done for today." : "No classes today.")
                              + (Amazecc.nextDay ? " " + Planner.whenLabel(Amazecc.nextDay.date.getTime() + Amazecc.nextDay.first.start * 60000, false) + " · " + Amazecc.nextDay.first.title : "")
                    }

                    // Attendance that needs care
                    Repeater {
                        model: Amazecc.attention.slice(0, 3)
                        delegate: Row {
                            required property var modelData
                            readonly property string tone: Amazecc.attendanceTone(modelData)
                            width: parent.width; height: 22; spacing: Theme.space.s2
                            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: parent.tone === "error" ? "error" : "warning"; size: 14
                                    color: parent.tone === "error" ? Theme.error : Theme.warning }
                            LText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 22; elide: Text.ElideRight; role: "caption"
                                    text: modelData.title + " · " + modelData.pct + "% · "
                                          + (modelData.pct < Amazecc.cfg.threshold ? "attend the next " + Amazecc.needed(modelData)
                                             : Amazecc.skippable(modelData) === 0 ? "don't miss the next one" : "can miss " + Amazecc.skippable(modelData)) }
                        }
                    }
                    LText { visible: Amazecc.error !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.error; text: Amazecc.error }
                }
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
                                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: parent.parent.soon ? Theme.accent : Theme.textMuted
                                        text: Planner.whenLabel(modelData.when, modelData.allDay) + (modelData.detail ? " · " + modelData.detail : "") }
                            }
                            // From AmazeCC (VTOP): read-only here
                            LIcon { visible: !!modelData.external; anchors { right: parent.right; rightMargin: 5; verticalCenter: parent.verticalCenter }
                                    icon: "school"; size: 14; color: Theme.textMuted }
                            HoverTarget { id: del; visible: !modelData.external; width: 24; height: 24; anchors { right: parent.right; verticalCenter: parent.verticalCenter }
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

            // ── Your week: screen time & focus (services/ScreenTime, this machine only) ──
            Card {
                id: weekCard
                title: "Your week"
                icon: "insights"
                property bool menu: false
                property bool confirmClear: false
                readonly property var w: ScreenTime.week
                readonly property var todayData: ScreenTime.days.length ? ScreenTime.days[ScreenTime.days.length - 1] : null
                headerRight: [
                    LText { visible: ScreenTime.enabled && weekCard.todayData !== null; role: "caption"; color: Theme.textMuted
                            text: ScreenTime.fmt(weekCard.todayData?.total ?? 0) + " today" + (weekCard.w.avg > 0 ? " · avg " + ScreenTime.fmt(weekCard.w.avg) : "")
                            anchors.verticalCenter: parent.verticalCenter },
                    HoverTarget { width: 24; height: 24; onClicked: { weekCard.menu = !weekCard.menu; weekCard.confirmClear = false; }
                                  LIcon { anchors.centerIn: parent; icon: "more_horiz"; size: 16; color: Theme.textMuted } }
                ]
                Column {
                    width: parent.width
                    spacing: Theme.space.s2

                    // Settings, behind ⋯
                    Row {
                        visible: weekCard.menu
                        spacing: Theme.space.s2
                        HoverTarget {
                            width: recRow.implicitWidth + 18; height: 26; radius: 13
                            onClicked: Persist.data.screenTime = !ScreenTime.enabled
                            Rectangle { anchors.fill: parent; radius: 13; z: -1; color: "transparent"; border.width: 1; border.color: Theme.border }
                            Row { id: recRow; anchors.centerIn: parent; spacing: 5
                                  LIcon { icon: ScreenTime.enabled ? "pause_circle" : "play_circle"; size: 14; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                  LText { role: "caption"; text: ScreenTime.enabled ? "Stop recording" : "Record screen time"; anchors.verticalCenter: parent.verticalCenter } }
                        }
                        HoverTarget {
                            width: clrRow.implicitWidth + 18; height: 26; radius: 13
                            onClicked: { if (weekCard.confirmClear) { ScreenTime.clearHistory(); weekCard.confirmClear = false; weekCard.menu = false; } else weekCard.confirmClear = true; }
                            Rectangle { anchors.fill: parent; radius: 13; z: -1; color: weekCard.confirmClear ? Theme.withAlpha(Theme.error, 0.14) : "transparent"; border.width: 1; border.color: weekCard.confirmClear ? Theme.withAlpha(Theme.error, 0.4) : Theme.border }
                            Row { id: clrRow; anchors.centerIn: parent; spacing: 5
                                  LIcon { icon: "delete"; size: 14; color: weekCard.confirmClear ? Theme.error : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                  LText { role: "caption"; color: weekCard.confirmClear ? Theme.error : Theme.text; text: weekCard.confirmClear ? "Press again to clear" : "Clear history"; anchors.verticalCenter: parent.verticalCenter } }
                        }
                    }
                    LText {
                        visible: weekCard.menu
                        width: parent.width; wrapMode: Text.Wrap
                        role: "caption"; color: Theme.textMuted
                        text: "Which app is in front, counted while you're active. Stored only on this computer (~/.local/state/lumen/screentime), kept 60 days."
                    }

                    LText {
                        visible: !ScreenTime.enabled && !weekCard.menu
                        role: "caption"; color: Theme.textMuted
                        text: "Screen time is off. ⋯ to turn it on."
                    }

                    // 7 small bars, today accented; the focused part of each day is brighter
                    Row {
                        id: bars
                        visible: ScreenTime.enabled && ScreenTime.days.length > 0
                        width: parent.width
                        height: 58
                        readonly property real peak: Math.max(3600, ...ScreenTime.days.map(d => d.total))
                        Repeater {
                            model: ScreenTime.days
                            delegate: Item {
                                required property var modelData
                                required property int index
                                readonly property bool isToday: index === ScreenTime.days.length - 1
                                width: bars.width / 7; height: bars.height
                                Rectangle {
                                    id: bar
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: dayLbl.top; bottomMargin: 4 }
                                    width: 14; radius: 4
                                    height: Math.max(3, (parent.height - 18) * modelData.total / bars.peak)
                                    color: parent.isToday ? Theme.withAlpha(Theme.accent, 0.35) : Theme.withAlpha(Theme.text, 0.10)
                                    Behavior on height { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                                    Rectangle {   // focused time
                                        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
                                        width: parent.width; radius: 4
                                        height: modelData.total > 0 ? parent.height * Math.min(1, modelData.focus / modelData.total) : 0
                                        color: parent.parent.isToday ? Theme.accent : Theme.withAlpha(Theme.text, 0.28)
                                    }
                                }
                                LText {
                                    id: dayLbl
                                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom }
                                    role: "caption"; font.pixelSize: 10
                                    color: parent.isToday ? Theme.accent : Theme.textMuted
                                    text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd").charAt(0)
                                }
                            }
                        }
                    }

                    // Top apps this week
                    Row {
                        visible: ScreenTime.enabled && weekCard.w.top.length > 0
                        width: parent.width
                        Repeater {
                            model: weekCard.w.top
                            delegate: Column {
                                required property var modelData
                                width: parent.width / 5
                                spacing: 3
                                Image {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 22; height: 22
                                    sourceSize: Qt.size(44, 44)
                                    source: ScreenTime.iconOf(modelData.id)
                                    asynchronous: true
                                }
                                LText { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, parent.width - 4); elide: Text.ElideRight
                                        role: "caption"; font.pixelSize: 10; color: Theme.textSecondary; text: ScreenTime.nameOf(modelData.id) }
                                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; font.pixelSize: 10; color: Theme.textMuted; text: ScreenTime.fmt(modelData.secs) }
                            }
                        }
                    }

                    // Focus
                    Flow {
                        visible: ScreenTime.enabled && weekCard.w.total > 0
                        width: parent.width
                        spacing: Theme.space.s3
                        Row { spacing: 4
                              LIcon { icon: "self_improvement"; size: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                              LText { role: "caption"; color: Theme.textSecondary; text: ScreenTime.fmt(weekCard.w.focus) + " focused"; anchors.verticalCenter: parent.verticalCenter } }
                        Row { spacing: 4
                              LIcon { icon: "timer"; size: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                              LText { role: "caption"; color: Theme.textSecondary; text: weekCard.w.rounds + (weekCard.w.rounds === 1 ? " Pomodoro round" : " Pomodoro rounds"); anchors.verticalCenter: parent.verticalCenter } }
                        LText { role: "caption"; color: Theme.textMuted; text: ScreenTime.fmt(weekCard.w.total) + " this week" }
                    }
                    LText {
                        visible: ScreenTime.enabled && weekCard.w.total === 0 && ScreenTime.days.length > 0
                        role: "caption"; color: Theme.textMuted
                        text: "Nothing recorded yet — it fills in as you work."
                    }
                }
            }

            // ── Notes: at least a comfortable box, the rest of the panel when
            //    there's room, and as long as what you've written ──
            Rectangle {
                id: notesCard
                width: parent.width
                readonly property real minH: 180
                // `y` doesn't depend on this height, so no binding loop
                height: Math.max(minH, flick.height - y - Theme.space.s4,
                                 notesHead.height + notesArea.implicitHeight + Theme.space.s3 * 2 + Theme.space.s2)
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
                border.width: 1; border.color: notesArea.activeFocus ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
                Row {
                    id: notesHead
                    x: Theme.space.s3; y: Theme.space.s3
                    height: 24
                    spacing: Theme.space.s2
                    LIcon { icon: "edit_note"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "bodyStrong"; text: "Notes"; anchors.verticalCenter: parent.verticalCenter }
                }
                LText {
                    anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: notesHead.verticalCenter }
                    visible: Planner.notes.length > 0
                    role: "caption"; color: Theme.textMuted
                    text: { const w = Planner.notes.trim().split(/\s+/).filter(x => x).length; return w + (w === 1 ? " word" : " words"); }
                }
                // Clicking anywhere in the box starts typing
                MouseArea {
                    anchors { top: notesHead.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }
                    cursorShape: Qt.IBeamShape
                    onClicked: { notesArea.forceActiveFocus(); notesArea.cursorPosition = notesArea.length; }
                }
                QQC.TextArea {
                    id: notesArea
                    anchors { top: notesHead.bottom; left: parent.left; right: parent.right; margins: Theme.space.s3; topMargin: Theme.space.s2 }
                    text: Planner.notes
                    onTextChanged: Planner.setNotes(text)
                    onCursorRectangleChanged: if (activeFocus) flick.ensureVisible(notesArea, cursorRectangle.y, cursorRectangle.height)
                    onActiveFocusChanged: if (activeFocus) flick.ensureVisible(notesArea, cursorRectangle.y, cursorRectangle.height)
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
}
