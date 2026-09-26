// Lumen AI panel (Super+Shift+Space): drops from under the island.
//   context chips   Selection (your highlighted text, if any) · Screen (attach a screenshot)
//   quick actions   Explain · Summarize · Fix writing · What's on my screen?
//   transcript      Markdown answers, streamed; copy any answer
//   Enter sends · Shift+Enter new line · Esc closes · Ctrl+L clears
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
    readonly property bool showing: Ai.open && isFocused

    visible: showing || panel.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-ai"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: showing ? catcher : null }

    onShowingChanged: if (showing) Qt.callLater(() => prompt.forceActiveFocus())

    // Click outside the panel closes it
    MouseArea { id: catcher; anchors.fill: parent; onClicked: Ai.open = false }

    GlassSurface {
        id: panel
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(720, win.width - 64)
        height: Math.min(content.implicitHeight + Theme.space.s4 * 2, win.height * 0.78)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.edgeGap + Theme.barHeight + Theme.space.s3
        transformOrigin: Item.Top
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.normal : Theme.motion.micro) } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.45) }
        MouseArea { anchors.fill: parent }       // swallow clicks so they don't reach the catcher

        Column {
            id: content
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3

            // ── Header ──
            Item {
                width: parent.width; height: 28
                Row {
                    spacing: Theme.space.s2
                    anchors.verticalCenter: parent.verticalCenter
                    LIcon { icon: "auto_awesome"; size: 20; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "heading"; text: "Ask Lumen"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                        visible: Ai.provider !== "off"
                        anchors.verticalCenter: parent.verticalCenter
                        height: 20; width: modelLbl.implicitWidth + 14; radius: 10
                        color: Theme.withAlpha(Theme.text, 0.06); border.width: 1; border.color: Theme.border
                        LText { id: modelLbl; anchors.centerIn: parent; role: "caption"; color: Theme.textMuted
                                text: (Ai.provider === "ollama" ? "Local · " : "") + Ai.model }
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    HoverTarget { visible: Ai.messages.length > 0; width: 28; height: 28; onClicked: Ai.clear()
                                  LIcon { anchors.centerIn: parent; icon: "delete_sweep"; size: 18; color: Theme.textMuted } }
                    HoverTarget { width: 28; height: 28; onClicked: { Ai.open = false; SettingsState.launch("ai"); }
                                  LIcon { anchors.centerIn: parent; icon: "settings"; size: 18; color: Theme.textMuted } }
                }
            }

            // ── Not set up ──
            Rectangle {
                visible: !Ai.configured
                width: parent.width
                height: setupCol.implicitHeight + Theme.space.s4 * 2
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.accent, 0.08)
                border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.3)
                Column {
                    id: setupCol
                    x: Theme.space.s4; y: Theme.space.s4
                    width: parent.width - Theme.space.s4 * 2
                    spacing: Theme.space.s2
                    LText { role: "bodyStrong"; text: Ai.provider === "off" ? "Choose where answers come from" : Ai.provider === "ollama" ? "Ollama isn't running" : "Add your Anthropic API key" }
                    LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                            text: Ai.provider === "ollama" ? "Start it with “ollama serve”, then pull a model, e.g. “ollama pull llama3.2”."
                                : "Local models via Ollama keep everything on this machine; Claude (Anthropic) needs your own API key. Lumen never sends anything until you set one up." }
                    Row {
                        spacing: Theme.space.s2
                        HoverTarget {
                            width: setupLbl.implicitWidth + 28; height: 32
                            onClicked: { Ai.open = false; SettingsState.launch("ai"); }
                            Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.accent }
                            LText { id: setupLbl; anchors.centerIn: parent; role: "bodyStrong"; color: Theme.onAccent; text: "Open AI settings" }
                        }
                        HoverTarget {
                            visible: Ai.provider === "ollama"
                            width: retryLbl.implicitWidth + 28; height: 32
                            onClicked: Ai.refreshStatus()
                            Rectangle { anchors.fill: parent; radius: height / 2; color: "transparent"; border.width: 1; border.color: Theme.border }
                            LText { id: retryLbl; anchors.centerIn: parent; text: "Check again" }
                        }
                    }
                }
            }

            // ── Transcript ──
            ListView {
                id: transcript
                visible: Ai.messages.length > 0
                width: parent.width
                height: Math.min(contentHeight, win.height * 0.78 - 220)
                clip: true
                spacing: Theme.space.s3
                model: Ai.messages
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: Qt.callLater(positionViewAtEnd)
                onContentHeightChanged: if (Ai.busy) positionViewAtEnd()
                delegate: Item {
                    required property var modelData
                    required property int index
                    readonly property bool mine: modelData.role === "user"
                    width: transcript.width
                    height: bubble.height
                    Rectangle {
                        id: bubble
                        anchors.right: mine ? parent.right : undefined
                        width: mine ? Math.min(parent.width * 0.8, userText.implicitWidth + Theme.space.s3 * 2) : parent.width
                        height: (mine ? userText.implicitHeight : answer.implicitHeight) + Theme.space.s3 * 2 + (shot.visible ? shot.height + Theme.space.s2 : 0)
                        radius: Theme.radius.md
                        color: mine ? Theme.withAlpha(Theme.accent, 0.16) : Theme.withAlpha(Theme.surfaceElevated, 0.7)
                        border.width: mine ? 0 : 1; border.color: Theme.border
                        Image {
                            id: shot
                            visible: !!modelData.image
                            x: Theme.space.s3; y: Theme.space.s3
                            width: 160; height: 90
                            fillMode: Image.PreserveAspectCrop
                            source: modelData.image ? "file://" + modelData.image : ""
                        }
                        LText {
                            id: userText
                            visible: mine
                            x: Theme.space.s3; y: Theme.space.s3 + (shot.visible ? shot.height + Theme.space.s2 : 0)
                            width: Math.min(implicitWidth, transcript.width * 0.8 - Theme.space.s3 * 2)
                            wrapMode: Text.Wrap
                            // Show just the question (the attached selection is summarised)
                            text: modelData.text.replace(/^Selected text:\n```\n[\s\S]*?\n```\n\n/, "📎 selection · ")
                        }
                        TextEdit {
                            id: answer
                            visible: !mine
                            x: Theme.space.s3; y: Theme.space.s3
                            width: parent.width - Theme.space.s3 * 2 - 28
                            readOnly: true
                            selectByMouse: true
                            wrapMode: Text.Wrap
                            textFormat: TextEdit.MarkdownText
                            text: modelData.text || (Ai.busy ? "…" : "")
                            color: Theme.text
                            selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                            font.family: Theme.fontUi
                            font.pixelSize: 14
                        }
                        HoverTarget {
                            visible: !mine && modelData.text !== ""
                            anchors { right: parent.right; top: parent.top; margins: 6 }
                            width: 26; height: 26
                            onClicked: { Ai.copy(modelData.text); copied.restart(); }
                            LIcon { anchors.centerIn: parent; icon: copied.running ? "check" : "content_copy"; size: 15; color: Theme.textMuted }
                            Timer { id: copied; interval: 1200 }
                        }
                    }
                }
            }

            LText { visible: Ai.error !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.error; text: Ai.error }

            // ── Context + quick actions ──
            Flow {
                width: parent.width
                spacing: Theme.space.s2
                visible: Ai.configured
                component Chip: HoverTarget {
                    id: chip
                    property string icon
                    property string label
                    property bool on: false
                    width: chipRow.implicitWidth + 22; height: 30
                    Rectangle { anchors.fill: parent; radius: height / 2
                                color: chip.on ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                                border.width: 1; border.color: chip.on ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border }
                    Row { id: chipRow; anchors.centerIn: parent; spacing: 6
                          LIcon { icon: chip.icon; size: 15; color: chip.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                          LText { role: "caption"; text: chip.label; color: chip.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter } }
                }
                Chip {
                    visible: Ai.selection !== "" && Ai.messages.length === 0
                    icon: "format_quote"; on: Ai.useSelection
                    label: "Selection · " + Ai.selection.split(/\s+/).length + " words"
                    onClicked: Ai.useSelection = !Ai.useSelection
                }
                Chip { icon: "screenshot_monitor"; label: "Screen"; on: Ai.useScreen; onClicked: Ai.useScreen = !Ai.useScreen }
                Repeater {
                    model: Ai.messages.length > 0 ? [] : [
                        { icon: "lightbulb", label: "Explain", prompt: "Explain this clearly." },
                        { icon: "short_text", label: "Summarize", prompt: "Summarize this in a few bullet points." },
                        { icon: "spellcheck", label: "Fix writing", prompt: "Fix the grammar and make this read naturally. Reply with only the corrected text." },
                        { icon: "visibility", label: "What's on my screen?", prompt: "What's on my screen? Point out anything important.", screen: true },
                    ]
                    delegate: Chip {
                        required property var modelData
                        icon: modelData.icon; label: modelData.label
                        onClicked: { if (modelData.screen) Ai.useScreen = true; Ai.send(modelData.prompt); }
                    }
                }
            }

            // ── Prompt ──
            Rectangle {
                width: parent.width
                height: Math.max(44, Math.min(140, prompt.contentHeight + 22))
                radius: 22
                color: Theme.withAlpha(Theme.text, 0.05)
                border.width: 1
                border.color: prompt.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                enabled: Ai.configured
                opacity: enabled ? 1 : 0.5
                QQC.ScrollView {
                    anchors { left: parent.left; right: sendBtn.left; top: parent.top; bottom: parent.bottom; leftMargin: Theme.space.s4; topMargin: 11; bottomMargin: 8 }
                    QQC.TextArea {
                        id: prompt
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        placeholderText: Ai.busy ? "Thinking…" : Ai.messages.length ? "Ask a follow-up" : "Ask anything…"
                        placeholderTextColor: Theme.textMuted
                        selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        background: null
                        padding: 0
                        Keys.onPressed: event => {
                            if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                Ai.send(text); text = ""; event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) { Ai.open = false; event.accepted = true; }
                            else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) { Ai.clear(); event.accepted = true; }
                        }
                    }
                }
                HoverTarget {
                    id: sendBtn
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32
                    onClicked: { if (Ai.busy) Ai.stop(); else { Ai.send(prompt.text); prompt.text = ""; } }
                    Rectangle { anchors.fill: parent; radius: 16; color: Ai.busy || prompt.text !== "" ? Theme.accent : Theme.surfaceHover }
                    LIcon { anchors.centerIn: parent; icon: Ai.busy ? "stop" : "arrow_upward"; size: 18; fill: 1
                            color: Ai.busy || prompt.text !== "" ? Theme.onAccent : Theme.textMuted }
                }
            }
        }
    }
}
