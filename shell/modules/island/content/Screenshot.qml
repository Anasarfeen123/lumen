// screenshot — thumbnail + confirmation. Clicking the island opens the file.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components

Item {
    id: root
    required property var info
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2
        ClippingRectangle {
            width: 36; height: 22
            radius: Theme.radius.xs
            color: Theme.surfaceElevated
            anchors.verticalCenter: parent.verticalCenter
            Image {
                anchors.fill: parent
                source: root.info.path ? "file://" + root.info.path : ""
                sourceSize: Qt.size(72, 44)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        LText { role: "bodyStrong"; text: "Screenshot copied"; anchors.verticalCenter: parent.verticalCenter }
    }
}
