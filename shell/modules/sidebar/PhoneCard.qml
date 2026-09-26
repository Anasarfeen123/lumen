// Your phone in the control centre (only when one is paired):
// name · battery · Find · Send file · Send clipboard · Ping
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    readonly property var d: Connect.phone
    visible: d !== null
    implicitHeight: col.implicitHeight + Theme.space.s3 * 2
    radius: Theme.radius.md
    color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
    border.width: 1; border.color: Theme.border
    Binding { target: Connect; property: "watching"; value: Sidebar.open }

    component Act: HoverTarget {
        id: a
        property string icon
        property string label
        width: (col.width - 3 * 6) / 4; height: 30
        enabled: root.d?.reachable ?? false
        opacity: enabled ? 1 : 0.4
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: Theme.withAlpha(Theme.text, 0.05); border.width: 1; border.color: Theme.border }
        Row { anchors.centerIn: parent; spacing: 5
              LIcon { icon: a.icon; size: 15; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: a.label; anchors.verticalCenter: parent.verticalCenter } }
    }

    Column {
        id: col
        x: Theme.space.s3; y: Theme.space.s3
        width: parent.width - Theme.space.s3 * 2
        spacing: Theme.space.s2
        Item {
            width: parent.width; height: 24
            Row {
                spacing: Theme.space.s2
                anchors.verticalCenter: parent.verticalCenter
                LIcon { icon: root.d?.type === "tablet" ? "tablet_android" : "smartphone"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "bodyStrong"; text: root.d?.name ?? ""; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                        text: (root.d?.reachable ?? false) ? "Connected" : "Not nearby" }
            }
            Row {
                visible: (root.d?.battery ?? -1) >= 0
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: 3
                LIcon { icon: root.d?.charging ? "battery_charging_full" : "battery_full"; size: 15; rotation: 90
                        color: (root.d?.battery ?? 100) <= 15 ? Theme.error : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                LText { role: "caption"; font.features: { "tnum": 1 }; text: (root.d?.battery ?? 0) + "%"; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Row {
            spacing: 6
            Act { icon: "phone_in_talk"; label: "Find"; onClicked: Connect.act("ring", root.d.id) }
            Act { icon: "upload_file"; label: "File"; onClicked: { Sidebar.hide(); Connect.act("pick-and-share", root.d.id); } }
            Act { icon: "content_paste_go"; label: "Clip"; onClicked: Connect.act("send-clipboard", root.d.id) }
            Act { icon: "notifications_active"; label: "Ping"; onClicked: Connect.act("ping", root.d.id) }
        }
    }
}
