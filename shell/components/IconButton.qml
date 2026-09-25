// Round icon button (32 px) with hover feedback and keyboard activation.
import QtQuick
import qs.theme

HoverTarget {
    id: root
    property string icon: ""
    property color tone: Theme.textSecondary
    property real iconSize: Theme.size.iconSmall
    signal activated()

    width: 32
    height: 32
    activeFocusOnTab: true
    highlighted: activeFocus
    onClicked: activated()
    Keys.onReturnPressed: activated()
    Keys.onSpacePressed: activated()

    LIcon { anchors.centerIn: parent; icon: root.icon; size: root.iconSize; color: root.tone }
}
