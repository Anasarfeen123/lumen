// Paired Bluetooth devices: click to connect / disconnect. Pairing new
// devices happens in the system's Bluetooth settings (footer link).
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt
import qs.theme
import qs.components
import qs.services

DetailPage {
    title: "Bluetooth"
    showSwitch: true
    switchOn: Bluetooth.enabled
    onSwitchToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
    emptyText: Bluetooth.enabled ? "No paired devices" : "Bluetooth is off"
    footerText: "Pair new device…"
    onFooterActivated: { Sidebar.hide(); Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "systemsettings kcm_bluetooth", "blueman-manager"]); }

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

    model: Bluetooth.enabled ? Bluetooth.paired : []
    delegate: ListRow {
        required property var modelData
        icon: glyph(modelData.icon ?? "")
        title: modelData.name || modelData.deviceName || modelData.address
        subtitle: modelData.pairing ? "Pairing…"
                : modelData.state === QsBt.BluetoothDeviceState.Connecting ? "Connecting…"
                : modelData.connected ? ("Connected" + (modelData.batteryAvailable ? ` · ${Math.round(modelData.battery * 100)}%` : ""))
                : ""
        trailing: modelData.connected ? "check" : ""
        current: modelData.connected
        onClicked: Bluetooth.toggleDevice(modelData)
    }
}
