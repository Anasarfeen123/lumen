pragma Singleton
// Lumen Link — your phone and this computer, through KDE Connect
// (scripts/link.sh; the daemon does all the networking).
//   status    devices, battery, how they're connected (Wi-Fi, USB, Bluetooth)
//   events    the daemon's signals, live: a phone appearing or leaving,
//             battery changes, files received — announced in the island
//   doctor    why a phone isn't found, and the fixes (Settings → Lumen Link)
//   actions   ring, ping, send files / text / links / clipboard / a screenshot
// Only the main shell announces events (Persist.automates); every view reads.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool available: false
    property var devices: []
    property var backends: ({})          // { lan: bool, bluetooth: bool }
    property var custom: []              // addresses KDE Connect contacts directly
    property string tether: ""           // a phone's USB tethering interface, if any
    readonly property var paired: devices.filter(d => d.paired)
    readonly property var phone: paired.find(d => d.reachable) ?? paired[0] ?? null
    readonly property bool connected: !!phone && phone.reachable
    readonly property var pending: devices.filter(d => !d.paired && d.reachable)
    property bool watching: false        // a view that shows devices is open

    readonly property string script: Theme.lumenRoot + "/scripts/link.sh"
    function viaLabel(v) { return ({ wifi: "Wi-Fi", usb: "USB", bluetooth: "Bluetooth" })[v] ?? ""; }
    function viaIcon(v) { return ({ wifi: "wifi", usb: "usb", bluetooth: "bluetooth" })[v] ?? "link_off"; }

    // ── status ──
    function refresh() { if (!probe.running) probe.running = true; }
    Process {
        id: probe
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.mock) return;
                try {
                    const d = JSON.parse(text);
                    root.available = d.available;
                    root.devices = d.devices ?? [];
                    root.backends = d.backends ?? {};
                    root.custom = d.custom ?? [];
                    root.tether = d.tether ?? "";
                } catch (e) {}
            }
        }
    }
    Timer { interval: root.watching ? 6000 : 120000; running: !root.mock; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
    Timer { id: refreshSoon; interval: 1200; onTriggered: root.refresh() }

    // ── doctor ──
    property var doctor: null
    property bool diagnosing: false
    function diagnose() { diagnosing = true; if (!doctorProc.running) doctorProc.running = true; }
    Process {
        id: doctorProc
        command: [root.script, "doctor"]
        stdout: StdioCollector { onStreamFinished: { try { root.doctor = JSON.parse(text); } catch (e) {} root.diagnosing = false; } }
    }

    // ── actions ──
    function nameOf(id) { return devices.find(d => d.id === id)?.name ?? "your phone"; }
    function run(args) { if (!mock) Quickshell.execDetached([script].concat(args)); }
    function ring(id) { run(["ring", id ?? phone?.id]); Island.system("phone_in_talk", "Ringing " + nameOf(id ?? phone?.id), ""); }
    function ping(id) { run(["ping", id ?? phone?.id]); }
    function sendClipboard(id) { run(["send-clipboard", id ?? phone?.id]); Island.system("content_paste_go", "Clipboard sent", nameOf(id ?? phone?.id)); }
    function sendFiles(paths, id) {
        const to = id ?? phone?.id;
        if (!to || !paths?.length) return;
        run(["share", to].concat(paths));
        Island.system("send_to_mobile", paths.length === 1 ? "Sending " + paths[0].replace(/.*\//, "") : "Sending " + paths.length + " files", "to " + nameOf(to));
    }
    function sendText(text, id) {
        const to = id ?? phone?.id;
        if (!to || !text) return;
        run([/^https?:\/\//.test(text.trim()) ? "share" : "text", to, text.trim()]);
        Island.system(/^https?:/.test(text.trim()) ? "link" : "sms", /^https?:/.test(text.trim()) ? "Link sent" : "Text sent", nameOf(to));
    }
    function pickAndSend(id) { run(["pick-and-share", id ?? phone?.id]); }
    function screenshotToPhone(id) { run(["screenshot", id ?? phone?.id]); }
    function pair(id) { run(["pair", id]); refreshSoon.restart(); }
    function unpair(id) { run(["unpair", id]); refreshSoon.restart(); }
    function addAddress(ip) { run(["add-address", ip]); refreshSoon.restart(); }
    function removeAddress(ip) { run(["remove-address", ip]); refreshSoon.restart(); }
    function setBackend(name, on) { run(["backend", name, on ? "on" : "off"]); refreshSoon.restart(); Qt.callLater(diagnose); }
    function search() { run(["refresh"]); refreshSoon.restart(); }
    // Kept for older callers (Search): act("ring"|"ping"|"send-clipboard"|"pick-and-share"|"pair"|"unpair", id)
    function act(cmd, id) {
        ({ ring: () => ring(id), ping: () => ping(id), "send-clipboard": () => sendClipboard(id),
           "pick-and-share": () => pickAndSend(id), pair: () => pair(id), unpair: () => unpair(id) })[cmd]?.();
    }
    // Phone as webcam / microphone needs scrcpy (not in Fedora's repositories)
    property bool hasScrcpy: false
    Process { running: true; command: ["sh", "-c", "command -v scrcpy"]; onExited: code => root.hasScrcpy = code === 0 }

    // ── live events → the island ──
    readonly property bool announces: Persist.automates || mock
    Process {
        running: root.available && Persist.automates
        command: [root.script, "events"]
        stdout: SplitParser { onRead: line => { try { root.onEvent(JSON.parse(line)); } catch (e) {} } }
    }
    property var lastBattery: ({})
    property var warned: ({})
    function onEvent(ev) {
        if (ev.e === "list") { refreshSoon.restart(); return; }
        const d = devices.find(x => x.id === ev.id);
        if (ev.e === "visible") {
            refreshSoon.restart();
            if (!d?.paired || !announces) return;
            if (ev.on) announceConnected(d);
            else Island.system("mobile_off", d.name, "Disconnected");
        } else if (ev.e === "battery") {
            if (!d) return;
            const w = Object.assign({}, warned);
            if (ev.charge <= 15 && !ev.charging && !w[d.id]) { w[d.id] = true; if (announces) Island.system("battery_alert", d.name + " battery low", ev.charge + "% left", "warning"); }
            else if (ev.charge > 20 || ev.charging) delete w[d.id];
            warned = w;
            devices = devices.map(x => x.id === d.id ? Object.assign({}, x, { battery: ev.charge, charging: ev.charging }) : x);
        } else if (ev.e === "received") {
            const path = decodeURIComponent(ev.url.replace(/^file:\/\//, ""));
            if (!announces) return;
            Island.device("recv:" + path, {
                icon: /\.(png|jpe?g|webp|heic|gif)$/i.test(path) ? "image" : /\.(mp4|mov|mkv|webm)$/i.test(path) ? "movie" : "draft",
                title: path.replace(/.*\//, ""),
                badge: "",
                detail: "Received from " + (d?.name ?? "your phone"),
                actions: [{ icon: "open_in_new", label: "Open", cmd: ["xdg-open", path] },
                          { icon: "folder_open", label: "Show", cmd: ["dbus-send", "--session", "--type=method_call", "--dest=org.freedesktop.FileManager1", "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems", "array:string:file://" + path, "string:"] }]
            });
            Sounds.play("plug");
        }
    }
    function announceConnected(d) {
        Island.device("link:" + d.id, {
            icon: d.type === "tablet" ? "tablet_android" : "smartphone",
            title: d.name + (d.battery >= 0 ? " — " + d.battery + "%" : ""),
            badge: "",
            detail: "Linked" + (d.via ? " over " + viaLabel(d.via) : "") + (d.charging ? " · charging" : ""),
            actions: [{ icon: "phone_in_talk", label: "Ring", cmd: [script, "ring", d.id] },
                      { icon: "content_paste_go", label: "Send clipboard", cmd: [script, "send-clipboard", d.id] }]
        });
    }

    IpcHandler {
        target: "link"
        function send(path: string): void { root.sendFiles([path]); }
        function text(t: string): void { root.sendText(t); }
        function ring(): void { root.ring(); }
        function clipboard(): void { root.sendClipboard(); }
        function screenshot(): void { root.screenshotToPhone(); }
        function state(): string { return JSON.stringify({ available: root.available, connected: root.connected, phone: root.phone, backends: root.backends, custom: root.custom, tether: root.tether }); }
    }

    // ── dev mock (LUMEN_DEV): a phone without a phone ──
    property bool mock: false
    IpcHandler {
        target: "linkTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void {
            root.mock = true; root.available = true; root.backends = { lan: true, bluetooth: false };
            root.devices = [{ id: "mock1", name: "Anas's Phone", type: "smartphone", paired: true, reachable: true, battery: 82, charging: false, via: "wifi", signal: 3 }];
        }
        function connect(): void { root.announceConnected(root.devices[0]); }
        function receive(): void { root.onEvent({ e: "received", id: "mock1", url: "file:///home/anas07/Downloads/IMG_2041.jpg" }); }
        function low(): void { root.warned = {}; root.onEvent({ e: "battery", id: "mock1", charge: 12, charging: false }); }
        function away(): void { root.devices = root.devices.map(d => Object.assign({}, d, { reachable: false, via: "" })); }
        function none(): void { root.mock = true; root.available = true; root.devices = []; }
        function real(): void { root.mock = false; root.refresh(); }
    }
}
