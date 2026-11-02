pragma Singleton
// Halo's smart router (Settings → Halo → "Smart"): picks a model for each
// request instead of one model for everything.
//
//   quick    greetings, thanks, small talk         → this computer first
//   smart    facts, how/why, code, writing, plans  → the best free cloud model
//   vision   a picture is attached                 → a cloud model that sees, else the local one
//   agent    a job done step by step (JSON)        → a cloud model that follows formats
//   long     more than a small model can read      → a cloud model with a big context
//
// Free tiers only (never a paid provider), within each one's daily limits:
// requests and tokens are counted here per provider per day (UTC), a provider
// close to its limit is skipped, and one that says "too many requests" (429)
// rests until its reset. If the chosen one fails, the next is tried; this
// computer is always last, so there is always an answer.
// Counts live in ~/.local/state/lumen/ai-usage.json.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    // Free-tier limits, approximate and kept a little low (Oct 2026; providers
    // change them, and each account's console shows the real ones).
    readonly property var limits: ({
        gemini:     { rpm: 10, rpd: 250,  tpd: 0,      maxIn: 200000 },
        groq:       { rpm: 30, rpd: 1000, tpd: 100000, maxIn: 10000 },   // 12k tokens a minute caps one request
        mistral:    { rpm: 1,  rpd: 0,    tpd: 0,      maxIn: 30000 },
    })
    // Free cloud choices, best first, with the model each uses and whether it sees pictures
    readonly property var cloud: [
        { provider: "gemini",     model: "gemini-2.5-flash",        label: "Gemini 2.5 Flash", vision: true,  json: true },
        { provider: "groq",       model: "llama-3.3-70b-versatile", label: "Llama 3.3 70B (Groq)", vision: false, json: true },
        { provider: "mistral",    model: "mistral-small-latest",    label: "Mistral Small",    vision: false, json: true },
    ]
    function available(c) { return c && Ai.isConfigured(c.provider); }
    readonly property var localText: Ai.isConfigured("ollama") ? { provider: "ollama", model: Ai.textModel, label: Ai.textModel.replace(/:latest$/, ""), vision: false, json: true, local: true } : null
    readonly property var localVision: Ai.isConfigured("ollama") && Ai.visionModel ? { provider: "ollama", model: Ai.visionModel, label: Ai.visionModel.replace(/:latest$/, ""), vision: true, json: true, local: true } : null
    readonly property bool ready: !!localText || cloud.some(available)
    readonly property bool canSee: !!localVision || cloud.some(c => c.vision && available(c))

    // ── what kind of request is this ──
    // text: what you asked (without the context Halo added); chars: the whole request
    function kindOf(text, chars, hasImage) {
        const t = (text ?? "").trim().toLowerCase();
        if (hasImage) return "vision";
        if (chars > 12000) return "long";
        if (t.length < 60 && /^(hi|hello|hey|yo|thanks|thank you|thx|ok|okay|cool|nice|great|lol|good (morning|afternoon|evening|night)|bye|see you|how are you|what'?s up|who are you)\b[^?]*$/.test(t)) return "quick";
        return "smart";
    }

    // ── the candidates for a request, best first; this computer always last ──
    function plan(kind, chars) {
        const tokens = Math.ceil((chars ?? 0) / 4);
        const fits = c => !limits[c.provider] || tokens <= limits[c.provider].maxIn;
        const free = cloud.filter(c => available(c) && fits(c) && hasRoom(c.provider, tokens));
        let out;
        if (kind === "quick") out = [localText].concat(free);
        else if (kind === "vision") out = free.filter(c => c.vision).concat([localVision]);
        else if (kind === "agent") out = free.filter(c => c.json).concat([localText]);
        else out = free.concat([localText]);
        out = out.filter(c => !!c);
        // nothing free and no local model: the first configured free one even if it's resting
        if (!out.length) out = cloud.filter(available).slice(0, 1);
        return out;
    }
    function pick(kind, chars) { return plan(kind, chars)[0] ?? null; }

    // ── budgets ──
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/ai-usage.json"
    property var usage: ({})            // { day: "YYYY-MM-DD" (UTC), p: { gemini: { req, tok, recent: [ms…], restUntil, lastLimit } } }
    FileView {
        id: store
        path: root.statePath
        watchChanges: true              // Settings (its own process) shows the shell's counts live
        onFileChanged: reload()
        onLoaded: { try { root.usage = JSON.parse(text()) ?? {}; } catch (e) { root.usage = {}; } }
        onLoadFailed: root.usage = {}
    }
    function today() { return new Date().toISOString().slice(0, 10); }
    // today's counts: yesterday's are dropped, but a rest that runs past midnight UTC still applies
    function current() {
        if (usage.day === today()) return usage;
        const u = { day: today(), p: {} };
        for (const k in (usage.p ?? {})) if ((usage.p[k].restUntil ?? 0) > Date.now()) u.p[k] = { req: 0, tok: 0, recent: [], restUntil: usage.p[k].restUntil };
        return u;
    }
    function entry(p) { return current().p?.[p] ?? { req: 0, tok: 0, recent: [], restUntil: 0 }; }
    function save(p, e) {
        const u = Object.assign({}, current());
        u.p = Object.assign({}, u.p ?? {}); u.p[p] = e;
        usage = u;
        store.setText(JSON.stringify(u));
    }
    function hasRoom(p, tokens) {
        const l = limits[p];
        if (!l) return true;
        const e = entry(p), now = Date.now();
        if ((e.restUntil ?? 0) > now) return false;
        if (l.rpm && (e.recent ?? []).filter(t => now - t < 60000).length >= l.rpm) return false;
        if (l.rpd && e.req >= Math.floor(l.rpd * 0.95)) return false;
        if (l.tpd && e.tok + tokens >= Math.floor(l.tpd * 0.95)) return false;
        return true;
    }
    // a request went out (chars: its size); tokens out are added when known
    function sent(p, chars) {
        if (!limits[p]) return;
        const e = Object.assign({}, entry(p)), now = Date.now();
        e.req += 1;
        e.tok += Math.ceil((chars ?? 0) / 4);
        e.recent = (e.recent ?? []).filter(t => now - t < 60000).concat([now]);
        save(p, e);
    }
    function answered(p, outTokens) {
        if (!limits[p] || !outTokens) return;
        const e = Object.assign({}, entry(p));
        e.tok += outTokens;
        save(p, e);
    }
    // "too many requests": rest a minute (or what it asked); a second time
    // within ten minutes means the day is used up, so rest until midnight UTC
    function limited(p, retrySeconds) {
        const e = Object.assign({}, entry(p)), now = Date.now();
        const again = (e.lastLimit ?? 0) > now - 600000;
        const midnight = new Date(); midnight.setUTCHours(24, 0, 0, 0);
        e.restUntil = again ? midnight.getTime() : now + Math.max(60, retrySeconds || 0) * 1000;
        e.lastLimit = now;
        save(p, e);
    }
    // couldn't reach it: try the others for a minute
    function unreachable(p) {
        const e = Object.assign({}, entry(p));
        e.restUntil = Date.now() + 60000;
        save(p, e);
    }
    // for Settings: "Gemini 12 of 250 today"
    function summary() {
        return cloud.filter(available).map(c => {
            const l = limits[c.provider], e = entry(c.provider);
            const resting = (e.restUntil ?? 0) > Date.now();
            return { label: c.label, req: e.req, rpd: l.rpd, tok: e.tok, tpd: l.tpd, resting,
                     until: resting ? Qt.formatTime(new Date(e.restUntil), Theme.timeFormatFull) : "" };
        });
    }
}
