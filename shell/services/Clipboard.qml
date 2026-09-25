pragma Singleton

// Clipboard history (cliphist). Loaded on demand when clipboard mode opens.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var entries: []     // { id, text, isImage }

    function refresh() { proc.running = false; proc.running = true; }

    function copy(id) {
        Quickshell.execDetached(["sh", "-c", `cliphist decode ${parseInt(id)} | wl-copy`]);
    }
    function remove(id) {
        Quickshell.execDetached(["sh", "-c", `cliphist list | grep -m1 "^${parseInt(id)}\t" | cliphist delete`]);
        entries = entries.filter(e => e.id !== id);
    }

    Process {
        id: proc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).slice(0, 200).map(l => {
                    const i = l.indexOf("\t");
                    const body = l.slice(i + 1);
                    return { id: l.slice(0, i), text: body, isImage: /^\[\[ binary data/.test(body) };
                });
            }
        }
    }
}
