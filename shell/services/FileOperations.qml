pragma Singleton
// One worker owns the file queue. Progress is bytes copied, not a timer.
// Closing the UI does not stop jobs. Terminal history is session-only.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property var jobs: []
    property string activeId: ""
    property int serial: 0
    signal settled(var job, var result)
    readonly property int remaining: jobs.filter(j => j.status === "queued" || j.status === "running" || j.status === "cancelling").length
    readonly property string helper: Theme.lumenRoot + "/scripts/desktop-tools.py"

    function update(id, patch) {
        jobs = jobs.map(j => j.id === id ? Object.assign({}, j, patch) : j);
    }
    function enqueue(kind, paths, destination) {
        if (!paths.length || !destination) return;
        if (remaining >= 20) { Island.system("error", "The queue is full", "Wait for a job to finish", "warning"); return; }
        const id = String(Date.now()) + "-" + (++serial);
        jobs = jobs.filter(j => ["queued", "running", "cancelling"].includes(j.status)).concat(
            jobs.filter(j => !["queued", "running", "cancelling"].includes(j.status)).slice(-30)).concat([
            { id, kind, paths: paths.slice(), destination, status: "queued", progress: 0,
              name: paths.length === 1 ? paths[0].replace(/^.*\//, "") : paths.length + " items", error: "", completed: [], bytes: 0, total: 0 }]);
        Qt.callLater(startNext);
    }
    function startNext() {
        if (worker.busy || activeId) return;
        const next = jobs.find(j => j.status === "queued");
        if (!next) return;
        activeId = next.id;
        update(activeId, { status: "running" });
        worker.terminal = false;
        worker.start(["python3", helper, "job", JSON.stringify(next)]);
    }
    function cancel(id) {
        const job = jobs.find(j => j.id === id);
        if (job?.status === "queued") update(id, { status: "cancelled" });
        else if (activeId === id && worker.running) {
            update(id, { status: "cancelling" }); worker.signal(15);
        }
    }
    function retry(id) {
        const job = jobs.find(j => j.id === id);
        if (job) enqueue(job.kind, job.paths.filter(p => !job.completed.some(c => c.replace(/^.*\//, "") === p.replace(/^.*\//, ""))), job.destination);
    }
    function clearFinished() { jobs = jobs.filter(j => ["queued", "running", "cancelling"].includes(j.status)); }
    function receive(event) {
        if (event.type === "progress") {
            update(activeId, { progress: event.progress, bytes: event.bytes, total: event.total, current: event.name });
            return;
        }
        if (!["done", "error", "cancelled"].includes(event.type)) return;
        worker.terminal = true;
        const job = jobs.find(j => j.id === activeId);
        update(activeId, { status: event.type === "done" ? "done" : event.type === "error" ? "failed" : "cancelled",
                          destination: event.destination ?? job?.destination ?? "", progress: event.progress ?? job?.progress ?? 0, error: event.error ?? "", completed: event.completed ?? [] });
        settled(job, event);
        Island.system(event.type === "error" ? "error" : "folder", event.type === "done" ? "File operation complete" : event.type === "error" ? "File operation failed" : "File operation cancelled",
                      event.error || ((event.completed?.length ?? 0) + " items completed"), event.type === "error" ? "error" : "normal");
    }
    ToolsStream {
        id: worker
        property bool terminal: false
        onEvent: value => root.receive(value)
        onFinished: code => {
            if (!terminal) root.update(root.activeId, { status: "failed", error: "Worker stopped (exit " + code + "). Check the destination before retrying." });
            root.activeId = "";

            Qt.callLater(root.startNext);
        }
    }
}
