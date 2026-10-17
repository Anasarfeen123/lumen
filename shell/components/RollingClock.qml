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
    // "roll": digits slide up like a counter · "flip": each digit on a small card
    // that flips over when it changes (a split-flap clock)
    property string style: "roll"
    readonly property bool flip: style === "flip"

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property string value: Theme.timeDigits(clock.date)   // 12h/24h from tokens [locale]

    spacing: flip ? 2 : 0

    Repeater {
        model: root.value.length
        delegate: Item {
            id: cell
            required property int index
            readonly property string ch: root.value.charAt(index)
            readonly property bool isDigit: ch >= "0" && ch <= "9"
            property string shown: ch
            property string leaving: ""

            width: metrics.advanceWidth + (root.flip && cell.isDigit ? 6 : 0)
            height: metrics.height + (root.flip ? 2 : 0)
            clip: !root.flip

            // flip: the card behind a digit, with the hairline across its middle
            Rectangle {
                visible: root.flip && cell.isDigit
                anchors.fill: parent
                radius: 4
                color: Theme.withAlpha(Theme.text, 0.08)
                border.width: 1; border.color: Theme.withAlpha(Theme.text, 0.06)
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.withAlpha(Theme.bg, 0.22) }
            }

            TextMetrics {
                id: metrics
                font: front.font
                text: cell.isDigit ? "0" : cell.ch        // tabular: every digit cell is "0" wide
            }

            onChChanged: {
                if (ch === shown) return;
                leaving = shown;
                shown = ch;
                if (root.flip) flipAnim.restart(); else roll.restart();
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
                y: root.flip ? 1 : 0
                opacity: 0
                transform: Rotation { id: backTurn; origin.x: cell.width / 2; origin.y: cell.height / 2; axis { x: 1; y: 0; z: 0 } angle: 0 }
            }
            Glyph {
                id: front
                text: cell.shown
                y: root.flip ? 1 : 0
                opacity: cell.isDigit ? 1 : 0.55        // soften the colon
                transform: Rotation { id: frontTurn; origin.x: cell.width / 2; origin.y: cell.height / 2; axis { x: 1; y: 0; z: 0 } angle: 0 }
            }
            // flip: the old digit tips away, the new one falls into place
            SequentialAnimation {
                id: flipAnim
                ScriptAction { script: { back.opacity = 1; front.opacity = 0; backTurn.angle = 0; frontTurn.angle = -90; } }
                NumberAnimation { target: backTurn; property: "angle"; to: 90; duration: Theme.motion.normal; easing.type: Easing.InQuad }
                ScriptAction { script: { back.opacity = 0; front.opacity = cell.isDigit ? 1 : 0.55; } }
                NumberAnimation { target: frontTurn; property: "angle"; to: 0; duration: Theme.motion.normal; easing.type: Easing.OutBack }
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
