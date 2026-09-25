// Network: Wi-Fi (networks, join), airplane mode, VPN / WARP.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Network"
    Component.onCompleted: { Network.scanning = true; Vpn.refresh(); Warp.refresh(); }
    Component.onDestruction: Network.scanning = false

    property string asking: ""

    Group {
        title: "Wi-Fi"
        SetRow {
            icon: Network.icon
            title: "Wi-Fi"
            description: !Network.wifiEnabled ? "Off" : Network.connected ? "Connected to " + Network.ssid : "Not connected"
            LSwitch { checked: Network.wifiEnabled; onToggled: Network.setWifiEnabled(!Network.wifiEnabled) }
        }
        Repeater {
            model: Network.wifiEnabled ? Network.networks.slice(0, 12) : []
            delegate: SetRow {
                required property var modelData
                readonly property real s: modelData.signalStrength > 1 ? modelData.signalStrength / 100 : modelData.signalStrength
                icon: s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
                title: modelData.name
                description: modelData.connected ? "Connected" : modelData.known ? "Saved" : Network.isSecure(modelData) ? "Secured" : "Open"
                Row {
                    spacing: Theme.space.s2
                    Rectangle {
                        visible: page.asking === modelData.name
                        width: 180; height: 32; radius: 16
                        color: Theme.surface
                        border.width: 1; border.color: pw.activeFocus ? Theme.accent : Theme.borderStrong
                        TextInput {
                            id: pw
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.text; font.family: Theme.fontUi; font.pixelSize: Theme.size.body
                            Keys.onReturnPressed: { Network.connectTo(modelData, text); text = ""; page.asking = ""; }
                            Keys.onEscapePressed: { text = ""; page.asking = ""; }
                        }
                    }
                    Button {
                        visible: !modelData.connected
                        text: page.asking === modelData.name ? "Join" : "Connect"
                        onActivated: {
                            if (page.asking === modelData.name) { Network.connectTo(modelData, pw.text); pw.text = ""; page.asking = ""; }
                            else if (Network.needsPassword(modelData)) { page.asking = modelData.name; pw.forceActiveFocus(); }
                            else Network.connectTo(modelData, "");
                        }
                    }
                    LIcon { visible: modelData.connected; icon: "check"; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    Group {
        title: "More"
        SetRow {
            icon: "flight"
            title: "Airplane mode"
            description: "Every radio off: Wi-Fi, mobile and Bluetooth"
            LSwitch { checked: Airplane.on; onToggled: Airplane.toggle() }
        }
        SetRow {
            visible: Vpn.available
            icon: Vpn.active ? "vpn_lock" : "vpn_key"
            title: "VPN" + (Vpn.primary ? " — " + Vpn.primary.name : "")
            LSwitch { checked: Vpn.active; onToggled: Vpn.toggle() }
        }
        SetRow {
            icon: "cloud"
            title: "Cloudflare WARP"
            description: Warp.available ? (Warp.connected ? "Connected" : "Off") : "Not installed — see one.one.one.one for Cloudflare's official Fedora repository"
            LSwitch { visible: Warp.available; checked: Warp.connected; enabled: !Warp.busy; onToggled: Warp.toggle() }
        }
        SetRow {
            icon: "settings_ethernet"
            title: "Advanced network settings"
            description: "Static IP, DNS, hidden networks, hotspots"
            Button { text: "Open…"; onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "nm-connection-editor", "systemsettings kcm_networkmanagement"]) }
        }
    }
}
