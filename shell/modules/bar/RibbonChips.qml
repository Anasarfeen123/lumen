// The Ribbon's inner shoulders (DESIGN.md §30): once the bar has merged, the
// glass either side of the island carries a few calm chips — only the ones
// that have something to say right now, nearest-to-the-island first:
//
//   left   now playing (art, title, play/pause) · Focus mode / timer
//   right  weather · your next event · a busy system (only when it is) · Halo
//
// They follow the island's width as it grows and shrinks, and a chip that
// wouldn't fit before the app menu / status pill simply isn't shown.
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property bool shown
    required property real leftLimit        // x where the left shoulder must stop (app menu's right edge)
    required property real rightLimit       // x where the right shoulder must stop (status pill's left edge)

    readonly property real gap: Theme.space.s3
    property real islandHalf: Island.shapeWidth / 2
    readonly property real centre: width / 2
    Behavior on islandHalf { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

    // Sysinfo samples while the Ribbon wants to know about a busy system
    Binding { target: Sysinfo; property: "ribbonActive"; value: root.shown }

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var nextEvent: {
        const now = clock.date.getTime();
        const e = (Planner.upcoming ?? []).find(e => !e.allDay && e.when > now - 5 * 60000 && e.when - now < 3 * 3600000);
        return e ?? null;
    }
    function inText(ms) {
        const m = Math.round((ms - clock.date.getTime()) / 60000);
        if (m <= 0) return "now";
        if (m < 60) return "in " + m + " min";
        return "at " + Qt.formatTime(new Date(ms), Theme.timeFormatFull);
    }

    // ── left shoulder: grows leftward from the island ──
    Shoulder {
        id: left
        rightToLeft: true
        x: root.centre - root.islandHalf - root.gap - width
        room: root.centre - root.islandHalf - root.gap - root.leftLimit - root.gap

        // On air: the mic or camera is in use (a privacy light; always first)
        Chip {
            id: onAir
            want: Meeting.onAir || Meeting.live
            onClicked: SettingsState.launch("sound")
            Rectangle {
                width: 8; height: 8; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.error
                SequentialAnimation on opacity {
                    running: onAir.fits && !Theme.reducedMotion; loops: Animation.Infinite; alwaysRunToEnd: true
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: Meeting.icon; size: 15; fill: 1; color: Theme.error }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; text: Meeting.label; color: Theme.text }
        }
        // Messages (Lumen Inbox): a call, or how many chats are waiting
        Chip {
            id: messages
            readonly property var waiting: Inbox.unreadConversations
            want: WhatsApp.enabled && WhatsApp.cfg.ribbon && (Inbox.call !== null || waiting.length > 0)
            onClicked: Inbox.call ? Inbox.focusApp(Inbox.call.provider) : Inbox.showPanel(waiting.length === 1 ? waiting[0].key : "")
            LIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Inbox.call ? (Inbox.call.video ? "videocam" : "call") : "forum"
                size: 15; fill: 1; color: Theme.accent
                SequentialAnimation on opacity {
                    running: Inbox.call !== null && !Theme.reducedMotion; loops: Animation.Infinite; alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: 600 } NumberAnimation { to: 1; duration: 600 }
                }
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                width: Math.min(implicitWidth, 170)
                elide: Text.ElideRight
                text: Inbox.call ? Inbox.call.title + " · calling"
                    : messages.waiting.length === 1 ? messages.waiting[0].title + (messages.waiting[0].unread > 1 ? " · " + messages.waiting[0].unread : "")
                    : Inbox.unreadTotal + " in " + messages.waiting.length + " chats"
            }
        }
        Chip {
            id: media
            want: Media.present
            onClicked: Island.togglePinned()
            ClippingRectangle {
                width: 18; height: 18; radius: 9
                color: Theme.surfaceHover
                anchors.verticalCenter: parent.verticalCenter
                Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(36, 36); asynchronous: true }
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                width: Math.min(implicitWidth, 190)
                elide: Text.ElideRight
                text: Media.title + (Media.artist ? "  ·  " + Media.artist : "")
                color: Media.playing ? Theme.text : Theme.textSecondary
            }
            HoverTarget {
                width: 20; height: 20
                anchors.verticalCenter: parent.verticalCenter
                onClicked: Media.active?.togglePlaying()
                LIcon { anchors.centerIn: parent; icon: Media.playing ? "pause" : "play_arrow"; size: 15; fill: 1; color: Theme.textSecondary }
            }
        }
        Chip {
            want: Focus.mode !== "off" || Countdown.active
            onClicked: Sidebar.showDetail("focus")
            LIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Focus.mode !== "off" ? Focus.current.icon : (Countdown.mode === "timer" ? "timer" : "timelapse")
                size: 15; fill: 1; color: Theme.accent
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: (Focus.mode !== "off" ? Focus.current.label : (Countdown.label || "Timer"))
                      + (Countdown.active ? "  ·  " + Countdown.display : "")
            }
        }
    }

    // ── right shoulder: grows rightward from the island ──
    Shoulder {
        id: right
        x: root.centre + root.islandHalf + root.gap
        room: root.rightLimit - root.gap - (root.centre + root.islandHalf + root.gap)

        // Time left, only when it matters: on battery and below 30 %
        Chip {
            want: Battery.forecastText !== "" && (Battery.mock || (Battery.available && !Battery.pluggedIn && Battery.percentage < 0.3))
            onClicked: SettingsState.launch("power")
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: Battery.icon; size: 15; color: Battery.forecastMin < 20 ? Theme.warning : Theme.textSecondary }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; text: Battery.forecastText + " left"; color: Battery.forecastMin < 20 ? Theme.warning : Theme.text }
        }
        Chip {
            want: Weather.ready
            onClicked: Planner.toggle()
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: Weather.icon(Weather.now?.code ?? 0, Weather.now?.isDay ?? true); size: 15; color: Theme.textSecondary }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; text: Math.round(Weather.now?.temp ?? 0) + "°" }
        }
        Chip {
            want: root.nextEvent !== null
            onClicked: Planner.toggle()
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: "event"; size: 15; color: Theme.accent }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: root.nextEvent ? root.nextEvent.title + "  ·  " + root.inText(root.nextEvent.when) : ""
            }
        }
        Chip {
            // Only when something is actually straining
            readonly property bool hot: Sysinfo.cpu > 0.8 || Sysinfo.cpuTemp > 88 || (Sysinfo.memTotal > 0 && Sysinfo.memUsed / Sysinfo.memTotal > 0.9)
            want: hot
            onClicked: SettingsState.launch("system")
            LIcon { anchors.verticalCenter: parent.verticalCenter; icon: "speed"; size: 15; color: Theme.warning }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                role: "caption"
                text: Sysinfo.cpuTemp > 88 ? Math.round(Sysinfo.cpuTemp) + "°C"
                    : Sysinfo.cpu > 0.8 ? "CPU " + Math.round(Sysinfo.cpu * 100) + "%"
                    : "Memory " + Math.round(Sysinfo.memUsed / Sysinfo.memTotal * 100) + "%"
            }
        }
        Chip {
            want: Ai.provider !== "off"
            onClicked: Ai.toggle()
            HaloRing { anchors.verticalCenter: parent.verticalCenter }
            LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; text: "Halo"; color: Theme.textSecondary }
        }
    }

    // A row of chips that shows as many as fit in `room`, in order
    component Shoulder: Row {
        id: sh
        property bool rightToLeft: false
        property real room: 0
        layoutDirection: rightToLeft ? Qt.RightToLeft : Qt.LeftToRight
        spacing: Theme.space.s2
        height: parent.height
        opacity: root.shown && room > 40 ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        // Decide which chips fit, in order
        function fit() {
            let used = 0;
            for (const c of children) {
                if (c.want === undefined) continue;
                const w = c.naturalWidth + (used > 0 ? spacing : 0);
                c.fits = c.want && used + w <= room;
                if (c.fits) used += w;
            }
        }
        onRoomChanged: Qt.callLater(fit)
        Component.onCompleted: Qt.callLater(fit)
    }

    component Chip: HoverTarget {
        id: chip
        property bool want: false
        property bool fits: false
        default property alias content: chipRow.data
        readonly property real naturalWidth: chipRow.implicitWidth + 20
        onWantChanged: Qt.callLater(parent.fit)
        onNaturalWidthChanged: Qt.callLater(parent.fit)
        visible: fits
        width: naturalWidth
        height: Theme.barHeight - 12
        anchors.verticalCenter: parent.verticalCenter
        radius: height / 2
        Rectangle { anchors.fill: parent; radius: parent.radius; z: -1; color: Theme.withAlpha(Theme.text, 0.05); border.width: 1; border.color: Theme.withAlpha(Theme.text, 0.06) }
        Row { id: chipRow; anchors.centerIn: parent; spacing: 6; height: parent.height }
        // Arrives gently when it becomes relevant
        opacity: fits ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    }

    // Halo's mark, small
    component HaloRing: Rectangle {
        width: 13; height: 13; radius: 6.5
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: Ai.busy ? 1 : 0.85
        SequentialAnimation on scale {
            running: Ai.busy && !Theme.reducedMotion; loops: Animation.Infinite; alwaysRunToEnd: true
            NumberAnimation { to: 1.15; duration: 600; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 600; easing.type: Easing.InOutSine }
        }
    }
}
