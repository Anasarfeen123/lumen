// Halo, in person: the ring of light with a small face. Its mood shows in how
// it moves, never in words (DESIGN.md: motion explains):
//   rest       a slow breath, a blink (sometimes two), a glance now and then
//   listening  eyes wide, a little "o", the ring swells with your voice (level)
//   thinking   looks up and aside, a point of light circles the ring
//   speaking   the mouth moves with the words it says (mouth 0–1, from Voice)
//   happy      ^ ^ eyes, a smile and two small hops
//   concerned  amber, eyes narrowed, a flat mouth, one small shake
//   sleeping   dimmed, eyes closed, breathing slower, a "z" drifting up
// The face turns as a whole toward lookX/lookY (-1 … 1) on a soft spring —
// the eye on the far side narrows, like a head turning — and the ring's light
// slides round to that side too.
//   pop()   arrives: grows from small with a springy overshoot and a hop
//   wake()  eyes closed, then open with a little hop (the panel opening)
// Sizes: 17 in the resting island, 40–48 in cards, 52+ in the Halo panel.
// Small sizes drop details (glints below 28, the mouth below 22).
//
// The ring is lit glass: a conic sheen, still at rest, turning while Halo
// listens, thinks or speaks. With `breathes` off (the island) nothing animates
// continuously at rest — the idle desktop spends nothing (DESIGN.md §0).
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.theme

Item {
    id: root
    property string mood: "rest"
    property real size: 20
    property real level: 0              // microphone level while listening
    property real mouth: -1             // 0–1 while speaking (lip-sync); -1 = make it up
    property bool face: true
    property real lookX: 0              // -1 … 1: where it looks (the pointer, a card…)
    property real lookY: 0
    property bool breathes: true        // a slow breath at rest (off in the island)
    property string accessory: ""       // "headphones" (music) · "party" (your birthday) · "scarf" (winter)
    width: size; height: size

    readonly property bool still: Theme.reducedMotion
    readonly property color tone: mood === "concerned" ? Theme.warning
                                 : mood === "sleeping" ? Theme.textMuted : Theme.accent
    readonly property real stroke: Math.max(1.6, size * 0.1)
    readonly property bool details: size >= 28
    readonly property bool hasMouth: face && size >= 22

    function pop() {
        if (still) return;
        popAnim.restart();
    }
    function wake() {
        if (still) return;
        blink = true;
        wakeAnim.restart();
    }

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
                running: (root.mood === "speaking" || root.mood === "happy") && !root.still && root.visible
                loops: Animation.Infinite
                PauseAnimation { duration: ripple.index * 700 }
                ParallelAnimation {
                    NumberAnimation { target: ripple; property: "scale"; from: 1; to: 1.7; duration: 1400; easing.type: Easing.OutCubic }
                    NumberAnimation { target: ripple; property: "opacity"; from: 0.5; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // a "z" drifting up while it sleeps (big sizes only)
    Text {
        id: zed
        visible: root.mood === "sleeping" && root.size >= 40 && !root.still && root.breathes
        text: "z"
        color: root.tone
        font.family: Theme.fontUi; font.pixelSize: root.size * 0.24; font.weight: Font.DemiBold
        x: root.size * 0.78; y: 0
        opacity: 0
        SequentialAnimation {
            running: zed.visible
            loops: Animation.Infinite
            ParallelAnimation {
                NumberAnimation { target: zed; property: "y"; from: root.size * 0.1; to: -root.size * 0.25; duration: 2200; easing.type: Easing.OutQuad }
                NumberAnimation { target: zed; property: "x"; from: root.size * 0.72; to: root.size * 0.9; duration: 2200; easing.type: Easing.InOutSine }
                SequentialAnimation {
                    NumberAnimation { target: zed; property: "opacity"; from: 0; to: 0.8; duration: 500 }
                    NumberAnimation { target: zed; property: "opacity"; to: 0; duration: 1700 }
                }
            }
            PauseAnimation { duration: 900 }
        }
    }

    Item {
        id: body
        anchors.fill: parent
        // breathing + the voice + hops
        property real breath: 1
        property real bounce: 1             // pop / wake
        property real hop: 0                // px up
        property real shakeX: 0
        transform: Translate { x: body.shakeX; y: -body.hop }
        // the head tilts a little toward where it looks
        rotation: root.still ? 0 : faceBox.fx * 7
        scale: breath * bounce * (root.mood === "listening" ? 1 + Math.min(1, root.level) * 0.14 : 1)
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
            // looking somewhere: the light slides round to that side
            readonly property real lookSheen: (Math.abs(root.lookX) + Math.abs(root.lookY) > 0.15)
                                              ? -Math.atan2(root.lookY, root.lookX) * 180 / Math.PI : 300
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
            readonly property bool busy: ["listening", "thinking", "speaking"].includes(root.mood)
            onBusyChanged: if (!busy) sheen = lookSheen
            onLookSheenChanged: if (!busy) sheen = lookSheen
            Behavior on sheen { enabled: !ring.busy && !root.still; NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
            // the light turns while Halo is busy with you
            NumberAnimation on sheen {
                running: !root.still && root.visible && ring.busy
                from: ring.sheen; to: ring.sheen + 360; loops: Animation.Infinite
                duration: root.mood === "thinking" ? 1600 : 4200
            }
        }

        // a point of light travelling round (thinking)
        Item {
            anchors.fill: parent
            visible: root.mood === "thinking"
            RotationAnimation on rotation { from: 0; to: 360; duration: 1300; loops: Animation.Infinite; running: root.mood === "thinking" && !root.still && root.visible }
            Rectangle {
                width: root.stroke * 1.5; height: width; radius: width / 2
                x: (root.size - width) / 2; y: -width * 0.25
                color: Qt.tint(root.tone, "#aaffffff")
            }
        }

        // ── the face ──
        Item {
            id: faceBox
            visible: root.face && root.size >= 14
            width: root.size; height: root.size
            // where it looks: told (pointer, a card) — else thinking looks up and
            // aside, sleeping looks down, rest wanders now and then
            property real wander: 0
            readonly property real gx: root.mood === "thinking" ? 0.6 : root.mood === "sleeping" ? 0 : Math.max(-1, Math.min(1, root.lookX + wander))
            readonly property real gy: root.mood === "thinking" ? -0.75 : root.mood === "sleeping" ? 0.45 : Math.max(-1, Math.min(1, root.lookY))
            property real fx: gx
            property real fy: gy
            Behavior on fx { enabled: !root.still; SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.005 } }
            Behavior on fy { enabled: !root.still; SpringAnimation { spring: 3.2; damping: 0.3; epsilon: 0.005 } }
            x: root.size * 0.17 * fx
            y: root.size * 0.13 * fy - (root.hasMouth ? root.size * 0.05 : 0)

            Eye { side: -1; x: root.size / 2 - root.size * 0.155 - width / 2 }
            Eye { side: 1;  x: root.size / 2 + root.size * 0.155 - width / 2 }

            // the mouth
            Item {
                id: mouthBox
                visible: root.hasMouth
                width: root.size * 0.24; height: root.size * 0.16
                x: root.size / 2 - width / 2 + root.size * 0.03 * faceBox.fx
                y: root.size / 2 + root.size * 0.13
                // speaking: opens with the words (or a believable guess)
                property real open: root.mood !== "speaking" ? 0 : root.mouth >= 0 ? root.mouth : chatter
                property real chatter: 0
                Behavior on open { NumberAnimation { duration: 70 } }
                Timer {
                    running: root.mood === "speaking" && root.mouth < 0 && !root.still && root.visible
                    interval: 110; repeat: true
                    onTriggered: mouthBox.chatter = Math.random() < 0.25 ? 0.1 : 0.3 + Math.random() * 0.7
                }
                // speaking: a soft rounded opening
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width * (0.55 + 0.15 * mouthBox.open)
                    height: Math.max(root.stroke * 0.8, parent.height * (0.18 + 0.82 * mouthBox.open))
                    radius: Math.min(width, height) / 2
                    color: Qt.darker(root.tone, 1.6)
                    border.width: Math.max(1, root.size * 0.03); border.color: root.tone
                    opacity: root.mood === "speaking" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                }
                // happy / rest: a smile (rest: a small, faint one)
                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -parent.height * 0.25
                    width: parent.width * (root.mood === "happy" ? 1 : 0.62); height: width / 2
                    clip: true
                    opacity: root.mood === "happy" ? 1 : root.mood === "rest" && root.details ? 0.7 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                    Rectangle {
                        y: -height / 2
                        width: parent.width; height: width; radius: width / 2
                        color: "transparent"
                        border.width: Math.max(1.2, root.size * 0.045)
                        border.color: root.tone
                    }
                }
                // listening: a little "o" that follows your voice (asleep: a small one)
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (0.32 + 0.2 * Math.min(1, root.level)); height: width; radius: width / 2
                    color: "transparent"
                    border.width: Math.max(1.2, root.size * 0.04); border.color: root.tone
                    opacity: root.mood === "listening" ? 1 : root.mood === "sleeping" ? 0.5 : 0
                    scale: root.mood === "sleeping" ? 0.6 : 1
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
                // concerned / thinking: a short flat line (thinking: off to one side, "hmm")
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.mood === "thinking" ? parent.width * 0.45 : parent.width * 0.25
                    width: parent.width * (root.mood === "thinking" ? 0.32 : 0.5)
                    height: Math.max(1.2, root.size * 0.045); radius: height / 2
                    color: root.tone
                    rotation: root.mood === "concerned" ? -6 : 0
                    opacity: root.mood === "concerned" || root.mood === "thinking" ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                    Behavior on x { NumberAnimation { duration: 220 } }
                }
            }
        }

        // ── the wardrobe ──
        // headphones: a band over the top, a cup each side
        Item {
            anchors.fill: parent
            visible: root.accessory === "headphones" && root.size >= 16
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: Theme.textSecondary; strokeWidth: Math.max(1.4, root.size * 0.075); fillColor: "transparent"; capStyle: ShapePath.RoundCap
                    startX: -root.size * 0.04; startY: root.size * 0.46
                    PathArc { x: root.size * 1.04; y: root.size * 0.46; radiusX: root.size * 0.56; radiusY: root.size * 0.66; useLargeArc: false }
                }
            }
            Repeater {
                model: [-1, 1]
                Rectangle {
                    required property int modelData
                    width: root.size * 0.16; height: root.size * 0.3; radius: width / 2
                    x: modelData < 0 ? -width * 0.45 : root.size - width * 0.55
                    y: root.size * 0.38
                    color: Theme.textSecondary
                    border.width: Math.max(1, root.size * 0.03); border.color: Qt.darker(Theme.textSecondary, 1.4)
                }
            }
        }
        // a party hat, a little tilted, with a bobble
        Item {
            visible: root.accessory === "party" && root.size >= 16
            width: root.size * 0.42; height: root.size * 0.46
            x: root.size * 0.5; y: -root.size * 0.3
            rotation: 18
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeWidth: -1
                    fillGradient: LinearGradient { x1: 0; y1: 0; x2: root.size * 0.42; y2: 0
                        GradientStop { position: 0; color: Theme.warning } GradientStop { position: 0.5; color: Theme.accent } GradientStop { position: 1; color: Theme.error } }
                    startX: root.size * 0.21; startY: 0
                    PathLine { x: root.size * 0.42; y: root.size * 0.46 }
                    PathLine { x: 0; y: root.size * 0.46 }
                    PathLine { x: root.size * 0.21; y: 0 }
                }
            }
            Rectangle { width: root.size * 0.12; height: width; radius: width / 2; color: "white"; x: root.size * 0.21 - width / 2; y: -width / 2 }
        }
        // a scarf, wrapped round the bottom
        Item {
            visible: root.accessory === "scarf" && root.size >= 20
            anchors.fill: parent
            Rectangle {
                width: root.size * 0.86; height: root.size * 0.16; radius: height / 2
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.size * 0.78
                color: Theme.error
                Rectangle { width: parent.height * 0.6; height: parent.height * 1.9; radius: width / 3; color: Qt.darker(Theme.error, 1.15); x: parent.width * 0.62; y: parent.height * 0.6; rotation: -12 }
            }
        }

        // pop: from small, a springy overshoot and a hop
        ParallelAnimation {
            id: popAnim
            SequentialAnimation {
                PropertyAction { target: body; property: "bounce"; value: 0.35 }
                NumberAnimation { target: body; property: "bounce"; to: 1.14; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { target: body; property: "bounce"; to: 0.95; duration: 140; easing.type: Easing.InOutSine }
                NumberAnimation { target: body; property: "bounce"; to: 1; duration: 160; easing.type: Easing.OutSine }
            }
            SequentialAnimation {
                NumberAnimation { target: body; property: "hop"; to: root.size * 0.14; duration: 200; easing.type: Easing.OutQuad }
                NumberAnimation { target: body; property: "hop"; to: 0; duration: 320; easing.type: Easing.OutBounce }
            }
        }
        // wake: eyes stay shut a moment, then open with a little hop
        SequentialAnimation {
            id: wakeAnim
            PauseAnimation { duration: 260 }
            ScriptAction { script: root.blink = false }
            NumberAnimation { target: body; property: "hop"; to: root.size * 0.08; duration: 160; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "hop"; to: 0; duration: 300; easing.type: Easing.OutBounce }
        }
        // happy: two small hops
        SequentialAnimation {
            id: hops
            NumberAnimation { target: body; property: "hop"; to: root.size * 0.16; duration: 170; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "hop"; to: 0; duration: 170; easing.type: Easing.InQuad }
            NumberAnimation { target: body; property: "hop"; to: root.size * 0.09; duration: 130; easing.type: Easing.OutQuad }
            NumberAnimation { target: body; property: "hop"; to: 0; duration: 220; easing.type: Easing.OutBounce }
        }
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
        if (mood === "happy") hops.restart();
        else if (mood === "concerned") shake.restart();
    }

    // blinking (not while asleep or delighted); now and then twice
    property bool blink: false
    Timer {
        interval: 2600 + Math.random() * 4200
        running: root.face && !root.still && root.visible && ["rest", "listening", "speaking", "concerned"].includes(root.mood)
        repeat: true
        onTriggered: {
            interval = 2600 + Math.random() * 4200;
            root.blink = true; unblink.restart();
            if (Math.random() < 0.22) twice.restart();
        }
    }
    Timer { id: unblink; interval: 120; onTriggered: if (!wakeAnim.running) root.blink = false }
    Timer { id: twice; interval: 260; onTriggered: { root.blink = true; unblink.restart(); } }
    // now and then, a look around (only when nothing tells it where to look)
    Timer {
        interval: 7000
        running: root.face && !root.still && root.visible && root.mood === "rest" && root.lookX === 0 && root.lookY === 0
        repeat: true
        onTriggered: { interval = 5000 + Math.random() * 7000; faceBox.wander = Math.random() < 0.5 ? 0 : (Math.random() < 0.5 ? -0.7 : 0.7); }
    }
    onLookXChanged: faceBox.wander = 0

    component Eye: Item {
        id: eye
        property int side: 1
        width: root.size * 0.13; height: root.size * 0.3
        y: root.size / 2 - height / 2
        readonly property bool arcUp: root.mood === "happy"
        readonly property bool closed: root.mood === "sleeping"
        // turning the head: the eye on the far side narrows a little
        readonly property real turn: faceBox.fx * eye.side
        // the open eye: a soft pill with a glint
        Rectangle {
            id: pill
            anchors.centerIn: parent
            width: parent.width * (root.mood === "listening" ? 1.2 : 1) * (eye.turn < -0.3 ? 0.82 : 1)
            height: eye.closed ? Math.max(1.2, root.size * 0.045)
                  : root.blink ? Math.max(1, parent.height * 0.1)
                  : root.mood === "concerned" ? parent.height * 0.48
                  : root.mood === "listening" ? parent.height * 0.86 : parent.height * 0.7
            radius: Math.min(width, height) / 2
            color: root.tone
            opacity: eye.arcUp ? 0 : 1
            rotation: root.mood === "concerned" ? eye.side * -14 : 0
            Behavior on height { NumberAnimation { duration: root.blink ? 55 : 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 220 } }
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on rotation { NumberAnimation { duration: 260 } }
            // a glint, toward where it's looking
            Rectangle {
                visible: root.details && !eye.closed && !root.blink && pill.height > pill.width
                width: pill.width * 0.42; height: width; radius: width / 2
                x: pill.width * 0.5 - width / 2 + pill.width * 0.18 * (faceBox.fx >= 0 ? 1 : -1)
                y: pill.height * 0.16
                color: Qt.rgba(1, 1, 1, 0.85)
            }
        }
        // the delighted eye: an arch ( ^ )
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.22
            width: parent.width * 1.6; height: width / 2
            clip: true
            opacity: eye.arcUp ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Rectangle {
                width: parent.width; height: width; radius: width / 2
                color: "transparent"
                border.width: Math.max(1.2, root.size * 0.055)
                border.color: root.tone
            }
        }
    }
}
