pragma Singleton
// Halo from your phone, through Lumen Link (KDE Connect) — nothing new on the
// phone and no change to KDE Connect's own settings:
//   on the phone, share (or copy, with clipboard sync on) a line that starts
//   with "Halo" — "Halo, what's my next class?" — and the answer comes back
//   as a notification on the phone a moment later.
// Halo's own abilities answer at once; anything else goes to Halo's model
// (one short answer, nothing remembered). Things that would need your OK on
// the laptop (clicks, typing, commands) are not done from the phone.
// And the other way: "send that to my phone" sends Halo's last answer.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property var pattern: /^\s*(?:hey\s+|ok(?:ay)?\s+)?halo[\s,:.!-]+(.{2,400})$/i
    function wants(text) { return pattern.test(text); }

    function ask(text) {
        const m = pattern.exec(text);
        if (!m) return;
        const q = m[1].trim();
        const it = Halo.intent(q);
        if (it && !it.ask && !/^(ads_click|keyboard|near_me|south|north)$/.test(it.glyph ?? "")) {
            let said = null;
            Halo.capture = c => said = c;
            try { if (it.own) it.own(); else if (!it.already) it.run(); } finally { Halo.capture = null; }
            const reply = said ? [said.title, said.text].filter(x => x).join(" — ") : (it.already ? it.title : Halo.done(it.doneTitle ?? it.title));
            send(reply);
            Island.system("phone_android", "From your phone: " + q, reply.slice(0, 60));
            return;
        }
        if (it?.ask) { send("That needs your OK on the laptop — I've left it there."); Halo.handle(q, "island"); return; }
        if (!Ai.configured) { send("I can do timers, reminders, your classes and settings from here; for other questions choose a model in Settings → Halo."); return; }
        // one short answer from the model, quietly
        reqFile.setText(JSON.stringify({ provider: Ai.provider, model: Ai.model,
            system: Ai.system + "\nYou're answering on the user's phone: reply in 1-3 short sentences, plain text, no Markdown.",
            messages: [{ role: "user", text: q }] }));
        brain.buf = ""; brain.q = q;
        brain.command = [Theme.lumenRoot + "/scripts/ai.sh", "ask", reqFile.path];
        brain.running = true;
        Island.system("phone_android", "From your phone: " + q, "Thinking…");
    }
    FileView { id: reqFile; path: Ai.runDir + "/phone.json"; blockWrites: true; printErrors: false }
    Process {
        id: brain
        property string buf: ""
        property string q: ""
        stdout: SplitParser { onRead: line => { try { const d = JSON.parse(line); if (d.t) brain.buf += d.t; else if (d.e) brain.buf = "Sorry — " + d.e; } catch (e) {} } }
        onExited: root.send(Voice.speakable(brain.buf) || brain.buf.trim() || "Sorry, I couldn't answer that.")
    }
    function send(text) { Link.notify("Halo: " + String(text).replace(/\s+/g, " ").slice(0, 380)); }

    // Halo's last words → the phone
    function lastAnswer() {
        const m = Ai.messages.slice().reverse().find(x => x.role === "assistant" && (x.text || x.card));
        if (m?.text) return m.text;
        if (m?.card) return [m.card.title, m.card.text].filter(x => x).join(" — ");
        const c = Halo.log[Halo.log.length - 1];
        return c ? [c.title, c.text].filter(x => x).join(" — ") : "";
    }
}
