// One row in a detail list: icon · title/subtitle · trailing glyph or button.
//   section         a small heading drawn above the row (first row of a group)
//   trailingAction  an icon button at the end (e.g. "more_horiz"); trailingClicked()
//   busy            the leading icon breathes (connecting, pairing)
// Anything declared inside the row (a password field, action chips) appears
// under it.
import QtQuick
import qs.theme
import qs.components

Item {
    id: root
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string trailing: ""        // icon name, e.g. "check" or "lock"
    property string trailingAction: ""
    property string section: ""
    property bool current: false
    property bool busy: false
    default property alias extra: extraSlot.data
    signal clicked()
    signal trailingClicked()

    readonly property int sectionHeight: section !== "" ? 26 : 0
    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: sectionHeight + 44 + (extraSlot.visibleChildren.length > 0 ? extraSlot.height + Theme.space.s2 : 0)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
    clip: true

    LText {
        visible: root.section !== ""
        x: Theme.space.s3
        y: 8
        role: "caption"
        font.weight: Font.DemiBold
        color: Theme.textMuted
        text: root.section
    }

    HoverTarget {
        id: hit
        y: root.sectionHeight
        width: parent.width
        height: parent.height - root.sectionHeight
        radius: Theme.radius.sm
        highlighted: root.ListView.isCurrentItem && (root.ListView.view?.activeFocus ?? false)
        onClicked: root.clicked()

        Item {
            id: rowContent
            width: parent.width
            height: 44
            LIcon {
                id: lead
                anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                icon: root.icon
                fill: root.current ? 1 : 0
                color: root.current ? Theme.accent : Theme.textSecondary
                SequentialAnimation on opacity {
                    running: root.busy
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.35; duration: 650; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
                }
            }
            Column {
                anchors { left: lead.right; leftMargin: Theme.space.s3; right: trail.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                LText { width: parent.width; role: root.current ? "bodyStrong" : "body"; text: root.title; elide: Text.ElideRight }
                LText { width: parent.width; visible: text !== ""; role: "caption"; color: root.current ? Theme.accent : Theme.textMuted; text: root.subtitle; elide: Text.ElideRight }
            }
            Row {
                id: trail
                anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                spacing: 2
                LIcon {
                    visible: root.trailing !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    icon: root.trailing
                    size: Theme.size.iconSmall
                    color: root.current ? Theme.accent : Theme.textMuted
                }
                HoverTarget {
                    visible: root.trailingAction !== ""
                    width: 28; height: 28
                    onClicked: root.trailingClicked()
                    LIcon { anchors.centerIn: parent; icon: root.trailingAction; size: Theme.size.iconSmall; color: Theme.textSecondary }
                }
            }
        }
        Item {
            id: extraSlot
            anchors { top: rowContent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
            height: childrenRect.height
        }
    }
}
