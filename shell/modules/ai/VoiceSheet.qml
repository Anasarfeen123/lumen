// Talking with Halo (services/Converse.qml): a glass sheet rises from the
// bottom of the focused screen over a soft aurora of the accent's colours that
// swells with your voice and moves with Halo's words. What you said is large;
// Halo's answer under it, with what you can do about it. Suggestions to start,
// "Type instead" when speaking isn't handy.
//   Esc closes · Space talks again · Enter sends what you typed
import QtQuick
import QtQuick.Effects
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
    readonly property bool isFocused: Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Converse.open && isFocused
    property bool typing: false

    visible: showing || rise > 0.01
    anchors { left: true; right: true; bottom: true }
    implicitHeight: Math.min(screen?.height ?? 800, 620)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-voice"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: showing ? sheet : null }

    // arriving: a spring up from below; leaving: down and away
    property real rise: showing ? 1 : 0
    Behavior on rise { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? 520 : 240); easing.type: win.showing ? Easing.OutBack : Easing.InCubic; easing.overshoot: 0.9 } }
    onShowingChanged: { typing = !Voice.canListen; if (showing) { field.text = ""; Qt.callLater(() => (typing ? field : keys).forceActiveFocus()); } }

    // what the aurora follows: your voice, Halo's words, or a slow swirl while thinking
    readonly property real energy: Voice.listening ? 0.25 + Math.min(1, Voice.level) * 0.9
        : Voice.speaking ? 0.3 + Math.max(0, Voice.mouth) * 0.7
        : (Converse.last?.state === "thinking" || Ai.busy || Agent.running) ? 0.45 : 0.15
    property real smoothEnergy: energy
    Behavior on smoothEnergy { NumberAnimation { duration: 140 } }

    // ── the aurora along the bottom edge ──
    Item {
        id: aurora
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 260
        opacity: win.rise * (0.55 + win.smoothEnergy * 0.45)
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 64; saturation: 0.2 }
        property real t: 0
        NumberAnimation on t { from: 0; to: Math.PI * 2; duration: (Converse.last?.state === "thinking" || Ai.busy) ? 2600 : 7000; loops: Animation.Infinite; running: win.visible && !Theme.reducedMotion }
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property real phase: index * Math.PI / 2
                // the accent, its neighbours either side, and a quiet complement
                readonly property real hueShift: [0, 0.06, -0.06, 0.5][index]
                width: aurora.width * 0.42; height: 150 + win.smoothEnergy * 140
                radius: height / 2
                x: aurora.width * (0.12 + 0.24 * index) - width / 2 + Math.sin(aurora.t + phase) * aurora.width * 0.06
                y: aurora.height - height * 0.62 + Math.cos(aurora.t * 1.3 + phase) * 14
                color: Qt.hsla(((Theme.accent.hslHue < 0 ? 0.5 : Theme.accent.hslHue) + hueShift + 1) % 1, index === 3 ? 0.55 : 0.8, 0.58, index === 3 ? 0.5 : 0.8)
            }
        }
    }

    // ── the sheet ──
    Rectangle {
        id: sheet
        width: Math.min(760, win.width - 48)
        height: col.implicitHeight + Theme.space.s5 * 2
        anchors.horizontalCenter: parent.horizontalCenter
        y: win.height - height - 28 + (1 - win.rise) * (height + 60)
        radius: Theme.radius.lg + 6
        color: Theme.withAlpha(Qt.tint(Theme.surface, Theme.withAlpha(Theme.bg, 0.35)), 0.92)
        border.width: 1; border.color: Theme.withAlpha(Theme.text, 0.1)
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1; shadowOpacity: 0.4; shadowVerticalOffset: 10; shadowHorizontalOffset: 0 }
        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

        Column {
            id: col
            x: Theme.space.s5; y: Theme.space.s5
            width: parent.width - Theme.space.s5 * 2
            spacing: Theme.space.s4

            // earlier turns, dimmed
            Repeater {
                model: Converse.turns.slice(Math.max(0, Converse.turns.length - 3), -1)
                Column {
                    required property var modelData
                    width: col.width
                    spacing: 2
                    opacity: 0.45
                    LText { visible: !!modelData.you; width: parent.width; role: "body"; color: Theme.textSecondary; text: modelData.you; elide: Text.ElideRight; textFormat: Text.PlainText }
                    LText { visible: !!modelData.answer; width: parent.width; role: "caption"; color: Theme.textMuted; text: modelData.answer; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText }
                }
            }

            // what you said — big, as it arrives
            LText {
                id: said
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: 26; font.weight: Font.DemiBold
                color: Converse.last?.you ? Theme.text : Theme.textMuted
                text: Voice.listening ? (Voice.heardSpeech ? "Listening…" : (Converse.followUp ? "Anything else?" : "Hi" + (Halo.you ? " " + Halo.you : "") + ", what can I do?"))
                    : Voice.transcribing ? "…"
                    : Converse.last?.you ? Converse.last.you
                    : !Voice.canListen ? "Type to " + Halo.name : "Tap the ring and talk"
                onTextChanged: if (!Theme.reducedMotion) { saidIn.restart(); }
                opacity: 1
                transform: Translate { id: saidT; y: 0 }
                ParallelAnimation {
                    id: saidIn
                    NumberAnimation { target: said; property: "opacity"; from: 0.2; to: 1; duration: 260 }
                    NumberAnimation { target: saidT; property: "y"; from: 8; to: 0; duration: 320; easing.type: Easing.OutCubic }
                }
            }

            // Halo's answer
            Column {
                visible: !!Converse.last && (Converse.last.state === "thinking" || !!Converse.last.answer)
                width: parent.width
                spacing: Theme.space.s3
                // thinking: three dots that breathe in turn
                Row {
                    visible: Converse.last?.state === "thinking" && !(Ai.busy && Ai.streamText)
                    spacing: 7
                    Repeater {
                        model: 3
                        Rectangle {
                            required property int index
                            width: 9; height: 9; radius: 4.5; color: Theme.accent
                            SequentialAnimation on opacity { running: win.visible && !Theme.reducedMotion; loops: Animation.Infinite
                                PauseAnimation { duration: index * 160 } NumberAnimation { to: 0.25; duration: 360 } NumberAnimation { to: 1; duration: 360 } PauseAnimation { duration: (2 - index) * 160 } }
                        }
                    }
                }
                LText {
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.Wrap; textFormat: Text.PlainText
                    font.pixelSize: 17
                    color: Theme.textSecondary
                    text: Converse.last?.state === "thinking" && Ai.busy ? Voice.speakable(Ai.streamText) || Ai.streamText
                        : (Converse.last?.card ? (Converse.last.card.text || "") : (Converse.last?.answer ?? ""))
                    maximumLineCount: 8; elide: Text.ElideRight
                }
                // a card's title as the headline (when Halo did something)
                Row {
                    visible: !!Converse.last?.card
                    spacing: 8
                    Rectangle {
                        width: 30; height: 30; radius: 10
                        color: Theme.withAlpha(Converse.last?.card?.tone === "concerned" ? Theme.warning : Theme.accent, 0.16)
                        LIcon { anchors.centerIn: parent; icon: Converse.last?.card?.icon ?? "auto_awesome"; size: 17; fill: 1
                                color: Converse.last?.card?.tone === "concerned" ? Theme.warning : Theme.accent }
                    }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; text: Converse.last?.card?.title ?? ""; textFormat: Text.PlainText }
                }
                Flow {
                    visible: (Converse.last?.card?.actions ?? []).length > 0
                    width: parent.width; spacing: 6
                    Repeater {
                        model: (Converse.last?.card?.actions ?? []).filter(a => a)
                        Chip { required property var modelData; required property int index; primary: index === 0; icon: modelData.icon ?? ""; text: modelData.label; onClicked: modelData.run?.() }
                    }
                }
            }

            // to start with
            Flow {
                visible: Converse.turns.length === 0
                width: parent.width; spacing: 8
                Repeater {
                    model: [HaloCollege.on && Amazecc.next ? "What's my next class?" : "What's the weather?", "What did I miss?", "Remind me in 20 minutes to stretch",
                            "Play something for studying", "How's my computer?", HaloCollege.on ? "Can I skip tomorrow?" : "Tidy my downloads"]
                    Chip { required property string modelData; icon: "chat_bubble"; text: modelData; onClicked: Converse.say(modelData) }
                }
            }

            // typing instead
            Rectangle {
                visible: win.typing
                width: parent.width; height: 46; radius: 23
                color: Theme.withAlpha(Theme.text, 0.06)
                border.width: 1; border.color: field.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                QQC.TextField {
                    id: field
                    anchors { left: parent.left; leftMargin: 18; right: parent.right; rightMargin: 18; verticalCenter: parent.verticalCenter }
                    background: null; color: Theme.text
                    placeholderText: "Type to " + Halo.name + "…"; placeholderTextColor: Theme.textMuted
                    font.family: Theme.fontUi; font.pixelSize: 15
                    onAccepted: { if (text.trim()) Converse.say(text); text = ""; }
                    Keys.onEscapePressed: Converse.close()
                }
            }

            // the ring, and what you can do
            Item {
                width: parent.width; height: 64
                Chip { anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                       icon: win.typing ? "mic" : "keyboard"; text: win.typing ? (Voice.canListen ? "Talk instead" : "Voice needs whisper.cpp") : "Type instead"
                       onClicked: { if (win.typing && Voice.canListen) { win.typing = false; Converse.show(); keys.forceActiveFocus(); } else if (!win.typing) { win.typing = true; Voice.cancel(); field.forceActiveFocus(); } else SettingsState.launch("ai"); } }
                HaloOrb {
                    id: orb
                    anchors.centerIn: parent
                    size: 56
                    mood: Halo.mood
                    level: Voice.level
                    mouth: Voice.mouth
                    face: Persist.data.haloFace ?? true
                    accessory: HaloExtras.accessory
                    Component.onCompleted: pop()
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: Voice.listening ? Voice.stopListening() : Voice.speaking ? Voice.stop() : Converse.show() }
                }
                LText { anchors { left: orb.right; leftMargin: 14; verticalCenter: parent.verticalCenter } role: "caption"; color: Theme.textMuted
                        text: Voice.listening ? "I'll stop when you pause" : Voice.speaking ? "Tap to stop" : Voice.canListen ? "Tap to talk" : "" }
                Chip { anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "close"; text: "Done"; onClicked: Converse.close() }
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { Converse.close(); e.accepted = true; }
            else if (e.key === Qt.Key_Space && !win.typing) { if (Voice.listening) Voice.stopListening(); else if (Voice.speaking) Voice.stop(); else Converse.show(); e.accepted = true; }
            else if (e.text && e.text.trim() && !win.typing) { win.typing = true; Voice.cancel(); field.text = e.text; field.forceActiveFocus(); e.accepted = true; }
        }
    }

    component Chip: HoverTarget {
        id: ch
        property string icon
        property string text
        property bool primary: false
        width: chRow.implicitWidth + 26; height: 34
        scale: pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                    color: ch.primary ? Theme.withAlpha(Theme.accent, 0.2) : Theme.withAlpha(Theme.text, ch.containsMouse ? 0.1 : 0.06)
                    border.width: 1; border.color: ch.primary ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border }
        Row { id: chRow; anchors.centerIn: parent; spacing: 7
              LIcon { visible: ch.icon !== ""; icon: ch.icon; size: 16; color: ch.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "body"; text: ch.text; color: ch.primary ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }
}
