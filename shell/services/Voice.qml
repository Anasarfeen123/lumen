pragma Singleton
// Halo's ears and voice (scripts/halo-voice.py). Offline only: whisper.cpp
// hears, Piper or espeak-ng speaks. Nothing listens until you ask — there is
// no wake word: press the talk key (Super+Alt+H) or the mic in Halo.
//   listen() / stopListening() (use what was said) / cancel()
//   say(text)   spoken only if Settings → Halo → "Speak replies" allows it
//               (on · only with headphones), never during a call
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/halo-voice.py"

    property var status: ({ tts: "", stt: false })
    function refresh() { if (!statusProc.running) statusProc.running = true; }
    Process {
        id: statusProc
        running: true
        command: [root.script, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(text); } catch (e) {} } }
    }
    readonly property bool canListen: status.stt === true
    readonly property bool canSpeak: (status.tts ?? "") !== ""

    // ── listening ──
    property bool listening: false
    property bool transcribing: false
    property bool heardSpeech: false
    property real level: 0
    signal heard(string text)
    signal missed(string why)           // "nothing" | "cancelled" | "no-stt" | an error
    function listen() {
        if (listening || transcribing) return;
        if (!canListen) { refresh(); missed("no-stt"); return; }
        stop();
        level = 0; heardSpeech = false;
        listening = true;
        ear.running = true;
    }
    function stopListening() { if (ear.running && listening) ear.signal(15); }
    function cancel() { if (ear.running) ear.signal(2); }
    function toggle() { if (listening) stopListening(); else listen(); }
    Process {
        id: ear
        command: [root.script, "listen", "--max", "20"]
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.level !== undefined) root.level = d.level;
                else if (d.speech) root.heardSpeech = true;
                else if (d.state === "transcribing") { root.listening = false; root.transcribing = true; root.level = 0; }
                else if (d.heard !== undefined) { root.transcribing = false; root.heard(d.heard); }
                else if (d.error) { root.listening = false; root.transcribing = false; root.missed(d.error); }
            }
        }
        onExited: { root.listening = false; root.transcribing = false; root.level = 0; }
    }

    // ── speaking ──
    readonly property bool headphones: /bluez|headphone|headset|buds|airpods|\bwh-|\bwf-|earphone/i.test((Audio.sink?.name ?? "") + " " + Audio.deviceName)
    readonly property bool wanted: {
        const v = Persist.data.haloVoice ?? "off";
        return v === "on" || (v === "headphones" && headphones);
    }
    readonly property bool speaking: mouth.running
    // Markdown, code and links don't read well aloud: the first few sentences, plain
    function speakable(t) {
        t = (t ?? "").replace(/```[\s\S]*?```/g, " (there's code on screen) ").replace(/`([^`]*)`/g, "$1")
                     .replace(/!\[[^\]]*\]\([^)]*\)/g, "").replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
                     .replace(/^#+\s*/gm, "").replace(/[*_~>|#]/g, "").replace(/^\s*[-•]\s+/gm, "").replace(/https?:\/\/\S+/g, "a link")
                     .replace(/\s+/g, " ").trim();
        const s = t.match(/[^.!?]+[.!?]+/g) ?? [t];
        let outText = "";
        for (const x of s) { if ((outText + x).length > 320 && outText) break; outText += x; }
        return outText.trim();
    }
    function say(text, force) {
        if (!(wanted || force) || !canSpeak || Meeting.live || Audio.muted) return;
        const t = speakable(text);
        if (!t) return;
        mouth.running = false;
        mouth.command = [script, "say", String(Persist.data.haloVoiceRate ?? 1), Halo.character === "jarvis" ? "uk" : "us", t];
        mouth.running = true;
    }
    function stop() { if (mouth.running) mouth.running = false; }
    Process { id: mouth }

    IpcHandler {
        target: "voice"
        function talk(): void { Halo.talk(); }
        function stop(): void { root.stopListening(); root.stop(); }
        function say(text: string): void { root.say(text, true); }
        function state(): string { return JSON.stringify({ status: root.status, listening: root.listening, speaking: root.speaking, headphones: root.headphones }); }
    }
}
