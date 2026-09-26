// Bluetooth: your devices, then devices nearby (searched for only while this
// list is open). Click one of yours to connect or disconnect; click a nearby
// device to pair it; it's trusted, so it reconnects by itself next time. The
// ⋯ button on your devices offers Forget.
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt
import qs.theme
import qs.components
import qs.services

DetailPage {
    id: page
    title: "Bluetooth"
    showSwitch: true
    switchOn: Bluetooth.enabled
    onSwitchToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
    busy: Bluetooth.enabled && Bluetooth.discovering
    emptyText: Bluetooth.enabled ? "Looking for devices…" : "Bluetooth is off"
    footerText: "Bluetooth settings…"
    onFooterActivated: { Sidebar.hide(); Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "systemsettings kcm_bluetooth", "blueman-manager"]); }

    property string menuFor: ""         // address whose Forget chip is open

    // Yours (connected first), then nearby
    readonly property var items: Bluetooth.enabled
        ? Bluetooth.paired.map(d => ({ d, group: "My devices" })).concat(Bluetooth.nearby.map(d => ({ d, group: "Nearby" })))
        : []

    model: items
    delegate: ListRow {
        id: row
        required property var modelData
        required property int index
        readonly property var dev: modelData.d
        readonly property bool mine: modelData.group === "My devices"
        readonly property bool connecting: dev.state === QsBt.BluetoothDeviceState.Connecting
        readonly property bool pairingThis: dev.pairing || Bluetooth.pairing === dev
        section: index === 0 || page.items[index - 1].group !== modelData.group ? modelData.group : ""
        icon: Bluetooth.glyph(dev.icon ?? "")
        title: dev.name || dev.deviceName || dev.address
        subtitle: pairingThis ? "Pairing…"
                : connecting ? "Connecting…"
                : dev.state === QsBt.BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                : dev.connected ? "Connected" + (dev.batteryAvailable ? ` · ${Math.round(dev.battery * 100)}% battery` : "")
                : mine ? "Not connected" : "Click to pair"
        busy: pairingThis || connecting
        trailing: dev.connected ? "check" : ""
        trailingAction: mine ? "more_horiz" : ""
        current: dev.connected
        onTrailingClicked: page.menuFor = page.menuFor === dev.address ? "" : dev.address
        onClicked: mine ? Bluetooth.toggleDevice(dev) : Bluetooth.pair(dev)

        Row {
            visible: page.menuFor === row.dev.address
            spacing: 6
            ActionChip {
                icon: row.dev.connected ? "link_off" : "link"
                label: row.dev.connected ? "Disconnect" : "Connect"
                onClicked: { page.menuFor = ""; Bluetooth.toggleDevice(row.dev); }
            }
            ActionChip {
                icon: "delete"; label: "Forget"; danger: true
                onClicked: { page.menuFor = ""; Bluetooth.forget(row.dev); }
            }
        }
    }
}
