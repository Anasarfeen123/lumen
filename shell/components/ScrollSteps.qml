// Turns wheel and touchpad scrolling into calm, deliberate steps.
// Touchpads and smooth-scrolling wheels send many small deltas per swipe:
// they add up to one notch (120) per step, and steps come at most once per
// `cooldown` ms, so one flick moves one workspace (or one volume notch).
//   ScrollSteps { id: s; onStep: dir => … }   ·   WheelHandler { onWheel: e => s.feed(e.angleDelta.y) }
import QtQuick

QtObject {
    property int cooldown: 220
    property real acc: 0
    property double last: 0
    signal step(int dir)            // +1 = up / away from you, -1 = down
    function feed(dy) {
        if (dy === 0) return;
        if ((dy > 0) !== (acc > 0)) acc = 0;     // changed direction: start over
        acc += dy;
        if (Math.abs(acc) < 120) return;
        const dir = acc > 0 ? 1 : -1;
        acc = 0;
        const now = Date.now();
        if (now - last < cooldown) return;
        last = now;
        step(dir);
    }
}
