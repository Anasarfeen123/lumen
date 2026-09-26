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

    // Money is in Indian rupees: "₹500", "500 rs", "2 lakh", "1.5 crore" are
    // understood, any other currency is converted to ₹, and results use Indian
    // grouping (₹1,23,456.78). qalc's own default follows the system locale.
    readonly property var currencyWords: /(?:^|[^a-z])(usd|eur|gbp|jpy|aed|sgd|cad|aud|cny|chf|dollars?|euros?|pounds?|yen)\b|[$€£¥]/i
    property bool money: false
    function normalise(q) {
        let e = q.replace(/^=\s*/, "").replace(/(\d(?:\.\d+)?)\s*%\s+of\s+/gi, "$1% * ");   // "15% of 240" → "15% * 240"
        e = e.replace(/(\d(?:\.\d+)?)\s*(lakhs?|lacs?)\b/gi, "($1*100000 INR)")
             .replace(/(\d(?:\.\d+)?)\s*(crores?|cr)\b/gi, "($1*10000000 INR)")
             .replace(/₹\s*/g, "INR ")
             .replace(/(^|[^a-z])(rs\.?|rupees?|inr)(?=\s|$|[-+*/)])/gi, "$1INR");
        // "INR 500" → "500 INR" (qalc wants the unit after the number)
        e = e.replace(/INR\s+(\(?[\d.]+(?:\*\d+)?\)?)/g, "$1 INR");
        money = /INR/.test(e) || currencyWords.test(e);
        if (money && !/\s(to|in)\s+\S+\s*$/i.test(e)) e += " to INR";
        return e;
    }
    function evaluate(q) {
        // Maths, or an amount of money in any currency ("$100", "50 usd", "2 lakh")
        const moneyish = /\d/.test(q) && (currencyWords.test(q) || /[₹]|(?:^|[^a-z])(rs|rupees?|inr|lakhs?|crores?)\b/i.test(q));
        if (!looksLikeMath(q) && !moneyish) { result = ""; expression = ""; return; }
        expression = normalise(q);
        debounce.restart();
    }
    // ₹1234567.891 → ₹12,34,567.89
    function indian(r) {
        const m = /^(-?)₹\s*([\d.]+)(.*)$/.exec(r);
        if (!m) return r;
        const n = Number(m[2]);
        if (!isFinite(n)) return r;
        const fixed = Math.abs(n) >= 100 || Number.isInteger(n) ? (Number.isInteger(n) ? String(n) : n.toFixed(2)) : n.toFixed(2);
        let [int, dec] = fixed.split(".");
        const last3 = int.slice(-3), rest = int.slice(0, -3);
        int = rest ? rest.replace(/\B(?=(\d{2})+(?!\d))/g, ",") + "," + last3 : last3;
        return m[1] + "₹" + int + (dec ? "." + dec : "") + m[3];
    }
    // "≈ 12.3 lakh" under big amounts
    function words(r) {
        const m = /₹([\d,]+(?:\.\d+)?)/.exec(r);
        if (!m) return "";
        const n = Number(m[1].replace(/,/g, ""));
        if (n >= 1e7) return "≈ " + +(n / 1e7).toFixed(2) + " crore";
        if (n >= 1e5) return "≈ " + +(n / 1e5).toFixed(2) + " lakh";
        return "";
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
                root.result = (r === "" || r === root.expression || unevaluated || /error|warning/i.test(r)) ? "" : root.indian(r);
            }
        }
    }
}
