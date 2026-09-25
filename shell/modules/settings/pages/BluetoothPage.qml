// Bluetooth: on/off, paired devices (connect, battery), pairing.
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Bluetooth"

    function glyph(icon) {
        if (/headset|headphone|audio-card/.test(icon)) return "headphones";
        if (/speaker|audio/.test(icon)) return "speaker";
        if (/mouse/.test(icon)) return "mouse";
        if (/keyboard/.test(icon)) return "keyboard";
        if (/phone/.test(icon)) return "smartphone";
        if (/gaming|joystick/.test(icon)) return "sports_esports";
        if (/watch/.test(icon)) return "watch";
        return "bluetooth";
    }

    Group {
        SetRow {
            icon: Bluetooth.icon
            title: "Bluetooth"
            description: !Bluetooth.available ? "No adapter found" : Bluetooth.enabled ? (Bluetooth.adapter?.name ?? "On") : "Off"
            LSwitch { visible: Bluetooth.available; checked: Bluetooth.enabled; onToggled: Bluetooth.setEnabled(!Bluetooth.enabled) }
        }
    }

    Group {
        title: "My devices"
        visible: Bluetooth.enabled
        Repeater {
            model: Bluetooth.paired
            delegate: SetRow {
                required property var modelData
                icon: glyph(modelData.icon ?? "")
                title: modelData.name || modelData.deviceName || modelData.address
                description: modelData.state === QsBt.BluetoothDeviceState.Connecting ? "Connecting…"
                           : modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "% battery" : "")
                           : "Not connected"
                Button {
                    text: modelData.connected ? "Disconnect" : "Connect"
                    primary: !modelData.connected
                    onActivated: Bluetooth.toggleDevice(modelData)
                }
            }
        }
        SetRow {
            visible: Bluetooth.paired.length === 0
            icon: "info"
            title: "No paired devices yet"
        }
    }

    Group {
        SetRow {
            icon: "add_link"
            title: "Pair a new device"
            description: "Opens the system's Bluetooth pairing"
            Button { text: "Pair…"; onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "systemsettings kcm_bluetooth", "blueman-manager"]) }
        }
    }
}
