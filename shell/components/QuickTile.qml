// Control-centre connectivity tile (DESIGN.md §10: primitives).
//
//   ┌──────────────────────────────┐
//   │ (◉)  Wi-Fi                 › │   the round icon is the switch;
//   │      HomeNetwork             │   the rest opens the list
//   └──────────────────────────────┘
//
//   click icon / Space       → toggled()
//   click tile / Enter / →   → detailRequested()   (toggled() if no detail)
// When on, the icon disc fills with the accent and the tile takes a soft
// accent tint. One control never does two things.
import QtQuick
import qs.theme

Item {
    id: root
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool busy: false           // connecting / scanning: the disc breathes
    property bool hasDetail: false
    signal toggled()
    signal detailRequested()

    implicitHeight: 60
    activeFocusOnTab: true
    Keys.onSpacePressed: toggled()
    Keys.onReturnPressed: hasDetail ? detailRequested() : toggled()
    Keys.onRightPressed: if (hasDetail) detailRequested()

    // The whole tile: opens the detail list
    HoverTarget {
        id: main
        anchors.fill: parent
        radius: Theme.radius.md
        onClicked: root.hasDetail ? root.detailRequested() : root.toggled()

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius.md
            z: -1
            color: root.active ? Theme.withAlpha(Theme.accent, 0.12) : Theme.surfaceElevated
            border.width: 1
            border.color: root.activeFocus ? Theme.accent
                        : root.active ? Theme.withAlpha(Theme.accent, 0.28) : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
            Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
        }

        Column {
            anchors { left: parent.left; leftMargin: Theme.space.s3 + 36 + Theme.space.s3; right: chevron.left; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
            LText { width: parent.width; role: "bodyStrong"; text: root.label; elide: Text.ElideRight }
            LText {
                width: parent.width
                visible: text !== ""
                role: "caption"
                color: root.active ? Theme.textSecondary : Theme.textMuted
                text: root.sublabel
                elide: Text.ElideRight
            }
        }
        LIcon {
            id: chevron
            visible: root.hasDetail
            anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
            icon: "chevron_right"
            size: Theme.size.iconSmall
            color: main.containsMouse ? Theme.text : Theme.textMuted
        }
    }

    // The switch: a round disc on the left
    HoverTarget {
        id: disc
        width: 36; height: 36
        radius: 18
        anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        onClicked: root.toggled()

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            z: -1
            color: root.active ? Theme.accent : (disc.containsMouse ? Theme.surfaceHover : Theme.withAlpha(Theme.text, 0.06))
            border.width: root.active ? 0 : 1
            border.color: Theme.border
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
            SequentialAnimation on opacity {
                running: root.busy
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.55; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        LIcon {
            anchors.centerIn: parent
            icon: root.icon
            size: Theme.size.iconSmall + 2
            fill: root.active ? 1 : 0
            color: root.active ? Theme.onAccent : Theme.textSecondary
        }
    }
}
