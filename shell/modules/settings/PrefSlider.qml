// A slider for a numeric `lumen set` preference: shows the saved value,
// follows your drag, and applies once on release (a rebuild per release,
// never per pixel).   PrefSlider { key: "scroll_speed"; lo: 25; hi: 200; current: … }
import QtQuick
import qs.components
import qs.services

LSlider {
    id: ps
    property string key
    property real lo: 0
    property real hi: 100
    property real current: 50
    property real pending: -1
    readonly property int shown: Math.round(lo + (pending >= 0 ? pending : (current - lo) / (hi - lo)) * (hi - lo))
    width: 260
    value: pending >= 0 ? pending : (current - lo) / (hi - lo)
    onMoved: v => pending = v
    onDraggingChanged: if (!dragging && pending >= 0) {
        SettingsState.lumen(["set", key, String(shown)]);
        settle.restart();
    }
    Timer { id: settle; interval: 1500; onTriggered: ps.pending = -1 }
}
