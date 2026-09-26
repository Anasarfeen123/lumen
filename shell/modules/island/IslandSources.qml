// Everything that can make the island speak, in one place.
// Watches services for *changes* (never initial values — Island.ready gates
// the first 2 s) and turns them into island events. Also hosts the IPC and
// global-shortcut entry points used by keybinds and scripts.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

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
                    Island.system("bluetooth_connected", d.name || "Bluetooth device", detail);
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

    // USB: one long-running udev listener (event-driven, no polling).
    // Only whole devices (DEVTYPE=usb_device), not every interface.
    Process {
        id: usb
        running: true
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=usb/usb_device", "--property"]
        property var ev: ({})
        stdout: SplitParser {
            onRead: line => {
                const p = usb;
                if (line === "") {
                    const e = p.ev;
                    if (e.ACTION === "add" || e.ACTION === "remove") {
                        const name = (e.ID_MODEL_FROM_DATABASE || e.ID_MODEL || "USB device").replace(/_/g, " ");
                        Island.system(e.ACTION === "add" ? "usb" : "usb_off", name,
                                      e.ACTION === "add" ? "Connected" : "Removed");
                    }
                    p.ev = {};
                } else {
                    const i = line.indexOf("=");
                    if (i > 0) { const e = p.ev; e[line.slice(0, i)] = line.slice(i + 1); }
                }
            }
        }
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
