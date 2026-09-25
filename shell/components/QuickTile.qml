// Control-centre toggle tile (DESIGN.md §10: primitives).
//   click / Enter / Space  → toggled()
//   chevron (if hasDetail) → detailRequested()  e.g. network list
// Active tiles take a soft accent tint; the icon fills. Nothing else changes.
import QtQuick
import qs.theme

Item {
    id: root
    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool hasDetail: false
    signal toggled()
    signal detailRequested()

    implicitHeight: 56
    activeFocusOnTab: true
    Keys.onReturnPressed: toggled()
    Keys.onSpacePressed: toggled()
    Keys.onRightPressed: if (hasDetail) detailRequested()

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius.md
        color: root.active ? Theme.withAlpha(Theme.accent, 0.16) : Theme.surfaceElevated
        border.width: 1
        border.color: root.activeFocus ? Theme.accent
                    : root.active ? Theme.withAlpha(Theme.accent, 0.32) : Theme.border
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
    }

    HoverTarget {
        id: main
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: root.hasDetail ? chevron.left : parent.right }
        radius: Theme.radius.md
        onClicked: root.toggled()

        Row {
            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s3

            LIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: root.icon
                fill: root.active ? 1 : 0
                color: root.active ? Theme.accent : Theme.textSecondary
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: main.width - Theme.space.s3 * 3 - Theme.size.icon
                LText { width: parent.width; role: "bodyStrong"; text: root.label; elide: Text.ElideRight }
                LText {
                    width: parent.width
                    visible: text !== ""
                    role: "caption"
                    color: Theme.textMuted
                    text: root.sublabel
                    elide: Text.ElideRight
                }
            }
        }
    }

    HoverTarget {
        id: chevron
        visible: root.hasDetail
        width: root.hasDetail ? 32 : 0
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        radius: Theme.radius.md
        onClicked: root.detailRequested()
        LIcon { anchors.centerIn: parent; icon: "chevron_right"; size: Theme.size.iconSmall; color: Theme.textMuted }
    }
}
