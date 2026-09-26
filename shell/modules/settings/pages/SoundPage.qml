// Sound: output + input devices, volume, microphone.
import QtQuick
import Quickshell.Services.Pipewire
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Sound"

    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)

    Group {
        title: "Output"
        SetRow {
            icon: Audio.muted ? "volume_off" : "volume_up"
            title: "Volume"
            description: Audio.muted ? "Muted" : Math.round(Audio.volume * 100) + "%"
            Row {
                spacing: Theme.space.s2
                LSlider { width: 240; icon: "volume_up"; value: Audio.volume; dimmed: Audio.muted; onMoved: v => Audio.nudge(v - Audio.volume) }
                IconButton { icon: Audio.muted ? "volume_off" : "volume_mute"; onActivated: Audio.toggleMute() }
            }
        }
        Repeater {
            model: Audio.sinks
            delegate: SetRow {
                required property var modelData
                icon: /headphone|headset/i.test(Audio.label(modelData)) ? "headphones" : /hdmi|displayport/i.test(Audio.label(modelData)) ? "tv" : "speaker"
                title: Audio.label(modelData)
                LIcon {
                    icon: Audio.sink === modelData ? "radio_button_checked" : "radio_button_unchecked"
                    fill: Audio.sink === modelData ? 1 : 0
                    color: Audio.sink === modelData ? Theme.accent : Theme.textMuted
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Audio.setSink(modelData) }
                }
            }
        }
    }

    Group {
        title: "Input"
        SetRow {
            icon: Audio.micMuted ? "mic_off" : "mic"
            title: "Microphone"
            description: Audio.micMuted ? "Muted — Super+Alt+M" : "On — Super+Alt+M to mute"
            LSwitch { checked: !Audio.micMuted; onToggled: Audio.toggleMicMute() }
        }
        Repeater {
            model: sources
            delegate: SetRow {
                required property var modelData
                icon: "mic_external_on"
                title: Audio.label(modelData)
                LIcon {
                    icon: Audio.source === modelData ? "radio_button_checked" : "radio_button_unchecked"
                    fill: Audio.source === modelData ? 1 : 0
                    color: Audio.source === modelData ? Theme.accent : Theme.textMuted
                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: Pipewire.preferredDefaultAudioSource = modelData }
                }
            }
        }
    }

    Group {
        title: "Music"
        SetRow {
            icon: "queue_music"
            title: "Music app"
            description: "Opens in the music scratchpad (Super+Shift+M). YouTube Music runs as a web app in your browser, signed in."
            Segmented {
                width: 330
                options: [{ id: "auto", label: "Auto" }, { id: "ytmusic", label: "YouTube Music" }, { id: "spotify", label: "Spotify" }]
                current: Persist.data.musicApp ?? "auto"
                onPicked: id => Persist.data.musicApp = id
            }
        }
        SetRow {
            icon: "lyrics"
            title: "Lyrics"
            description: "In the island's now playing, from LRCLIB (lrclib.net, free, no account). Sends the song's title and artist, only while you have the island open; answers are cached."
            LSwitch { checked: Persist.data.lyrics ?? true; onToggled: Persist.data.lyrics = !checked }
        }
    }
}
