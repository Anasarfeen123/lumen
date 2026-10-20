// Circle to search (services/Lens.qml): the frozen screen under a soft dim.
// Draw round something (a glowing stroke follows the pointer), click a window
// to take all of it, or drag a box. The circled part lifts out of the dim and
// a sheet rises from the bottom: ask Halo about it, or copy, translate,
// search, Google Lens, save, send to your phone.
//   Esc closes · right-click (or Redo) draws again · Enter asks
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import "../ai/markdown.js" as Md

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool showing: Lens.open && (monitor?.name ?? "") === Lens.screen

    // Leaving: the frozen screen fades into the live one and the sheet drops away
    property real fade: showing ? 1 : 0
    Behavior on fade { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? 90 : 240); easing.type: Easing.OutCubic } }
    Binding { target: win.contentItem; property: "opacity"; value: win.fade }
    visible: showing || fade > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-lens"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // frozen-image pixels per window point (HiDPI / scaled monitors)
    readonly property real px: shot.sourceSize.width > 0 ? shot.sourceSize.width / width : 1
    property var points: []
    // the stroke, smoothed (two rounds of Chaikin's corner cutting) so it flows
    readonly property var smooth: {
        let p = points;
        for (let k = 0; k < 2 && p.length > 2; k++) {
            const q = [p[0]];
            for (let i = 0; i < p.length - 1; i++) {
                const a = p[i], b = p[i + 1];
                q.push(Qt.point(0.75 * a.x + 0.25 * b.x, 0.75 * a.y + 0.25 * b.y), Qt.point(0.25 * a.x + 0.75 * b.x, 0.25 * a.y + 0.75 * b.y));
            }
            q.push(p[p.length - 1]);
            p = q;
        }
        return p;
    }
    property bool drawing: false
    property rect box: Qt.rect(0, 0, 0, 0)      // the selection, in window points
    readonly property bool hasBox: box.width > 0

    onShowingChanged: {
        points = []; drawing = false; box = Qt.rect(0, 0, 0, 0); question.text = "";
        if (showing) { Hyprland.refreshToplevels(); enter.restart(); Qt.callLater(() => keys.forceActiveFocus()); }
    }

    // Behind the frozen screen as it settles back: a deep backdrop
    Rectangle { anchors.fill: parent; color: "#05070a"; opacity: win.lift }

    // The frozen screen settles back a touch into a rounded card while you
    // circle (like a phone's circle to search), and springs back when done.
    // Everything that works in screen points lives inside it, unscaled.
    property real lift: showing ? 1 : 0
    Behavior on lift { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? 520 : 260); easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } }
    // the card's rounded corners (a mask: a clipping rectangle won't stay see-through)
    Item {
        id: stageMask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: stage.radius; color: "#ffffff" }
    }
    Item {
        id: stage
        anchors.fill: parent
        readonly property real radius: 30 * win.lift
        scale: 1 - 0.032 * win.lift
        layer.enabled: win.lift > 0.001
        layer.effect: MultiEffect { maskEnabled: true; maskSource: stageMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }

    Image {
        id: shot
        anchors.fill: parent
        source: Lens.shot ? "file://" + Lens.shot : ""
        fillMode: Image.Stretch
        cache: false
        asynchronous: false
        smooth: true
    }

    // ── the dim, with the circled part left bright ──
    readonly property color dim: Qt.rgba(0, 0, 0, win.hasBox ? 0.5 : 0.28)
    Item {
        anchors.fill: parent
        opacity: dimIn.value
        QtObject { id: dimIn; property real value: 0 }
        Rectangle { x: 0; y: 0; width: parent.width; height: win.hasBox ? win.box.y : parent.height; color: stage.dim }
        Rectangle { visible: win.hasBox; x: 0; y: win.box.y; width: win.box.x; height: win.box.height; color: stage.dim }
        Rectangle { visible: win.hasBox; x: win.box.x + win.box.width; y: win.box.y; width: parent.width - x; height: win.box.height; color: stage.dim }
        Rectangle { visible: win.hasBox; x: 0; y: win.box.y + win.box.height; width: parent.width; height: parent.height - y; color: stage.dim }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
    }
    // Arriving: a glowing rim and one shimmer across the screen
    Rectangle {
        id: rim
        anchors.fill: parent
        color: "transparent"
        border.width: 3
        border.color: Theme.accent
        radius: stage.radius
        opacity: 0
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 1; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
    }
    Rectangle {
        id: shimmer
        width: parent.width * 0.35; height: parent.height
        x: -width
        opacity: 0.0
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Theme.withAlpha(Theme.accent, 0.16) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    SequentialAnimation {
        id: enter
        ScriptAction { script: { dimIn.value = 0; rim.opacity = 0; shimmer.x = -shimmer.width; } }
        ParallelAnimation {
            NumberAnimation { target: dimIn; property: "value"; to: 1; duration: Theme.reducedMotion ? 0 : 260 }
            SequentialAnimation {
                NumberAnimation { target: rim; property: "opacity"; to: 0.85; duration: Theme.reducedMotion ? 0 : 200 }
                NumberAnimation { target: rim; property: "opacity"; to: 0.35; duration: Theme.reducedMotion ? 0 : 900; easing.type: Easing.OutCubic }
            }
            SequentialAnimation {
                PropertyAction { target: shimmer; property: "opacity"; value: Theme.reducedMotion ? 0 : 1 }
                NumberAnimation { target: shimmer; property: "x"; to: win.width; duration: Theme.reducedMotion ? 0 : 900; easing.type: Easing.InOutCubic }
                PropertyAction { target: shimmer; property: "opacity"; value: 0 }
            }
        }
    }

    // A hint until you draw
    Rectangle {
        visible: !win.hasBox && !win.drawing
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        width: hintRow.implicitWidth + 32; height: 40; radius: 20
        color: Theme.withAlpha(Theme.bg, 0.82)
        border.width: 1; border.color: Theme.border
        Row {
            id: hintRow
            anchors.centerIn: parent
            spacing: 10
            HaloOrb { size: 20; mood: "rest"; anchors.verticalCenter: parent.verticalCenter; face: Persist.data.haloFace ?? true }
            LText { text: "Circle anything · click a window · Esc to close"; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ── drawing ──
    MouseArea {
        id: drawArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.CrossCursor
        enabled: !sheetArea.containsMouse
        property point start
        onPressed: m => {
            if (m.button === Qt.RightButton) { win.redo(); return; }
            win.points = [Qt.point(m.x, m.y)];
            start = Qt.point(m.x, m.y);
            win.drawing = true;
            win.box = Qt.rect(0, 0, 0, 0);
            Lens.reset();
        }
        onPositionChanged: m => {
            if (!win.drawing) return;
            const p = win.points, l = p[p.length - 1];
            if (Math.hypot(m.x - l.x, m.y - l.y) < 3) return;
            p.push(Qt.point(m.x, m.y));
            win.points = p;
        }
        onReleased: m => {
            if (!win.drawing) return;
            win.drawing = false;
            const p = win.points;
            const xs = p.map(q => q.x), ys = p.map(q => q.y);
            let r = Qt.rect(Math.min(...xs), Math.min(...ys), Math.max(...xs) - Math.min(...xs), Math.max(...ys) - Math.min(...ys));
            if (r.width < 8 && r.height < 8) r = win.windowAt(m.x, m.y);      // a click: the window under it
            else r = Qt.rect(r.x - 10, r.y - 10, r.width + 20, r.height + 20);
            // keep it on screen, at least 24 px
            const x = Math.max(0, r.x), y = Math.max(0, r.y);
            r = Qt.rect(x, y, Math.max(24, Math.min(win.width - x, r.x + r.width - x)), Math.max(24, Math.min(win.height - y, r.y + r.height - y)));
            win.box = r;
            fadeStroke.restart();
            Lens.pick(Qt.rect(r.x * win.px, r.y * win.px, r.width * win.px, r.height * win.px));
            Qt.callLater(() => question.forceActiveFocus());
        }
    }
    function windowAt(x, y) {
        const ox = win.screen?.x ?? 0, oy = win.screen?.y ?? 0, ws = monitor?.activeWorkspace?.id;
        const hit = Hyprland.toplevels.values.map(t => t.lastIpcObject ?? {})
            .filter(o => o.workspace?.id === ws && o.at && o.size)
            .sort((a, b) => (b.floating === true) - (a.floating === true))
            .find(o => x >= o.at[0] - ox && x < o.at[0] - ox + o.size[0] && y >= o.at[1] - oy && y < o.at[1] - oy + o.size[1]);
        return hit ? Qt.rect(hit.at[0] - ox, hit.at[1] - oy, hit.size[0], hit.size[1]) : Qt.rect(0, 0, win.width, win.height);
    }
    // A piece picked from outside (lens IPC) shows the same way
    Connections {
        target: Lens
        function onSelChanged() { if (win.showing && !win.hasBox && Lens.picked) win.box = Qt.rect(Lens.sel.x / win.px, Lens.sel.y / win.px, Lens.sel.width / win.px, Lens.sel.height / win.px); }
    }
    function redo() { points = []; box = Qt.rect(0, 0, 0, 0); question.text = ""; Lens.reset(); keys.forceActiveFocus(); }

    // The stroke: a glowing line that follows the pointer, fading once you let go
    Shape {
        id: stroke
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 1
        layer.enabled: true
        layer.samples: 4
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.8; shadowOpacity: 1; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
        ShapePath {
            strokeColor: Qt.tint(Theme.accent, "#55ffffff")
            strokeWidth: 6
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathPolyline { path: win.smooth }
        }
    }
    SequentialAnimation {
        id: fadeStroke
        NumberAnimation { target: stroke; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 420; easing.type: Easing.OutCubic }
        ScriptAction { script: { win.points = []; stroke.opacity = 1; } }
    }

    // The circled part: a glowing frame with corner brackets
    Item {
        id: frame
        visible: win.hasBox
        x: win.box.x; y: win.box.y; width: win.box.width; height: win.box.height
        Behavior on x { enabled: !Theme.reducedMotion; SpringAnimation { spring: 4; damping: 0.4 } }
        Behavior on y { enabled: !Theme.reducedMotion; SpringAnimation { spring: 4; damping: 0.4 } }
        Behavior on width { enabled: !Theme.reducedMotion; SpringAnimation { spring: 4; damping: 0.4 } }
        Behavior on height { enabled: !Theme.reducedMotion; SpringAnimation { spring: 4; damping: 0.4 } }
        // the circled piece, lifted a little off the screen with a soft shadow
        property real pop: 0
        onVisibleChanged: if (visible) { pop = 0; popIn.restart(); }
        NumberAnimation { id: popIn; target: frame; property: "pop"; from: 0; to: 1; duration: Theme.reducedMotion ? 0 : 480; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        Item {
            anchors.fill: parent
            scale: 1 + 0.018 * frame.pop
            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 1; shadowOpacity: 0.55 * frame.pop; shadowVerticalOffset: 10 * frame.pop; shadowHorizontalOffset: 0 }
            ClippingRectangle {
                anchors.fill: parent
                radius: 12
                color: "transparent"
                ShaderEffectSource {
                    anchors.fill: parent
                    sourceItem: shot
                    sourceRect: Qt.rect(frame.x, frame.y, frame.width, frame.height)
                    live: true
                }
                Rectangle { anchors.fill: parent; radius: 12; color: "transparent"; border.width: 1; border.color: Theme.withAlpha("#ffffff", 0.25) }
            }
        }
        // accent corner brackets that spring into place
        Repeater {
            model: 4
            Item {
                required property int index
                readonly property bool atRight: index % 2 === 1
                readonly property bool atBottom: index >= 2
                readonly property real arm: Math.min(26, Math.min(frame.width, frame.height) / 3)
                readonly property real out: 7 + 10 * (1 - frame.pop)
                width: arm; height: arm
                x: atRight ? frame.width - arm + out : -out
                y: atBottom ? frame.height - arm + out : -out
                opacity: frame.pop
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 0.6; shadowOpacity: 0.9; shadowHorizontalOffset: 0; shadowVerticalOffset: 0 }
                Rectangle { width: parent.width; height: 4; radius: 2; color: Theme.accent; y: parent.atBottom ? parent.height - 4 : 0 }
                Rectangle { width: 4; height: parent.height; radius: 2; color: Theme.accent; x: parent.atRight ? parent.width - 4 : 0 }
            }
        }
        // reading the text: a light sweeping down the piece
        Rectangle {
            visible: Lens.reading && !Theme.reducedMotion
            width: parent.width; height: Math.min(60, parent.height / 2)
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: Theme.withAlpha(Theme.accent, 0.25) }
            }
            NumberAnimation on y { running: Lens.reading; from: -60; to: frame.height; duration: 1100; loops: Animation.Infinite }
            clip: true
        }
    }

    }   // stage

    // ── the sheet ──
    MouseArea { id: sheetArea; anchors.fill: sheet; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    GlassSurface {
        id: sheet
        level: "panel"
        readonly property bool up: win.hasBox && !win.drawing && win.showing
        opacity: up ? 1 : 0
        scale: up ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        transformOrigin: Item.Bottom
        width: Math.min(720, win.width - 48)
        height: sheetCol.implicitHeight + Theme.space.s4 * 2 + 6
        anchors.horizontalCenter: parent.horizontalCenter
        y: up ? win.height - height - 28 : win.height + 20
        Behavior on y { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Behavior on height { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal } }
        radius: Theme.radius.lg

        // a grab handle, as on a phone's sheet
        Rectangle { anchors { top: parent.top; topMargin: 7; horizontalCenter: parent.horizontalCenter } width: 36; height: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.22) }

        Column {
            id: sheetCol
            x: Theme.space.s4; y: Theme.space.s4 + 6
            width: parent.width - Theme.space.s4 * 2
            spacing: Theme.space.s3

            Row {
                width: parent.width
                spacing: Theme.space.s3
                ClippingRectangle {
                    id: thumb
                    readonly property real aspect: win.box.width / Math.max(1, win.box.height)
                    width: Math.min(120, 64 * aspect); height: Math.max(24, Math.min(64, 120 / aspect))
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.radius.sm
                    color: Theme.withAlpha(Theme.text, 0.06)
                    Image { anchors.fill: parent; source: Lens.cropReady ? "file://" + Lens.cropReady : ""; fillMode: Image.PreserveAspectFit; cache: false; asynchronous: true }
                }
                Column {
                    width: parent.width - thumb.width - parent.spacing
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    LText { role: "caption"; color: Theme.textMuted
                            text: Lens.reading ? "Reading the text…" : Lens.text ? (n => n + (n === 1 ? " word" : " words") + " found")(Lens.text.split(/\s+/).filter(w => w).length) : "No text in it — Halo can still look at the picture" }
                    TextEdit {
                        visible: Lens.text !== ""
                        width: parent.width
                        readOnly: true; selectByMouse: true
                        wrapMode: Text.Wrap
                        text: Lens.text.length > 220 ? Lens.text.slice(0, 220) + "…" : Lens.text
                        color: Theme.text
                        selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                        font.family: Theme.fontUi; font.pixelSize: 13
                        height: Math.min(contentHeight, 54); clip: true
                    }
                }
            }

            // Ask Halo
            Rectangle {
                width: parent.width; height: 44; radius: 22
                color: Theme.withAlpha(Theme.text, 0.05)
                border.width: 1; border.color: question.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
                HaloOrb { id: askOrb; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 22; mood: Lens.asked ? Halo.mood : "rest"; face: Persist.data.haloFace ?? true }
                QQC.TextField {
                    id: question
                    anchors { left: askOrb.right; leftMargin: 10; right: askBtn.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    background: null
                    color: Theme.text
                    placeholderText: Ai.configured ? "Ask " + Halo.name + " about this — or just press Enter" : "Halo needs a model to answer — Settings → Halo"
                    placeholderTextColor: Theme.textMuted
                    font.family: Theme.fontUi; font.pixelSize: 14
                    selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                    onAccepted: if (Lens.crop) Lens.ask(text)
                    Keys.onEscapePressed: Lens.close()
                }
                HoverTarget {
                    id: askBtn
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 32; height: 32
                    onClicked: if (Lens.crop) Lens.ask(question.text)
                    Rectangle { anchors.fill: parent; radius: 16; color: Theme.accent; z: -1 }
                    LIcon { anchors.centerIn: parent; icon: "arrow_upward"; size: 18; fill: 1; color: Theme.onAccent }
                }
            }

            // Halo's answer, right here
            Rectangle {
                id: answerBox
                visible: Lens.asked
                width: parent.width
                height: visible ? Math.min(answer.implicitHeight + Theme.space.s3 * 2, win.height * 0.4) : 0
                radius: Theme.radius.md
                color: Theme.withAlpha(Theme.surfaceElevated, 0.8)
                border.width: 1; border.color: Theme.border
                readonly property string txt: Ai.busy ? Ai.streamText : (Ai.messages.length ? (Ai.messages[Ai.messages.length - 1].text ?? "") : "")
                Flickable {
                    anchors { fill: parent; margins: Theme.space.s3 }
                    contentHeight: answer.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Text {
                        id: answer
                        width: parent.width
                        wrapMode: Text.Wrap
                        textFormat: Text.RichText
                        color: Theme.text
                        font.family: Theme.fontUi; font.pixelSize: 14
                        text: answerBox.txt ? Md.toHtml(answerBox.txt, { accent: Theme.accent.toString(), muted: Theme.textMuted.toString(), mono: Theme.fontMono,
                                                                               codeBg: Theme.surfaceHover.toString(), blockBg: Theme.surface.toString() })
                              : (Ai.error ? '<span style="color:' + Theme.error + '">' + Ai.error + '</span>' : (Ai.phase === "reading" || Ai.phase === "" ? "Looking…" : "Thinking…"))
                        onLinkActivated: link => Qt.openUrlExternally(link)
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                Chip { visible: Lens.asked && !Ai.busy && Ai.messages.length > 0; primary: true; icon: "open_in_full"; text: "Continue in " + Halo.name; onClicked: { Lens.close(); Ai.show(); } }
                Chip { visible: Lens.text !== ""; primary: !Lens.asked; icon: "content_copy"; text: "Copy text"; onClicked: Lens.copyText() }
                Chip { visible: Lens.text !== "" && Ai.configured; icon: "translate"; text: "Translate"; onClicked: Lens.translate() }
                Chip { visible: Lens.text !== ""; icon: "travel_explore"; text: "Search the web"; onClicked: Lens.webSearch() }
                Chip { icon: "image_search"; text: "Google Lens"; onClicked: Lens.google() }
                Chip { icon: "image"; text: "Copy picture"; onClicked: Lens.copyImage() }
                Chip { icon: "save"; text: "Save"; onClicked: Lens.save() }
                Chip { visible: !!Link.phone; icon: "smartphone"; text: "Send to phone"; onClicked: Lens.toPhone() }
                Chip { icon: "gesture"; text: "Redo"; onClicked: win.redo() }
            }
        }
    }

    component Chip: HoverTarget {
        id: chip
        property string icon
        property string text
        property bool primary: false
        width: chipRow.implicitWidth + 22; height: 30
        Rectangle {
            anchors.fill: parent; radius: height / 2; z: -1
            color: chip.primary ? Theme.withAlpha(Theme.accent, 0.2) : Theme.withAlpha(Theme.text, chip.containsMouse ? 0.1 : 0.06)
            border.width: 1; border.color: chip.primary ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border
        }
        Row { id: chipRow; anchors.centerIn: parent; spacing: 6
              LIcon { icon: chip.icon; size: 15; color: chip.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: chip.text; color: chip.primary ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }

    // Keyboard: Esc closes (or steps back from a selection), Enter asks
    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Escape) { if (win.hasBox && !Lens.asked) win.redo(); else Lens.close(); e.accepted = true; }
            else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && Lens.crop) { Lens.ask(""); e.accepted = true; }
            else if (e.key === Qt.Key_C && (e.modifiers & Qt.ControlModifier)) { Lens.copyText(); e.accepted = true; }
        }
    }
}
