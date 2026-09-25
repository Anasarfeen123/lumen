// Pill slider: the fill IS the value (no thumb). Drag, click, scroll, or
// Left/Right when focused. Emits moved(v) — the owner decides what to do.
import QtQuick
import qs.theme

Item {
    id: root
    property real value: 0          // 0–1
    property string icon: ""
    property bool dimmed: false     // e.g. muted: fill turns neutral
    readonly property bool dragging: area.pressed
    signal moved(real v)

    implicitHeight: 32
    activeFocusOnTab: true
    Keys.onLeftPressed: moved(Math.max(0, value - 0.05))
    Keys.onRightPressed: moved(Math.min(1, value + 0.05))

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceElevated
        border.width: 1
        border.color: root.activeFocus ? Theme.accent : Theme.border
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, root.value)))
            radius: height / 2
            color: root.dimmed ? Theme.surfaceHover : Theme.accent
            Behavior on width { enabled: !root.dragging; NumberAnimation { duration: Theme.motion.micro } }
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        }

        LIcon {
            anchors { left: parent.left; leftMargin: (parent.height - width) / 2; verticalCenter: parent.verticalCenter }
            icon: root.icon
            size: Theme.size.iconSmall
            fill: 1
            color: root.dimmed ? Theme.textMuted : Theme.onAccent
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        function set(x) { root.moved(Math.max(0, Math.min(1, x / width))); }
        onPressed: mouse => set(mouse.x)
        onPositionChanged: mouse => { if (pressed) set(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
