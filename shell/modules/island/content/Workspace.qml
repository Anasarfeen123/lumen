// workspace — brief name/number after a switch.
import QtQuick
import qs.theme
import qs.components

Item {
    required property var info
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.island.height
    LText { id: label; anchors.centerIn: parent; role: "bodyStrong"; text: parent.info.label ?? "" }
}
