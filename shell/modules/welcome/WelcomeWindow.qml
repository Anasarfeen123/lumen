// The first-run welcome (services/Welcome.qml): a glass card over a dimmed
// desktop, five short steps. Keyboard first: Enter / → next, ← back,
// Esc skips (nothing is asked). Everything it sets lives in Settings too.
//   1 Hello · 2 Look (theme, accent) · 3 Your phone · 4 Halo · 5 Five keys
import QtQuick
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
    readonly property bool showing: Welcome.open && isFocused

    visible: showing || card.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: if (showing) Qt.callLater(() => keys.forceActiveFocus())

    // Dim the desktop behind
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: win.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        MouseArea { anchors.fill: parent }             // the desktop waits
    }

    readonly property string curTheme: Theme.tokens.theme ?? "dark"
    readonly property string curAccent: Theme.tokens.accent_name ?? "ion"

    Item {
        id: keys
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) Welcome.skip();
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) Welcome.next();
            else if (event.key === Qt.Key_Left) Welcome.back();
            else return;
            event.accepted = true;
        }
    }

    GlassSurface {
        id: card
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(720, win.width - 64)
        height: 480
        anchors.centerIn: parent
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.5) }

        // ── the steps (each fades and slides in the direction you travel) ──
        Item {
            id: stage
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: footer.top; margins: Theme.space.s6 }
            clip: true
            property int shown: Welcome.step
            property int dir: 1
            Connections {
                target: Welcome
                function onStepChanged() { stage.dir = Welcome.step >= stage.shown ? 1 : -1; stage.shown = Welcome.step; }
            }
            Repeater {
                model: [helloC, lookC, phoneC, haloC, keysC]
                delegate: Loader {
                    required property var modelData
                    required property int index
                    anchors.fill: parent
                    sourceComponent: modelData
                    readonly property bool on: index === Welcome.step
                    opacity: on ? 1 : 0
                    visible: opacity > 0.01
                    x: on ? 0 : (index < Welcome.step ? -40 : 40)
                    Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal } }
                    Behavior on x { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                }
            }
        }

        // ── footer: dots · Skip · Back · Next ──
        Item {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s6 }
            height: 36
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Repeater {
                    model: Welcome.steps
                    delegate: Rectangle {
                        required property int index
                        width: index === Welcome.step ? 22 : 7; height: 7; radius: 3.5
                        color: index === Welcome.step ? Theme.accent : index < Welcome.step ? Theme.textSecondary : Theme.withAlpha(Theme.text, 0.2)
                        Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Welcome.go(index) }
                    }
                }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                Pill { visible: Welcome.step < Welcome.steps - 1; text: "Skip"; ghost: true; onClicked: Welcome.skip() }
                Pill { visible: Welcome.step > 0; text: "Back"; onClicked: Welcome.back() }
                Pill { primary: true; text: Welcome.step === Welcome.steps - 1 ? "You're set" : Welcome.step === 0 ? "Let's go" : "Next"; onClicked: Welcome.next() }
            }
        }
    }

    // ── 1 · Hello ──
    Component {
        id: helloC
        Column {
            spacing: Theme.space.s4
            topPadding: Theme.space.s6
            LumenLogo { size: 72; anchors.horizontalCenter: parent.horizontalCenter }
            LText { anchors.horizontalCenter: parent.horizontalCenter; font.pixelSize: 30; font.weight: Font.DemiBold; text: "Welcome to Lumen" }
            LText {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.textSecondary; font.pixelSize: 15
                text: "A calm desktop that's capable underneath: an island that tells you what just happened, a Ribbon, Halo the assistant, and your phone, all in one design."
            }
            LText {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; color: Theme.textMuted
                text: "Takes a minute. Everything here can be changed later in Settings."
            }
        }
    }

    // ── 2 · Look ──
    Component {
        id: lookC
        Column {
            spacing: Theme.space.s4
            StepHead { icon: "palette"; title: "Pick a look"; sub: "It changes as you click. Your wallpaper can choose the accent for you." }
            Row {
                spacing: Theme.space.s3
                Repeater {
                    model: SettingsState.previews.themes
                    delegate: Column {
                        required property var modelData
                        readonly property bool on: modelData.id === win.curTheme
                        spacing: Theme.space.s2
                        Rectangle {
                            width: 138; height: 88; radius: Theme.radius.md
                            color: "#" + modelData.bg
                            border.width: parent.on ? 2 : 1
                            border.color: parent.on ? Theme.accent : Theme.border
                            Rectangle { x: 9; y: 8; width: 120; height: 11; radius: 5.5; color: "#" + modelData.surface
                                Rectangle { x: 6; y: 3.5; width: 14; height: 4; radius: 2; color: "#" + modelData.accent } }
                            Rectangle { x: 9; y: 26; width: 74; height: 54; radius: 6; color: "#" + modelData.elevated
                                Rectangle { x: 8; y: 10; width: 46; height: 5; radius: 2; color: "#" + modelData.text }
                                Rectangle { x: 8; y: 20; width: 32; height: 4; radius: 2; color: "#" + modelData.muted }
                                Rectangle { x: 8; y: 36; width: 26; height: 10; radius: 5; color: "#" + modelData.accent } }
                            Rectangle { x: 90; y: 26; width: 39; height: 54; radius: 6; color: "#" + modelData.surface }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsState.lumen(["theme", modelData.id]) }
                        }
                        LText { anchors.horizontalCenter: parent.horizontalCenter; role: parent.on ? "bodyStrong" : "body"; color: parent.on ? Theme.text : Theme.textSecondary; text: modelData.name }
                    }
                }
            }
            Row {
                spacing: Theme.space.s3
                LText { anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary; text: "Accent" }
                Repeater {
                    model: SettingsState.previews.accents
                    delegate: Rectangle {
                        required property var modelData
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30; height: 30; radius: 15
                        color: "#" + modelData.hex
                        border.width: modelData.id === win.curAccent ? 3 : 0
                        border.color: Theme.text
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsState.lumen(["accent", modelData.id]) }
                    }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30; height: 30; radius: 15
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "#f3ad6d" }
                        GradientStop { position: 0.5; color: "#b6b3ff" }
                        GradientStop { position: 1; color: "#52d1e9" }
                    }
                    border.width: win.curAccent === "wallpaper" ? 3 : 0
                    border.color: Theme.text
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsState.lumen(["accent", "wallpaper"]) }
                }
                LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted; text: win.curAccent === "wallpaper" ? "from your wallpaper" : "" }
            }
        }
    }

    // ── 3 · Your phone ──
    Component {
        id: phoneC
        Column {
            spacing: Theme.space.s4
            StepHead { icon: "phonelink"; title: "Your phone, part of the desktop"; sub: "Lumen Link: its battery in the island, calls, files and clipboard both ways — through KDE Connect." }
            // Linked
            Rectangle {
                visible: Link.connected
                width: parent.width; height: 64; radius: Theme.radius.md
                color: Theme.withAlpha(Theme.success, 0.12); border.width: 1; border.color: Theme.withAlpha(Theme.success, 0.35)
                Row {
                    anchors { left: parent.left; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s3
                    LIcon { icon: "check_circle"; fill: 1; color: Theme.success; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        LText { role: "bodyStrong"; text: "Linked to " + (Link.phone?.name ?? "your phone") }
                        LText { role: "caption"; color: Theme.textSecondary
                                text: "Over " + Link.viaLabel(Link.phone?.via ?? "") + ((Link.phone?.battery ?? -1) >= 0 ? " · " + Link.phone.battery + "% battery" : "") }
                    }
                }
            }
            // Linked: what you can do now
            Column {
                visible: Link.connected
                width: parent.width
                spacing: Theme.space.s3
                Repeater {
                    model: [
                        { i: "phone_in_talk", t: "Calls and your phone's battery appear in the island" },
                        { i: "move_to_inbox", t: "Drag a file to the right edge of the screen → Send to phone" },
                        { i: "content_paste_go", t: "Copy on one, paste on the other (Settings → Lumen Link)" },
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: Theme.space.s3
                        LIcon { icon: modelData.i; size: 18; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        LText { color: Theme.textSecondary; text: modelData.t; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            // Not yet
            Column {
                visible: !Link.connected
                width: parent.width
                spacing: Theme.space.s2
                Repeater {
                    model: [
                        { n: "1", t: "Install KDE Connect on your phone", d: "Play Store, F-Droid or the App Store" },
                        { n: "2", t: "Put both on the same network", d: "Same Wi-Fi — or, on hostel and campus Wi-Fi, turn on Bluetooth tethering on the phone" },
                        { n: "3", t: "Accept the pairing", d: "Open the app, pick this computer, and accept here" },
                    ]
                    delegate: Row {
                        required property var modelData
                        spacing: Theme.space.s3
                        Rectangle { width: 28; height: 28; radius: 14; color: Theme.withAlpha(Theme.accent, 0.16)
                                    LText { anchors.centerIn: parent; role: "bodyStrong"; color: Theme.accent; text: modelData.n } }
                        Column {
                            LText { role: "bodyStrong"; text: modelData.t }
                            LText { role: "caption"; color: Theme.textMuted; text: modelData.d }
                        }
                    }
                }
                Item { width: 1; height: Theme.space.s2 }
                Pill { text: "Open Lumen Link settings"; icon: "open_in_new"; onClicked: SettingsState.launch("phone") }
            }
            LText { visible: !Link.available; width: parent.width; wrapMode: Text.Wrap; role: "caption"; color: Theme.textMuted
                    text: "KDE Connect isn't installed on this computer yet (Fedora: sudo dnf install kdeconnectd). You can skip this and come back." }
        }
    }

    // ── 4 · Halo ──
    Component {
        id: haloC
        Column {
            spacing: Theme.space.s4
            StepHead { icon: "auto_awesome"; title: "Halo, your assistant"; sub: "Explains what you select, reads your screen, checks your system, drafts messages. Nothing is sent until you press Enter." }
            Choice {
                icon: "shield_lock"
                title: "On this computer" + (Ai.status.ollama ? "" : " (needs Ollama)")
                sub: Ai.status.ollama
                    ? ((Ai.status.ollamaModels ?? []).length ? "Private and free · " + Ai.status.ollamaModels.join(", ") : "Ollama is running — download a model in Settings → Halo")
                    : "Install Ollama (Fedora: sudo dnf install ollama), then pick a model in Settings → Halo"
                on: Ai.provider === "ollama"
                onPicked: {
                    if (Ai.status.ollama && (Ai.status.ollamaModels ?? []).length) { Persist.data.aiProvider = "ollama"; Persist.data.aiModel = "auto"; Ai.refreshStatus(); }
                    else SettingsState.launch("ai");
                }
            }
            Choice {
                icon: "cloud"
                title: "Claude, with your own key"
                sub: "Most capable; your question goes to Anthropic. Add the key in Settings → Halo"
                on: Ai.provider === "anthropic"
                onPicked: { Persist.data.aiProvider = "anthropic"; SettingsState.launch("ai"); }
            }
            Choice {
                icon: "do_not_disturb_on"
                title: "Not now"
                sub: "Halo stays off. Super+Shift+Space asks again whenever you like"
                on: Ai.provider === "off"
                onPicked: Persist.data.aiProvider = "off"
            }
        }
    }

    // ── 5 · Five keys ──
    Component {
        id: keysC
        Column {
            spacing: Theme.space.s3
            StepHead { icon: "keyboard"; title: "Five keys to start with"; sub: "Everything else is in the cheatsheet — the last one here." }
            Repeater {
                model: [
                    { k: ["Super"], tap: true, t: "Search", d: "Apps, windows, maths and ₹, commands, settings" },
                    { k: ["Super", "A"], t: "Control centre", d: "Wi-Fi, Bluetooth, toggles, volume, your phone" },
                    { k: ["Super", "Shift", "Space"], t: "Halo", d: "Ask about anything you've selected" },
                    { k: ["Alt", "Tab"], t: "Switch windows", d: "Live previews, in the order you used them" },
                    { k: ["Super", "/"], t: "Every shortcut", d: "The full cheatsheet" },
                ]
                delegate: Item {
                    id: keyRow
                    required property var modelData
                    required property int index
                    width: parent.width; height: 42
                    // Arrives one after another
                    opacity: 0
                    Component.onCompleted: arrive.start()
                    SequentialAnimation {
                        id: arrive
                        PauseAnimation { duration: Theme.reducedMotion ? 0 : keyRow.index * 70 }
                        NumberAnimation { target: keyRow; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : Theme.motion.normal }
                    }
                    Row {
                        id: caps
                        anchors.verticalCenter: parent.verticalCenter
                        width: 230
                        spacing: 5
                        Repeater {
                            model: keyRow.modelData.k
                            delegate: Rectangle {
                                required property string modelData
                                height: 30; width: Math.max(30, capLbl.implicitWidth + 18); radius: 8
                                color: Theme.withAlpha(Theme.text, 0.07)
                                border.width: 1; border.color: Theme.border
                                Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 3; radius: 8; color: Theme.withAlpha("#000000", 0.25) }
                                LText { id: capLbl; anchors.centerIn: parent; role: "bodyStrong"; text: modelData }
                            }
                        }
                        LText { visible: keyRow.modelData.tap === true; anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted; text: "tap" }
                    }
                    Column {
                        anchors { left: caps.right; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                        LText { role: "bodyStrong"; text: keyRow.modelData.t }
                        LText { role: "caption"; color: Theme.textMuted; text: keyRow.modelData.d }
                    }
                }
            }
        }
    }

    // ── pieces ──
    component StepHead: Column {
        property string icon
        property string title
        property string sub
        width: parent ? parent.width : 0
        spacing: Theme.space.s1
        Row {
            spacing: Theme.space.s2
            LIcon { icon: parent.parent.icon; size: 22; fill: 1; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText { font.pixelSize: 22; font.weight: Font.DemiBold; text: parent.parent.title; anchors.verticalCenter: parent.verticalCenter }
        }
        LText { width: parent.width; wrapMode: Text.Wrap; color: Theme.textSecondary; text: parent.sub }
    }
    component Pill: HoverTarget {
        id: pill
        property string text
        property string icon: ""
        property bool primary: false
        property bool ghost: false
        width: pillRow.implicitWidth + 32; height: 36
        radius: height / 2
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1
                    color: pill.primary ? Theme.accent : pill.ghost ? "transparent" : Theme.withAlpha(Theme.text, 0.06)
                    border.width: pill.primary || pill.ghost ? 0 : 1; border.color: Theme.border }
        Row {
            id: pillRow
            anchors.centerIn: parent
            spacing: 6
            LIcon { visible: pill.icon !== ""; icon: pill.icon; size: 16; color: pill.primary ? Theme.onAccent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "bodyStrong"; text: pill.text; color: pill.primary ? Theme.onAccent : pill.ghost ? Theme.textMuted : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component Choice: HoverTarget {
        id: ch
        property string icon
        property string title
        property string sub
        property bool on: false
        signal picked()
        width: parent ? parent.width : 0; height: 62
        radius: Theme.radius.md
        onClicked: picked()
        Rectangle { anchors.fill: parent; radius: parent.radius; z: -1
                    color: ch.on ? Theme.withAlpha(Theme.accent, 0.12) : Theme.withAlpha(Theme.surfaceElevated, 0.6)
                    border.width: 1; border.color: ch.on ? Theme.withAlpha(Theme.accent, 0.5) : Theme.border }
        LIcon { id: chIcon; x: Theme.space.s4; anchors.verticalCenter: parent.verticalCenter; icon: ch.icon; size: 22; color: ch.on ? Theme.accent : Theme.textSecondary }
        Column {
            anchors { left: chIcon.right; leftMargin: Theme.space.s3; right: chCheck.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            LText { role: "bodyStrong"; text: ch.title; width: parent.width; elide: Text.ElideRight }
            LText { role: "caption"; color: Theme.textMuted; text: ch.sub; width: parent.width; elide: Text.ElideRight }
        }
        LIcon { id: chCheck; anchors { right: parent.right; rightMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                visible: ch.on; icon: "check_circle"; fill: 1; color: Theme.accent }
    }
}
