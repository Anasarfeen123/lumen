// Lumen lock screen — one per monitor.
//
//            Friday, 25 September
//                  23:42                    (hero clock)
//
//     [ now playing ] [ battery ] [ calendar ] [ notifications ]
//
//                   ( A )
//                  Alex
//            [ •••••••         → ]
//
// The wallpaper stays sharp and gently dimmed; every card is real frosted
// glass cut from a blurred copy of it (FrostPane). Typing anywhere goes to
// the password box; any key or pointer movement also starts Face ID.
//
// Transitions (macOS-like), driven by a snapshot of this output taken just
// before locking (services/Lock.qml):
//   lock    the desktop blurs and gently zooms into the frosted wallpaper,
//           then the clock, widgets and password rise in, one after another
//   unlock  the lock UI lifts away and the blurred desktop comes into focus
//           beneath it; only then is the lock released — so the real desktop
//           appears exactly where the animation ended.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    property string screenName: ""
    property string wallpaper: ""
    // Entrance/exit progress for the three groups (0 hidden → 1 in place)
    property real heroIn: 0
    property real widgetsIn: 0
    property real authIn: 0
    property string userName: Quickshell.env("USER") ?? ""
    readonly property bool leaving: Lock.status === "success"
    onLeavingChanged: if (leaving) leave.start()
    Component.onCompleted: enter.start()

    SystemClock { id: clock; precision: SystemClock.Seconds }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/wallpaper"
        onLoaded: root.wallpaper = text().trim()
    }

    // Display name from the passwd GECOS field, falling back to the login
    Process {
        running: true
        command: ["getent", "passwd", Quickshell.env("USER") ?? ""]
        stdout: StdioCollector {
            onStreamFinished: {
                const gecos = (text.split(":")[4] ?? "").split(",")[0].trim();
                if (gecos !== "") root.userName = gecos;
            }
        }
    }

    // ── Backdrop ────────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: Theme.bg }

    Image {
        id: wp
        anchors.fill: parent
        source: root.wallpaper !== "" ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        visible: false
    }

    // Heavily blurred copy — the material every FrostPane is cut from.
    // Hidden underneath the sharp backdrop, but still rendered so panes can sample it.
    MultiEffect {
        id: frost
        anchors.fill: parent
        source: wp
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.15
        brightness: -0.08
    }

    MultiEffect {
        id: backdrop
        anchors.fill: parent
        source: wp
        blurEnabled: true
        blur: 0.12
        blurMax: 32
        brightness: -0.14
        opacity: 0
    }

    // Soft vignette so the clock and the auth area always read
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.7; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.35) }
        }
    }

    // ── Snapshot of the desktop (transitions only) ──────────────────────────
    Image {
        id: snapImg
        anchors.fill: parent
        visible: false
        cache: false
        sourceSize: Qt.size(root.width, root.height)
        source: Lock.snapshotReady && root.screenName !== ""
                ? "file://" + Lock.snapshotDir + "/" + root.screenName + ".jpg?v=" + Lock.snapshotVersion : ""
    }
    MultiEffect {
        id: snap
        anchors.fill: parent
        source: snapImg
        visible: snapImg.status === Image.Ready && opacity > 0
        blurEnabled: true
        blurMax: 64
        blur: 0
        brightness: 0
        opacity: 1
    }

    // Lock: desktop → frosted wallpaper → UI, staggered
    ParallelAnimation {
        id: enter
        NumberAnimation { target: snap; property: "blur"; from: 0; to: 1; duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
        NumberAnimation { target: snap; property: "scale"; from: 1; to: 1.06; duration: 560; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        NumberAnimation { target: snap; property: "brightness"; from: 0; to: -0.1; duration: 420 }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: snap; property: "opacity"; from: 1; to: 0; duration: 340; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
        }
        // The frosted wallpaper is fully in before the desktop finishes fading
        NumberAnimation { target: backdrop; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
        SequentialAnimation {
            PauseAnimation { duration: 200 }
            NumberAnimation { target: root; property: "heroIn"; from: 0; to: 1; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        }
        SequentialAnimation {
            PauseAnimation { duration: 290 }
            NumberAnimation { target: root; property: "widgetsIn"; from: 0; to: 1; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        }
        SequentialAnimation {
            PauseAnimation { duration: 370 }
            NumberAnimation { target: root; property: "authIn"; from: 0; to: 1; duration: 520; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        }
    }

    // Unlock: UI lifts away, blurred desktop fades in and comes into focus
    ParallelAnimation {
        id: leave
        ScriptAction { script: enter.stop() }
        NumberAnimation { target: root; property: "authIn"; to: 0; duration: 180; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
        NumberAnimation { target: root; property: "widgetsIn"; to: 0; duration: 200; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
        NumberAnimation { target: root; property: "heroIn"; to: 0; duration: 220; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveAccelerate }
        SequentialAnimation {
            PropertyAction { target: snap; property: "blur"; value: 1 }
            PropertyAction { target: snap; property: "scale"; value: 1.06 }
            PropertyAction { target: snap; property: "brightness"; value: -0.1 }
            NumberAnimation { target: snap; property: "opacity"; to: 1; duration: 160; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
            ParallelAnimation {
                NumberAnimation { target: snap; property: "blur"; to: 0; duration: 300; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard }
                NumberAnimation { target: snap; property: "scale"; to: 1; duration: 320; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                NumberAnimation { target: snap; property: "brightness"; to: 0; duration: 300 }
            }
        }
        // Without a snapshot, fade the whole scene out instead
        NumberAnimation { target: backdrop; property: "opacity"; to: snapImg.status === Image.Ready ? 1 : 0; duration: 480 }
    }

    // ── Content ─────────────────────────────────────────────────────────────
    Item {
        id: content
        anchors.fill: parent

        // Clicking anywhere keeps the keyboard in the password box; moving the
        // pointer counts as "I'm here" and starts Face ID
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { auth.input.forceActiveFocus(); Lock.intent(); }
            onPositionChanged: Lock.intent()
        }

        // Hero clock
        Column {
            id: hero
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.1) - (1 - root.heroIn) * 28
            opacity: root.heroIn
            spacing: -Theme.space.s2

            layer.enabled: true
            layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.9; shadowOpacity: 0.35; shadowVerticalOffset: 2; shadowColor: "black" }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, "dddd, d MMMM")
                color: Theme.withAlpha(Theme.text, 0.85)
                font.family: Theme.fontUi
                font.pixelSize: 22
                font.weight: Font.Medium
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    id: bigTime
                    text: Theme.timeDigits(clock.date)
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 136
                    font.variableAxes: ({ "wght": 380, "ROND": 100 })
                    font.letterSpacing: -3
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    visible: Theme.clock12h
                    anchors.baseline: bigTime.baseline
                    leftPadding: 10
                    text: Theme.timePeriod(clock.date)
                    color: Theme.withAlpha(Theme.text, 0.7)
                    font.family: Theme.fontUi
                    font.pixelSize: 30
                    font.variableAxes: ({ "wght": 560, "ROND": 100 })
                }
            }
        }

        // Widgets
        Row {
            id: widgets
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.43) + (1 - root.widgetsIn) * 24
            opacity: root.widgetsIn
            spacing: Theme.space.s4

            MediaCard { frost: frost; visible: Media.present && Persist.data.lockMedia }
            BatteryCard { frost: frost; visible: Battery.available && Persist.data.lockBattery }
            CalendarCard { frost: frost; today: clock.date; visible: Persist.data.lockCalendar }
            NotificationsCard { frost: frost; visible: Notifications.count > 0 && Persist.data.lockNotifications }
            GlanceCard { id: glance; frost: frost; visible: glance.wanted }
        }

        // Who + password
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(root.height * 0.72) + (1 - root.authIn) * 20
            opacity: root.authIn
            spacing: Theme.space.s3

            // Avatar: ~/.face if present, else the initial on an accent disc
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72

                // Glow behind the picture: stacked soft discs in the accent. It
                // breathes slowly while waiting, flares on success, reddens on a
                // wrong password.
                Item {
                    id: glow
                    anchors.centerIn: parent
                    width: 72; height: 72
                    readonly property color tone: Lock.status === "failed" ? Theme.error
                                                : Lock.status === "success" ? Theme.success : Theme.accent
                    property real breath: 0
                    SequentialAnimation on breath {
                        running: root.visible && !Theme.reducedMotion
                        loops: Animation.Infinite
                        NumberAnimation { to: 1; duration: 2600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 2600; easing.type: Easing.InOutSine }
                    }
                    scale: Lock.status === "success" ? 1.35 : 1 + glow.breath * 0.06
                    Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            required property int index
                            anchors.centerIn: parent
                            width: 72 + (5 - index) * 14
                            height: width
                            radius: width / 2
                            color: Qt.rgba(glow.tone.r, glow.tone.g, glow.tone.b, (0.035 + index * 0.02 + glow.breath * 0.012) * Theme.glow)
                            Behavior on color { ColorAnimation { duration: 300 } }
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 36
                    color: Theme.withAlpha(Theme.accent, 0.85)
                    visible: face.status !== Image.Ready
                    Text {
                        anchors.centerIn: parent
                        text: root.userName.charAt(0).toUpperCase()
                        color: Theme.onAccent
                        font.family: Theme.fontUi
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }
                }
                Image {
                    id: face
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.face"
                    cache: false
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                }
                MultiEffect {
                    anchors.fill: parent
                    source: face
                    visible: face.status === Image.Ready
                    maskEnabled: true
                    maskSource: avatarMask
                }
                FaceRing { anchors.centerIn: parent; size: 88 }
                Item {
                    id: avatarMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: 36 }
                }
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "heading"
                text: root.userName
            }

            PasswordBox {
                id: auth
                frost: frost
                anchors.horizontalCenter: parent.horizontalCenter
                Component.onCompleted: input.forceActiveFocus()
            }

            LText {
                anchors.horizontalCenter: parent.horizontalCenter
                role: "caption"
                color: Lock.status === "failed" ? Theme.error
                     : Lock.faceStatus === "matched" ? Theme.success : Theme.textSecondary
                text: Lock.status === "checking" ? "Checking…"
                    : Lock.faceStatus === "scanning" ? "Looking for you…"
                    : Lock.faceStatus === "matched" ? "Welcome back"
                    : Lock.message !== "" ? Lock.message
                    : Lock.faceReady ? (Lock.autoFace ? "Look at the camera, or type your password"
                                                      : "Press F2 for Face ID, or type your password") : ""
                opacity: text !== "" ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            }
        }

        // Top-right: connection + battery, phone-style
        Row {
            anchors { top: parent.top; right: parent.right; margins: Theme.space.s6 }
            opacity: root.heroIn
            spacing: Theme.space.s3
            LIcon { icon: Network.icon; size: Theme.size.iconSmall; color: Theme.text }
            LIcon { visible: Bluetooth.hasConnection; icon: "bluetooth_connected"; size: Theme.size.iconSmall; color: Theme.text }
            Row {
                visible: Battery.available
                spacing: 2
                LIcon { icon: Battery.icon; rotation: 90; fill: 1; size: Theme.size.iconSmall; color: Theme.text }
                LText { role: "bodyStrong"; text: Math.round(Battery.percentage * 100) + "%"; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // Bottom-right: sleep · shut down (press twice)
        Row {
            anchors { bottom: parent.bottom; right: parent.right; margins: Theme.space.s6 }
            opacity: root.authIn
            spacing: Theme.space.s2
            property bool confirmOff: false
            Timer { id: confirmReset; interval: 3000; onTriggered: parent.confirmOff = false }

            IconButton { icon: "bedtime"; tone: Theme.text; onActivated: Session.run("suspend") }
            IconButton {
                icon: "power_settings_new"
                tone: parent.confirmOff ? Theme.error : Theme.text
                highlighted: parent.confirmOff
                onActivated: {
                    if (parent.confirmOff) Session.run("poweroff");
                    else { parent.confirmOff = true; confirmReset.restart(); }
                }
            }
            LText {
                anchors.verticalCenter: parent.verticalCenter
                visible: parent.confirmOff
                role: "caption"; color: Theme.error; text: "Press again to shut down"
            }
        }
    }
}
