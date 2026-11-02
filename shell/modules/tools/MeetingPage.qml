import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Flickable {
    id: root
    contentHeight: content.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
    SystemClock { id: clock; precision: SystemClock.Seconds }
    Column {
        id: content; width: root.width; spacing: Theme.space.s5
        Rectangle {
            width: parent.width; height: hero.implicitHeight + Theme.space.s4 * 2
            radius: Theme.radius.md; color: Theme.surfaceElevated
            Column {
                id: hero; x: Theme.space.s4; y: Theme.space.s4; width: parent.width - Theme.space.s4 * 2; spacing: Theme.space.s2
                Row {
                    spacing: Theme.space.s2
                    LIcon { icon: Meeting.live ? "call" : "video_call"; color: Meeting.live ? Theme.success : Theme.textSecondary }
                    LText { role: "heading"; text: Meeting.live ? Meeting.label : "Ready when you are" }
                }
                LText {
                    width: parent.width; color: Theme.textSecondary; wrapMode: Text.Wrap; lineHeight: 1.45
                    text: Meeting.live && Meeting.since ? "Call time · " + Math.floor(Math.max(0, clock.date.getTime() - Meeting.since) / 60000) + " min" : "Check your devices, quiet the desktop and keep your meeting notes nearby."
                }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    ToolButton { glyph: Audio.micMuted ? "mic_off" : "mic"; label: Audio.micMuted ? "Unmute mic" : "Mute mic"; primary: !Audio.micMuted; enabled: Audio.source !== null; onClicked: Audio.toggleMicMute() }
                    ToolButton { glyph: "open_in_new"; label: "Return to call"; enabled: Meeting.meetingWindow !== null; onClicked: DesktopTools.returnToCall() }
                    ToolButton { glyph: "edit_note"; label: "Meeting notes"; onClicked: DesktopTools.meetingNotes() }
                }
            }
        }
        Column {
            width: parent.width; spacing: Theme.space.s3
            LText { role: "heading"; text: "Microphone" }
            LText { width: parent.width; text: Audio.label(Audio.source) + (Audio.micMuted ? " · muted" : " · unmuted"); color: Theme.textSecondary; wrapMode: Text.Wrap }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                ToolButton { glyph: "graphic_eq"; label: Audio.micTesting ? "Stop mic check" : "Check mic · 10 sec"; enabled: Audio.source !== null; primary: Audio.micTesting; onClicked: Audio.micTesting ? Audio.micTesting = false : Audio.testMic() }
                LText { visible: Audio.micTesting; height: Theme.space.s8 + Theme.space.s2; color: Theme.textSecondary; text: Audio.micMuted ? "Unmute to check your voice" : "Speak to see your level · nothing is saved" }
            }
            Rectangle {
                visible: Audio.micTesting
                width: parent.width; height: Theme.space.s2; radius: height / 2; color: Theme.surfaceHover
                Rectangle { width: parent.width * Audio.micLevel; height: parent.height; radius: parent.radius; color: Theme.accent }
            }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                Repeater {
                    model: Audio.sources
                    ToolButton {
                        required property var modelData
                        label: Audio.label(modelData); primary: modelData === Audio.source
                        onClicked: Audio.setSource(modelData)
                    }
                }
            }
            LText { role: "heading"; text: "Speakers" }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                Repeater {
                    model: Audio.sinks
                    ToolButton {
                        required property var modelData
                        label: Audio.label(modelData); primary: modelData === Audio.sink
                        onClicked: Audio.setSink(modelData)
                    }
                }
            }
            ToolButton { glyph: "tune"; label: "All sound settings"; onClicked: DesktopTools.soundSettings() }
        }
        Column {
            width: parent.width; spacing: Theme.space.s3
            LText { role: "heading"; text: "Desktop during a call" }
            Flow {
                width: parent.width; spacing: Theme.space.s2
                ToolButton { glyph: "notifications_off"; label: Notifications.dnd ? "Notifications held" : "Hold notifications"; primary: Notifications.dnd; onClicked: Notifications.setDnd(!Notifications.dnd) }
                ToolButton { glyph: "coffee"; label: Caffeine.on ? "Keeping awake" : "Keep awake"; primary: Caffeine.on; onClicked: Caffeine.toggle() }
                ToolButton { glyph: "photo_camera_front"; label: "Camera preview"; onClicked: DesktopTools.cameraPreview() }
            }
            LText { width: parent.width; color: Theme.textSecondary; wrapMode: Text.Wrap; lineHeight: 1.45
                    text: (Meeting.cameraOn ? "Camera in use" : "No camera activity detected") + " · " + (Meeting.micOn ? "Microphone in use" : "No microphone activity detected") + "\n" + (HaloExtras.sharing ? "A screen capture is active. Manage sharing in your meeting app." : "No active screen capture reported.") }
            LText { width: parent.width; role: "caption"; color: Theme.textMuted; wrapMode: Text.Wrap; lineHeight: 1.45
                    text: "Mute controls the system microphone. Camera and sharing controls stay in your meeting app. Camera preview opens only when you request it." }
        }
    }
}
