pragma Singleton

// Calculator via qalc (libqalculate): units, currencies, percentages,
// "5 ft to cm", "sqrt(2)"… Debounced; only runs for input that looks like math.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string expression: ""
    property string result: ""
    readonly property bool available: true

    // Digits with an operator, a leading "=", or a unit conversion
    function looksLikeMath(q) {
        return /^=/.test(q) || /\d\s*[-+*/^%()]|[-+*/^]\s*\d/.test(q)
            || /\d.*\s(to|in)\s+\S/.test(q) || /^(sqrt|sin|cos|tan|log|ln)\(/.test(q);
    }

    function evaluate(q) {
        if (!looksLikeMath(q)) { result = ""; expression = ""; return; }
        // "15% of 240" → "15% * 240" (qalc has no "of")
        expression = q.replace(/^=\s*/, "").replace(/(\d(?:\.\d+)?)\s*%\s+of\s+/gi, "$1% * ");
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: {
            proc.running = false;
            proc.command = ["qalc", "-t", root.expression];
            proc.running = true;
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: {
                const r = text.trim();
                // Reject echoes and half-parsed input (unknown words become
                // function calls like "rem(…)" rather than a value).
                const unevaluated = /[A-Za-z]{2,}\(/.test(r) && !/[A-Za-z]{2,}\(/.test(root.expression);
                root.result = (r === "" || r === root.expression || unevaluated || /error|warning/i.test(r)) ? "" : r;
            }
        }
    }
}
