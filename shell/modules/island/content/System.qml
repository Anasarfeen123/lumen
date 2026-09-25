// system — icon + title + muted detail (Bluetooth, Wi-Fi, USB, power…).
import QtQuick
import qs.theme
import qs.components

Item {
    id: root
    required property var info
    readonly property color tone: ({ success: Theme.success, warning: Theme.warning, error: Theme.error })[info.tone] ?? Theme.text

    implicitWidth: Math.min(row.implicitWidth, Theme.island.maxCompactWidth - 2 * Theme.space.s4)
    implicitHeight: Theme.island.height

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2
        LIcon { icon: root.info.icon ?? ""; fill: 1; color: root.tone; anchors.verticalCenter: parent.verticalCenter }
        LText {
            role: "bodyStrong"; text: root.info.title ?? ""
            elide: Text.ElideRight; width: Math.min(implicitWidth, 180)
            anchors.verticalCenter: parent.verticalCenter
        }
        LText {
            visible: text !== ""
            role: "body"; color: Theme.textMuted; text: root.info.detail ?? ""
            elide: Text.ElideRight; width: Math.min(implicitWidth, 120)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
