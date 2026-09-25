// System tray. Icons are desaturated at rest so third-party colours don't
// fight the design, and regain colour on hover.
//   left click: activate · middle: secondary · right: app menu
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.SystemTray
import qs.theme
import qs.components

Row {
    id: root
    required property var window
    spacing: 0
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items
        delegate: HoverTarget {
            id: target
            required property SystemTrayItem modelData
            width: 28
            height: Theme.barHeight - 8
            anchors.verticalCenter: parent?.verticalCenter

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate();
                else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
                else if (modelData.hasMenu) {
                    const p = target.mapToItem(null, 0, target.height + Theme.space.s2);
                    modelData.display(root.window, p.x, p.y);
                }
            }

            Image {
                id: img
                anchors.centerIn: parent
                width: Theme.size.iconSmall
                height: Theme.size.iconSmall
                sourceSize: Qt.size(width * 2, height * 2)
                source: target.modelData.icon
                smooth: true
                visible: false
            }
            MultiEffect {
                anchors.fill: img
                source: img
                saturation: target.containsMouse ? 0 : -0.85
                opacity: target.containsMouse ? 1 : 0.8
                Behavior on saturation { NumberAnimation { duration: Theme.motion.micro } }
                Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
            }
        }
    }
}
