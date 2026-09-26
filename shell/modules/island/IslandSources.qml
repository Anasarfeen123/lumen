// Everything that can make the island speak, in one place.
// Watches services for *changes* (never initial values — Island.ready gates
// the first 2 s) and turns them into island events. Also hosts the IPC and
// global-shortcut entry points used by keybinds and scripts.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.theme

Scope {
    id: root

    // ── Persistent state ──
    Binding { target: Island; property: "mediaPlaying"; value: Media.playing }
    Binding { target: Island; property: "mediaPresent"; value: Media.present }
    Binding {
        target: Island; property: "criticalBattery"
        value: Battery.available && !Battery.pluggedIn && Battery.percentage <= 0.05
    }

    // ── Now playing: announce briefly on play/track change, then back to the
    //    clock (which shows an equalizer while music plays) ──
    property string lastAnnounced: ""
    function announceTrack() {
        if (!Media.playing || !Media.title) return;
        const key = Media.title + "\u0000" + Media.artist;
        if (key === root.lastAnnounced) return;
        root.lastAnnounced = key;
        Island.push({ kind: "nowPlaying", priority: Island.priority.nowPlaying, duration: 4000,
                      data: { title: Media.title } });
    }
    Timer { id: trackSettle; interval: 400; onTriggered: root.announceTrack() }   // metadata arrives in pieces
    Connections {
        target: Media
        function onTitleChanged() { trackSettle.restart(); }
        function onPlayingChanged() {
            if (Media.playing) trackSettle.restart();
            else root.lastAnnounced = "";   // resuming later announces again
        }
    }

    // ── Volume / mute (PipeWire events) ──
    function volumeIcon() {
        if (Audio.muted || Audio.volume <= 0.001) return "volume_off";
        return Audio.volume < 0.34 ? "volume_mute" : Audio.volume < 0.67 ? "volume_down" : "volume_up";
    }
    property string lastSink: ""
    Connections {
        target: Audio
        function onVolumeChanged() { Island.osd("volume", root.volumeIcon(), Audio.muted ? 0 : Audio.volume); if (Island.ready) Sounds.play("volume"); }
        function onMutedChanged() { Island.osd("volume", root.volumeIcon(), Audio.muted ? 0 : Audio.volume); }
        function onMicMutedChanged() {
            Island.osd("mic", Audio.micMuted ? "mic_off" : "mic", -1, Audio.micMuted ? "Microphone off" : "Microphone on");
        }
        function onDeviceNameChanged() {
            if (Audio.deviceName && root.lastSink && Audio.deviceName !== root.lastSink)
                Island.osd("volume", root.volumeIcon(), Audio.volume, Audio.deviceName);
            root.lastSink = Audio.deviceName;
        }
    }

    // ── Brightness (only user-initiated changes; hypridle dimming stays silent) ──
    Connections {
        target: Brightness
        function onChangedByUser() {
            Island.push({ kind: "osd", key: "osd", priority: Island.priority.osd, duration: 1200, force: true,
                          data: { channel: "brightness", icon: Brightness.value > 0.5 ? "brightness_high" : "brightness_low",
                                  value: Brightness.value, label: "" } });
        }
    }

    // ── Workspace switches (debounced: rapid switching shows nothing) ──
    property int pendingWs: 0
    Timer {
        id: wsDebounce
        interval: 150
        onTriggered: {
            const ws = Hyprland.focusedWorkspace;
            if (!ws || ws.id !== root.pendingWs || ws.id <= 0 || !Persist.data.islandWorkspace) return;
            const label = (ws.name && ws.name !== String(ws.id)) ? ws.name : `Workspace ${ws.id}`;
            Island.push({ kind: "workspace", priority: Island.priority.workspace, duration: 800,
                          data: { id: ws.id, label } });
        }
    }
    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() {
            root.pendingWs = Hyprland.focusedWorkspace?.id ?? 0;
            wsDebounce.restart();
        }
    }

    // ── System events ──
    Connections {
        target: Battery
        function onPluggedInChanged() {
            if (!Battery.available) return;
            if (Battery.pluggedIn) Island.system("battery_charging_full", "Charging", Math.round(Battery.percentage * 100) + "%", "success");
            if (Island.ready) Sounds.play(Battery.pluggedIn ? "power" : "unplug");
            else Island.system("battery_full", "On battery", Battery.formatDuration(Battery.timeToEmpty) || (Math.round(Battery.percentage * 100) + "%"));
            Island.criticalDismissed = false;
        }
        function onLowChanged() {
            if (Battery.low) { Island.system("battery_2_bar", "Battery low", Math.round(Battery.percentage * 100) + "% remaining", "warning"); Sounds.play("warning", Battery.critical); }
        }
    }

    property var knownBt: ({})
    Connections {
        target: Bluetooth
        function onConnectedDevicesChanged() {
            const now = {};
            for (const d of Bluetooth.connectedDevices) {
                now[d.address] = d.name;
                if (!root.knownBt[d.address]) {
                    const detail = d.batteryAvailable ? Math.round(d.battery * 100) + "% battery" : "Connected";
                    if (root.firstTime("bt:" + d.address))
                        Island.device("bt:" + d.address, { icon: Bluetooth.glyph(d.icon ?? ""), title: d.name || "Bluetooth device", badge: "New",
                                      detail: "Paired over Bluetooth · " + detail, actions: [] });
                    else Island.system(Bluetooth.glyph(d.icon ?? ""), d.name || "Bluetooth device", detail);
                    if (Island.ready) Sounds.play("plug");
                }
            }
            for (const addr in root.knownBt)
                if (!now[addr]) { Island.system("bluetooth_disabled", root.knownBt[addr] || "Bluetooth device", "Disconnected"); if (Island.ready) Sounds.play("unplug"); }
            root.knownBt = now;
        }
    }

    Connections {
        target: Network
        function onSsidChanged() {
            if (Network.ssid) Island.system("wifi", Network.ssid, "Connected");
            else if (Network.wifiEnabled) Island.system("wifi_off", "Wi-Fi", "Disconnected", "warning");
        }
    }

    // ── Devices ─────────────────────────────────────────────────────────────
    // A device this computer has never seen gets a card with a "New" badge;
    // drives and displays always get one (there's something to do with them).
    // Everything else — your usual mouse, the dock — is a quiet one-line pill.
    function firstTime(id) {
        if (!id) return false;
        const seen = Persist.data.seenDevices ?? [];
        if (seen.includes(id)) return false;
        if (Persist.automates) Persist.data.seenDevices = seen.concat([id]).slice(-300);
        return true;
    }

    // What a USB device is, from its interface classes (cc:ss:pp per interface)
    function usbKind(e) {
        const ifs = e.ID_USB_INTERFACES ?? "";
        const has = re => re.test(ifs);
        if (has(/:09/)) return null;                               // hubs (and docks' hubs)
        if (has(/:e0/)) return null;                               // internal Bluetooth radios
        if (has(/:0e/)) return { icon: "videocam", what: "Camera" };
        if (has(/:08/)) return { icon: "hard_drive", what: "Drive", drive: true };
        if (has(/:06/) || has(/:ff4201/)) return { icon: "smartphone", what: "Phone or camera" };
        if (has(/:030101/)) return { icon: "keyboard", what: "Keyboard" };        // HID boot keyboard
        if (has(/:030102/)) return { icon: "mouse", what: "Mouse" };
        if (has(/:01/)) return { icon: "headphones", what: "Audio device" };
        if (has(/:03/)) return /game|pad|xbox|controller|joy/i.test(e.ID_MODEL ?? "")
                              ? { icon: "sports_esports", what: "Game controller" } : { icon: "keyboard", what: "Input device" };
        if (has(/:07/)) return { icon: "print", what: "Printer" };
        if (has(/:02|:0a/)) return { icon: "lan", what: "Network adapter" };
        return { icon: "usb", what: "USB device" };
    }
    function usbName(e) {
        let vendor = (e.ID_VENDOR_FROM_DATABASE || e.ID_VENDOR || "").replace(/_/g, " ");
        for (let k = 0; k < 3; k++)           // "Sonix Technology Co., Ltd." → "Sonix"
            vendor = vendor.replace(/[,.]?\s+(Inc|Corp|Corporation|Ltd|Co|Company|Technology|Technologies|Electronics|International|Semiconductor|Microelectronics)\.?,?\s*$/i, "").trim();
        const model = (e.ID_MODEL_FROM_DATABASE || e.ID_MODEL || "").replace(/_/g, " ").replace(/\s+/g, " ").trim();
        if (!model) return vendor || "USB device";
        return model.toLowerCase().startsWith(vendor.toLowerCase()) || !vendor ? model : vendor + " " + model;
    }

    property var usbSeen: ({})          // DEVPATH → { name, kind } (removal events carry no names)
    function onUsb(e) {
        if (e.ACTION === "add") {
            const k = usbKind(e);
            if (!k) return;
            const name = usbName(e);
            const m = Object.assign({}, usbSeen); m[e.DEVPATH] = { name, kind: k }; usbSeen = m;
            if (k.drive) return;                          // the drive's partition brings its own card
            const id = "usb:" + (e.ID_VENDOR_ID ?? "") + ":" + (e.ID_MODEL_ID ?? "") + ":" + (e.ID_SERIAL_SHORT ?? "");
            if (firstTime(id)) Island.device(id, { icon: k.icon, title: name, badge: "New", detail: k.what + " · connected by USB", actions: [] });
            else Island.system(k.icon, name, "Connected");
            if (Island.ready) Sounds.play("plug");
        } else if (e.ACTION === "remove") {
            const d = usbSeen[e.DEVPATH];
            if (!d) return;
            const m = Object.assign({}, usbSeen); delete m[e.DEVPATH]; usbSeen = m;
            Island.system(d.kind.drive ? "eject" : d.kind.icon, d.name, d.kind.drive ? "Removed" : "Disconnected");
            if (Island.ready) Sounds.play("unplug");
        }
    }

    function fmtSize(bytes) {
        if (!(bytes > 0)) return "";
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0;
        while (bytes >= 1000 && i < u.length - 1) { bytes /= 1000; i++; }
        return (bytes >= 100 || i === 0 ? Math.round(bytes) : bytes.toFixed(1)) + " " + u[i];
    }
    function onBlock(e) {
        if (e.ACTION !== "add" || e.ID_FS_USAGE !== "filesystem") return;
        const removable = e.ID_BUS === "usb" || /usb/.test(e.ID_PATH ?? "") || /^\/dev\/mmcblk/.test(e.DEVNAME ?? "");
        if (!removable) return;
        const sd = /^\/dev\/mmcblk/.test(e.DEVNAME ?? "");
        const label = e.ID_FS_LABEL_ENC ? e.ID_FS_LABEL_ENC.replace(/\\x20/g, " ") : (e.ID_FS_LABEL || "");
        const model = (e.ID_MODEL || "").replace(/_/g, " ");
        const size = fmtSize(Number(e.ID_PART_ENTRY_SIZE ?? 0) * 512);
        const id = "drive:" + (e.ID_FS_UUID || e.ID_SERIAL || e.DEVNAME);
        const scripts = Theme.lumenRoot + "/scripts/drive.sh";
        Island.device(id, {
            icon: sd ? "sd_card" : "hard_drive",
            title: label || model || (sd ? "SD card" : "USB drive"),
            badge: firstTime(id) ? "New" : "",
            detail: [sd ? "SD card" : "USB drive", size, (e.ID_FS_TYPE || "").toUpperCase()].filter(x => x).join(" · "),
            actions: [{ icon: "folder_open", label: "Open", cmd: [scripts, "open", e.DEVNAME] },
                      { icon: "eject", label: "Eject", cmd: [scripts, "eject", e.DEVNAME] }]
        });
    }

    // One long-running udev listener per subsystem (event-driven, no polling);
    // only whole USB devices, and block devices that carry a file system
    component UdevWatch: Process {
        id: w
        property var subsystem
        signal event(var e)
        property var ev: ({})
        running: true
        // SplitParser drops empty lines, and udev ends each event with one:
        // turn them into "--" (sed -u: unbuffered, so events arrive at once)
        command: ["sh", "-c", 'udevadm monitor --udev --subsystem-match="$1" --property | sed -u "s/^$/--/"', "sh", subsystem]
        stdout: SplitParser {
            onRead: line => {
                if (line === "--") { if (w.ev.ACTION) w.event(w.ev); w.ev = {}; return; }
                const i = line.indexOf("=");
                if (i > 0) w.ev[line.slice(0, i)] = line.slice(i + 1);
            }
        }
    }
    UdevWatch { subsystem: "usb/usb_device"; onEvent: e => root.onUsb(e) }

    // Devices already plugged in when the shell starts: remember their names
    // (so unplugging them is announced too) and mark them as seen, silently.
    Process {
        id: usbAtStart
        running: true
        command: ["sh", "-c", 'for d in /sys/bus/usb/devices/*; do [ -f "$d/idVendor" ] && udevadm info -q property -p "$d" && echo --; done 2>/dev/null']
        property var ev: ({})
        stdout: SplitParser {
            onRead: line => {
                const p = usbAtStart;
                if (line !== "--") { const i = line.indexOf("="); if (i > 0) p.ev[line.slice(0, i)] = line.slice(i + 1); return; }
                const e = p.ev; p.ev = {};
                const k = e.DEVPATH ? root.usbKind(e) : null;
                if (!k) return;
                const m = Object.assign({}, root.usbSeen); m[e.DEVPATH] = { name: root.usbName(e), kind: k }; root.usbSeen = m;
                root.firstTime("usb:" + (e.ID_VENDOR_ID ?? "") + ":" + (e.ID_MODEL_ID ?? "") + ":" + (e.ID_SERIAL_SHORT ?? ""));
            }
        }
    }
    UdevWatch { subsystem: "block"; onEvent: e => root.onBlock(e) }

    // Displays: Hyprland reports outputs as they come and go
    Connections {
        target: Hyprland
        function onRawEvent(ev) { root.onMonitor(ev); }
    }
    // "Dell Inc. DELL U2723QE 7X2KHK3 (HDMI-A-1)" → "Dell U2723QE"
    function displayName(desc) {
        let words = desc.replace(/\s*\(.*\)$/, "").split(/\s+/).filter(w => w);
        const last = words[words.length - 1] ?? "";
        if (words.length > 2 && (/^0x/i.test(last) || /\d/.test(last) && /[A-Z]/i.test(last) && last === last.toUpperCase() && last.length >= 6)) words.pop();
        words = words.filter(w => !/^(Inc\.?|Corp\.?|Corporation|Co\.?|Ltd\.?|Electronics|Electric|Company|Technology)$/i.test(w));
        if (words.length > 1 && words[1].toLowerCase() === words[0].toLowerCase()) words.splice(1, 1);
        return words.join(" ");
    }
    function onMonitor(ev) {
        {
            if (ev.name !== "monitoraddedv2" && ev.name !== "monitorremovedv2") return;
            const parts = ev.data.split(",");
            const name = parts[1] ?? "", desc = parts.slice(2).join(",").trim();
            if (/^(HEADLESS|LUMENTEST|WAYLAND|X11)/.test(name)) return;       // virtual outputs, test sessions
            const title = root.displayName(desc) || name;
            if (ev.name === "monitorremovedv2") { Island.system("desktop_access_disabled", title || "Display", "Disconnected"); return; }
            const id = "display:" + (desc || name);
            Island.device(id, {
                icon: /^eDP|^LVDS|^DSI/.test(name) ? "laptop" : "desktop_windows",
                title: title || "Display",
                badge: firstTime(id) ? "New" : "",
                detail: "Display connected · " + name,
                actions: [{ icon: "tune", label: "Arrange", page: "display" }]
            });
            if (Island.ready) Sounds.play("plug");
        }
    }

    // Dev only (LUMEN_DEV): `ipc call deviceTest usb|kbd|drive|display` replays a fake udev/Hyprland event
    IpcHandler {
        target: "deviceTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function usb(): void { root.onUsb({ ACTION: "add", DEVPATH: "/t/1", ID_USB_INTERFACES: ":010100:010200:030000:", ID_VENDOR_FROM_DATABASE: "Sony Corp.", ID_MODEL: "WH-1000XM5", ID_VENDOR_ID: "054c", ID_MODEL_ID: "0" + Date.now() % 1000 }); }
        function kbd(): void { root.onUsb({ ACTION: "add", DEVPATH: "/t/2", ID_USB_INTERFACES: ":030101:030000:", ID_VENDOR_FROM_DATABASE: "Keychron", ID_MODEL: "K2", ID_VENDOR_ID: "3434", ID_MODEL_ID: "0210" }); }
        function unplug(): void { root.onUsb({ ACTION: "remove", DEVPATH: "/t/2" }); }
        function known(): string { return JSON.stringify(Object.values(root.usbSeen).map(d => d.name + " (" + d.kind.what + ")")); }
        function drive(): void { root.onBlock({ ACTION: "add", ID_FS_USAGE: "filesystem", ID_BUS: "usb", DEVNAME: "/dev/sdz1", ID_FS_LABEL: "BACKUP", ID_FS_TYPE: "exfat", ID_PART_ENTRY_SIZE: "124735488", ID_FS_UUID: "t" + Date.now() }); }
        function display(): void { root.onMonitor({ name: "monitoraddedv2", data: "3,HDMI-A-1,Dell Inc. DELL U2723QE 7X2KHK3 (HDMI-A-1)" }); }
    }

    // ── Entry points ──
    GlobalShortcut {
        appid: "lumen"
        name: "island"
        description: "Expand the island (media controls)"
        onPressed: Island.togglePinned()
    }

    IpcHandler {
        target: "brightness"
        function up(): void { Brightness.up(); }
        function down(): void { Brightness.down(); }
    }

    IpcHandler {
        target: "island"
        function toggle(): void { Island.togglePinned(); }
        function pin(): void { Island.pinned = true; }
        function unpin(): void { Island.pinned = false; }
        // Debug: current decision state as JSON
        function state(): string {
            return JSON.stringify({ variant: Island.variant, kind: Island.kind, pinned: Island.pinned,
                                    hovered: Island.hovered, pointerInside: Island.pointerInside,
                                    queue: Island.queue.map(e => e.key), media: Media.title, playing: Island.mediaPlaying,
                                    present: Island.mediaPresent, context: Context.kind, project: Context.projectDir });
        }
        function dismiss(): void { Island.dismiss(); }
        function screenshot(path: string): void {
            Sounds.play("shutter");
            Island.push({ kind: "screenshot", priority: Island.priority.screenshot, duration: 5000,
                          queueable: true, force: true, data: { path } });
        }
        function recording(active: bool): void {
            if (active && !Island.recording) Island.recordingSince = new Date();
            Island.recording = active;
        }
        function recordingSaved(path: string): void {
            Island.recording = false;
            Island.push({ kind: "system", key: "rec-saved", priority: Island.priority.system, duration: 2500,
                          queueable: true, force: true,
                          data: { icon: "videocam", title: "Recording saved", detail: path.split("/").pop(), tone: "normal", path } });
        }
        // Progress from scripts (`lumen progress`, `lumen run`): value 0–100, -1 unknown
        function progress(id: string, title: string, value: real, detail: string): void {
            Island.progress(id, "", title, value, detail);
        }
        function progressDone(id: string, title: string, ok: bool, detail: string): void {
            Island.push({ kind: "system", key: "progress:" + id, priority: Island.priority.system, duration: 3500,
                          queueable: true, force: true,
                          data: { icon: ok ? "task_alt" : "error", title, detail, tone: ok ? "success" : "error" } });
            Sounds.play(ok ? "done" : "warning");
        }
        // For scripts and testing: qs -p … ipc call island event <icon> <title> <detail>
        function event(icon: string, title: string, detail: string): void {
            Island.push({ kind: "system", key: "ipc:" + title, priority: Island.priority.system, duration: 2500,
                          queueable: true, force: true, data: { icon, title, detail, tone: "normal" } });
        }
        function notify(app: string, title: string, body: string): void {
            Island.push({ kind: "notification", key: "notif:" + title, priority: Island.priority.notification,
                          duration: 4000, queueable: true, force: true,
                          data: { appName: app, appIcon: "", summary: title, body } });
        }
    }

    // A recorder may already be running when the shell (re)starts
    Process {
        running: true
        command: ["pgrep", "-x", "wf-recorder"]
        onExited: code => { if (code === 0) Island.recording = true; }
    }
}
