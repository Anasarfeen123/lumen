// Shared native surface motion. Geometry and opacity have separate clocks;
// interrupted transitions continue from their actual values, never from zero.
// `retained` owns window lifetime, including the final frame of dismissal.
import QtQuick
import qs.theme

GlassSurface {
    id: root
    property bool shown: false
    property string motionStyle: "popup"       // popup | sidebar | dialog | sheet
    property int motionOrigin: Item.Top
    property real offsetX: 0
    property real offsetY: motionStyle === "sidebar" ? 0 : motionStyle === "sheet" ? Theme.space.s4 : motionStyle === "dialog" ? Theme.space.s2 : -Theme.space.s1
    property real progress: 0
    property real alpha: 0
    property bool initialized: false
    property bool didSettle: true
    readonly property bool retained: shown || progress > 0.001 || alpha > 0.001 || travel.running || fade.running
    readonly property bool animating: travel.running || fade.running
    readonly property real initialScale: motionStyle === "sidebar" || motionStyle === "sheet" ? 1 : motionStyle === "dialog" ? Theme.motion.dialogScale : Theme.motion.popupScale
    signal opening(bool fresh)
    signal settled(bool opened)

    function notifySettled() {
        const goal = shown ? 1 : 0;
        if (didSettle || animating || Math.abs(progress - goal) > 0.001 || Math.abs(alpha - goal) > 0.001) return;
        didSettle = true;
        settled(shown);
    }
    function transition(announce) {
        const goal = shown ? 1 : 0;
        const fresh = progress <= 0.001 && alpha <= 0.001;
        didSettle = false;
        travel.stop(); fade.stop();
        if (shown && announce) opening(fresh);
        const distance = Math.abs(goal - progress);
        if (Theme.reducedMotion || distance <= 0.001) progress = goal;
        else {
            travel.from = progress; travel.to = goal;
            // Short reversals finish sooner without snapping or replaying an entrance.
            travel.duration = Math.max(1, Math.round(Theme.surfaceDuration(motionStyle, shown) * Math.sqrt(distance)));
            travel.easing.bezierCurve = shown ? Theme.curveSurface : Theme.curveAccelerate;
            travel.start();
        }
        const opacityDistance = Math.abs(goal - alpha);
        if (opacityDistance <= 0.001) alpha = goal;
        else {
            fade.from = alpha; fade.to = goal;
            fade.duration = Math.max(1, Math.round((Theme.reducedMotion ? 100 : shown ? Theme.motion.surfaceFadeIn : Theme.motion.surfaceFadeOut) * opacityDistance));
            fade.start();
        }
        Qt.callLater(notifySettled);
    }
    // A compositor-dismissed xdg popup is already gone: do not leave a stale
    // partially-open value behind for its next mapping.
    function resetClosed() {
        travel.stop(); fade.stop(); progress = 0; alpha = 0; didSettle = true;
    }
    onShownChanged: if (initialized) transition(true)
    Component.onCompleted: { initialized = true; if (shown) transition(true); }
    Connections { target: Theme; function onReducedMotionChanged() { if (root.initialized) root.transition(false); } }
    NumberAnimation { id: travel; target: root; property: "progress"; easing.type: Easing.Bezier; onFinished: root.notifySettled() }
    NumberAnimation { id: fade; target: root; property: "alpha"; easing.type: Easing.OutQuad; onFinished: root.notifySettled() }

    opacity: alpha
    transformOrigin: motionOrigin
    scale: Theme.reducedMotion ? 1 : initialScale + (1 - initialScale) * progress
    transform: Translate {
        x: Theme.reducedMotion ? 0 : root.offsetX * (1 - root.progress)
        y: Theme.reducedMotion ? 0 : root.offsetY * (1 - root.progress)
    }
}
