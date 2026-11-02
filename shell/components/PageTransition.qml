// Swap content at zero opacity, rather than crossfading two readable pages.
// The header/selection can update immediately; presentedKey changes only at
// the midpoint. A new request during either phase retargets from that frame.
import QtQuick
import qs.theme

Item {
    id: root
    property string key: ""
    property string presentedKey: key
    property bool active: true
    property int direction: 1
    property real distance: Theme.space.s3
    property real reveal: 1
    property real offset: 0
    property bool initialized: false
    signal swapped()
    readonly property bool animating: leave.running || arrive.running || slide.running

    function stopAnimations() { leave.stop(); arrive.stop(); slide.stop(); }
    function snap() { stopAnimations(); presentedKey = key; reveal = 1; offset = 0; }
    function enter(resetOffset) {
        if (resetOffset) offset = Theme.reducedMotion ? 0 : direction * distance;
        arrive.from = reveal;
        arrive.duration = Math.max(1, Math.round((Theme.reducedMotion ? 100 : Theme.motion.pageIn) * (1 - reveal)));
        arrive.start();
        if (Theme.reducedMotion) offset = 0;
        else { slide.from = offset; slide.duration = Theme.motion.pageMove; slide.start(); }
    }
    function change() {
        if (!initialized || !active) { snap(); return; }
        stopAnimations();
        if (key === presentedKey) { enter(false); return; }
        leave.from = reveal;
        leave.duration = Math.max(1, Math.round((Theme.reducedMotion ? 50 : Theme.motion.pageOut) * reveal));
        leave.start();
    }
    onKeyChanged: change()
    onActiveChanged: if (!active) snap()
    Component.onCompleted: { initialized = true; snap(); }
    Connections { target: Theme; function onReducedMotionChanged() { if (Theme.reducedMotion) { slide.stop(); root.offset = 0; } } }
    NumberAnimation {
        id: leave; target: root; property: "reveal"; to: 0; easing.type: Easing.OutQuad
        onFinished: { root.presentedKey = root.key; root.swapped(); root.enter(true); }
    }
    NumberAnimation { id: arrive; target: root; property: "reveal"; to: 1; easing.type: Easing.OutQuad }
    NumberAnimation { id: slide; target: root; property: "offset"; to: 0; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveSurface }
}
