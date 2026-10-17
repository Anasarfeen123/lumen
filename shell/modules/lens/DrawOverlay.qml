// Draw on the screen (Ctrl+Super+D): ink over everything — for presenting,
// explaining something on a call, or marking up before a screenshot.
//   drag: draw · right-drag: erase a stroke · 1–5: colours · [ ]: thinner/thicker
//   Ctrl+Z: undo · C: clear · S: screenshot with the ink · Esc: done (ink fades)
//   L: spotlight (everything dims but a circle round the pointer; scroll sizes it)
//   Z: zoom in round the pointer (Hyprland's zoom; reset when you're done)
//   P: back to the pen
// Lives on the focused screen; the ink is never saved unless you press S.
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool showing: DrawState.open && (Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? ""))
    property real fade: showing ? 1 : 0
    Behavior on fade { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? 120 : 420) } }

    visible: showing || fade > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-draw"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Region { item: showing ? board : null }

    readonly property var colors: [Theme.accent, "#ff5c5c", "#ffd84d", "#5ce08a", "#ffffff"]
    property int colorIndex: 0
    property real width_: 5
    property var strokes: []            // [{ points: [pt], color, width }]
    property var current: null
    property string tool: "pen"         // "pen" | "spotlight"
    property real spotR: 140
    property point pointer: Qt.point(width / 2, height / 2)
    property bool zoomed: false
    function setZoom(on) { zoomed = on; Hypr.set("{ cursor = { zoom_factor = " + (on ? 2 : 1) + " } }"); }
    onShowingChanged: {
        if (showing) { strokes = []; tool = "pen"; Qt.callLater(() => keys.forceActiveFocus()); }
        else if (zoomed) setZoom(false);
    }

    Item {
        id: board
        anchors.fill: parent
        opacity: win.fade
        // a whisper of a tint, so it's clear the screen is in drawing mode
        Rectangle { anchors.fill: parent; color: Theme.withAlpha(Theme.bg, 0.06); visible: win.tool === "pen" }
        // spotlight: a ring so thick it covers the screen, leaving a soft-edged hole round the pointer
        Item {
            anchors.fill: parent
            visible: win.tool === "spotlight"
            readonly property real b: Math.hypot(win.width, win.height)
            Rectangle {
                x: win.pointer.x - width / 2; y: win.pointer.y - height / 2
                width: 2 * (win.spotR + parent.b); height: width; radius: width / 2
                color: "transparent"
                border.width: parent.b; border.color: Theme.withAlpha("#000000", 0.62)
                Behavior on width { NumberAnimation { duration: Theme.motion.fast } }
            }
            Rectangle {
                x: win.pointer.x - width / 2; y: win.pointer.y - height / 2
                width: 2 * win.spotR + 2; height: width; radius: width / 2
                color: "transparent"; border.width: 2; border.color: Theme.withAlpha(win.colors[win.colorIndex], 0.7)
                Behavior on width { NumberAnimation { duration: Theme.motion.fast } }
            }
        }

        Repeater {
            model: win.strokes.concat(win.current ? [win.current] : [])
            Shape {
                required property var modelData
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 0.3; shadowOpacity: 0.35; shadowVerticalOffset: 1; shadowHorizontalOffset: 0 }
                ShapePath {
                    strokeColor: modelData.color
                    strokeWidth: modelData.width
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline { path: modelData.points }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: win.tool === "pen" ? Qt.CrossCursor : Qt.BlankCursor
            hoverEnabled: true
            onWheel: w => { if (win.tool === "spotlight") win.spotR = Math.max(50, Math.min(500, win.spotR + (w.angleDelta.y > 0 ? 20 : -20))); }
            onPressed: m => {
                if (win.tool !== "pen") return;
                if (m.button === Qt.RightButton) { win.eraseAt(m.x, m.y); return; }
                win.current = { points: [Qt.point(m.x, m.y)], color: win.colors[win.colorIndex], width: win.width_ };
            }
            onPositionChanged: m => {
                win.pointer = Qt.point(m.x, m.y);
                if (win.tool !== "pen") return;
                if (m.buttons & Qt.RightButton) { win.eraseAt(m.x, m.y); return; }
                if (!win.current) return;
                const p = win.current.points, l = p[p.length - 1];
                if (Math.hypot(m.x - l.x, m.y - l.y) < 2) return;
                win.current = { points: p.concat([Qt.point(m.x, m.y)]), color: win.current.color, width: win.current.width };
            }
            onReleased: { if (win.current) { win.strokes = win.strokes.concat([win.current]); win.current = null; } }
        }

        // the palette, bottom centre
        Rectangle {
            id: bar
            visible: !DrawState.snapping
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 28 }
            width: barRow.implicitWidth + 24; height: 44; radius: 22
            color: Theme.withAlpha(Theme.bg, 0.9)
            border.width: 1; border.color: Theme.border
            Row {
                id: barRow
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: win.colors.length
                    Rectangle {
                        required property int index
                        width: 22; height: 22; radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: win.colors[index]
                        border.width: win.colorIndex === index ? 3 : 1
                        border.color: win.colorIndex === index ? Theme.text : Theme.border
                        scale: win.colorIndex === index ? 1.12 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.colorIndex = index }
                    }
                }
                Rectangle { width: 1; height: 22; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                Tool { icon: "draw"; on: win.tool === "pen"; onClicked: win.tool = "pen" }
                Tool { icon: "flashlight_on"; on: win.tool === "spotlight"; onClicked: win.tool = win.tool === "spotlight" ? "pen" : "spotlight" }
                Tool { icon: "zoom_in"; on: win.zoomed; onClicked: win.setZoom(!win.zoomed) }
                Rectangle { width: 1; height: 22; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                Tool { icon: "line_weight"; label: Math.round(win.width_) + ""; onClicked: win.width_ = win.width_ >= 14 ? 3 : win.width_ + 3 }
                Tool { icon: "undo"; onClicked: win.strokes = win.strokes.slice(0, -1) }
                Tool { icon: "delete_sweep"; onClicked: win.strokes = [] }
                Tool { icon: "screenshot_monitor"; onClicked: DrawState.snap(win.monitor?.name ?? "") }
                Tool { icon: "check"; onClicked: DrawState.open = false }
            }
        }
    }
    function eraseAt(x, y) {
        strokes = strokes.filter(s => !s.points.some(p => Math.hypot(p.x - x, p.y - y) < s.width + 8));
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (e.key === Qt.Key_Escape) DrawState.open = false;
            else if (e.key === Qt.Key_Z && ctrl) win.strokes = win.strokes.slice(0, -1);
            else if (e.key === Qt.Key_C) win.strokes = [];
            else if (e.key === Qt.Key_L) win.tool = win.tool === "spotlight" ? "pen" : "spotlight";
            else if (e.key === Qt.Key_P) win.tool = "pen";
            else if (e.key === Qt.Key_Z && !ctrl) win.setZoom(!win.zoomed);
            else if (e.key === Qt.Key_S) DrawState.snap(win.monitor?.name ?? "");
            else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_5) win.colorIndex = e.key - Qt.Key_1;
            else if (e.key === Qt.Key_BracketLeft) win.width_ = Math.max(2, win.width_ - 2);
            else if (e.key === Qt.Key_BracketRight) win.width_ = Math.min(24, win.width_ + 2);
            else return;
            e.accepted = true;
        }
    }

    component Tool: HoverTarget {
        id: tl
        property string icon
        property string label: ""
        property bool on: false
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; visible: tl.on; color: Theme.withAlpha(Theme.accent, 0.2) }
        width: label ? tlRow.implicitWidth + 14 : 30; height: 30
        anchors.verticalCenter: parent.verticalCenter
        Row { id: tlRow; anchors.centerIn: parent; spacing: 3
              LIcon { icon: tl.icon; size: 18; color: tl.on ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
              LText { visible: tl.label !== ""; role: "caption"; text: tl.label; anchors.verticalCenter: parent.verticalCenter } }
    }
}
