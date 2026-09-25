// A clock whose digits roll. When a minute ticks over, only the digits that
// changed slide up and out while the new ones rise in from below — like a
// mechanical counter. Motion that says "time moved", once a minute.
//
// Set in Google Sans Flex with its rounded axis (ROND) and a firm weight, so
// the island's clock has a voice of its own rather than a default UI face.
import QtQuick
import Quickshell
import qs.theme

Row {
    id: root
    property real pixelSize: 15
    property int weight: 650
    property color color: Theme.text
    property bool showPeriod: Theme.clock12h           // small AM/PM after the digits

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string value: Theme.timeDigits(clock.date)   // 12h/24h from tokens [locale]

    spacing: 0

    Repeater {
        model: root.value.length
        delegate: Item {
            id: cell
            required property int index
            readonly property string ch: root.value.charAt(index)
            readonly property bool isDigit: ch >= "0" && ch <= "9"
            property string shown: ch
            property string leaving: ""

            width: metrics.advanceWidth
            height: metrics.height
            clip: true

            TextMetrics {
                id: metrics
                font: front.font
                text: cell.isDigit ? "0" : cell.ch        // tabular: every digit cell is "0" wide
            }

            onChChanged: {
                if (ch === shown) return;
                leaving = shown;
                shown = ch;
                roll.restart();
            }

            component Glyph: Text {
                color: root.color
                font.family: Theme.fontUi
                font.pixelSize: root.pixelSize
                font.variableAxes: ({ "wght": root.weight, "ROND": 100, "wdth": 100 })
                font.features: ({ "tnum": 1 })
                width: cell.width
                horizontalAlignment: Text.AlignHCenter
                renderType: Text.NativeRendering
            }

            Glyph {
                id: back
                text: cell.leaving
                y: 0
                opacity: 0
            }
            Glyph {
                id: front
                text: cell.shown
                opacity: cell.isDigit ? 1 : 0.55        // soften the colon
            }

            ParallelAnimation {
                id: roll
                NumberAnimation { target: back; property: "y"; from: 0; to: -cell.height; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                NumberAnimation { target: back; property: "opacity"; from: 1; to: 0; duration: Theme.motion.large }
                NumberAnimation { target: front; property: "y"; from: cell.height; to: 0; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
            }
        }
    }

    // AM / PM — smaller and quieter than the digits, sitting on their baseline
    Text {
        visible: root.showPeriod
                leftPadding: root.pixelSize * 0.22
        text: Theme.timePeriod(clock.date)
        color: Theme.withAlpha(root.color, 0.6)
        font.family: Theme.fontUi
        font.pixelSize: Math.round(root.pixelSize * 0.62)
        font.variableAxes: ({ "wght": Math.min(800, root.weight + 50), "ROND": 100 })
        font.letterSpacing: 0.3
        renderType: Text.NativeRendering
        height: parent.height
        verticalAlignment: Text.AlignBottom
        bottomPadding: root.pixelSize * 0.2
    }
}
