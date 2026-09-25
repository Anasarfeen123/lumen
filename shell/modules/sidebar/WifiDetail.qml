// Wi-Fi networks. Known/open networks join on click; new secured networks
// reveal a password field in place (Enter joins, Esc cancels).
import QtQuick
import Quickshell
import Quickshell.Networking
import qs.theme
import qs.components
import qs.services

DetailPage {
    id: page
    title: "Wi-Fi"
    showSwitch: true
    switchOn: Network.wifiEnabled === true
    onSwitchToggled: Network.setWifiEnabled(!Network.wifiEnabled)
    emptyText: Network.wifiEnabled ? "Searching…" : "Wi-Fi is off"
    footerText: "Network settings…"
    onFooterActivated: { Sidebar.hide(); Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-launch", "nm-connection-editor", "systemsettings kcm_networkmanagement"]); }

    property string asking: ""          // SSID whose password field is open

    model: Network.wifiEnabled ? Network.networks : []
    delegate: ListRow {
        id: row
        required property var modelData
        readonly property real s: modelData.signalStrength > 1 ? modelData.signalStrength / 100 : modelData.signalStrength
        icon: s > 0.75 ? "signal_wifi_4_bar" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar"
        title: modelData.name
        subtitle: modelData.connected ? "Connected" : modelData.known ? "Saved" : ""
        trailing: modelData.connected ? "check" : Network.isSecure(modelData) ? "lock" : ""
        current: modelData.connected
        onClicked: {
            if (modelData.connected) return;
            if (Network.needsPassword(modelData)) { page.asking = modelData.name; field.forceActiveFocus(); }
            else Network.connectTo(modelData, "");
        }

        Rectangle {
            visible: page.asking === row.modelData.name
            width: parent.width
            height: visible ? 36 : 0
            radius: Theme.radius.sm
            color: Theme.surface
            border.width: 1
            border.color: field.activeFocus ? Theme.accent : Theme.borderStrong
            TextInput {
                id: field
                anchors { fill: parent; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.text
                font.family: Theme.fontUi
                font.pixelSize: Theme.size.body
                selectByMouse: true
                Keys.onReturnPressed: { Network.connectTo(row.modelData, text); text = ""; page.asking = ""; }
                Keys.onEscapePressed: event => { text = ""; page.asking = ""; event.accepted = true; }
                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: parent.text === ""
                    color: Theme.textMuted
                    text: "Password"
                }
            }
        }
    }
}
