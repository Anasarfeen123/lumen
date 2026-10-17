// Halo, in person: the ring of light with a quiet face. Its mood shows in how
// it moves, never in words (DESIGN.md: motion explains):
//   rest       breathes slowly, blinks, glances about now and then
//   listening  eyes wide, the ring swells with your voice (level 0–1)
//   thinking   looks up and aside, a point of light circles the ring
//   speaking   ripples go out from the ring
//   happy      ^ ^ eyes, one bright spin
//   concerned  amber, eyes narrowed, one small shake
//   sleeping   dimmed, eyes closed, breathing slower
// Sizes: 18 in the resting island, 40–48 in cards, 64+ in the Halo panel.
//
// The ring is lit glass: a conic sheen runs round it, still at rest, turning
// while Halo listens, thinks or speaks. At rest nothing animates continuously
// unless `breathes` (the island turns it off: the idle desktop spends nothing,
// DESIGN.md §0) — it only blinks and glances now and then.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.theme

Item {
    id: root
    property string mood: "rest"
    property real size: 20
    property real level: 0              // microphone level while listening
    property bool face: true
    property real lookX: 0              // -1 … 1: where it glances (a window it was told about…)
    property real lookY: 0
    property bool breathes: true        // a slow breath at rest (off in the island)
    width: size; height: size

    readonly property bool still: Theme.reducedMotion
    readonly property color tone: mood === "concerned" ? Theme.warning
                                 : mood === "sleeping" ? Theme.textMuted : Theme.accent
    readonly property real stroke: Math.max(1.6, size * 0.1)

    // ── ripples (speaking, happy) ──
    Repeater {
        model: 2
        Rectangle {
            id: ripple
            required property int index
            anchors.centerIn: parent
            width: root.size; height: width; radius: width / 2
            color: "transparent"
            border.width: Math.max(1, root.stroke * 0.6)
            border.color: root.tone
            opacity: 0
            visible: running.running
            SequentialAnimation {
                id: running
                running: (root.mood === "speaking" || root.mood === "happy") && !root.still
                loops: Animation.Infinite
                PauseAnimation { duration: ripple.index * 700 }
                ParallelAnimation {
                    NumberAnimation { target: ripple; property: "scale"; from: 1; to: 1.7; duration: 1400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.5; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        // breathing + the voice
        property real breath: 1
        property real shakeX: 0
        transform: Translate { x: body.shakeX }
        scale: breath * (root.mood === "listening" ? 1 + Math.min(1, root.level) * 0.14 : 1)
        Behavior on scale { enabled: root.mood === "listening"; NumberAnimation { duration: 90 } }
        opacity: root.mood === "sleeping" ? 0.62 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }

        SequentialAnimation on breath {
            running: !root.still && root.visible && (root.breathes || root.mood === "concerned") && ["rest", "sleeping", "concerned"].includes(root.mood)
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { to: 1.045; duration: root.mood === "sleeping" ? 3200 : 2100; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: root.mood === "sleeping" ? 3200 : 2100; easing.type: Easing.InOutSine }
        }

        // the plate: a soft light from above
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0; color: Theme.withAlpha(root.tone, root.mood === "sleeping" ? 0.09 : 0.22) }
                GradientStop { position: 1; color: Theme.withAlpha(root.tone, root.mood === "sleeping" ? 0.03 : 0.07) }
            }
        }
        // the ring: lit glass, a conic sheen running round it
        Item {
            id: ring
            anchors.fill: parent
            property real sheen: 300            // where the light sits (degrees)
            property real w: root.mood === "listening" ? root.stroke * (1 + Math.min(1, root.level) * 0.9) : root.stroke
            Behavior on w { NumberAnimation { duration: 90 } }
            readonly property real c: root.size / 2
            layer.enabled: root.size >= 14
            layer.samples: 4
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: root.tone; shadowBlur: 0.7
                shadowOpacity: root.mood === "sleeping" ? 0.15 : root.mood === "rest" ? 0.45 : 0.85
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillRule: ShapePath.OddEvenFill
                    fillGradient: ConicalGradient {
                        centerX: ring.c; centerY: ring.c; angle: ring.sheen
                        GradientStop { position: 0.0; color: Qt.tint(root.tone, "#88ffffff") }
                        GradientStop { position: 0.18; color: root.tone }
                        GradientStop { position: 0.5; color: Qt.darker(root.tone, 1.35) }
                        GradientStop { position: 0.82; color: root.tone }
                        GradientStop { position: 1.0; color: Qt.tint(root.tone, "#88ffffff") }
                    }
                    PathAngleArc { centerX: ring.c; centerY: ring.c; radiusX: ring.c; radiusY: ring.c; startAngle: 0; sweepAngle: 360 }
                    PathMove { x: ring.c + ring.c - ring.w; y: ring.c }
                    PathAngleArc { centerX: ring.c; centerY: ring.c; radiusX: ring.c - ring.w; radiusY: ring.c - ring.w; startAngle: 0; sweepAngle: 360 }
                }
            }
            // the light turns while Halo is busy with you, and rests where it stopped
            NumberAnimation on sheen {
                running: !root.still && root.visible && ["listening", "thinking", "speaking"].includes(root.mood)
                from: ring.sheen; to: ring.sheen + 360; loops: Animation.Infinite
                duration: root.mood === "thinking" ? 1600 : 4200
            }
        }

        // a point of light travelling round (thinking)
        Item {
            anchors.fill: parent
            visible: root.mood === "thinking"
            RotationAnimation on rotation { from: 0; to: 360; duration: 1300; loops: Animation.Infinite; running: root.mood === "thinking" && !root.still }
            Rectangle {
                width: root.stroke * 1.5; height: width; radius: width / 2
                x: (root.size - width) / 2; y: -width * 0.25
                color: Qt.tint(root.tone, "#aaffffff")
            }
        }

        // ── the face ──
        Item {
            id: eyes
            visible: root.face && root.size >= 14
            anchors.centerIn: parent
            width: root.size * 0.5; height: root.size * 0.3
            // glance: told where to look, else thinking looks up and aside, else wander
            property real wander: 0
            x: (parent.width - width) / 2 + root.size * 0.09 * (root.mood === "thinking" ? 0.7 : Math.max(-1, Math.min(1, root.lookX + wander)))
            y: (parent.height - height) / 2 + root.size * 0.07 * (root.mood === "thinking" ? -0.8 : root.mood === "sleeping" ? 0.4 : root.lookY)
            Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

            Eye { x: 0; side: -1 }
            Eye { x: eyes.width - width; side: 1 }
        }
        // one bright spin when something worked
        RotationAnimation on rotation { id: spin; from: 0; to: 360; duration: 900; easing.type: Easing.OutBack; running: false }
        SequentialAnimation {
            id: shake
            NumberAnimation { target: body; property: "shakeX"; to: -root.size * 0.06; duration: 60 }
            NumberAnimation { target: body; property: "shakeX"; to: root.size * 0.06; duration: 90 }
            NumberAnimation { target: body; property: "shakeX"; to: -root.size * 0.03; duration: 80 }
            NumberAnimation { target: body; property: "shakeX"; to: 0; duration: 70 }
        }
    }

    onMoodChanged: {
        if (still) return;
        if (mood === "happy") spin.restart();
        else if (mood === "concerned") shake.restart();
    }

    // blinking (not while asleep or delighted)
    property bool blink: false
    Timer {
        interval: 2600 + Math.random() * 4200
        running: root.face && !root.still && root.visible && ["rest", "listening", "speaking", "concerned"].includes(root.mood)
        repeat: true
        onTriggered: { interval = 2600 + Math.random() * 4200; root.blink = true; unblink.restart(); }
    }
    Timer { id: unblink; interval: 130; onTriggered: root.blink = false }
    // now and then, a look around
    Timer {
        interval: 7000
        running: root.face && !root.still && root.visible && root.mood === "rest" && root.lookX === 0
        repeat: true
        onTriggered: { interval = 5000 + Math.random() * 7000; eyes.wander = Math.random() < 0.5 ? 0 : (Math.random() < 0.5 ? -0.8 : 0.8); }
    }
    onLookXChanged: eyes.wander = 0

    component Eye: Item {
        id: eye
        property int side: 1
        width: root.size * 0.12; height: eyes.height
        readonly property bool arcUp: root.mood === "happy"
        readonly property bool closed: root.mood === "sleeping"
        // the open eye: a soft pill
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * (root.mood === "listening" ? 1.25 : 1)
            height: eye.arcUp || eye.closed ? width * 0.4
                  : root.blink ? Math.max(1, parent.height * 0.12)
                  : root.mood === "concerned" ? parent.height * 0.5
                  : root.mood === "listening" ? parent.height * 0.85 : parent.height * 0.68
            radius: width / 2
            color: root.tone
            opacity: eye.arcUp ? 0 : 1
            rotation: root.mood === "concerned" ? eye.side * -14 : 0
            Behavior on height { NumberAnimation { duration: root.blink ? 60 : 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 220 } }
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Behavior on rotation { NumberAnimation { duration: 260 } }
        }
        // the delighted eye: an arch ( ^ )
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.2
            width: parent.width * 1.5; height: width / 2
            clip: true
            opacity: eye.arcUp ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
            Rectangle {
                width: parent.width; height: width; radius: width / 2
                color: "transparent"
                border.width: Math.max(1.2, root.size * 0.06)
                border.color: root.tone
            }
        }
    }
}
