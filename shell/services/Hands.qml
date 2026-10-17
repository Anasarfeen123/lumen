pragma Singleton
// Halo's hands (scripts/halo-hands.py): it can move your pointer, point at
// things, click, scroll, press keys and type — in this session only.
//
//   pointing and scrolling     just happen (a ring marks the spot; Halo rides
//                              along with your cursor while it glides)
//   clicks, keys, typing       ask first, right where they'll happen:
//                              Allow · Allow for 2 minutes · Cancel (Enter / Esc)
//   you're always in charge    move the mouse during a glide and it stops; Esc
//                              stops; Settings → Halo → "Hands" turns it all off
// Never on the lock screen or over a password prompt.
//
// Targets come from what's on screen: text Halo reads there (tesseract, on
// this computer) or a window. modules/hands/HandsOverlay.qml draws it all.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/halo-hands.py"
    readonly property bool enabled: Persist.data.haloHands ?? true
    readonly property bool blocked: Lock.locked || Polkit.flow !== null

    // what's happening
    property var target: null           // { kind: point|click|key|type, x, y, w, h, label, combo?, text?, button?, window? }
    property bool asking: false
    property bool driving: false
    property var glideFrom: null        // { x, y } where the pointer started (for the companion)
    property real glideMs: 0
    property int glideId: 0             // bumps each glide: the overlay replays its companion
    property real trustUntil: 0
    property real now: Date.now()
    Timer { interval: 1000; repeat: true; running: root.trustUntil > root.now || root.asking; onTriggered: root.now = Date.now() }
    readonly property bool trusted: trustUntil > now
    readonly property int trustLeft: Math.max(0, Math.round((trustUntil - now) / 1000))

    // ydotool's socket (your ydotool service) — needed for clicks and the wheel
    property bool canClick: false
    Process {
        id: probe
        running: true
        command: ["sh", "-c", 'command -v ydotool >/dev/null && [ -S "${YDOTOOL_SOCKET:-$XDG_RUNTIME_DIR/.ydotool_socket}" ] && echo yes']
        stdout: StdioCollector { onStreamFinished: root.canClick = text.trim() === "yes" }
    }
    function refresh() { probe.running = true; }

    function say(title, text, tone) {
        Halo.say({ key: "hands", icon: "pan_tool_alt", title, text: text ?? "", tone: tone ?? "normal", level: "asked", duration: 4500, speak: false });
    }
    function refuse() {
        if (!enabled) { say("My hands are off", "Turn them on in Settings → Halo → Hands."); return true; }
        if (blocked) return true;
        return false;
    }

    // ── pointing ──
    function point(x, y, w, h, label) {
        if (refuse()) return;
        target = { kind: "point", x, y, w: w ?? 0, h: h ?? 0, label: label ?? "" };
        asking = false;
        glide(x, y, () => markTimer.restart());
    }
    Timer { id: markTimer; interval: 2600; onTriggered: if (root.target?.kind === "point") root.target = null }

    // ── asking first ──
    function request(a) {
        if (refuse()) return;
        if ((a.kind === "click" || a.kind === "scroll") && !canClick) {
            say("I can't click yet", "Clicks and scrolling go through ydotool — its service isn't running (systemctl --user start ydotool).", "concerned");
            return;
        }
        target = a;
        if (a.safe || trusted) { asking = false; run(); return; }
        asking = true;
        // show where it would act, without acting
        if (a.kind === "click") glide(a.x, a.y, null);
    }
    function allow(forAWhile) {
        if (!asking) return;
        if (forAWhile) { trustUntil = Date.now() + 120000; now = Date.now(); }
        asking = false;
        run();
    }
    function cancel() {
        asking = false;
        target = null;
        if (doer.running) doer.running = false;
        if (glider.running) glider.running = false;
        driving = false;
    }
    function stopTrust() { trustUntil = 0; }

    function run() {
        const a = target;
        if (!a) return;
        driving = true;
        if (a.kind === "click") {
            startCompanion(a.x, a.y);
            doer.command = [script, "click", String(a.x), String(a.y), a.button ?? "left"];
        } else if (a.kind === "key") doer.command = [script, "key", a.combo];
        else if (a.kind === "type") doer.command = [script, "type", a.text];
        else if (a.kind === "scroll") doer.command = [script, "scroll", a.dir, String(a.steps ?? 5)];
        else { driving = false; return; }
        doer.running = true;
    }
    Process {
        id: doer
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}; try { r = JSON.parse(text); } catch (e) {}
                root.finished(r);
            }
        }
        onExited: code => { if (code !== 0) root.finished({ ok: false, why: "it didn't work" }); }
    }
    function finished(r) {
        if (!driving) return;
        driving = false;
        const a = target;
        if (r.ok) {
            Halo.react("happy", 1400);
            if (a?.kind === "click") { target = Object.assign({}, a, { kind: "done" }); doneTimer.restart(); }
            else target = null;
        } else {
            target = null;
            if (r.why === "you-moved") say("All yours", "You moved the mouse, so I stopped.");
            else say("That didn't work", r.why ?? "", "concerned");
        }
    }
    Timer { id: doneTimer; interval: 700; onTriggered: if (root.target?.kind === "done") root.target = null }

    // ── the glide (the pointer moves; Halo rides along) ──
    property var _after: null
    function glide(x, y, after) {
        _after = after;
        whereProc.tx = x; whereProc.ty = y;
        whereProc.running = true;
    }
    Process {
        id: whereProc
        property real tx: 0
        property real ty: 0
        command: [root.script, "where"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = {}; try { p = JSON.parse(text); } catch (e) {}
                root.startCompanion(whereProc.tx, whereProc.ty, p);
                glider.command = [root.script, "glide", String(whereProc.tx), String(whereProc.ty)];
                glider.running = true;
            }
        }
    }
    function startCompanion(x, y, from) {
        const f = from ?? glideFrom ?? { x, y };
        const dist = Math.hypot(x - f.x, y - f.y);
        glideFrom = { x: f.x, y: f.y };
        glideMs = Math.max(180, Math.min(520, 300 + dist * 0.35));
        glideId++;
    }
    Process {
        id: glider
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}; try { r = JSON.parse(text); } catch (e) {}
                if (r.ok === false && r.why === "you-moved") { root.cancel(); root.say("All yours", "You moved the mouse, so I stopped."); return; }
                const f = root._after; root._after = null;
                if (f) f();
            }
        }
    }

    // ── finding things on screen ──
    function find(text, then) {
        finder.then = then;
        finder.command = [script, "find", text];
        finder.running = true;
    }
    Process {
        id: finder
        property var then: null
        stdout: StdioCollector {
            onStreamFinished: {
                let hits = []; try { hits = JSON.parse(text); } catch (e) {}
                const f = finder.then; finder.then = null;
                if (f) f(hits);
            }
        }
    }
    // A window by name, title or app
    function windowFor(name) {
        const q = name.toLowerCase().replace(/^the /, "");
        let best = null, score = 0;
        for (const t of Hyprland.toplevels.values) {
            const o = t.lastIpcObject ?? {};
            if (!o.at || !o.size) continue;
            const s = Math.max(Fuzzy.score(q, t.title ?? ""), Fuzzy.score(q, o.class ?? ""), Fuzzy.score(q, Apps.entryFor(o.class ?? "")?.name ?? ""));
            if (s > score) { score = s; best = o; }
        }
        return score >= 600 ? best : null;
    }

    // Halo's own panels slide away first: they'd be in the way (and in the picture)
    property var _queued: null
    function clearView(then) {
        if (Ai.open || Overview.open || Sidebar.open) { Ai.open = false; Overview.open = false; Sidebar.open = false; _queued = then; clearTimer.restart(); }
        else then();
    }
    Timer { id: clearTimer; interval: 380; onTriggered: { const f = root._queued; root._queued = null; if (f) f(); } }

    // The things Halo says yes to (from Halo.intent)
    function clickText(what, button) {
        if (refuse()) return;
        Halo.react("thinking", 900);
        clearView(() => find(what, hits => {
            if (!hits.length) { say("I can't see “" + what + "”", "Not on this screen — is it scrolled out of view?", "concerned"); return; }
            const h = hits[0];
            request({ kind: "click", x: h.x, y: h.y, w: h.w, h: h.h, label: h.text, button: button ?? "left" });
        }));
    }
    function pointAt(what) {
        if (refuse()) return;
        clearView(() => pointNow(what));
    }
    function pointNow(what) {
        const w = windowFor(what);
        if (w) {
            Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ window = \"address:" + w.address + "\" })"]);
            point(w.at[0] + w.size[0] / 2, w.at[1] + w.size[1] / 2, w.size[0], w.size[1], Apps.entryFor(w.class ?? "")?.name ?? w.title);
            return;
        }
        find(what, hits => {
            if (!hits.length) { say("I can't see “" + what + "”", "Not on this screen.", "concerned"); return; }
            const h = hits[0];
            point(h.x, h.y, h.w, h.h, h.text);
        });
    }
    function scroll(dir, steps) { clearView(() => request({ kind: "scroll", dir, steps: steps ?? 5, safe: true, label: dir === "up" ? "Scrolling up" : "Scrolling down" })); }
    function key(combo, safe) { clearView(() => request({ kind: "key", combo, safe: !!safe, label: combo, window: Hyprland.activeToplevel?.title ?? "" })); }
    function type(text) { clearView(() => request({ kind: "type", text, label: text, window: Hyprland.activeToplevel?.title ?? "" })); }

    GlobalShortcut { appid: "lumen"; name: "handsStop"; description: "Halo: let go of the mouse"; onPressed: root.cancel() }
    IpcHandler {
        target: "hands"
        function point(text: string): void { root.pointAt(text); }
        function click(text: string): void { root.clickText(text, "left"); }
        function allow(): void { root.allow(false); }
        function cancel(): void { root.cancel(); }
        function state(): string { return JSON.stringify({ target: root.target, asking: root.asking, driving: root.driving, trusted: root.trusted, canClick: root.canClick }); }
    }
}
