// Hot corners for one screen.
//   top-left  → overview & search      top-right → control centre
import QtQuick
import Quickshell
import qs.services

Scope {
    id: root
    required property var screen

    HotCorner {
        screen: root.screen
        corner: "topLeft"
        allowed: Persist.data.hotCornerLeft
        onTriggered: Overview.toggle("search")
    }
    HotCorner {
        screen: root.screen
        corner: "topRight"
        allowed: Persist.data.hotCornerRight
        onTriggered: Sidebar.toggle("controls")
    }
}
