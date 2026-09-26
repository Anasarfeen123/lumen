// Lumen Halo (Super+Shift+Space): drops from under the island.
//   header        Halo · model (click to switch) · "On this computer" / "Claude"
//   empty state   a greeting and six skills to start from
//   transcript    Markdown answers, streamed; each answer: Copy · Insert · Save to notes · Retry;
//                 code blocks: Copy · Run (asks first; risky commands say so)
//   context       Selection · Clipboard · Screen · Window · System · Project
//   prompt        "/" lists skills (↑/↓, Tab or Enter picks) · ↑ recalls what you asked
// The halo — a slow ring of light around the panel — turns while Halo works.
//   Enter sends · Shift+Enter new line · Esc closes · Ctrl+L new chat · Ctrl+R retry
import QtQuick
import QtQuick.Effects
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
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
    MouseArea { id: catcher; anchors.fill: parent; onClicked: { modelMenu.visible = false; Ai.open = false; } }

    readonly property int ringW: 2
    readonly property real panelRadius: Theme.radius.lg

    // ── The halo: a ring of light around the panel ─────────────────────────
    // A rotating two-tone gradient, clipped to a rounded rect a little larger
    // than the panel; a blurred copy behind it is the glow. Resting: a faint
    // static rim. Working: it turns and brightens.
    Item {
        id: halo
        x: panel.x - win.ringW; y: panel.y - win.ringW
        width: panel.width + win.ringW * 2; height: panel.height + win.ringW * 2
        opacity: panel.opacity * (Ai.busy ? 1 : 0.35)
        scale: panel.scale
        transformOrigin: Item.Top
        Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }

        component Sweep: ClippingRectangle {
            anchors.fill: parent
            radius: win.panelRadius + win.ringW
            color: "transparent"
            Rectangle {
                id: sweep
                anchors.centerIn: parent
                width: Math.hypot(parent.width, parent.height); height: width
                rotation: spin.angle
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Theme.withAlpha(Theme.accent, 0.0) }
                    GradientStop { position: 0.3; color: Theme.accent }
                    GradientStop { position: 0.5; color: Theme.withAlpha(Theme.accentHover, 0.15) }
                    GradientStop { position: 0.7; color: Qt.tint(Theme.accent, Theme.withAlpha("#ffffff", 0.35)) }
                    GradientStop { position: 1.0; color: Theme.withAlpha(Theme.accent, 0.0) }
                }
            }
        }
        QtObject {
            id: spin
            property real angle: 0
            NumberAnimation on angle { from: 0; to: 360; duration: 3600; loops: Animation.Infinite; running: win.visible && Ai.busy && !Theme.reducedMotion }
        }
        // Glow
        Sweep {
            anchors.margins: -10
            opacity: 0.55
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 40 }
        }
        // Rim
        Sweep {}
    }

    GlassSurface {
        id: panel
        level: "panel"
        radius: win.panelRadius
        width: Math.min(760, win.width - 64)
        height: Math.min(content.implicitHeight + Theme.space.s4 * 2, win.height * 0.82)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.edgeGap + Theme.barHeight + Theme.space.s3
        transformOrigin: Item.Top
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.normal : Theme.motion.micro) } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.55) }
        MouseArea { anchors.fill: parent; onClicked: modelMenu.visible = false }   // swallow clicks so they don't reach the catcher

        Column {
            id: content
            x: Theme.space.s4; y: Theme.space.s4
            width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3

            // ── Header ──
            Item {
                width: parent.width; height: 30
                Row {
                    spacing: Theme.space.s2
                    anchors.verticalCenter: parent.verticalCenter
                    HaloMark { anchors.verticalCenter: parent.verticalCenter; active: Ai.busy }
                    LText { role: "heading"; text: "Halo"; anchors.verticalCenter: parent.verticalCenter }
                    // Model: click to switch
                    HoverTarget {
                        id: modelChip
                        visible: Ai.provider !== "off"
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24; width: modelRow.implicitWidth + 18
                        onClicked: modelMenu.visible = !modelMenu.visible
                        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: Theme.withAlpha(Theme.text, 0.06); border.width: 1; border.color: Theme.border }
                        Row {
                            id: modelRow
                            anchors.centerIn: parent
                            spacing: 4
                            LText { role: "caption"; color: Theme.textSecondary; text: (Ai.auto ? "Auto · " : "") + Ai.model.replace(/:latest$/, ""); anchors.verticalCenter: parent.verticalCenter }
                            LIcon { icon: "expand_more"; size: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    // Where answers come from
                    Row {
                        visible: Ai.provider !== "off"
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        LIcon { icon: Ai.local ? "shield_lock" : "cloud"; size: 14; fill: 1; color: Ai.local ? Theme.success : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        LText { role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                                text: Ai.local ? (Ai.modelLoaded ? "On this computer" : "On this computer · loading model…") : "Claude · your key" }
                    }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    HeadButton { visible: Ai.messages.length > 0; icon: "add_comment"; onClicked: Ai.clear() }
                    HeadButton { icon: "settings"; onClicked: { Ai.open = false; SettingsState.launch("ai"); } }
                    HeadButton { icon: "close"; onClicked: Ai.open = false }
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
                    LText { role: "bodyStrong"
                            text: Ai.provider === "off" ? "Choose where Halo's answers come from"
                                : Ai.provider === "ollama" ? (Ai.status.ollama ? "No local model yet" : "Ollama isn't running")
                                : "Add your Anthropic API key" }
                    LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary
                            text: Ai.provider === "ollama" ? (Ai.status.ollama ? "Download one in Settings → Halo — Gemma 3 4B is a good start, and it can read your screen."
                                                                               : "Start it with “systemctl start ollama”, or pick Claude instead.")
                                : "Local models via Ollama keep everything on this machine; Claude needs your own API key. Halo never sends anything until you set one up." }
                    Row {
                        spacing: Theme.space.s2
                        PillButton { primary: true; text: "Open Halo settings"; onClicked: { Ai.open = false; SettingsState.launch("ai"); } }
                        PillButton { visible: Ai.provider === "ollama"; text: "Check again"; onClicked: Ai.refreshStatus() }
                    }
                }
            }

            // ── Empty state: a greeting and where to start ──
            Column {
                visible: Ai.configured && Ai.messages.length === 0 && !Ai.busy
                width: parent.width
                spacing: Theme.space.s3
                topPadding: Theme.space.s2
                LText {
                    font.pixelSize: 22; font.weight: Font.DemiBold
                    text: "Hi" + (Quickshell.env("USER") ? ", " + Quickshell.env("USER") : "") + ". What can I help with?"
                }
                LText {
                    width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                    text: Ai.selection ? "You've selected " + Ai.selection.split(/\s+/).length + " words — ask about them, or pick a skill."
                                       : "Ask anything, select text first, or type / for skills."
                }
                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: Theme.space.s2; rowSpacing: Theme.space.s2
                    Repeater {
                        model: ["explain", "summarize", "fix", "diagnose", Ai.vision ? "screen" : "cmd", Ai.projectDir ? "commit" : "translate"]
                        delegate: HoverTarget {
                            id: card
                            required property string modelData
                            readonly property var sk: Ai.skills.find(s => s.id === modelData)
                            width: (parent.width - Theme.space.s2 * 2) / 3; height: 64
                            radius: Theme.radius.md
                            onClicked: {
                                if (["cmd", "translate"].includes(sk.id)) { prompt.text = "/" + sk.id + " "; prompt.cursorPosition = prompt.length; prompt.forceActiveFocus(); }
                                else Ai.send("/" + sk.id);
                            }
                            Rectangle { anchors.fill: parent; radius: parent.radius; z: -1; color: Theme.withAlpha(Theme.surfaceElevated, 0.6); border.width: 1; border.color: card.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border }
                            Row {
                                anchors { left: parent.left; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                spacing: Theme.space.s3
                                LIcon { icon: card.sk?.icon ?? ""; size: 20; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    width: parent.width - 20 - Theme.space.s3
                                    anchors.verticalCenter: parent.verticalCenter
                                    LText { role: "bodyStrong"; text: card.sk?.label ?? ""; width: parent.width; elide: Text.ElideRight }
                                    LText { role: "caption"; color: Theme.textMuted; text: card.sk?.hint ?? ""; width: parent.width; elide: Text.ElideRight }
                                }
                            }
                        }
                    }
                }
            }

            // ── Transcript ──
            ListView {
                id: transcript
                visible: Ai.messages.length > 0
                width: parent.width
                height: Math.min(contentHeight, win.height * 0.82 - 250)
                clip: true
                spacing: Theme.space.s3
                model: Ai.messages
                boundsBehavior: Flickable.StopAtBounds
                onCountChanged: Qt.callLater(positionViewAtEnd)
                onContentHeightChanged: if (Ai.busy) positionViewAtEnd()
                QQC.ScrollBar.vertical: QQC.ScrollBar { policy: transcript.contentHeight > transcript.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff }
                delegate: Item {
                    id: msg
                    required property var modelData
                    required property int index
                    readonly property bool mine: modelData.role === "user"
                    readonly property bool last: index === Ai.messages.length - 1
                    readonly property var blocks: mine ? [] : Ai.codeBlocks(modelData.text)
                    width: transcript.width
                    height: mine ? userBubble.height : answerCol.height

                    // You
                    Rectangle {
                        id: userBubble
                        visible: msg.mine
                        anchors.right: parent.right
                        width: Math.min(parent.width * 0.8, Math.max(userText.implicitWidth, chipsRow.implicitWidth, (msg.modelData.fileNames ?? []).length ? 260 : 0) + Theme.space.s3 * 2)
                        height: userCol.implicitHeight + Theme.space.s3 * 2
                        radius: Theme.radius.md
                        color: Theme.withAlpha(Theme.accent, 0.16)
                        Column {
                            id: userCol
                            x: Theme.space.s3; y: Theme.space.s3
                            width: parent.width - Theme.space.s3 * 2
                            spacing: 6
                            ClippingRectangle {
                                visible: !!msg.modelData.image
                                width: 160; height: 90; radius: Theme.radius.sm
                                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; source: msg.modelData.image ? "file://" + msg.modelData.image : ""; sourceSize.width: 320 }
                            }
                            LText { id: userText; width: Math.min(implicitWidth, transcript.width * 0.8 - Theme.space.s3 * 2); wrapMode: Text.Wrap
                                    text: msg.modelData.shown ?? msg.modelData.text }
                            // Attached files, by name
                            Repeater {
                                model: msg.modelData.fileNames ?? []
                                delegate: Row {
                                    required property string modelData
                                    spacing: 4
                                    LIcon { icon: win.fileIcon(modelData); size: 12; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                    LText { role: "caption"; color: Theme.textSecondary; text: modelData; elide: Text.ElideMiddle
                                            width: Math.min(implicitWidth, transcript.width * 0.8 - Theme.space.s3 * 2 - 16); anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                            Row {
                                id: chipsRow
                                visible: (msg.modelData.chips ?? []).length > 0
                                spacing: 4
                                Repeater {
                                    model: msg.modelData.chips ?? []
                                    delegate: Rectangle {
                                        required property string modelData
                                        height: 18; width: chipLbl.implicitWidth + chipIco.width + 14; radius: 9
                                        color: Theme.withAlpha(Theme.text, 0.08)
                                        Row { anchors.centerIn: parent; spacing: 3
                                              LIcon { id: chipIco; icon: win.ctxIcon(modelData); size: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                              LText { id: chipLbl; role: "caption"; font.pixelSize: 10; color: Theme.textSecondary; text: win.ctxLabel(modelData); anchors.verticalCenter: parent.verticalCenter } }
                                    }
                                }
                            }
                        }
                    }

                    // Halo
                    Column {
                        id: answerCol
                        visible: !msg.mine
                        width: parent.width
                        spacing: Theme.space.s2
                        Rectangle {
                            visible: !msg.modelData.renames
                            width: parent.width
                            height: visible ? answer.implicitHeight + Theme.space.s3 * 2 : 0
                            radius: Theme.radius.md
                            color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
                            border.width: 1; border.color: Theme.border
                            TextEdit {
                                id: answer
                                x: Theme.space.s3; y: Theme.space.s3
                                width: parent.width - Theme.space.s3 * 2
                                readOnly: true
                                selectByMouse: true
                                wrapMode: Text.Wrap
                                textFormat: TextEdit.MarkdownText
                                text: msg.modelData.text
                                color: Theme.text
                                selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                                visible: text !== ""
                            }
                            // Before the first words: what Halo is doing
                            Row {
                                visible: msg.modelData.text === ""
                                x: Theme.space.s3; anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.space.s2
                                Repeater {
                                    model: 3
                                    Rectangle {
                                        required property int index
                                        width: 6; height: 6; radius: 3; color: Theme.accent
                                        anchors.verticalCenter: parent.verticalCenter
                                        SequentialAnimation on opacity {
                                            loops: Animation.Infinite; running: msg.modelData.text === ""
                                            PauseAnimation { duration: index * 160 }
                                            NumberAnimation { from: 0.25; to: 1; duration: 380 }
                                            NumberAnimation { from: 1; to: 0.25; duration: 380 }
                                            PauseAnimation { duration: (2 - index) * 160 }
                                        }
                                    }
                                }
                                LText { role: "caption"; color: Theme.textMuted; text: Ai.local && !Ai.modelLoaded ? "Loading " + Ai.model + "…" : "Thinking…" }
                            }
                        }
                        // /rename: check the new names, then apply (and undo)
                        RenamePlan { visible: !!msg.modelData.renames; width: answerCol.width; msgIndex: msg.index; msgData: msg.modelData }
                        // Code blocks: copy or run
                        Repeater {
                            model: Ai.busy && msg.last || msg.modelData.renames ? [] : msg.blocks
                            delegate: CodeActions { required property var modelData; width: answerCol.width; block: modelData }
                        }
                        // Answer actions
                        Row {
                            visible: msg.modelData.text !== "" && !(Ai.busy && msg.last)
                            spacing: 4
                            ActionPill { icon: copied.running ? "check" : "content_copy"; text: copied.running ? "Copied" : "Copy"; onClicked: { Ai.copy(msg.modelData.text); copied.restart(); } Timer { id: copied; interval: 1400 } }
                            ActionPill { icon: "keyboard_return"; text: "Insert"; onClicked: Ai.insert(msg.blocks.length === 1 && msg.modelData.text.trim().startsWith("```") ? msg.blocks[0].code : msg.modelData.text) }
                            ActionPill { icon: "note_add"; text: "Save to notes"; onClicked: Ai.saveToNotes(msg.modelData.text) }
                            ActionPill { visible: msg.last; icon: "refresh"; text: "Retry"; onClicked: Ai.retry() }
                            LText { visible: msg.last && Ai.speed > 0; role: "caption"; color: Theme.textMuted; text: "  " + Ai.speed + " tokens/s"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            LText { visible: Ai.error !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.error; text: Ai.error }

            // ── Context chips ──
            Flow {
                width: parent.width
                spacing: Theme.space.s2
                visible: Ai.configured
                ContextChip { visible: Ai.selection !== "" && Ai.messages.length === 0; kind: "selection"; on: Ai.useSelection
                              label: "Selection · " + Ai.selection.split(/\s+/).length + " words"; onClicked: Ai.useSelection = !Ai.useSelection }
                ContextChip { kind: "clipboard"; on: Ai.useClipboard; onClicked: Ai.useClipboard = !Ai.useClipboard }
                ContextChip { kind: "screen"; on: Ai.useScreen; enabled: Ai.vision; opacity: enabled ? 1 : 0.45
                              label: Ai.vision ? "Screen" : "Screen · needs a vision model"; onClicked: Ai.useScreen = !Ai.useScreen }
                ContextChip { kind: "window"; on: Ai.useWindow; onClicked: Ai.useWindow = !Ai.useWindow }
                ContextChip { kind: "system"; on: Ai.useSystem; onClicked: Ai.useSystem = !Ai.useSystem }
                ContextChip { visible: Ai.projectDir !== ""; kind: "project"; on: Ai.useProject
                              label: "Project · " + Ai.projectDir.replace(/.*\//, ""); onClicked: Ai.useProject = !Ai.useProject }
                ContextChip { kind: "file"; on: Ai.files.length > 0 || Ai.pickerOpen
                              label: Ai.files.length ? "Files · " + Ai.files.length : "Files"
                              onClicked: { Ai.pickerOpen = !Ai.pickerOpen; if (Ai.pickerOpen) Ai.loadDownloads(); } }
            }

            // ── Files: attached, and a picker of your newest downloads ──
            Flow {
                visible: Ai.files.length > 0
                width: parent.width
                spacing: 6
                Repeater {
                    model: Ai.files
                    delegate: Rectangle {
                        required property string modelData
                        height: 26; radius: 13
                        width: fRow.implicitWidth + 16
                        color: Theme.withAlpha(Theme.accent, 0.12)
                        border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.35)
                        Row {
                            id: fRow
                            anchors.centerIn: parent
                            spacing: 4
                            LIcon { icon: win.fileIcon(modelData); size: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; text: modelData.replace(/.*\//, ""); elide: Text.ElideMiddle; width: Math.min(implicitWidth, 220); anchors.verticalCenter: parent.verticalCenter }
                            HoverTarget { width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; onClicked: Ai.toggleFile(modelData)
                                          LIcon { anchors.centerIn: parent; icon: "close"; size: 12; color: Theme.textMuted } }
                        }
                    }
                }
            }
            Rectangle {
                id: picker
                visible: Ai.pickerOpen
                width: parent.width
                height: visible ? pickCol.implicitHeight + 12 : 0
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surfaceElevated, 0.9)
                border.width: 1; border.color: Theme.border
                Column {
                    id: pickCol
                    x: 6; y: 6
                    width: parent.width - 12
                    Item {
                        width: parent.width; height: 26
                        LText { x: 8; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                                text: "Newest in Downloads · pick up to 5" + (Ai.local ? "" : " · they'll be sent to Claude") }
                        HoverTarget { anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                      width: doneLbl.implicitWidth + 16; height: 22; onClicked: Ai.pickerOpen = false
                                      LText { id: doneLbl; anchors.centerIn: parent; role: "caption"; color: Theme.accent; text: "Done" } }
                    }
                    Repeater {
                        model: Ai.downloads.slice(0, 8)
                        delegate: HoverTarget {
                            id: dl
                            required property var modelData
                            readonly property bool picked: Ai.files.includes(modelData.path)
                            width: pickCol.width; height: 32
                            radius: Theme.radius.sm
                            onClicked: Ai.toggleFile(modelData.path)
                            LIcon { id: box; x: 8; anchors.verticalCenter: parent.verticalCenter; icon: dl.picked ? "check_box" : "check_box_outline_blank"; fill: dl.picked ? 1 : 0; size: 18
                                    color: dl.picked ? Theme.accent : Theme.textMuted }
                            LIcon { id: kindIco; anchors { left: box.right; leftMargin: 8; verticalCenter: parent.verticalCenter } icon: win.fileIcon(dl.modelData.name); size: 16; color: Theme.textSecondary }
                            LText { anchors { left: kindIco.right; leftMargin: 8; right: meta.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                                    elide: Text.ElideMiddle; text: dl.modelData.name }
                            LText { id: meta; anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter } role: "caption"; color: Theme.textMuted
                                    text: win.size(dl.modelData.size) + " · " + win.ago(dl.modelData.mtime) }
                        }
                    }
                    LText { visible: Ai.downloads.length === 0; x: 8; height: 28; role: "caption"; color: Theme.textMuted
                            text: "Nothing in Downloads. Drop files on the Drop Zone's “Ask Halo”, or run: qs ipc call ai files <path>" }
                }
            }

            // ── Skills (type "/") ──
            Rectangle {
                id: palette
                readonly property var matches: Ai.skillMatches(prompt.text)
                property int current: 0
                onMatchesChanged: current = 0
                visible: matches.length > 0 && prompt.activeFocus
                width: parent.width
                height: visible ? paletteList.contentHeight + 8 : 0
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surfaceElevated, 0.9)
                border.width: 1; border.color: Theme.border
                function pick(i) {
                    const s = matches[i];
                    if (!s) return;
                    prompt.text = "/" + s.id + " ";
                    prompt.cursorPosition = prompt.length;
                }
                ListView {
                    id: paletteList
                    anchors { fill: parent; margins: 4 }
                    interactive: false
                    model: palette.matches
                    delegate: HoverTarget {
                        id: prow
                        required property var modelData
                        required property int index
                        width: paletteList.width; height: 34
                        radius: Theme.radius.sm
                        highlighted: palette.current === index
                        onClicked: { palette.pick(index); prompt.forceActiveFocus(); }
                        Row {
                            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s3
                            LIcon { icon: prow.modelData.icon; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "bodyStrong"; text: "/" + prow.modelData.id; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; color: Theme.textMuted; text: prow.modelData.hint; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            // ── Prompt ──
            Rectangle {
                width: parent.width
                height: Math.max(46, Math.min(150, prompt.contentHeight + 24))
                radius: 23
                color: Theme.withAlpha(Theme.text, 0.05)
                border.width: 1
                border.color: prompt.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                enabled: Ai.configured
                opacity: enabled ? 1 : 0.5
                property int histIdx: -1
                QQC.ScrollView {
                    anchors { left: parent.left; right: sendBtn.left; top: parent.top; bottom: parent.bottom; leftMargin: Theme.space.s4; topMargin: 12; bottomMargin: 8 }
                    QQC.TextArea {
                        id: prompt
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        placeholderText: Ai.busy ? ({ reading: "Reading context…", looking: "Looking at your screen…" })[Ai.phase] ?? "Thinking…"
                                       : Ai.messages.length ? "Ask a follow-up" : "Ask Halo anything, or type / for skills"
                        placeholderTextColor: Theme.textMuted
                        selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                        font.family: Theme.fontUi
                        font.pixelSize: 14
                        background: null
                        padding: 0
                        function submit() { Ai.send(text); text = ""; parent.parent.parent.histIdx = -1; }
                        Keys.onPressed: event => {
                            const box = parent.parent.parent;
                            const ctrl = event.modifiers & Qt.ControlModifier;
                            if (palette.visible && (event.key === Qt.Key_Down || event.key === Qt.Key_Up)) {
                                const n = palette.matches.length;
                                palette.current = (palette.current + (event.key === Qt.Key_Down ? 1 : n - 1)) % n;
                                event.accepted = true;
                            } else if (palette.visible && (event.key === Qt.Key_Tab || event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                                // Enter on a skill that needs no argument sends it at once
                                const s = palette.matches[palette.current];
                                if (event.key !== Qt.Key_Tab && s && !/<|\//.test(s.hint.replace(/^\/\w+/, ""))) { text = "/" + s.id; submit(); }
                                else palette.pick(palette.current);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                                submit(); event.accepted = true;
                            } else if (event.key === Qt.Key_Up && (text === "" || box.histIdx >= 0) && Ai.history.length) {
                                box.histIdx = box.histIdx < 0 ? Ai.history.length - 1 : Math.max(0, box.histIdx - 1);
                                text = Ai.history[box.histIdx]; cursorPosition = length; event.accepted = true;
                            } else if (event.key === Qt.Key_Down && box.histIdx >= 0) {
                                box.histIdx++;
                                if (box.histIdx >= Ai.history.length) { box.histIdx = -1; text = ""; } else { text = Ai.history[box.histIdx]; cursorPosition = length; }
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Escape) {
                                if (text !== "") text = ""; else Ai.open = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_L && ctrl) { Ai.clear(); event.accepted = true; }
                            else if (event.key === Qt.Key_R && ctrl) { Ai.retry(); event.accepted = true; }
                        }
                    }
                }
                HoverTarget {
                    id: sendBtn
                    anchors { right: parent.right; rightMargin: 7; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32
                    onClicked: { if (Ai.busy) Ai.stop(); else prompt.submit(); }
                    Rectangle { anchors.fill: parent; radius: 16; color: Ai.busy || prompt.text !== "" ? Theme.accent : Theme.surfaceHover
                                Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
                    LIcon { anchors.centerIn: parent; icon: Ai.busy ? "stop" : "arrow_upward"; size: 18; fill: 1
                            color: Ai.busy || prompt.text !== "" ? Theme.onAccent : Theme.textMuted }
                }
            }
            LText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "caption"; color: Theme.textMuted; font.pixelSize: 10
                text: "Enter to send · / for skills · ↑ for earlier questions · Ctrl+L new chat" + (Ai.local ? " · nothing leaves this computer" : "")
            }
        }
    }

    // ── Model menu (under the model chip) ──
    Rectangle {
        id: modelMenu
        visible: false
        readonly property point at: modelChip.mapToItem(win.contentItem, 0, modelChip.height + 6)
        x: at.x; y: at.y
        width: 280
        height: menuCol.implicitHeight + 8
        radius: Theme.radius.md
        color: Theme.surfaceElevated
        border.width: 1; border.color: Theme.border
        onVisibleChanged: if (visible) Ai.refreshStatus()
        MouseArea { anchors.fill: parent }
        Column {
            id: menuCol
            x: 4; y: 4
            width: parent.width - 8
            LText { visible: (Ai.status.ollamaModels ?? []).length > 0; leftPadding: 10; topPadding: 6; bottomPadding: 4; role: "caption"; color: Theme.textMuted; text: "On this computer" }
            MenuRow {
                visible: (Ai.status.ollamaModels ?? []).length > 1
                icon: "auto_awesome"; title: "Automatic"
                sub: Ai.textModel + " for text" + (Ai.visionModel && Ai.visionModel !== Ai.textModel ? ", " + Ai.visionModel + " for your screen" : "")
                current: Ai.auto
                onClicked: { Ai.setModel("ollama", "auto"); modelMenu.visible = false; }
            }
            Repeater {
                model: Ai.status.ollamaInfo ?? []
                delegate: MenuRow {
                    required property var modelData
                    icon: modelData.vision ? "visibility" : "memory"
                    title: modelData.name.replace(/:latest$/, "")
                    sub: (modelData.params ? modelData.params + " · " : "") + (modelData.size / 1e9).toFixed(1) + " GB" + (modelData.vision ? " · reads images" : "")
                    current: Ai.provider === "ollama" && !Ai.auto && Ai.model === modelData.name
                    onClicked: { Ai.setModel("ollama", modelData.name); modelMenu.visible = false; }
                }
            }
            LText { visible: Ai.status.anthropic; leftPadding: 10; topPadding: 6; bottomPadding: 4; role: "caption"; color: Theme.textMuted; text: "Claude" }
            Repeater {
                model: Ai.status.anthropic ? [{ id: "claude-haiku-4-5-20251001", label: "Haiku 4.5", sub: "Fastest" }, { id: "claude-sonnet-5", label: "Sonnet 5", sub: "Balanced" }, { id: "claude-opus-5-5", label: "Opus 5.5", sub: "Most capable" }] : []
                delegate: MenuRow {
                    required property var modelData
                    icon: "cloud"; title: modelData.label; sub: modelData.sub
                    current: Ai.provider === "anthropic" && Ai.model === modelData.id
                    onClicked: { Ai.setModel("anthropic", modelData.id); modelMenu.visible = false; }
                }
            }
            MenuRow { icon: "tune"; title: "Manage models…"; sub: "Download, remove, set up Claude"; onClicked: { modelMenu.visible = false; Ai.open = false; SettingsState.launch("ai"); } }
        }
    }

    // ── pieces ──
    function ctxIcon(k) { return ({ selection: "format_quote", clipboard: "content_paste", screen: "screenshot_monitor", window: "select_window", system: "monitor_heart", project: "commit", file: "attach_file" })[k] ?? "attach_file"; }
    function ctxLabel(k) { return ({ selection: "Selection", clipboard: "Clipboard", screen: "Screen", window: "Window", system: "System", project: "Project", file: "Files" })[k] ?? k; }
    function fileIcon(name) {
        const e = (name.match(/\.([^.\/]+)$/)?.[1] ?? "").toLowerCase();
        if (e === "pdf") return "picture_as_pdf";
        if (["png", "jpg", "jpeg", "webp", "gif", "heic", "avif"].includes(e)) return "image";
        if (["mp4", "mkv", "webm", "avi", "mov"].includes(e)) return "movie";
        if (["mp3", "flac", "ogg", "wav", "m4a"].includes(e)) return "music_note";
        if (["zip", "tar", "gz", "xz", "zst", "7z", "rar"].includes(e)) return "folder_zip";
        if (["doc", "docx", "odt", "rtf"].includes(e)) return "article";
        if (["ppt", "pptx", "odp", "key"].includes(e)) return "slideshow";
        if (["xls", "xlsx", "ods", "csv"].includes(e)) return "table_chart";
        if (["py", "js", "ts", "qml", "sh", "c", "cpp", "rs", "go", "java", "json", "lua"].includes(e)) return "code";
        return "description";
    }
    function size(b) { return b >= 1e9 ? (b / 1e9).toFixed(1) + " GB" : b >= 1e6 ? (b / 1e6).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1e3)) + " KB"; }
    function ago(t) {
        const s = Date.now() / 1000 - t;
        return s < 3600 ? Math.max(1, Math.round(s / 60)) + " min ago" : s < 86400 ? Math.round(s / 3600) + " h ago" : Math.round(s / 86400) + " d ago";
    }

    component HeadButton: HoverTarget {
        property string icon
        width: 28; height: 28
        LIcon { anchors.centerIn: parent; icon: parent.icon; size: 18; color: Theme.textMuted }
    }
    component PillButton: HoverTarget {
        id: pb
        property string text
        property bool primary: false
        width: pbl.implicitWidth + 28; height: 32
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: pb.primary ? Theme.accent : "transparent"; border.width: pb.primary ? 0 : 1; border.color: Theme.border }
        LText { id: pbl; anchors.centerIn: parent; role: "bodyStrong"; color: pb.primary ? Theme.onAccent : Theme.text; text: pb.text }
    }
    component ActionPill: HoverTarget {
        id: ap
        property string icon
        property string text
        width: apRow.implicitWidth + 16; height: 26
        Row { id: apRow; anchors.centerIn: parent; spacing: 4
              LIcon { icon: ap.icon; size: 14; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; color: Theme.textSecondary; text: ap.text; anchors.verticalCenter: parent.verticalCenter } }
    }
    component ContextChip: HoverTarget {
        id: chip
        property string kind
        property string label: win.ctxLabel(kind)
        property bool on: false
        width: chipRow.implicitWidth + 22; height: 30
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                    color: chip.on ? Theme.withAlpha(Theme.accent, 0.18) : "transparent"
                    border.width: 1; border.color: chip.on ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        Row { id: chipRow; anchors.centerIn: parent; spacing: 6
              LIcon { icon: win.ctxIcon(chip.kind); size: 15; fill: chip.on ? 1 : 0; color: chip.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: chip.label; color: chip.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter } }
    }
    component MenuRow: HoverTarget {
        id: mr
        property string icon
        property string title
        property string sub
        property bool current: false
        width: parent ? parent.width : 0; height: 40
        radius: Theme.radius.sm
        LIcon { id: mrIcon; x: 10; anchors.verticalCenter: parent.verticalCenter; icon: mr.icon; size: 16; color: mr.current ? Theme.accent : Theme.textSecondary }
        Column {
            anchors { left: mrIcon.right; leftMargin: 10; right: mrCheck.left; verticalCenter: parent.verticalCenter }
            LText { role: mr.current ? "bodyStrong" : "body"; text: mr.title; width: parent.width; elide: Text.ElideRight }
            LText { role: "caption"; color: Theme.textMuted; text: mr.sub; visible: text !== ""; width: parent.width; elide: Text.ElideRight }
        }
        LIcon { id: mrCheck; anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                icon: "check"; size: 16; color: Theme.accent; visible: mr.current }
    }
    // A code block's actions: Copy, and Run for shell (a second press confirms)
    component CodeActions: Rectangle {
        id: ca
        property var block
        property bool confirming: false
        readonly property bool shell: Ai.isShell(block.lang) && block.code.split("\n").length <= 12
        readonly property bool risky: Ai.risky(block.code)
        height: 34
        radius: Theme.radius.sm
        color: ca.confirming ? Theme.withAlpha(ca.risky ? Theme.error : Theme.accent, 0.12) : Theme.withAlpha(Theme.text, 0.04)
        border.width: 1; border.color: ca.confirming ? Theme.withAlpha(ca.risky ? Theme.error : Theme.accent, 0.4) : Theme.border
        Timer { id: confirmTimer; interval: 5000; onTriggered: ca.confirming = false }
        LIcon { id: caIcon; x: 10; anchors.verticalCenter: parent.verticalCenter; icon: ca.shell ? "terminal" : "code"; size: 15; color: Theme.textMuted }
        LText {
            anchors { left: caIcon.right; leftMargin: 8; right: caBtns.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight
            font.family: Theme.fontMono; font.pixelSize: 12
            color: ca.confirming && ca.risky ? Theme.error : Theme.textSecondary
            text: ca.confirming ? (ca.risky ? "This can delete or change things. Run anyway?" : "Run in a terminal?") : block.code.split("\n")[0]
        }
        Row {
            id: caBtns
            anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
            spacing: 2
            ActionPill { icon: caCopied.running ? "check" : "content_copy"; text: caCopied.running ? "Copied" : "Copy"; onClicked: { Ai.copy(ca.block.code); caCopied.restart(); } Timer { id: caCopied; interval: 1400 } }
            ActionPill {
                visible: ca.shell
                icon: "play_arrow"; text: ca.confirming ? "Run" : "Run…"
                onClicked: { if (ca.confirming) { ca.confirming = false; Ai.run(ca.block.code); } else { ca.confirming = true; confirmTimer.restart(); } }
            }
        }
    }

    // /rename's answer: each suggestion with a checkbox, then Apply (and Undo)
    component RenamePlan: Rectangle {
        id: rp
        property int msgIndex: -1
        property var msgData: ({})
        readonly property var renames: msgData.renames ?? []
        readonly property string stage: msgData.renameState ?? "plan"
        height: rpCol.implicitHeight + Theme.space.s3 * 2
        radius: Theme.radius.md
        color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
        border.width: 1; border.color: Theme.border
        Column {
            id: rpCol
            x: Theme.space.s3; y: Theme.space.s3
            width: parent.width - Theme.space.s3 * 2
            spacing: 4
            LText { role: "bodyStrong"; text: rp.stage === "applied" ? "Renamed" : rp.stage === "undone" ? "Names put back" : "Suggested names"; bottomPadding: 4 }
            Repeater {
                model: rp.renames
                delegate: HoverTarget {
                    id: rr
                    required property var modelData
                    required property int index
                    readonly property var result: (rp.msgData.renameResults ?? []).find(r => r.from === modelData.from) ?? null
                    width: rpCol.width; height: 30
                    radius: Theme.radius.sm
                    enabled: rp.stage === "plan"
                    onClicked: Ai.toggleRename(rp.msgIndex, index)
                    LIcon { id: rbox; x: 4; anchors.verticalCenter: parent.verticalCenter; size: 18
                            icon: rp.stage === "plan" ? (rr.modelData.on ? "check_box" : "check_box_outline_blank")
                                : rr.result?.status === "renamed" ? "check_circle" : "block"
                            fill: rr.modelData.on ? 1 : 0
                            color: rr.result?.status === "skipped" ? Theme.warning : rr.modelData.on ? Theme.accent : Theme.textMuted }
                    LText { id: oldName; anchors { left: rbox.right; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            width: (rpCol.width - 60) * 0.42; elide: Text.ElideMiddle; role: "caption"; color: Theme.textMuted
                            text: rr.modelData.from.replace(/.*\//, "") }
                    LIcon { id: arrow; anchors { left: oldName.right; leftMargin: 6; verticalCenter: parent.verticalCenter } icon: "arrow_forward"; size: 14; color: Theme.textMuted }
                    LText { anchors { left: arrow.right; leftMargin: 6; right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                            elide: Text.ElideMiddle
                            color: rr.modelData.on ? Theme.text : Theme.textMuted
                            text: rr.result?.status === "skipped" ? rr.modelData.to + "  (skipped: " + rr.result.why + ")" : rr.modelData.to }
                }
            }
            Row {
                spacing: 6
                topPadding: 6
                PillButton { visible: rp.stage === "plan"; primary: true; text: "Apply renames"; enabled: rp.renames.some(r => r.on); onClicked: Ai.applyRenames(rp.msgIndex) }
                PillButton { visible: rp.stage === "applied" && (rp.msgData.renameResults ?? []).some(r => r.status === "renamed"); text: "Undo"; onClicked: Ai.undoRenames(rp.msgIndex) }
                LText { visible: rp.stage === "plan"; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                        text: "Nothing changes until you press Apply. Existing files are never overwritten." }
            }
        }
    }
}
