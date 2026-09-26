// Control centre (DESIGN.md §13): the top of the right sidebar.
//   header   date · battery summary · settings · power
//   tiles    Wi-Fi · Bluetooth · Do Not Disturb · Night light · Mic · Power mode · VPN (if configured)
//   sliders  volume (→ output picker) · brightness
//   system   CPU · memory · temperature · GPU — sampled only while open
// A tile's chevron swaps the tiles for a detail list (networks, devices,
// outputs); Esc or the back arrow returns.
import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root

    property string detail: ""          // "" | wifi | bluetooth | output
    implicitHeight: header.height + Theme.space.s4 + body.height

    Keys.onEscapePressed: event => {
        if (detail !== "") { detail = ""; event.accepted = true; }
        else event.accepted = false;
    }

    onDetailChanged: Network.scanning = detail === "wifi"
    Connections {
        target: Sidebar
        function onOpenChanged() {
            if (!Sidebar.open) root.detail = "";
            else { Vpn.refresh(); Warp.refresh(); }
        }
    }
    Connections {
        target: Network
        function onConnectFailed(ssid) { Island.system("wifi_off", "Couldn't join " + ssid, "Check the password and try again", "error"); }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // Run a command once the sidebar has finished sliding away, so tools like
    // screenshots and the colour picker never capture it
    property var pendingCmd: null
    function later(cmd) { pendingCmd = cmd; laterTimer.restart(); }
    Timer { id: laterTimer; interval: Theme.motion.large + 60; onTriggered: if (root.pendingCmd) Quickshell.execDetached(root.pendingCmd) }

    // ── Header: you, the day, the battery ───────────────────────────────────
    readonly property string userName: Quickshell.env("USER") ?? ""
    readonly property int hour: clock.date.getHours()
    readonly property string greeting: hour < 5 ? "Good night" : hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : hour < 22 ? "Good evening" : "Good night"
    property int faceVersion: 0
    onVisibleChanged: if (visible) faceVersion++      // pick up a new picture

    Item {
        id: header
        width: parent.width
        height: 52

        Item {
            id: avatar
            width: 44; height: 44
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent; radius: width / 2
                color: Theme.withAlpha(Theme.accent, 0.85)
                visible: face.status !== Image.Ready
                LText { anchors.centerIn: parent; role: "heading"; color: Theme.onAccent; text: root.userName.charAt(0).toUpperCase() }
            }
            ClippingRectangle {
                anchors.fill: parent; radius: width / 2
                color: "transparent"
                visible: face.status === Image.Ready
                Image {
                    id: face
                    anchors.fill: parent
                    source: "file://" + Quickshell.env("HOME") + "/.face?v=" + root.faceVersion
                    cache: false
                    sourceSize: Qt.size(88, 88)
                    fillMode: Image.PreserveAspectCrop
                }
            }
            // Accent ring
            Rectangle { anchors.fill: parent; anchors.margins: -2; radius: width / 2; color: "transparent"; border.width: 1.5; border.color: Theme.withAlpha(Theme.accent, 0.55) }
        }

        Column {
            anchors { left: avatar.right; leftMargin: Theme.space.s3; right: headerButtons.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            spacing: 1
            LText { width: parent.width; elide: Text.ElideRight; role: "heading"; text: root.greeting + ", " + root.userName }
            LText {
                width: parent.width
                elide: Text.ElideRight
                role: "caption"
                color: Theme.textMuted
                text: {
                    let t = Qt.formatDate(clock.date, "dddd, d MMMM");
                    if (!Battery.available) return t;
                    const pct = Math.round(Battery.percentage * 100) + "%";
                    if (Battery.charging) return t + ` · ${pct} charging`;
                    if (Battery.pluggedIn) return t + ` · ${pct}`;
                    return t + ` · ${pct}` + (Battery.timeToEmpty > 0 ? `, ${Battery.formatDuration(Battery.timeToEmpty)} left` : "");
                }
            }
        }

        Row {
            id: headerButtons
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s1
            IconButton {
                icon: "settings"
                onActivated: { Sidebar.hide(); SettingsState.launch(""); }
            }
            IconButton {
                icon: "power_settings_new"
                onActivated: { Sidebar.hide(); Session.menuOpen = true; }
            }
        }
    }

    // ── Body: tiles/sliders/system, or a detail list ───────────────────────
    Item {
        id: body
        anchors { top: header.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right }
        height: root.detail === "" ? main.implicitHeight : detailLoader.implicitHeight
        clip: true
        Behavior on height { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

        Column {
            id: main
            width: parent.width
            spacing: Theme.space.s3
            opacity: root.detail === "" ? 1 : 0
            visible: opacity > 0
            x: root.detail === "" ? 0 : -24
            Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

            // Connectivity: wide tiles (they open detail lists)
            Row {
                id: tiles
                width: parent.width
                spacing: Theme.space.s2
                readonly property real tileWidth: Bluetooth.available ? (width - spacing) / 2 : width

                QuickTile {
                    width: tiles.tileWidth
                    icon: Network.icon
                    label: "Wi-Fi"
                    sublabel: !Network.wifiEnabled ? "Off" : Network.connected ? Network.ssid : "Not connected"
                    active: Network.wifiEnabled && Network.connected
                    hasDetail: true
                    onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
                    onDetailRequested: root.detail = "wifi"
                }
                QuickTile {
                    width: tiles.tileWidth
                    visible: Bluetooth.available
                    icon: Bluetooth.icon
                    label: "Bluetooth"
                    sublabel: !Bluetooth.enabled ? "Off" : Bluetooth.hasConnection ? (Bluetooth.primary?.name ?? "Connected") : "On"
                    active: Bluetooth.enabled
                    hasDetail: true
                    onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                    onDetailRequested: root.detail = "bluetooth"
                }
            }

            // Everything else: one calm grid of round toggles and actions.
            // Toggles fill with the accent when on; actions never do.
            Grid {
                id: toggles
                width: parent.width
                columns: 4
                rowSpacing: Theme.space.s2
                columnSpacing: (width - 4 * 76) / 3

                RoundToggle {
                    icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    label: "Focus"
                    active: Notifications.dnd
                    onToggled: Notifications.setDnd(!Notifications.dnd)
                }
                RoundToggle {
                    icon: "coffee"
                    label: Caffeine.on ? "Awake" : "Caffeine"
                    active: Caffeine.on
                    onToggled: Caffeine.toggle()
                }
                RoundToggle {
                    icon: "nightlight"
                    label: "Night light"
                    active: NightLight.enabled
                    onToggled: NightLight.toggle()
                }
                RoundToggle {
                    icon: Audio.micMuted ? "mic_off" : "mic"
                    label: Audio.micMuted ? "Mic off" : "Mic"
                    active: !Audio.micMuted
                    onToggled: Audio.toggleMicMute()
                }
                RoundToggle {
                    icon: "flight"
                    label: "Airplane"
                    active: Airplane.on
                    onToggled: Airplane.toggle()
                }
                RoundToggle {
                    icon: Power.icon
                    label: Power.saver ? "Saver" : Power.label
                    active: Power.profile !== PowerProfile.Balanced   // saver or performance = "on"
                    onToggled: Power.cycle()
                }
                RoundToggle {
                    icon: "sports_esports"
                    label: "Game mode"
                    active: GameMode.on
                    onToggled: GameMode.toggle()
                }
                RoundToggle {
                    icon: Theme.dark ? "dark_mode" : "light_mode"
                    label: Theme.dark ? "Dark" : "Light"
                    active: Theme.dark
                    onToggled: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "theme", Theme.dark ? "light" : "dark"])
                }
                RoundToggle {
                    visible: KbdLight.available
                    icon: "keyboard"
                    label: KbdLight.level === 0 ? "Keys off" : "Keys " + KbdLight.level + "/" + KbdLight.max
                    active: KbdLight.level > 0
                    onToggled: KbdLight.cycle()
                }
                RoundToggle {
                    visible: Warp.available
                    icon: "cloud"
                    label: "WARP"
                    active: Warp.connected
                    busy: Warp.busy
                    onToggled: Warp.toggle()
                }
                RoundToggle {
                    visible: Vpn.available
                    icon: Vpn.active ? "vpn_lock" : "vpn_key"
                    label: "VPN"
                    active: Vpn.active
                    onToggled: Vpn.toggle()
                }
                RoundToggle {
                    icon: glassOn ? "blur_on" : "blur_off"
                    label: "Glass"
                    readonly property bool glassOn: Theme.tokens.transparency ?? true
                    active: glassOn
                    onToggled: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "transparency", "toggle"])
                }
                RoundToggle {
                    action: true
                    icon: "lock"
                    label: "Lock"
                    onToggled: { Sidebar.hide(); root.later([Theme.lumenRoot + "/bin/lumen-shell-ipc", "lock", "lock"]); }
                }
                RoundToggle {
                    action: true
                    icon: Island.recording ? "stop_circle" : "screen_record"
                    label: Island.recording ? "Stop" : "Record"
                    active: Island.recording
                    onToggled: { Sidebar.hide(); root.later([Theme.lumenRoot + "/scripts/screen-record.sh", Island.recording ? "stop" : "toggle", "region"]); }
                }
                RoundToggle {
                    action: true
                    icon: "screenshot_region"
                    label: "Screenshot"
                    onToggled: { Sidebar.hide(); root.later([Theme.lumenRoot + "/scripts/screenshot.sh", "region"]); }
                }
                RoundToggle {
                    action: true
                    icon: "document_scanner"
                    label: "Copy text"
                    onToggled: { Sidebar.hide(); root.later([Theme.lumenRoot + "/scripts/screen-text.sh"]); }
                }
                RoundToggle {
                    action: true
                    icon: "colorize"
                    label: "Pick colour"
                    onToggled: { Sidebar.hide(); root.later(["hyprpicker", "-a"]); }
                }
            }

            // Sliders
            Column {
                width: parent.width
                spacing: Theme.space.s2

                Row {
                    width: parent.width
                    spacing: Theme.space.s2
                    LSlider {
                        id: volSlider
                        width: parent.width - outputButton.width - parent.spacing
                        icon: Audio.muted ? "volume_off" : Audio.volume < 0.34 ? "volume_mute" : Audio.volume < 0.67 ? "volume_down" : "volume_up"
                        value: Audio.volume
                        dimmed: Audio.muted
                        onMoved: v => Audio.nudge(v - Audio.volume)
                        Percent { value: Audio.muted ? -1 : Audio.volume }
                    }
                    IconButton {
                        id: outputButton
                        icon: "speaker_group"
                        onActivated: root.detail = "output"
                    }
                }
                LSlider {
                    visible: Brightness.available
                    width: parent.width - outputButton.width - parent.spacing
                    icon: "brightness_6"
                    value: Brightness.value
                    onMoved: v => Brightness.set(v)
                    Percent { value: Brightness.value }
                }
            }

            NowPlayingCard { width: parent.width; visible: Media.present }

            SystemStats { width: parent.width }

            MonthCard { width: parent.width; today: clock.date }
        }

        Loader {
            id: detailLoader
            width: parent.width
            active: root.detail !== ""
            opacity: root.detail !== "" ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
            sourceComponent: root.detail === "wifi" ? wifiDetail
                           : root.detail === "bluetooth" ? btDetail
                           : root.detail === "output" ? outputDetail : null
            onLoaded: item.forceActiveFocus()
        }
    }

    // "42%" at the slider's right end, over the track (muted → "Muted")
    component Percent: LText {
        property real value: 0
        anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        role: "caption"
        // Readable once the fill reaches under the label
        color: value > 0.86 ? Theme.onAccent : Theme.textSecondary
        text: value < 0 ? "Muted" : Math.round(value * 100) + "%"
    }

    Component { id: wifiDetail; WifiDetail { onBack: root.detail = "" } }
    Component { id: btDetail; BluetoothDetail { onBack: root.detail = "" } }
    Component { id: outputDetail; OutputDetail { onBack: root.detail = "" } }
}
