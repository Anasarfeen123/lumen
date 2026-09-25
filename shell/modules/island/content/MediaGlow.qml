// A living backdrop for the expanded player: soft blobs in the album art's
// own colours drift slowly behind the controls (think Apple Music's
// background), under a dark veil that keeps text readable. Animates only
// while visible; falls back to the accent when the art has no palette.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.services

ClippingRectangle {
    id: root
    property bool active: false
    color: "transparent"
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.motion.large } }

    function paletteColor(i) {
        const p = Media.palette;
        if (p.length === 0) return i === 0 ? Theme.accent : Theme.withAlpha(Theme.accent, 0.6);
        return p[(i * 3) % p.length];
    }

    Item {
        id: blobs
        anchors.fill: parent
        visible: false

        component Blob: Rectangle {
            id: blob
            required property int n
            property real phase: 0
            width: root.height * 1.5
            height: width
            radius: width / 2
            color: root.paletteColor(n)
            Behavior on color { ColorAnimation { duration: 900 } }
            // Each blob loops its own slow ellipse; different periods keep it organic
            x: root.width * (0.15 + 0.3 * n) - width / 2 + Math.cos(phase * 2 * Math.PI) * root.width * 0.18
            y: root.height * 0.5 - height / 2 + Math.sin(phase * 2 * Math.PI) * root.height * 0.35
            NumberAnimation on phase {
                running: root.visible && !Theme.reducedMotion
                from: blob.n % 2 ? 1 : 0; to: blob.n % 2 ? 0 : 1
                duration: 9000 + blob.n * 3700
                loops: Animation.Infinite
            }
        }
        Blob { n: 0 }
        Blob { n: 1 }
        Blob { n: 2 }
    }

    MultiEffect {
        anchors.fill: parent
        source: blobs
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        saturation: 0.25
        opacity: 0.75
    }

    // Veil: keeps white text above 4.5:1 whatever the album looks like
    Rectangle { anchors.fill: parent; color: Theme.withAlpha(Theme.bg, 0.42) }
}
