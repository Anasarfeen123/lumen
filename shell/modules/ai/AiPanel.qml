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
import "markdown.js" as Md

PanelWindow {
    id: win
    // Colours for answers (solid: Qt rich text ignores alpha in CSS colours)
    readonly property var mdColors: ({
        accent: Theme.accent.toString(), muted: Theme.textMuted.toString(), mono: Theme.fontMono,
        codeBg: Qt.tint(Theme.surfaceElevated, Theme.withAlpha(Theme.text, 0.10)).toString(),
        blockBg: Qt.tint(Theme.surface, Theme.withAlpha(Theme.bg, 0.55)).toString()
    })

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

    onShowingChanged: {
        if (!showing) return;
        Qt.callLater(() => prompt.forceActiveFocus());
        // Halo wakes as the panel arrives: eyes open with a little hop
        headOrb.wake();
        greetPop.restart();
    }
    Timer { id: greetPop; interval: 140; onTriggered: bigOrb.pop() }

    // Halo's eyes follow the pointer anywhere on this screen while the panel is open
    HoverHandler { id: screenHover }

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
            NumberAnimation on angle { from: 0; to: 360; duration: 4800; loops: Animation.Infinite; running: win.showing && Ai.busy && !Theme.reducedMotion }
        }
        // Glow: an accent frame blurred ONCE (its source never changes), that
        // only breathes through its opacity — compositing, not re-blurring.
        // (A blurred copy of the turning gradient re-rendered the blur every
        // frame and cost a large share of a core on the iGPU.)
        Rectangle {
            id: glow
            anchors.fill: parent
            anchors.margins: -6
            radius: win.panelRadius + 8
            color: "transparent"
            border.width: 7
            border.color: Theme.accent
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blur: 1.0; blurMax: 32 }
            opacity: Ai.busy ? 0.42 : 0.18
            SequentialAnimation on opacity {
                running: win.visible && Ai.busy && !Theme.reducedMotion
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.55; duration: 1400; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.3; duration: 1400; easing.type: Easing.InOutSine }
            }
        }
        // Rim: a thin turning light (no blur)
        Sweep {}
    }

    GlassSurface {
        id: panel
        level: "panel"
        // ── Arriving and leaving: the panel grows out of the island ──
        // It starts as the island's own pill, then stretches down and out on a
        // spring (a touch past full size); the words fade in once there's room.
        // Leaving, it pulls back up into the island and is gone.
        readonly property real fullW: Math.min(760, win.width - 64)
        property real fullH: Math.min(content.implicitHeight + Theme.space.s4 * 2, win.height * 0.82)
        Behavior on fullH { enabled: panel.grow >= 1; NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        readonly property real startW: Math.max(120, Island.shapeWidth)
        readonly property real startH: Theme.island.height
        readonly property real startY: Island.shapeY
        readonly property real targetY: Theme.edgeGap + Theme.barHeight + Theme.space.s3
        property real grow: win.showing ? 1 : 0
        Behavior on grow {
            NumberAnimation {
                duration: Theme.reducedMotion ? 0 : (win.showing ? 520 : 230)
                easing.type: win.showing ? Easing.OutBack : Easing.InCubic
                easing.overshoot: 1.15
            }
        }
        readonly property real g: Math.max(0, grow)
        radius: Math.min(height / 2, win.panelRadius + (1 - Math.min(1, g)) * 20)
        width: startW + (fullW - startW) * g
        height: Math.max(startH, startH + (fullH - startH) * g)
        x: (win.width - width) / 2
        y: startY + (targetY - startY) * Math.min(1, g)
        opacity: Math.min(1, g * 4)
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.55) }
        MouseArea { anchors.fill: parent; onClicked: modelMenu.visible = false }   // swallow clicks so they don't reach the catcher
        // Where Halo looks: at the pointer (anywhere on this screen), else down at
        // what you're typing, else straight ahead. Near → a small turn; far → a full one.
        property real typedAt: 0
        Connections { target: prompt; function onTextChanged() { panel.typedAt = Date.now(); lookRest.restart(); } }
        Timer { id: lookRest; interval: 1600 }
        function lookAt(orb) {
            if (lookRest.running && prompt.activeFocus) return Qt.point(-0.2, 0.9);     // reading what you type
            if (!screenHover.hovered) return Qt.point(0, 0);
            const c = orb.mapToItem(win.contentItem, orb.width / 2, orb.height / 2), p = screenHover.point.position;
            const dx = p.x - c.x, dy = p.y - c.y;
            return Qt.point(dx / (Math.abs(dx) + 140), dy / (Math.abs(dy) + 110));
        }
        // Drop files on Halo to ask about them (up to 5)
        DropArea {
            id: drop
            anchors.fill: parent
            keys: ["text/uri-list"]
            onDropped: d => {
                const paths = (d.urls ?? []).map(u => decodeURIComponent(String(u).replace(/^file:\/\//, ""))).filter(p => p.startsWith("/"));
                for (const p of paths) if (!Ai.files.includes(p) && Ai.files.length < 5) Ai.files = Ai.files.concat([p]);
                d.accept();
                prompt.forceActiveFocus();
            }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: 6; z: 50
            radius: win.panelRadius - 6
            visible: opacity > 0.01
            opacity: drop.containsDrag ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            color: Theme.withAlpha(Theme.accent, 0.10)
            border.width: 2; border.color: Theme.withAlpha(Theme.accent, 0.6)
            Column {
                anchors.centerIn: parent
                spacing: Theme.space.s2
                HaloOrb { anchors.horizontalCenter: parent.horizontalCenter; size: 44; mood: "listening"; level: 0.4; face: Persist.data.haloFace ?? true }
                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "bodyStrong"; text: "Drop to ask " + Halo.name + " about it" }
                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted; text: "PDFs, documents, code, pictures — up to 5" }
            }
        }

        // keeps the words inside the glass while it grows and shrinks
        Item { id: clipper; anchors.fill: parent; anchors.margins: 1; clip: panel.g < 0.999 }
        Column {
            id: content
            parent: clipper
            // laid out at full width from the start (no reflowing while it grows)
            x: (clipper.width - width) / 2; y: Theme.space.s4 - 1
            width: panel.fullW - Theme.space.s4 * 2
            spacing: Theme.space.s3
            // the words arrive once there's room, rising a little
            opacity: win.showing ? Math.max(0, Math.min(1, (panel.g - 0.55) / 0.4)) : Math.max(0, (panel.g - 0.75) / 0.25)
            transform: Translate { y: (1 - Math.min(1, panel.g)) * -14 }

            // ── Header ──
            Item {
                width: parent.width; height: 30
                Row {
                    spacing: Theme.space.s2
                    anchors.verticalCenter: parent.verticalCenter
                    HaloOrb { id: headOrb; anchors.verticalCenter: parent.verticalCenter; size: 24; mood: Halo.mood; level: Voice.level; mouth: Voice.mouth; face: Persist.data.haloFace ?? true
                              lookX: panel.lookAt(headOrb).x; lookY: panel.lookAt(headOrb).y }
                    LText { role: "heading"; text: Halo.name; anchors.verticalCenter: parent.verticalCenter }
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
                visible: Ai.messages.length === 0 && !Ai.busy
                width: parent.width
                spacing: Theme.space.s3
                topPadding: Theme.space.s2
                Row {
                    width: parent.width
                    spacing: Theme.space.s4
                    HaloOrb {
                        id: bigOrb
                        anchors.verticalCenter: parent.verticalCenter
                        size: 52; mood: Halo.mood; level: Voice.level; mouth: Voice.mouth; face: Persist.data.haloFace ?? true
                        // follows the pointer; looks down at what you're typing
                        lookX: panel.lookAt(bigOrb).x; lookY: panel.lookAt(bigOrb).y
                    }
                    Column {
                        width: parent.width - bigOrb.width - Theme.space.s4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        LText {
                            width: parent.width; wrapMode: Text.Wrap
                            font.pixelSize: 22; font.weight: Font.DemiBold
                            text: Halo.greeting().replace(/[.!]$/, "") + ". What can I help with?"
                        }
                        LText {
                            width: parent.width; wrapMode: Text.Wrap; color: Theme.textMuted
                            text: Voice.listening ? "Listening — I'll stop when you pause."
                                : Ai.selection ? "You've selected " + Ai.selection.split(/\s+/).length + " words — ask about them, or pick a skill."
                                : "Ask anything, or tell me to do something — “dark mode on”, “click Download”, “remind me at 9 to…” — or type / for skills."
                        }
                    }
                }
                // What Halo can do right now, model or not
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [
                            { icon: "inbox", label: "What did I miss?", q: "what did I miss" },
                            { icon: new Date().getHours() >= 17 ? "nights_stay" : "wb_sunny", label: new Date().getHours() >= 17 ? "Wrap up my day" : "Brief me", q: new Date().getHours() >= 17 ? "wrap up my day" : "brief me" },
                            { icon: "stethoscope", label: "How's my computer?", q: "how's my computer" },
                            { icon: "gesture", label: "Circle to search", lens: true },
                        ].concat(Voice.canListen ? [{ icon: "mic", label: "Talk", talk: true }] : [])
                         .concat(Ai.configured && Ai.projectDir ? [{ icon: "commit", label: "Commit message", q: "/commit" }] : [])
                         .concat(Halo.reminders.length ? [{ icon: "alarm", label: Halo.reminders.length === 1 ? "1 reminder" : Halo.reminders.length + " reminders", reminders: true }] : [])
                        delegate: ActionPill {
                            required property var modelData
                            outlined: true
                            icon: modelData.icon; text: modelData.label
                            onClicked: modelData.lens ? Lens.start() : modelData.talk ? Voice.toggle()
                                     : modelData.reminders ? Ai.note({ icon: "alarm", title: "Your reminders", text: Halo.reminders.map(r => "• " + Halo.whenText(r.at) + " — " + r.text).join("\n") })
                                     : Ai.send(modelData.q)
                        }
                    }
                }
                // What Halo noticed lately (the doctor, wrap-ups, things held while you were busy)
                Column {
                    readonly property var recent: Halo.log.filter(c => Date.now() - (c.time ?? 0) < 6 * 3600000 && c.key !== "live" && c.key !== "act").slice(-3).reverse()
                    visible: recent.length > 0
                    width: parent.width
                    spacing: 6
                    LText { role: "caption"; color: Theme.textMuted; text: "Lately" }
                    Repeater {
                        model: parent.recent
                        delegate: Rectangle {
                            id: noticed
                            required property var modelData
                            width: parent.width
                            height: nCol.implicitHeight + Theme.space.s3 * 2
                            radius: Theme.radius.md
                            color: Theme.withAlpha(Theme.surfaceElevated, 0.6)
                            border.width: 1; border.color: modelData.tone === "concerned" ? Theme.withAlpha(Theme.warning, 0.35) : Theme.border
                            LIcon { id: nIco; x: Theme.space.s3; y: Theme.space.s3 + 1; icon: noticed.modelData.icon ?? "auto_awesome"; size: 18; fill: 1
                                    color: noticed.modelData.tone === "concerned" ? Theme.warning : Theme.accent }
                            Column {
                                id: nCol
                                anchors { left: nIco.right; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s3; top: parent.top; topMargin: Theme.space.s3 }
                                spacing: 4
                                Row {
                                    width: parent.width
                                    LText { role: "bodyStrong"; text: noticed.modelData.title ?? ""; elide: Text.ElideRight; width: parent.width - when.width - forget.width; textFormat: Text.PlainText }
                                    LText { id: when; role: "caption"; color: Theme.textMuted; text: win.ago(Math.round((noticed.modelData.time ?? Date.now()) / 1000)); anchors.verticalCenter: parent.verticalCenter }
                                    HoverTarget { id: forget; width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter; onClicked: Halo.forget(noticed.modelData.key)
                                                  LIcon { anchors.centerIn: parent; icon: "close"; size: 13; color: Theme.textMuted } }
                                }
                                LText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary
                                        text: noticed.modelData.text ?? ""; maximumLineCount: 3; elide: Text.ElideRight; textFormat: Text.PlainText }
                                Flow {
                                    visible: (noticed.modelData.actions ?? []).length > 0
                                    width: parent.width; spacing: 4
                                    Repeater {
                                        model: (noticed.modelData.actions ?? []).filter(a => a)
                                        delegate: ActionPill { required property var modelData; outlined: true; icon: modelData.icon ?? ""; text: modelData.label
                                                               onClicked: { const key = noticed.modelData.key; modelData.run?.(); Halo.forget(key); } }
                                    }
                                }
                            }
                        }
                    }
                }
                Grid {
                    visible: Ai.configured
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
                // Follow the answer as it grows (once per batch, not per token)
                Connections { target: Ai; function onStreamTextChanged() { if (!transcript.moving) transcript.positionViewAtEnd(); } }
                QQC.ScrollBar.vertical: QQC.ScrollBar { policy: transcript.contentHeight > transcript.height ? QQC.ScrollBar.AsNeeded : QQC.ScrollBar.AlwaysOff }
                // Scrolled up while it writes: a way back to the latest
                HoverTarget {
                    parent: transcript
                    z: 10
                    readonly property bool want: !transcript.atYEnd && transcript.contentHeight > transcript.height + 40
                    opacity: want ? 1 : 0
                    visible: opacity > 0.01
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 8 }
                    width: jumpRow.implicitWidth + 22; height: 28
                    onClicked: transcript.positionViewAtEnd()
                    Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: Theme.surfaceElevated; border.width: 1; border.color: Theme.border }
                    Row { id: jumpRow; anchors.centerIn: parent; spacing: 4
                          LIcon { icon: "arrow_downward"; size: 14; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                          LText { role: "caption"; text: Ai.busy ? "Latest" : "Jump to the end"; anchors.verticalCenter: parent.verticalCenter } }
                }
                delegate: Item {
                    id: msg
                    required property var modelData
                    required property int index
                    readonly property bool mine: modelData.role === "user"
                    readonly property bool last: index === Ai.messages.length - 1
                    // The answer being written: cheap plain text from Ai.streamText,
                    // Markdown once it's done (re-parsing Markdown per token was the lag)
                    readonly property bool live: last && !mine && Ai.busy
                    readonly property var blocks: mine || live ? [] : Ai.codeBlocks(modelData.text)
                    width: transcript.width
                    height: modelData.hidden ? 0 : mine ? userBubble.height : answerCol.height
                    visible: !modelData.hidden
                    // Arrives with a small rise and fade (only when it's new)
                    opacity: 0
                    transform: Translate { id: rise; y: 10 }
                    Component.onCompleted: if (Theme.reducedMotion || index < Ai.messages.length - 2) { opacity = 1; rise.y = 0; } else enter.start()
                    ParallelAnimation {
                        id: enter
                        NumberAnimation { target: msg; property: "opacity"; to: 1; duration: Theme.motion.normal }
                        NumberAnimation { target: rise; property: "y"; to: 0; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                    }

                    // You: hover for Edit (back into the prompt) and Copy
                    HoverHandler { id: msgHover }
                    Row {
                        visible: msg.mine && msgHover.hovered && !Ai.busy
                        anchors { right: userBubble.left; rightMargin: 4; verticalCenter: userBubble.verticalCenter }
                        spacing: 2
                        HeadButton { icon: "edit"; onClicked: { prompt.text = msg.modelData.shown ?? msg.modelData.text; prompt.cursorPosition = prompt.length; prompt.forceActiveFocus(); } }
                        HeadButton { icon: "content_copy"; onClicked: Ai.copy(msg.modelData.shown ?? msg.modelData.text) }
                    }
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
                            visible: !msg.modelData.renames && msg.modelData.kind !== "wa" && msg.modelData.kind !== "act"
                            width: parent.width
                            radius: Theme.radius.md
                            color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
                            border.width: 1; border.color: Theme.border
                            readonly property Item shown: waiting.visible ? waiting : msg.live ? liveAnswer : answer
                            height: visible ? Math.max(40, shown.implicitHeight + Theme.space.s3 * 2) : 0
                            Behavior on height { enabled: msg.live; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
                            // The finished answer: text, with code blocks as cards (Copy / Run)
                            Column {
                                id: answer
                                x: Theme.space.s3; y: Theme.space.s3
                                width: parent.width - Theme.space.s3 * 2
                                spacing: 2
                                visible: !msg.live && msg.modelData.text !== ""
                                Repeater {
                                    model: msg.live || msg.mine ? [] : Md.segments(msg.modelData.text)
                                    delegate: Loader {
                                        id: seg
                                        required property var modelData
                                        width: answer.width
                                        sourceComponent: modelData.code ? codeSeg : textSeg
                                        Component {
                                            id: textSeg
                                            TextEdit {
                                                readOnly: true
                                                selectByMouse: true
                                                wrapMode: Text.Wrap
                                                textFormat: TextEdit.RichText
                                                width: seg.width
                                                text: Md.toHtml(seg.modelData.text.replace(/^\n+|\n+$/g, ""), win.mdColors)
                                                onLinkActivated: link => Qt.openUrlExternally(link)
                                                color: Theme.text
                                                selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                                                font.family: Theme.fontUi
                                                font.pixelSize: 14
                                            }
                                        }
                                        Component { id: codeSeg; CodeActions { width: seg.width; block: ({ lang: seg.modelData.lang, code: seg.modelData.text }) } }
                                    }
                                }
                            }
                            // While it's being written: plain text and a soft cursor
                            Text {
                                id: liveAnswer
                                visible: msg.live && Ai.streamText !== ""
                                x: Theme.space.s3; y: Theme.space.s3
                                width: parent.width - Theme.space.s3 * 2
                                wrapMode: Text.Wrap
                                textFormat: Text.RichText
                                text: msg.live ? Md.toHtml(Ai.streamText, win.mdColors) + '<span style="color:' + win.mdColors.accent + ';">▍</span>' : ""
                                color: Theme.text
                                font.family: Theme.fontUi
                                font.pixelSize: 14
                            }
                            // Before the first words: what Halo is doing, over three shimmering
                            // lines where the answer will appear
                            Column {
                                id: waiting
                                visible: msg.live ? Ai.streamText === "" : msg.modelData.text === ""
                                x: Theme.space.s3; y: Theme.space.s3
                                width: parent.width - Theme.space.s3 * 2
                                spacing: 8
                                Row {
                                    spacing: Theme.space.s2
                                    HaloOrb { size: 16; mood: "thinking"; face: false; anchors.verticalCenter: parent.verticalCenter }
                                    LText {
                                        role: "caption"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter
                                        text: Ai.phase === "reading" ? "Reading what you attached…"
                                            : Ai.phase === "looking" ? "Looking at your screen…"
                                            : Ai.slow ? (Ai.local ? "Still working — the first answer loads the model (images take longer on this computer)…" : "Still waiting for " + Ai.providerLabel + "…")
                                            : Ai.local && !Ai.modelLoaded ? "Loading " + Ai.model + "…" : "Thinking…"
                                    }
                                }
                                Repeater {
                                    model: [0.92, 0.78, 0.55]
                                    delegate: Rectangle {
                                        required property real modelData
                                        required property int index
                                        width: waiting.width * modelData; height: 9; radius: 4.5
                                        color: Theme.withAlpha(Theme.text, 0.07)
                                        clip: true
                                        Rectangle {
                                            width: parent.width * 0.45; height: parent.height
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: "transparent" }
                                                GradientStop { position: 0.5; color: Theme.withAlpha(Theme.accent, 0.22) }
                                                GradientStop { position: 1; color: "transparent" }
                                            }
                                            NumberAnimation on x {
                                                running: waiting.visible && win.visible && !Theme.reducedMotion
                                                from: -waiting.width * 0.45; to: waiting.width; duration: 1400; loops: Animation.Infinite
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        // Halo did (or offers to do) something itself: an action, a brief, a check
                        Rectangle {
                            id: actCard
                            visible: msg.modelData.kind === "act"
                            readonly property var c: msg.modelData.card ?? ({})
                            readonly property bool asking: msg.modelData.state === "ask"
                            readonly property color tone: c.tone === "concerned" ? Theme.warning : Theme.accent
                            width: answerCol.width
                            height: visible ? actCol.implicitHeight + Theme.space.s3 * 2 : 0
                            radius: Theme.radius.md
                            color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
                            border.width: 1; border.color: asking ? Theme.withAlpha(tone, 0.4) : Theme.border
                            Rectangle {
                                id: actTile
                                x: Theme.space.s3; y: Theme.space.s3
                                width: 32; height: 32; radius: Theme.radius.sm
                                color: Theme.withAlpha(actCard.tone, 0.14)
                                LIcon { anchors.centerIn: parent; icon: actCard.c.icon ?? "auto_awesome"; size: 18; fill: 1; color: actCard.tone }
                                scale: 0.7
                                Component.onCompleted: scale = 1
                                Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveOvershoot } }
                            }
                            Column {
                                id: actCol
                                anchors { left: actTile.right; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s3; top: parent.top; topMargin: Theme.space.s3 }
                                spacing: 4
                                LText { width: parent.width; wrapMode: Text.Wrap; role: "bodyStrong"; text: actCard.c.title ?? ""; textFormat: Text.PlainText }
                                LText { visible: text !== ""; width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary; text: actCard.c.text ?? ""; textFormat: Text.PlainText }
                                LText { visible: !actCard.asking && (msg.modelData.chose ?? "") !== ""; role: "caption"; color: Theme.textMuted; text: "✓ " + (msg.modelData.chose ?? "") }
                                Flow {
                                    visible: actCard.asking
                                    width: parent.width; spacing: 4; topPadding: 2
                                    Repeater {
                                        model: (actCard.c.actions ?? []).filter(a => a)
                                        delegate: ActionPill { required property var modelData; required property int index; outlined: true
                                                               icon: modelData.icon ?? ""; text: modelData.label; onClicked: Ai.actDecide(msg.index, index) }
                                    }
                                }
                            }
                        }
                        // /rename: check the new names, then apply (and undo)
                        RenamePlan { visible: !!msg.modelData.renames; width: answerCol.width; msgIndex: msg.index; msgData: msg.modelData }
                        // WhatsApp: a draft you confirm; Send opens WhatsApp pre-filled, you press Enter there
                        Rectangle {
                            id: waCard
                            visible: msg.modelData.kind === "wa"
                            readonly property var d: msg.modelData.draft ?? ({})
                            readonly property string st: msg.modelData.state ?? "ask"
                            width: answerCol.width
                            height: visible ? waCol.implicitHeight + Theme.space.s4 * 2 : 0
                            radius: Theme.radius.md
                            color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
                            border.width: 1; border.color: st === "ask" ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
                            Column {
                                id: waCol
                                x: Theme.space.s4; y: Theme.space.s4
                                width: parent.width - Theme.space.s4 * 2
                                spacing: Theme.space.s2
                                Row {
                                    spacing: Theme.space.s2
                                    LIcon { icon: "chat"; size: 18; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                                    LText { role: "bodyStrong"; anchors.verticalCenter: parent.verticalCenter
                                            text: waCard.st === "sent" ? "Opened in WhatsApp — press Enter there to send"
                                                : waCard.st === "cancelled" ? "Not sent" : "Send WhatsApp message?" }
                                }
                                LText { role: "caption"; color: Theme.textMuted; text: "To: " + (waCard.d.title ?? "") }
                                Rectangle {
                                    width: parent.width; height: waText.implicitHeight + Theme.space.s3 * 2
                                    radius: Theme.radius.sm; color: Theme.withAlpha(Theme.accent, 0.1)
                                    LText { id: waText; x: Theme.space.s3; y: Theme.space.s3; width: parent.width - Theme.space.s3 * 2
                                            wrapMode: Text.Wrap; text: "“" + (waCard.d.text ?? "") + "”" }
                                }
                                LText {
                                    visible: waCard.st === "ask" && (msg.modelData.needsNumber ?? false)
                                    width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted
                                    text: "No number saved for this chat, so WhatsApp's own chat picker opens with the text ready (add numbers in Settings → WhatsApp)."
                                }
                                Row {
                                    visible: waCard.st === "ask"
                                    spacing: Theme.space.s2
                                    ActionPill { icon: "close"; text: "Cancel"; onClicked: Ai.waDecide(msg.index, false) }
                                    HoverTarget {
                                        width: sendLbl.implicitWidth + 36; height: 28
                                        onClicked: Ai.waDecide(msg.index, true)
                                        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.accent; z: -1 }
                                        Row { anchors.centerIn: parent; spacing: 5
                                              LIcon { icon: "send"; size: 14; fill: 1; color: Theme.onAccent; anchors.verticalCenter: parent.verticalCenter }
                                              LText { id: sendLbl; role: "bodyStrong"; color: Theme.onAccent; text: "Send"; anchors.verticalCenter: parent.verticalCenter } }
                                    }
                                }
                            }
                        }
                        // Answer actions
                        Row {
                            visible: msg.modelData.text !== "" && !msg.live
                            spacing: 4
                            ActionPill { icon: copied.running ? "check" : "content_copy"; text: copied.running ? "Copied" : "Copy"; onClicked: { Ai.copy(msg.modelData.text); copied.restart(); } Timer { id: copied; interval: 1400 } }
                            ActionPill { icon: "keyboard_return"; text: "Insert"; onClicked: Ai.insert(msg.blocks.length === 1 && msg.modelData.text.trim().startsWith("```") ? msg.blocks[0].code : msg.modelData.text) }
                            ActionPill { icon: "note_add"; text: "Save to notes"; onClicked: Ai.saveToNotes(msg.modelData.text) }
                            ActionPill { visible: Voice.canSpeak; icon: Voice.speaking && msg.last ? "stop" : "volume_up"; text: Voice.speaking && msg.last ? "Stop" : "Read aloud"
                                         onClicked: Voice.speaking ? Voice.stop() : Voice.say(msg.modelData.text, true) }
                            ActionPill { visible: msg.last; icon: "refresh"; text: "Retry"; onClicked: Ai.retry() }
                            LText { visible: msg.last; role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                                    text: "  " + Ai.model.replace(/:latest$/, "") + (Ai.speed > 0 ? " · " + Ai.speed + " tokens/s" : "") }
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
                property int histIdx: -1
                QQC.ScrollView {
                    anchors { left: parent.left; right: micBtn.visible ? micBtn.left : sendBtn.left; top: parent.top; bottom: parent.bottom; leftMargin: Theme.space.s4; topMargin: 12; bottomMargin: 8 }
                    QQC.TextArea {
                        id: prompt
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        placeholderText: Voice.listening ? "Listening…" : Voice.transcribing ? "Writing down what you said…"
                                       : Ai.busy ? ({ reading: "Reading context…", looking: "Looking at your screen…" })[Ai.phase] ?? "Thinking…"
                                       : !Ai.configured ? "Tell " + Halo.name + " what to do — answers need a model (⚙)"
                                       : Ai.messages.length ? "Ask a follow-up" : "Ask " + Halo.name + " anything, or type / for skills"
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
                                if (Voice.listening) Voice.cancel(); else if (Voice.speaking) Voice.stop(); else if (Ai.busy) Ai.stop(); else if (text !== "") text = ""; else Ai.open = false;
                                event.accepted = true;
                            } else if (event.key === Qt.Key_V && ctrl) {
                                Ai.pasteImage();            // a picture on the clipboard is attached; text pastes as usual
                            } else if (event.key === Qt.Key_L && ctrl) { Ai.clear(); event.accepted = true; }
                            else if (event.key === Qt.Key_R && ctrl) { Ai.retry(); event.accepted = true; }
                        }
                    }
                }
                // Talk instead of typing (whisper.cpp, on this computer)
                HoverTarget {
                    id: micBtn
                    visible: Voice.canListen
                    anchors { right: sendBtn.left; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32
                    onClicked: Voice.toggle()
                    Rectangle { anchors.fill: parent; radius: 16; color: Voice.listening ? Theme.withAlpha(Theme.accent, 0.22) : "transparent"
                                border.width: Voice.listening ? 1 : 0; border.color: Theme.withAlpha(Theme.accent, 0.5)
                                scale: 1 + (Voice.listening ? Voice.level * 0.25 : 0)
                                Behavior on scale { NumberAnimation { duration: 90 } } }
                    LIcon { anchors.centerIn: parent; icon: Voice.transcribing ? "hourglass_top" : "mic"; size: 18; fill: Voice.listening ? 1 : 0
                            color: Voice.listening ? Theme.accent : Theme.textMuted }
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
                text: "Enter to send · / for skills · drop or paste files and pictures · ↑ earlier questions · Ctrl+L new chat" + (Ai.local ? " · nothing leaves this computer" : "")
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
    function ctxIcon(k) { return ({ selection: "format_quote", clipboard: "content_paste", screen: "screenshot_monitor", window: "select_window", system: "monitor_heart", project: "commit", file: "attach_file", college: "school", notes: "edit_note", lens: "gesture" })[k] ?? "attach_file"; }
    function ctxLabel(k) { return ({ selection: "Selection", clipboard: "Clipboard", screen: "Screen", window: "Window", system: "System", project: "Project", file: "Files", college: "Classes & marks", notes: "Notes", lens: "Circled" })[k] ?? k; }
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
        property bool outlined: false
        width: apRow.implicitWidth + (outlined ? 22 : 16); height: outlined ? 30 : 26
        Rectangle { visible: ap.outlined; anchors.fill: parent; radius: height / 2; z: -1; color: Theme.withAlpha(Theme.text, 0.04)
                    border.width: 1; border.color: ap.containsMouse ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border }
        Row { id: apRow; anchors.centerIn: parent; spacing: ap.outlined ? 6 : 4
              LIcon { visible: ap.icon !== ""; icon: ap.icon; size: ap.outlined ? 15 : 14; color: ap.outlined ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; color: ap.outlined ? Theme.text : Theme.textSecondary; text: ap.text; anchors.verticalCenter: parent.verticalCenter } }
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
    // A code block in an answer: a card with its language, Copy, and Run for
    // short shell commands (a second press runs; risky ones say so in red)
    component CodeActions: Rectangle {
        id: ca
        property var block
        property bool confirming: false
        readonly property bool shell: Ai.isShell(block.lang) && block.code.split("\n").length <= 12
        readonly property bool risky: Ai.risky(block.code)
        implicitHeight: caHead.height + caBody.implicitHeight + 16
        height: implicitHeight
        radius: Theme.radius.sm
        color: Theme.withAlpha(Theme.bg, 0.55)
        border.width: 1
        border.color: ca.confirming ? Theme.withAlpha(ca.risky ? Theme.error : Theme.accent, 0.5) : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
        Timer { id: confirmTimer; interval: 5000; onTriggered: ca.confirming = false }
        Item {
            id: caHead
            width: parent.width; height: 30
            Row {
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                spacing: 6
                LIcon { icon: ca.shell ? "terminal" : "code"; size: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "caption"
                    color: ca.confirming ? (ca.risky ? Theme.error : Theme.accent) : Theme.textMuted
                    text: ca.confirming ? (ca.risky ? "This can delete or change things — run anyway?" : "Run it in a terminal?")
                                        : (ca.block.lang || (ca.shell ? "shell" : "code"))
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                spacing: 2
                ActionPill { icon: caCopied.running ? "check" : "content_copy"; text: caCopied.running ? "Copied" : "Copy"; onClicked: { Ai.copy(ca.block.code); caCopied.restart(); } Timer { id: caCopied; interval: 1400 } }
                ActionPill {
                    visible: ca.shell
                    icon: "play_arrow"; text: ca.confirming ? "Run" : "Run…"
                    onClicked: { if (ca.confirming) { ca.confirming = false; Ai.run(ca.block.code); } else { ca.confirming = true; confirmTimer.restart(); } }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.border }
        }
        TextEdit {
            id: caBody
            x: 12; y: caHead.height + 8
            width: parent.width - 24
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.WrapAnywhere
            text: ca.block.code
            color: Theme.text
            selectionColor: Theme.withAlpha(Theme.accent, 0.4)
            font.family: Theme.fontMono
            font.pixelSize: 13
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
