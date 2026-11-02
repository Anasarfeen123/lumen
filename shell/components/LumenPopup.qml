// Every Lumen popup (bar app menu, tray drawer, …) opens and closes the same
// way: a frosted panel that settles 4 px and grows from 98.5 % while fading in,
// and reverses on close. The popup window is larger than the panel by
// `margin` on every side, so the soft shadow isn't clipped; only the panel
// takes input. xdg-popup grab: it gets pointer + keyboard, and a click
// outside closes it. Esc closes too.
//
//   anchor.rect.x/y: pass the PANEL's position minus `margin`.
import QtQuick
import Quickshell
import qs.theme

PopupWindow {
    id: pop
    property real contentWidth: 300
    property real contentHeight: 200
    property int margin: 28
    property bool shown: false
    property int motionOrigin: Item.Top
    default property alias content: inner.data

    implicitWidth: contentWidth + margin * 2
    implicitHeight: contentHeight + margin * 2
    color: "transparent"
    visible: false
    grabFocus: true
    mask: Region { item: panel }

    function open() { visible = true; shown = true; }
    function close() { if (visible && shown) shown = false; }
    // Native xdg dismissal ends the grab immediately. Explicit close waits
    // for the actual final animation frame, including reduced-motion fades.
    onVisibleChanged: if (!visible) { shown = false; panel.resetClosed(); }

    MotionSurface {
        id: panel
        shown: pop.shown
        onRetainedChanged: if (!retained && !pop.shown) pop.visible = false
        motionOrigin: pop.motionOrigin
        x: pop.margin; y: pop.margin
        width: pop.contentWidth
        height: pop.contentHeight
        level: "panel"
        radius: Theme.radius.md
        focus: pop.visible
        Keys.onEscapePressed: pop.close()

        // Menus hold text: a denser backing than panels, still frosted
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.45) }
        Item { id: inner; anchors.fill: parent }
    }
}
