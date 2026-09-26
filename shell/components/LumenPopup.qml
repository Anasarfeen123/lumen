// Every Lumen popup (bar app menu, tray drawer, …) opens and closes the same
// way: a frosted panel that drops 6 px and grows from 96 % while fading in,
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
    default property alias content: inner.data

    implicitWidth: contentWidth + margin * 2
    implicitHeight: contentHeight + margin * 2
    color: "transparent"
    visible: false
    grabFocus: true
    mask: Region { item: panel }

    function open() { closing.stop(); visible = true; shown = true; }
    function close() { if (!visible) return; shown = false; closing.restart(); }
    Timer { id: closing; interval: Theme.reducedMotion ? 0 : Theme.motion.micro + 40; onTriggered: if (!pop.shown) pop.visible = false }
    // Dismissed by the compositor (click outside): skip straight to hidden
    onVisibleChanged: if (!visible) shown = false

    GlassSurface {
        id: panel
        x: pop.margin; y: pop.margin
        width: pop.contentWidth
        height: pop.contentHeight
        level: "panel"
        radius: Theme.radius.md
        transformOrigin: Item.Top
        opacity: pop.shown ? 1 : 0
        scale: pop.shown ? 1 : 0.96
        transform: Translate { y: pop.shown ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } } }
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : (pop.shown ? Theme.motion.normal : Theme.motion.micro) } }
        Behavior on scale { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

        focus: pop.visible
        Keys.onEscapePressed: pop.close()

        // Menus hold text: a denser backing than panels, still frosted
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.45) }
        Item { id: inner; anchors.fill: parent }
    }
}
