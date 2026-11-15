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
            description: "Opens in the music scratchpad (Super+Shift+M). ytm-rs is the native YouTube Music app; Web is YouTube Music in your browser, signed in."
            Segmented {
                width: 340
                options: [{ id: "auto", label: "Auto" }, { id: "ytmrs", label: "ytm-rs" }, { id: "ytmusic", label: "Web" }, { id: "spotify", label: "Spotify" }]
                current: Persist.data.musicApp ?? "auto"
                onPicked: id => Persist.data.musicApp = id
            }
        }
        SetRow {
            icon: "palette"
            title: "Match Lumen's colours in ytm-rs"
            description: MusicApp.ownFile ? "Writes ytm-rs's theme.conf from your theme and wallpaper. In ytm-rs: Settings › Appearance › Accent colour › From file."
                                          : "You have a theme.conf of your own in ~/.local/share/ytm-rs — Lumen leaves it alone."
            LSwitch { checked: Persist.data.ytmTheme ?? true; onToggled: Persist.data.ytmTheme = !checked }
        }
        SetRow {
            icon: "picture_in_picture_alt"
            title: "Mini player when you hide the music app"
            description: "Hiding the music scratchpad while music plays keeps a small player on top in a corner. Also Ctrl+Super+P on the music app, or ask Halo for the mini player."
            LSwitch { checked: Persist.data.musicPip ?? true; onToggled: Persist.data.musicPip = !checked }
        }
        SetRow {
            icon: "headphones"
            title: "Music while studying"
            description: "Starting a study session plays your paused music; when the session ends, it pauses again."
            LSwitch { checked: Persist.data.studyMusic ?? true; onToggled: Persist.data.studyMusic = !checked }
        }
        SetRow {
            icon: "lyrics"
            title: "Lyrics"
            description: "In the island's now playing, from LRCLIB (lrclib.net, free, no account). Also on the mini player and the lock screen. Sends the song's title and artist only while lyrics are on screen; answers are cached."
            LSwitch { checked: Persist.data.lyrics ?? true; onToggled: Persist.data.lyrics = !checked }
        }
    }
}
