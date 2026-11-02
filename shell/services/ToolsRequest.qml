// A request with latest-request-wins delivery. Wait for stdout AND exit;
// rapid navigation never applies a stale directory response to the next page.
import QtQuick
import Quickshell.Io

Process {
    id: root
    property string helper: ""
    property var pending: null
    property bool busy: false
    property bool ended: false
    property bool streamed: false
    property int exitCode: 0
    property var requestToken: null
    signal result(var value)
    signal answered(var value, var token)

    function start(args, token) {
        if (busy) { pending = { args, token }; return; }
        requestToken = token ?? null;
        busy = true; ended = false; streamed = false;
        command = ["python3", helper].concat(args);
        running = true;
    }
    function finish() {
        if (!ended || !streamed) return;
        busy = false;
        if (pending !== null) {
            const next = pending; pending = null; start(next.args, next.token); return;
        }
        let value;
        try { value = JSON.parse(output.text.trim().split("\n").pop()); }
        catch (e) { value = { error: "The tool could not finish (exit " + exitCode + ")" }; }
        const token = requestToken;
        result(value); answered(value, token);
    }
    stdout: StdioCollector { id: output; onStreamFinished: { root.streamed = true; root.finish(); } }
    onExited: (code, status) => { root.exitCode = code; root.ended = true; root.finish(); }
}
