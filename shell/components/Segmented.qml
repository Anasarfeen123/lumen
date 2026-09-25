// Segmented control: a row of options with one selected; the highlight
// slides between them. options: [{ id, label }] ; emits picked(id).
import QtQuick
import qs.theme

Item {
    id: root
    property var options: []
    property string current: ""
    signal picked(string id)

    readonly property int index: Math.max(0, options.findIndex(o => o.id === current))
    readonly property real segWidth: width / Math.max(1, options.length)

    implicitWidth: Math.max(160, options.length * 96)
    implicitHeight: 32
    activeFocusOnTab: true
    Keys.onLeftPressed: if (index > 0) picked(options[index - 1].id)
    Keys.onRightPressed: if (index < options.length - 1) picked(options[index + 1].id)

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceElevated
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
    }
    Rectangle {
        x: root.index * root.segWidth + 3
        y: 3
        width: root.segWidth - 6
        height: parent.height - 6
        radius: height / 2
        color: Theme.accent
        Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
    }
    Row {
        anchors.fill: parent
        Repeater {
            model: root.options
            delegate: Item {
                required property var modelData
                required property int index
                width: root.segWidth
                height: root.height
                LText {
                    anchors.centerIn: parent
                    role: "bodyStrong"
                    text: modelData.label
                    color: index === root.index ? Theme.onAccent : Theme.textSecondary
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData.id) }
            }
        }
    }
}
