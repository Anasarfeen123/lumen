// A Process that stays up while `wanted` is true. If it dies unexpectedly
// (e.g. a GPU or audio device vanishing across suspend/resume), it is
// restarted with backoff: 1 s, 2 s, 4 s, 8 s, 16 s — then it gives up until
// `wanted` toggles again, so a broken tool can never spin in a loop.
// A process that has run for a minute is considered healthy again.
import QtQuick
import Quickshell.Io

Process {
    id: proc
    property bool wanted: false
    property int maxRestarts: 5
    property int restarts: 0

    running: false
    onWantedChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        if (wanted && !running) { restarts = 0; running = true; }
        else if (!wanted && running) running = false;
    }

    onExited: {
        if (!wanted || restarts >= maxRestarts) return;
        retry.interval = 1000 * Math.pow(2, restarts);
        restarts++;
        retry.restart();
    }

    property Timer retry: Timer { onTriggered: if (proc.wanted && !proc.running) proc.running = true }
    property Timer healthy: Timer { interval: 60000; running: proc.running; onTriggered: proc.restarts = 0 }
}
