// A live line graph: one or two series (e.g. receive and send), newest on the
// right, softly filled, with faint grid lines. `max` 0 = scale to the data.
//   Graph { values: SystemMonitor.series("cpu"); max: 100; color: Theme.accent }
import QtQuick
import qs.theme

Item {
    id: root
    property var values: []
    property var values2: []                 // optional second series (dashed)
    property real max: 100
    property color color: Theme.accent
    property color color2: Theme.textSecondary
    property int points: 60                  // how many samples span the width
    property bool grid: true
    property bool fill: true
    property real lineWidth: 1.5
    readonly property real ceiling: max > 0 ? max : Math.max(1, ...values.slice(-points), ...values2.slice(-points)) * 1.15

    onValuesChanged: canvas.requestPaint()
    onValues2Changed: canvas.requestPaint()
    onPointsChanged: canvas.requestPaint()
    onColorChanged: canvas.requestPaint()

    Rectangle { anchors.fill: parent; color: "transparent"; radius: Theme.radius.sm; border.width: root.grid ? 1 : 0; border.color: Theme.border }

    Canvas {
        id: canvas
        anchors { fill: parent; margins: 1 }
        renderStrategy: Canvas.Cooperative
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, h = height, n = root.points;
            if (root.grid) {
                c.strokeStyle = Theme.withAlpha(Theme.text, 0.06);
                c.lineWidth = 1;
                for (let i = 1; i < 4; i++) { const y = Math.round(h * i / 4) + 0.5; c.beginPath(); c.moveTo(0, y); c.lineTo(w, y); c.stroke(); }
                for (let i = 1; i < 6; i++) { const x = Math.round(w * i / 6) + 0.5; c.beginPath(); c.moveTo(x, 0); c.lineTo(x, h); c.stroke(); }
            }
            const draw = (vals, color, dashed, filled) => {
                const v = vals.slice(-n);
                if (v.length < 2) return;
                const step = w / (n - 1), x0 = w - (v.length - 1) * step;
                const y = val => h - Math.max(0, Math.min(1, val / root.ceiling)) * (h - 2) - 1;
                c.beginPath();
                v.forEach((val, i) => { const x = x0 + i * step; if (i === 0) c.moveTo(x, y(val)); else c.lineTo(x, y(val)); });
                if (filled) {
                    c.save();
                    c.lineTo(w, h); c.lineTo(x0, h); c.closePath();
                    const g = c.createLinearGradient(0, 0, 0, h);
                    g.addColorStop(0, Theme.withAlpha(color, 0.32));
                    g.addColorStop(1, Theme.withAlpha(color, 0.03));
                    c.fillStyle = g; c.fill();
                    c.restore();
                    c.beginPath();
                    v.forEach((val, i) => { const x = x0 + i * step; if (i === 0) c.moveTo(x, y(val)); else c.lineTo(x, y(val)); });
                }
                c.strokeStyle = color; c.lineWidth = root.lineWidth; c.lineJoin = "round";
                if (dashed) c.setLineDash([4, 3]);
                c.stroke();
                c.setLineDash([]);
            };
            draw(root.values2, root.color2, true, false);
            draw(root.values, root.color, false, root.fill);
        }
    }
}
