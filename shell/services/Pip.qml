pragma Singleton
// Picture-in-picture, two ways:
//  • Video PiP (modules/pip/VideoPip.qml): just the video you're watching —
//    found inside its window by what moves (scripts/pip.py video-rect) — shown
//    live in a small corner player with its own controls. The browser stays
//    where it is. Auto: leave the workspace with a playing video and it
//    follows you; go back and it steps away (Settings → Bar & Island).
//  • Window PiP (scripts/pip.py): any other window — a call, a chat — floats,
//    pinned in a corner across workspaces, and goes back exactly as it was.
//   Ctrl+Super+P · the island's player (⧉) · Halo: "picture in picture",
//   "move the pip to the top left", "make it bigger", "put it back"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/pip.py"
    property var state: ({})            // { address, title, class, corner, size, browser? }
    readonly property bool active: !!state.address || !!video
    readonly property bool windowActive: !!state.address

    // ── Video PiP ──
    property var video: null             // { address, player, auto }
    property var crops: ({})             // window address → { x, y, w, h (fractions), size: [w, h] }
    property string dismissed: ""        // auto: closed for this video — it won't follow you again until you go back
    readonly property string vCorner: Persist.data.pipCorner ?? "br"
    readonly property real vSize: Persist.data.pipSize ?? 0.26
    function norm(a) { return String(a ?? "").replace(/^0x/, ""); }
    function toplevelOf(addr) { return addr ? (Hyprland.toplevels.values.find(t => norm(t.lastIpcObject?.address ?? t.address) === norm(addr)) ?? null) : null; }
    function visible_(t) { return !!t && !!t.workspace && (t.workspace.active || (t.workspace.name ?? "").startsWith("special") && t.workspace.monitor?.lastIpcObject?.specialWorkspace?.name === t.workspace.name); }
    readonly property var videoTop: toplevelOf(video?.address)
    readonly property var videoCrop: {
        const c = crops[norm(video?.address)], s = videoTop?.lastIpcObject?.size;
        return c && s && Math.abs(c.size[0] - s[0]) < 4 && Math.abs(c.size[1] - s[1]) < 4 ? c : null;    // stale after a resize
    }
    readonly property bool sourceVisible: visible_(videoTop)
    readonly property bool videoShown: !!videoTop && !!video && (!video.auto || !sourceVisible)
    onVideoTopChanged: if (video && !videoTop) video = null          // its window closed

    // ── Firefox and its family: their own picture-in-picture (Ctrl+Shift+]) —
    // the real video with its own controls, floated and pinned by
    // hypr/rules.lua. Lumen opens it, puts your focus back, and ends it.
    function firefoxish(address) { return /firefox|zen|librewolf|floorp|waterfox|mullvad/i.test(toplevelOf(address)?.lastIpcObject?.class ?? ""); }
    property var native_: null          // { address, auto } — the window whose video is in Firefox's PiP
    readonly property bool nativeOpen: !!state.browser
    function nativeShortcut(address) {
        const back = Hyprland.activeToplevel?.lastIpcObject?.address ?? "";
        Hypr.d(`hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "bracketright", window = ${Hypr.win(address.startsWith("0x") ? address : "0x" + address)} })`);
        // sending the shortcut focuses the browser: give focus back to what you were using
        if (back && norm(back) !== norm(address)) { refocus.address = back; refocus.restart(); }
        refreshSoon.restart();
    }
    Timer { id: refocus; property string address: ""; interval: 450; onTriggered: Hypr.focusWindow(address) }
    function endNative() {
        if (native_ && toplevelOf(native_.address)) nativeShortcut(native_.address);
        else if (state.browser && state.address) Hypr.closeWindow(state.address);
        native_ = null;
    }

    function popVideo(address, auto) {
        if (!address) return;
        if (firefoxish(address)) {
            if (nativeOpen) return;
            video = null;
            native_ = { address, auto: !!auto };
            nativeShortcut(address);
            return;
        }
        if (!auto) {
            dismissed = "";
            // on screen and not measured yet: find the video first, then show it
            // (measuring with the PiP already on top would count the PiP as video)
            video = null;                                 // one at a time (and out of the way of the measuring)
            const c = crops[norm(address)], t = toplevelOf(address);
            if (visible_(t) && !(c && t?.lastIpcObject?.size && c.size[0] === t.lastIpcObject.size[0] && c.size[1] === t.lastIpcObject.size[1])) {
                pending = { address, player: playerFor(address) };
                findCrop(address);
                return;
            }
        }
        video = { address, player: playerFor(address), auto: !!auto };
    }
    property var pending: null        // a manual pop waiting for its video to be found
    // The window's own player — not just whichever is "active": Chromium names its
    // player after the browser's process (brave.instance<pid>), so match on that,
    // then on the window title carrying the track title.
    function playerFor(address) {
        const o = toplevelOf(address)?.lastIpcObject ?? {}, pid = String(o.pid ?? ""), title = (o.title ?? "").toLowerCase();
        const ps = Mpris.players.values;
        return ps.find(p => pid && (p.dbusName ?? "").endsWith("instance" + pid))
            ?? ps.find(p => (p.trackTitle ?? "").length > 3 && title.includes(p.trackTitle.toLowerCase().slice(0, 40)))
            ?? Media.active;
    }
    function closeVideo() {
        if (video?.auto) dismissed = Media.title;
        video = null;
    }
    function backToVideo() {
        if (!video) return;
        const a = video.address;
        video = null;
        Hypr.focusWindow(a.startsWith("0x") ? a : "0x" + a);
    }
    function moveVideo(c) { Persist.data.pipCorner = c; }
    function resizeVideo(f) { Persist.data.pipSize = Math.max(0.16, Math.min(0.5, f)); }

    // Where the video is inside its window — looked for while it's on screen
    property rect cardRect: Qt.rect(0, 0, 0, 0)       // where VideoPip's player is on screen (it's left out of the measuring)
    function findCrop(address) {
        if (cropProc.running) return;
        cropProc.address = address;
        cropProc.command = [script, "video-rect", address.startsWith("0x") ? address : "0x" + address]
            .concat(videoShown && cardRect.width > 0 ? [[cardRect.x, cardRect.y, cardRect.width, cardRect.height].map(Math.round).join(",")] : []);
        cropProc.running = true;
    }
    Process {
        id: cropProc
        property string address: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}; try { r = JSON.parse(text); } catch (e) {}
                const t = root.toplevelOf(cropProc.address);
                if (r.w && t?.lastIpcObject?.size) {
                    const c = Object.assign({}, root.crops);
                    c[root.norm(cropProc.address)] = Object.assign(r, { size: t.lastIpcObject.size.slice() });
                    root.crops = c;
                }
                if (root.pending) { root.video = Object.assign(root.pending, { auto: false }); root.pending = null; }
            }
        }
    }

    // ── Auto: the playing video's window, if it's a browser or a video player
    // and something in it moves (so music in a tab doesn't follow you) ──
    readonly property var candidate: {
        if (!Media.playing) return null;
        const w = playerWindow();
        return w && /brave|firefox|zen|chrom|vivaldi|librewolf|floorp|edge|vlc|mpv|haruna|celluloid|totem|showtime|clapper|freetube|smplayer/i.test(w.class ?? "")
                 && !/music|spotify/i.test((w.class ?? "") + " " + (w.title ?? "").slice(-40)) ? w : null;
    }
    readonly property var candidateTop: toplevelOf(candidate?.address)
    readonly property bool candidateVisible: visible_(candidateTop)
    property bool wasVisible: false
    onCandidateVisibleChanged: {
        if (candidateVisible) {
            if (video?.auto && norm(video.address) === norm(candidate?.address)) video = null;   // back at it
            if (native_?.auto && norm(native_.address) === norm(candidate?.address) && nativeOpen) endNative();
            dismissed = "";
            lookSoon.restart();
        } else if (wasVisible && candidate && (Persist.data.pipAuto ?? true) && !video && !nativeOpen && Media.title !== dismissed
                   && (crops[norm(candidate.address)] || firefoxish(candidate.address))) {   // Firefox's own PiP does nothing on a tab without video
            popVideo(candidate.address, true);
        }
        wasVisible = candidateVisible;
    }
    onCandidateChanged: { wasVisible = candidateVisible; if (candidate) lookSoon.restart(); }
    Connections { target: Media; function onTitleChanged() { if (root.candidate) lookSoon.restart(); } }
    // look while it plays on screen (and again now and then: a resize, theatre mode)
    // shown without its video found yet (it was paused, say): keep looking while its window is in view
    Timer { interval: 3000; repeat: true; running: root.videoShown && !root.videoCrop && root.sourceVisible; onTriggered: root.findCrop(root.video.address) }
    Timer { id: lookSoon; interval: 2500; onTriggered: if (root.candidate && root.candidateVisible) root.findCrop(root.candidate.address) }
    Timer { interval: 25000; repeat: true; running: !!root.candidate && root.candidateVisible; onTriggered: root.findCrop(root.candidate.address) }

    function refresh() { if (!stateProc.running) stateProc.running = true; }
    Process { id: stateProc; running: true; command: [root.script, "state"]
              stdout: StdioCollector { onStreamFinished: { try { root.state = JSON.parse(text); } catch (e) { root.state = ({}); } } } }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (/^(closewindow|openwindow|pin|changefloatingmode|windowtitlev2)$/.test(ev.name)) refreshSoon.restart(); }
    }
    Timer { id: refreshSoon; interval: 300; onTriggered: root.refresh() }

    function run(args, say) {
        const p = runner.createObject(root, { say });
        p.command = [script].concat(args);
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: rp
            property string say: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {}; try { r = JSON.parse(text); } catch (e) {}
                    if (r.ok === false) Island.system("picture_in_picture_alt", r.error || "Couldn't do that", "");
                    else if (rp.say) Island.system("picture_in_picture_alt", rp.say, r.title ?? "");
                    root.refresh();
                    rp.destroy();
                }
            }
        }
    }
    function pop(address) { run(["pop"].concat(address ? [address] : []), "Picture in picture"); }
    function back() { if (video) closeVideo(); else if (nativeOpen) endNative(); else run(["back"], "Back in its place"); }
    // Ctrl+Super+P: the video if you're looking at the one playing, else the focused window
    function toggle() {
        if (video) { closeVideo(); return; }
        if (nativeOpen) { endNative(); return; }
        if (windowActive && !state.browser) { back(); return; }
        const f = Hyprland.activeToplevel?.lastIpcObject?.address ?? "", w = playerWindow();
        if (Media.playing && w && norm(w.address) === norm(f)) popVideo(w.address, false);
        else pop("");
    }
    function corner(c) {
        if (!video) { run(["corner", c ?? "next"], ""); return; }
        const order = ["br", "bl", "tl", "tr"];
        moveVideo(!c || c === "next" ? order[(order.indexOf(vCorner) + 1) % 4] : c);
    }
    function size(s) {
        if (!video) { run(["size", s], ""); return; }
        resizeVideo(s === "bigger" ? vSize + 0.06 : s === "smaller" ? vSize - 0.06 : ({ small: 0.2, medium: 0.28, large: 0.4 })[s] ?? vSize);
    }

    // The music/video player's own window (for "pop it out" from the island)
    function playerWindow() {
        const p = Media.active;
        if (!p) return null;
        const keys = [p.desktopEntry, p.identity].filter(x => x).map(x => String(x).toLowerCase().replace(/\s+/g, ""));
        return Hyprland.toplevels.values.map(t => t.lastIpcObject ?? {}).find(o => {
            const c = (o.class ?? "").toLowerCase(), t = (o.title ?? "").toLowerCase();
            return keys.some(k => c.includes(k) || k.includes(c) && c.length > 3) || (Media.title && t.includes(Media.title.toLowerCase().slice(0, 24)));
        }) ?? null;
    }
    function popPlayer() { const w = playerWindow(); if (w?.address) popVideo(w.address, false); else Island.system("picture_in_picture_alt", "No window for this player", "It may be playing in the background"); }

    GlobalShortcut { appid: "lumen"; name: "pip"; description: "Picture in picture (the focused window)"; onPressed: root.toggle() }
    IpcHandler {
        target: "pip"
        function toggle(): void { root.toggle(); }
        function corner(c: string): void { root.corner(c); }
        function size(s: string): void { root.size(s); }
        function state(): string { return JSON.stringify({ window: root.state, video: root.video ? { address: root.video.address, auto: root.video.auto, shown: root.videoShown, crop: root.videoCrop, player: root.video.player?.dbusName ?? "" } : null, native: root.native_, candidate: root.candidate?.address ?? "", crops: root.crops }); }
        function video(address: string): void { root.popVideo(address, false); }
    }
}
