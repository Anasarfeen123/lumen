// JSON-line worker with a completion barrier: stdout may close before or
// after process exit. Consumers never start another job until both happen.
import QtQuick
import Quickshell.Io

Process {
    id: root
    property bool busy: false
    property bool ended: false
    property bool streamed: false
    property int code: -1
    property int consumed: 0
    signal event(var value)
    signal finished(int code)
    function start(args) {
        if (busy) return;
        ended = false; streamed = false; consumed = 0; code = -1;
        command = args; busy = true; running = true;
    }
    function drain(final) {
        const text = output.text;
        const end = final ? text.length : text.lastIndexOf("\n") + 1;
        if (end <= consumed) return;
        const part = text.slice(consumed, end); consumed = end;
        for (const line of part.split("\n")) {
            if (!line.trim()) continue;
            try { event(JSON.parse(line)); } catch (e) {}
        }
    }
    function finish() {
        if (!ended || !streamed) return;
        busy = false; finished(code);
    }
    stdout: StdioCollector {
        id: output
        waitForEnd: false
        onDataChanged: root.drain(false)
        onStreamFinished: { root.drain(true); root.streamed = true; root.finish(); }
    }
    onExited: (code, status) => { root.code = code; root.ended = true; root.finish(); }
}
