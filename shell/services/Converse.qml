pragma Singleton
// Talking with Halo, the way you talk to an assistant on a phone: a sheet
// rises from the bottom (modules/ai/VoiceSheet.qml), you speak (or type),
// Halo answers in words and out loud, then listens for a follow-up.
//
//   open()            the sheet, listening (Super+Alt+H, "Hey Halo", the mic)
//   press()/release() Super+Alt+H: a tap listens until you pause; holding it
//                     is push-to-talk (it stops when you let go)
//   say(text)         what you said (or typed) → one turn
//   follow-ups        after an answer Halo listens again for ~6 s; "thanks",
//                     "stop", "never mind" end it; "repeat that" says it again
// Answers come from Halo's own abilities first (Halo.intent), else the
// agent for jobs, else the model; cards Halo says while the sheet is open
// land in the sheet instead of the island.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    property var turns: []              // [{ you, answer, card, state: thinking|done }]
    property bool followUp: false       // listening again after an answer
    readonly property var last: turns.length ? turns[turns.length - 1] : null
    readonly property bool conversational: Persist.data.haloConversation ?? true
    property string typed: ""

    function show() {
        if (!open) { turns = []; open = true; Ai.prepare(); }
        if (Voice.canListen) Voice.listen();
    }
    function openWith(text) { if (!open) { turns = []; open = true; Ai.prepare(); } say(text); }
    function close() {
        open = false;
        followUp = false;
        Voice.cancel();
        Voice.stop();
    }
    function toggle() { if (open && !Voice.listening) close(); else show(); }

    // Super+Alt+H: tap → listen till a pause; hold → push-to-talk
    property real pressedAt: 0
    function press() {
        pressedAt = Date.now();
        if (Voice.speaking) Voice.stop();
        if (!open || !Voice.listening) show();
    }
    function release() {
        if (Date.now() - pressedAt > 450 && Voice.listening) Voice.stopListening();
    }

    function update(fn) { const t = turns.slice(); const i = t.length - 1; if (i < 0) return; t[i] = Object.assign({}, t[i]); fn(t[i]); turns = t; }

    // ── one turn ──
    property bool byVoice: false        // this turn was spoken (answers are spoken back) — typed ones stay quiet
    function say(text, spoken) {
        byVoice = !!spoken;
        text = String(text ?? "").trim();
        if (!text) return;
        followUp = false;
        turns = turns.concat([{ you: text, answer: "", card: null, state: "thinking" }]).slice(-8);
        const l = text.toLowerCase().replace(/[.!?]+$/, "");
        if (/^(stop|cancel|never ?mind|that'?s all|that'?s it|no thanks|thanks?( you| a lot)?( halo)?|bye|goodbye|see you|ok(ay)? thanks?)$/.test(l)) {
            reply(["Anytime.", "Happy to help.", "Okay."][Math.floor(Math.random() * 3)], true);
            closeSoon.restart();
            return;
        }
        if (/^(repeat( that)?|say (that|it) again|what did you say|pardon|come again)$/.test(l)) {
            const prev = turns.slice(0, -1).reverse().find(t => t.answer);
            reply(prev ? prev.answer : "I haven't said anything yet.");
            return;
        }
        if (/^(louder|speak up)$/.test(l)) { reply("I can't change the volume of my voice, but you can turn the sound up."); return; }
        if (/^(slower|speak slower|talk slower)$/.test(l)) { Persist.data.haloVoiceRate = Math.max(0.7, (Persist.data.haloVoiceRate ?? 1) - 0.15); reply("Okay, slower."); return; }
        if (/^(faster|speak faster|talk faster)$/.test(l)) { Persist.data.haloVoiceRate = Math.min(1.5, (Persist.data.haloVoiceRate ?? 1) + 0.15); reply("Okay, faster."); return; }
        // Halo's own abilities answer in the sheet (Halo.say is routed here while it's open)
        if (Ai.configured && Agent.multi(text)) { Agent.start(text, "island"); watchAgent = true; return; }
        if (Halo.handle(text, "voice")) { settleTimer.restart(); return; }
        if (Ai.configured && Agent.wants(text)) { Agent.start(text, "island"); watchAgent = true; return; }
        if (!Ai.configured) { reply("I can do things like timers, reminders, your classes and settings — for anything else I need a model. Choose one in Settings → Halo."); return; }
        Halo.session = true;
        Halo.heard = text;
        Ai.send(text);
    }
    // a card from Halo while the sheet is open (Halo.say → here)
    function card(c) {
        if (!turns.length || last.state === "done" && last.card) turns = turns.concat([{ you: "", answer: "", card: null, state: "thinking" }]);
        update(t => { t.card = c; t.answer = [c.title, c.text].filter(x => x).join(". "); t.state = "done"; });
        afterAnswer(c.speak === false ? "" : (c.speak ?? [c.title, c.text].filter(x => x).join(". ")));
    }
    // a plain answer (the model, or a few words of Halo's)
    function reply(text, quick) {
        update(t => { t.answer = text; t.state = "done"; });
        afterAnswer(text, quick);
    }
    // Halo's own action that didn't say anything: "Done."
    Timer { id: settleTimer; interval: 900; onTriggered: if (root.last?.state === "thinking" && !Ai.busy && !Agent.running) root.reply("Done.") }
    Timer { id: closeSoon; interval: 1400; onTriggered: root.close() }

    // the model's answer (Halo.answered → here while the sheet is open)
    function answered(answer) { reply(answer); }
    // a job by the agent: its answer when it's done
    property bool watchAgent: false
    Connections {
        target: Agent
        function onRunsChanged() {
            if (!root.watchAgent || !root.open) return;
            const r = Agent.active;
            if (r?.state === "done" || r?.state === "stopped") { root.watchAgent = false; root.reply(r.answer || "Stopped."); }
        }
    }

    // ── after an answer: speak it, then listen for a follow-up ──
    function afterAnswer(spoken, quick) {
        if (!open) return;
        if (spoken && (Voice.wanted || byVoice)) Voice.say(spoken, true);     // you spoke: Halo speaks back
        if (!quick && byVoice) listenAfter.restart();
    }
    Timer {
        id: listenAfter
        interval: 700; repeat: true
        onTriggered: {
            if (!root.open || !root.conversational || !Voice.canListen) { stop(); return; }
            if (Voice.speaking || Voice.listening || Voice.transcribing) return;      // wait until Halo is done talking
            stop();
            root.followUp = true;
            Voice.listen();
        }
    }
    Connections {
        target: Voice
        function onHeard(text) { if (root.open) root.say(text, true); }
        function onMissed(why) {
            if (!root.open) return;
            if (why === "nothing" && root.followUp) { root.followUp = false; closeSoon.restart(); }
        }
    }

    IpcHandler {
        target: "converse"
        function open(): void { root.show(); }
        function close(): void { root.close(); }
        function press(): void { root.press(); }
        function release(): void { root.release(); }
        function say(text: string): void { root.openWith(text); }
        function state(): string { return JSON.stringify({ open: root.open, followUp: root.followUp, turns: root.turns.map(t => ({ you: t.you, answer: (t.answer ?? "").slice(0, 120), state: t.state })) }); }
    }
}
