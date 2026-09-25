pragma Singleton
// Airplane mode: every radio off (Wi-Fi, WWAN via NetworkManager; Bluetooth
// via BlueZ). Off again restores Wi-Fi and Bluetooth.
import QtQuick
import Quickshell

Singleton {
    readonly property bool on: !Network.wifiEnabled && !Bluetooth.enabled
    function toggle() {
        const enable = on;
        Quickshell.execDetached(["nmcli", "radio", "all", enable ? "on" : "off"]);
        Bluetooth.setEnabled(enable);
    }
}
