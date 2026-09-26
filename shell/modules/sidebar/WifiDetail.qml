// Wi-Fi networks, in three calm groups: the one you're on, saved networks,
// and others nearby. Clicking a network joins it; a new secured network
// reveals a password field in place (Enter joins, Esc cancels). The ⋯ button
// on a known network offers Disconnect / Forget.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

DetailPage {
    id: page
    title: "Wi-Fi"
    showSwitch: true
    switchOn: Network.wifiEnabled === true
    onSwitchToggled: Network.setWifiEnabled(!Network.wifiEnabled)
    busy: Network.wifiEnabled && Network.scanning
    status: !Network.wifiEnabled ? "" : Network.wired && !Network.connected ? "Ethernet in use" : ""
    emptyText: Network.wifiEnabled ? "Looking for networks…" : "Wi-Fi is off"
    footerText: "Network settings…"
    onFooterActivated: { Sidebar.hide(); Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "nm-connection-editor", "systemsettings kcm_networkmanagement"]); }

    property string asking: ""          // SSID whose password field is open
    property string menuFor: ""         // SSID whose Disconnect / Forget chips are open
    property string joining: ""         // SSID we just asked to join (until it connects or fails)

    function groupOf(n) { return n.connected ? "Connected" : n.known ? "Saved networks" : "Other networks"; }

    Connections {
        target: Network
        function onSsidChanged() { if (Network.ssid === page.joining) page.joining = ""; }
        function onConnectFailed() { page.joining = ""; }
    }

    model: Network.wifiEnabled ? Network.networks : []
    delegate: ListRow {
        id: row
        required property var modelData
        required property int index
        readonly property real s: modelData.signalStrength > 1 ? modelData.signalStrength / 100 : modelData.signalStrength
        readonly property bool joiningThis: page.joining === modelData.name && !modelData.connected
        section: {
            const prev = index > 0 ? Network.networks[index - 1] : null;
            const g = page.groupOf(modelData);
            return !prev || page.groupOf(prev) !== g ? g : "";
        }
        icon: s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
        title: modelData.name
        subtitle: joiningThis || modelData.stateChanging ? "Connecting…"
                : modelData.connected ? "Connected" + (Network.isSecure(modelData) ? " · secured" : "")
                : !Network.isSecure(modelData) ? "Open network"
                : ""
        busy: joiningThis || modelData.stateChanging
        trailing: modelData.connected ? "check" : Network.isSecure(modelData) && !modelData.known ? "lock" : ""
        trailingAction: modelData.known || modelData.connected ? "more_horiz" : ""
        current: modelData.connected
        onTrailingClicked: page.menuFor = page.menuFor === modelData.name ? "" : modelData.name
        onClicked: {
            if (modelData.connected) { page.menuFor = page.menuFor === modelData.name ? "" : modelData.name; return; }
            if (Network.needsPassword(modelData)) {
                page.asking = page.asking === modelData.name ? "" : modelData.name;
                if (page.asking) field.forceActiveFocus();
                return;
            }
            page.joining = modelData.name;
            Network.connectTo(modelData, "");
        }

        // Password field (new secured network)
        Rectangle {
            visible: page.asking === row.modelData.name
            width: parent.width
            height: 36
            radius: Theme.radius.sm
            color: Theme.surface
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.borderStrong
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: Theme.space.s3; rightMargin: 34 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: reveal.shown ? TextInput.Normal : TextInput.Password
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.size.body
                selectByMouse: true
                function join() {
                    if (text === "") return;
                    page.joining = row.modelData.name;
                    Network.connectTo(row.modelData, text); text = ""; page.asking = "";
                }
                Keys.onReturnPressed: join()
                Keys.onEnterPressed: join()
                Keys.onEscapePressed: event => { text = ""; page.asking = ""; event.accepted = true; }
                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text === ""
                    color: Theme.textMuted
                    text: "Password for " + row.modelData.name
                }
            }
            HoverTarget {
                id: reveal
                property bool shown: false
                anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                width: 28; height: 28
                onClicked: shown = !shown
                LIcon { anchors.centerIn: parent; icon: reveal.shown ? "visibility_off" : "visibility"; size: 16; color: Theme.textMuted }
            }
        }

        // Disconnect / Forget
        Row {
            visible: page.menuFor === row.modelData.name
            spacing: 6
            ActionChip {
                visible: row.modelData.connected
                icon: "link_off"; label: "Disconnect"
                onClicked: { page.menuFor = ""; Network.disconnectFrom(row.modelData); }
            }
            ActionChip {
                visible: !row.modelData.connected
                icon: "wifi"; label: "Join"
                onClicked: { page.menuFor = ""; page.joining = row.modelData.name; Network.connectTo(row.modelData, ""); }
            }
            ActionChip {
                icon: "delete"; label: "Forget"; danger: true
                onClicked: { page.menuFor = ""; Network.forget(row.modelData); }
            }
        }
    }
}
