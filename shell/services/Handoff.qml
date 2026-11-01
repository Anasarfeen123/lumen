pragma Singleton
// Handoff (scripts/handoff.sh): what's playing, carried to the phone or back at
// the same second. "Continue on my phone" / "Continue on this PC" in search,
// or ask Halo ("continue this on my phone", "play what my phone is playing").
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool busy: false
    function toPhone() { run("to-phone"); }
    function toPc() { run("to-pc"); }
    function run(dir) {
        if (busy) return;
        busy = true; proc.dir = dir;
        proc.command = [Theme.lumenRoot + "/scripts/handoff.sh", dir];
        proc.running = true;
        Island.system(dir === "to-phone" ? "phone_android" : "computer", dir === "to-phone" ? "Sending it to your phone…" : "Getting it from your phone…", "");
    }
    Process {
        id: proc
        property string dir: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                let r = {}; try { r = JSON.parse(text); } catch (e) {}
                const at = r.seconds ? " · from " + Math.floor(r.seconds / 60) + ":" + String(r.seconds % 60).padStart(2, "0") : "";
                if (r.ok) Island.system(proc.dir === "to-phone" ? "phone_android" : "computer", proc.dir === "to-phone" ? "Continuing on your phone" : "Continuing here", (r.title ?? "") + at);
                else Island.system("error", "Couldn't hand it over", r.error ?? "Something went wrong", "warning");
            }
        }
    }
    IpcHandler { target: "handoff"; function toPhone(): void { root.toPhone(); } function toPc(): void { root.toPc(); } }
}
