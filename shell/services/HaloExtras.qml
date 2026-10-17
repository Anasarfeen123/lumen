pragma Singleton
// More things Halo does — each one small, local, and asked for in plain words:
//   web        "summarise https://…" · "read https://…"   (scripts/halo-web.py)
//   tidy       "tidy my downloads" → a plan by kind → Tidy · Undo   (halo-tidy.py)
//   repair     "fix my audio" (restart PipeWire / WirePlumber) · "what changed since yesterday"
//   battery    "what's draining my battery"
//   updates    "what's in the updates" — the ones that matter, in words
//   music      "play something for studying" (and focus, chill, sleep, workout…)
//   journal    "journal" — today's note with what happened and three prompts
//   breaks     after ~55 minutes at the screen: a short break, if you like
//   sharing    while your screen is shared, Halo keeps its cards to itself
//   lecture    "record the lecture" … "stop recording" → audio (+ transcript with whisper.cpp)
//   birthday   "my birthday is 12 March" — Halo dresses up that day
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string scripts: Theme.lumenRoot + "/scripts"
    function say(icon, title, text, extra) { Halo.say(Object.assign({ key: "extra", icon, title, text: text ?? "", level: "asked", duration: 12000 }, extra ?? {})); }
    function job(cmd, then) { const p = runner.createObject(root, { cb: then }); p.command = cmd; p.running = true; }
    Component {
        id: runner
        Process {
            id: rp
            property var cb: null
            stdout: StdioCollector { onStreamFinished: { const f = rp.cb; rp.cb = null; if (f) f(text); rp.destroy(); } }
        }
    }

    // ── what Halo understands here (from Halo.intent) ──
    function intent(q) {
        const l = q.toLowerCase().replace(/[?.!]+$/, "").trim();
        let m;
        if ((m = /^(?:summari[sz]e|read|explain|what does|tldr|tl;dr)\s+(?:this\s+)?(?:page\s+)?(https?:\/\/\S+)(?:\s+say)?$/i.exec(q)))
            return { glyph: "travel_explore", title: "Reading the page", own: () => root.readWeb(m[1]) };
        if (/^(tidy|clean|clean up|organi[sz]e|sort)( up)? (my |the )?downloads?( folder)?$/.test(l))
            return { glyph: "cleaning_services", title: "Tidying Downloads", own: () => root.tidyPlan() };
        if (/^undo (the |that )?tidy|^put (my )?downloads back$/.test(l))
            return { glyph: "undo", title: "Putting it back", own: () => root.tidyUndo() };
        if (/^(fix|repair|restart) (my |the )?(audio|sound|pipewire|wireplumber|speakers?|bluetooth audio)$/.test(l))
            return { glyph: "healing", title: "Restart the audio services", ask: true, run: () => root.restartAudio() };
        if (/^what('?s| has)? changed( since yesterday| recently| lately)?$|^what did the (last )?update change$/.test(l))
            return { glyph: "history", title: "What changed", own: () => root.whatChanged() };
        if (/^what('?s| is) (draining|eating|using) (my |the )?battery$|^battery (hogs|drain)$|^why is (my )?battery (draining|dying)( so fast)?$/.test(l))
            return { glyph: "battery_alert", title: "Battery", own: () => root.batteryCoach() };
        if (/^(what('?s| is) in|tell me about|explain) (the |my )?updates$|^should i update$|^any (important )?updates$/.test(l))
            return { glyph: "system_update", title: "Updates", own: () => root.updateButler() };
        if ((m = /^play (?:some(?:thing)?|music|songs?)(?: music)?(?: (?:for|to) )?(studying|study|focus|focusing|coding|code|chill|relaxing|relax|sleep|sleeping|workout|gym|running|happy|sad|party|rain|piano)?$/.exec(l)) && m[1])
            return { glyph: "queue_music", title: "Playing something for " + m[1], own: () => root.dj(m[1]) };
        if ((m = /^play (lofi|lo-fi|jazz|classical|ambient|synthwave|bollywood|tamil|telugu|hindi|k-?pop|rock|pop|edm|hip ?hop) ?(music|songs)?$/.exec(l)))
            return { glyph: "queue_music", title: "Playing " + m[1], own: () => root.dj(m[1]) };
        if (/^(journal|write (in )?my journal|open (my |today'?s )?journal|daily journal|diary)$/.test(l))
            return { glyph: "auto_stories", title: "Today's journal", own: () => root.journal() };
        if (/^(record|start recording) (the |this |my )?(lecture|class|lesson|talk|meeting)$/.test(l))
            return { glyph: "mic", title: "Recording the lecture", own: () => root.lectureStart() };
        if (/^stop (the )?(recording|lecture)( recording)?$/.test(l) && lecture.running)
            return { glyph: "stop_circle", title: "Stopped", own: () => root.lectureStop() };
        if ((m = /^my birthday is (?:on )?(\d{1,2})(?:st|nd|rd|th)? (jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*$/.exec(l))
            ?? (m = /^my birthday is (?:on )?(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w* (\d{1,2})(?:st|nd|rd|th)?$/.exec(l))) {
            const months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];
            const day = /^\d/.test(m[1]) ? +m[1] : +m[2], mon = months.indexOf(/^\d/.test(m[1]) ? m[2] : m[1]) + 1;
            return { glyph: "cake", title: "I'll remember your birthday", plain: true, run: () => { Persist.data.haloBirthday = (mon < 10 ? "0" : "") + mon + "-" + (day < 10 ? "0" : "") + day; } };
        }
        return null;
    }

    // ── web ──
    function readWeb(url, then) {
        job([scripts + "/halo-web.py", "read", url], out => {
            let d = {}; try { d = JSON.parse(out); } catch (e) { d = { error: "Couldn't read it." }; }
            if (then) { then(d); return; }
            if (d.error) { say("public_off", "I couldn't read that page", d.error, { tone: "concerned" }); return; }
            if (!Ai.configured) { say("article", d.title || url, d.text.slice(0, 300) + "…"); return; }
            Ai.show();
            Ai.askWith("Summarise " + (d.title || url), "Summarise this web page in a few bullet points, then one line on what matters for me.\n\nPage: " + d.title + " (" + d.url + ")\n\n" + d.text, ["web"]);
        });
    }

    // ── tidy ──
    property var lastPlan: null
    function tidyPlan() {
        job([scripts + "/halo-tidy.py", "plan"], out => {
            let p = null; try { p = JSON.parse(out); } catch (e) {}
            if (!p || !p.moves.length) { say("cleaning_services", "Downloads is already tidy", "Nothing to sort (files from the last 10 minutes stay put)."); return; }
            lastPlan = p;
            const kinds = Object.keys(p.counts).sort((a, b) => p.counts[b] - p.counts[a]);
            say("cleaning_services", "Tidy " + p.moves.length + " files in Downloads?", kinds.map(k => k + " " + p.counts[k]).join(" · ") + "\nInto folders by kind. Nothing is deleted, and Undo puts it all back.",
                { duration: 20000, actions: [{ label: "Tidy them", icon: "check", run: () => root.tidyApply() }, { label: "Not now", icon: "close", run: () => {} }] });
        });
    }
    function tidyApply() {
        if (!lastPlan) return;
        planFile.setText(JSON.stringify(lastPlan));
        job([scripts + "/halo-tidy.py", "apply", planFile.path], out => {
            let r = {}; try { r = JSON.parse(out); } catch (e) {}
            say("task_alt", "Tidied " + (r.done ?? 0) + " files", (r.skipped ? r.skipped + " had moved already. " : "") + "Into Documents, Images, Archives…", { tone: "happy",
                actions: [{ label: "Undo", icon: "undo", run: () => root.tidyUndo() }, { label: "Open Downloads", icon: "folder_open", run: () => Qt.openUrlExternally("file://" + root.lastPlan.dir) }] });
        });
    }
    FileView { id: planFile; path: Ai.runDir + "/tidy-plan.json"; blockWrites: true; printErrors: false }
    function tidyUndo() {
        job([scripts + "/halo-tidy.py", "undo"], out => {
            let r = {}; try { r = JSON.parse(out); } catch (e) {}
            say("undo", r.error ? "Nothing to undo" : "Put " + (r.done ?? 0) + " files back", r.error ?? "");
        });
    }

    // ── repair ──
    readonly property var units: ({ wireplumber: "wireplumber.service", pipewire: "pipewire.service", "pipewire-pulse": "pipewire-pulse.service", "xdg-desktop-portal": "xdg-desktop-portal.service" })
    function restartUnit(unit, then) { job(["systemctl", "--user", "restart", unit], () => { if (then) then(); }); }
    function restartAudio() {
        job(["systemctl", "--user", "restart", "wireplumber.service", "pipewire.service", "pipewire-pulse.service"],
            () => say("healing", "Audio restarted", "PipeWire and WirePlumber are fresh. Bluetooth headphones may need a moment to reconnect.", { tone: "happy" }));
    }
    function whatChanged() {
        job(["sh", "-c", 'dnf -q history list 2>/dev/null | sed -n "2,6p"; echo "@@"; git -C "$1" log --since=yesterday --pretty="%s" 2>/dev/null; echo "@@"; '
             + 'journalctl --user -p err --since yesterday -q --no-pager -o json 2>/dev/null | jq -r ".SYSLOG_IDENTIFIER // ._COMM // empty" | sort | uniq -c | sort -rn | head -4', "sh", Theme.lumenRoot], out => {
            const [dnf, lumen, errs] = out.split("@@").map(x => x.trim());
            const lines = [];
            const since = Date.now() - 2 * 86400000;
            const tx = (dnf ? dnf.split("\n") : []).map(l => {
                const d = /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2})/.exec(l), n = /(\d+)\s*$/.exec(l), what = /\b(upgrade|install|remove|reinstall|downgrade|update)\b/.exec(l);
                return d ? { when: new Date(d[1] + "T" + d[2]), n: n ? +n[1] : 0, what: what ? what[1] : "change" } : null;
            }).filter(t => t && t.when.getTime() > since);
            if (tx.length) lines.push("Packages: " + tx.map(t => Qt.formatDateTime(t.when, "d MMM h:mm AP") + " — " + t.what + " (" + t.n + (t.n === 1 ? " package" : " packages") + ")").join("; "));
            const commits = lumen ? lumen.split("\n").filter(x => x) : [];
            if (commits.length) lines.push("Lumen: " + commits.length + (commits.length === 1 ? " change" : " changes") + " — " + commits.slice(0, 2).map(c => c.replace(/:.*$/, "")).join(", ") + (commits.length > 2 ? "…" : ""));
            const er = errs ? errs.split("\n").map(l => l.trim().split(/\s+/)).filter(x => x.length === 2).map(([n, w]) => w + " ×" + n) : [];
            if (er.length) lines.push("Errors logged: " + er.join(", "));
            say("history", "Since yesterday", lines.join("\n") || "Nothing changed — no updates, no Lumen changes, no errors.", { duration: 16000,
                actions: er.some(e => /pipewire|wireplumber/.test(e)) ? [{ label: "Fix my audio", icon: "healing", run: () => root.restartAudio() }] : [] });
        });
    }

    // a check that's still running answers by itself when it's done
    property bool coachWaiting: false
    property bool updatesWaiting: false
    Connections { target: Doctor; function onLastChanged() { if (root.coachWaiting) { root.coachWaiting = false; root.batteryCoach(); } } }
    Connections { target: Updates; function onCheckedAtChanged() { if (root.updatesWaiting) { root.updatesWaiting = false; root.updateButler(); } } }

    // ── battery coach ──
    function batteryCoach() {
        const d = Doctor.last;
        if (!Battery.available) { say("power", "No battery here", ""); return; }
        if (!d || Date.now() - (d.t ?? 0) > 5 * 60000) { coachWaiting = true; Doctor.look(); say("hourglass_top", "Taking a look…", "", { duration: 3000, speak: false }); return; }
        const apps = (d.apps ?? []).filter(g => g.cores > 0.05 && !Doctor.exempt.test(g.name)).slice(0, 4);
        const total = apps.reduce((n, g) => n + g.cores, 0) || 1;
        const fast = Battery.usualRate > 0 && Battery.ratePerHour > 1.3 * Battery.usualRate;
        say("battery_alert", Battery.pluggedIn ? "On the charger now" : (fast ? "Draining faster than usual" : "Draining normally") + (Battery.forecastText ? " · " + Battery.forecastText + " left" : ""),
            (apps.length ? apps.map(g => g.name + " — " + Math.round(100 * g.cores / total) + "% of the work" + (g.tabs > 1 ? " (" + g.tabs + " tabs)" : "")).join("\n") : "Nothing's working hard.")
            + (Power.saver || Battery.pluggedIn ? "" : "\nBattery saver would stretch it."),
            { actions: [Power.saver || Battery.pluggedIn ? null : { label: "Battery saver", icon: "energy_savings_leaf", run: () => Power.saverOn() },
                        apps[0]?.window ? { label: "Close " + apps[0].name, icon: "close", run: () => Quickshell.execDetached([root.scripts + "/monitor.py", "signal", String(apps[0].pid), "TERM", "--tree"]) } : null].filter(a => a) });
    }

    // ── update butler ──
    readonly property var notable: [
        [/^kernel(-core)?$/, "a new kernel (needs a restart)"], [/^mesa/, "graphics drivers"], [/nvidia/, "the NVIDIA driver (needs a restart)"],
        [/^pipewire$/, "PipeWire (audio)"], [/^wireplumber$/, "WirePlumber (audio)"], [/^hyprland$/, "Hyprland (your compositor)"],
        [/^systemd$/, "systemd (needs a restart)"], [/^glibc$/, "the C library (needs a restart)"], [/^(firefox|brave.*|chromium)$/, "your browser"],
        [/^bluez$/, "Bluetooth"], [/^NetworkManager/, "networking"], [/^quickshell$/, "Quickshell (Lumen's shell)"], [/^ollama$/, "Ollama (local AI)"]]
    function updateButler() {
        if (!Updates.checkedAt) { updatesWaiting = true; Updates.check(); say("hourglass_top", "Checking for updates…", "I'll tell you in a moment.", { duration: 4000, speak: false }); return; }
        if (!Updates.count) { say("verified", "Everything's up to date", "Checked " + Qt.formatTime(new Date(Updates.checkedAt), "h:mm AP") + ".", { tone: "happy" }); return; }
        const hits = [];
        for (const p of Updates.dnf) for (const [re, what] of notable) if (re.test(p.name) && !hits.some(h => h.what === what)) hits.push({ what, p });
        const crashedAudio = Object.keys(Doctor.crashCount ?? {}).some(k => /wireplumber|pipewire/.test(k));
        say("system_update", Updates.count + (Updates.count === 1 ? " update" : " updates") + (Updates.security ? " · " + Updates.security + " security" : ""),
            (hits.length ? hits.map(h => "• " + h.what + " " + h.p.version + (crashedAudio && /audio/.test(h.what) ? " — may fix today's audio crashes" : "")).join("\n") : "Routine fixes, nothing big.")
            + (Updates.reboot ? "\nA restart will be needed afterwards." : ""),
            { duration: 18000, actions: [{ label: "Open Updates", icon: "system_update", run: () => SettingsState.launch("updates") }] });
    }

    // ── music ──
    readonly property var moods: ({ studying: "lofi study beats", study: "lofi study beats", focus: "deep focus instrumental", focusing: "deep focus instrumental",
        coding: "synthwave coding music", code: "synthwave coding music", chill: "chill vibes", relaxing: "relaxing music", relax: "relaxing music",
        sleep: "sleep ambient music", sleeping: "sleep ambient music", workout: "workout hits", gym: "gym workout music", running: "running music",
        happy: "feel good hits", sad: "sad songs", party: "party hits", rain: "rain sounds lofi", piano: "calm piano" })
    function dj(mood) {
        const q = moods[mood] ?? (mood + " music");
        const app = Persist.data.musicApp ?? "auto";
        Qt.openUrlExternally(app === "spotify" ? "spotify:search:" + encodeURIComponent(q) : "https://music.youtube.com/search?q=" + encodeURIComponent(q));
        say("queue_music", "Something for " + mood, "“" + q + "” on " + (app === "spotify" ? "Spotify" : "YouTube Music") + " — pick one and press play.", { tone: "happy", duration: 6000, speak: false });
    }

    // ── journal ──
    function journal() {
        const now = new Date(), st = ScreenTime.data ?? {};
        const top = Object.keys(st.apps ?? {}).sort((a, b) => st.apps[b] - st.apps[a]).slice(0, 3).map(id => ScreenTime.nameOf(id));
        const classes = HaloCollege.on ? Amazecc.today.map(c => c.title).join(", ") : "";
        const facts = ["Screen time: " + (st.total ? ScreenTime.fmt(st.total) : "—") + (top.length ? " (" + top.join(", ") + ")" : ""),
                       st.rounds ? "Focus rounds: " + st.rounds : "", classes ? "Classes: " + classes : ""].filter(x => x);
        const body = "_" + facts.join(" · ") + "_\n\n## What went well\n\n\n## What was hard\n\n\n## Tomorrow I'll\n\n";
        job(["sh", "-c", 'f=$("$1" --dir "$2" new "$3") && printf "%s\\n" "$4" >> "$2/$f" && echo "$f"', "sh", scripts + "/notes.py", Notes.dir,
             "Journal — " + Qt.formatDate(now, "ddd d MMM yyyy"), body], out => {
            const f = out.trim();
            if (!f) { say("error", "Couldn't start the journal", ""); return; }
            Notes.refresh();
            Notes.launch(f);
        });
    }

    // ── breaks: about an hour at the screen, then a nudge ──
    property int activeMin: 0
    property int idleMin: 0
    property real snoozeUntil: 0
    Timer {
        interval: 60000; repeat: true
        running: Persist.automates && (Persist.data.haloBreaks ?? true)
        onTriggered: {
            if (ScreenTime.counting) { root.activeMin++; root.idleMin = 0; }
            else if (++root.idleMin >= 5) root.activeMin = 0;           // a real break resets it
            if (root.activeMin < 55 || Date.now() < root.snoozeUntil || Countdown.active || Halo.quiet) return;
            root.activeMin = 0;
            Halo.say({ key: "break", icon: "self_improvement", title: "Time for a short break?", text: "About an hour at the screen. Stand up, stretch, look far away, drink some water.",
                       level: "important", duration: 15000, tone: "normal",
                       actions: [{ label: "5-minute break", icon: "timer", run: () => Countdown.startTimer(5 * 60000, "Break") },
                                 { label: "In 20 minutes", icon: "snooze", run: () => { root.snoozeUntil = Date.now() + 20 * 60000; root.activeMin = 35; } }] });
        }
    }

    // ── sharing your screen: Halo keeps its cards to itself ──
    property bool sharing: false
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "screencast") root.sharing = ev.data.startsWith("1"); }
    }

    // ── wardrobe: headphones with music, a hat on your birthday, a scarf in winter ──
    SystemClock { id: clock; precision: SystemClock.Hours }
    property string devWear: ""            // LUMEN_DEV: try one on
    readonly property string accessory: devWear !== "" ? (devWear === "none" ? "" : devWear)
        : Qt.formatDate(clock.date, "MM-dd") === (Persist.data.haloBirthday ?? "") ? "party"
        : Media.playing ? "headphones"
        : (clock.date.getMonth() === 11 || clock.date.getMonth() === 0) ? "scarf" : ""
    Timer {        // happy birthday, once, in the morning
        interval: 600000; repeat: true; triggeredOnStart: true
        running: Persist.automates && !!Persist.data.haloBirthday
        onTriggered: {
            const k = Qt.formatDate(new Date(), "yyyy-MM-dd");
            if (root.accessory !== "party" || Persist.data.haloLastBirthday === k || new Date().getHours() < 8) return;
            Persist.data.haloLastBirthday = k;
            Halo.say({ key: "birthday", icon: "cake", title: "Happy birthday" + (Halo.you ? ", " + Halo.you : "") + "!", text: "Hope it's a great one. 🎂", level: "important", tone: "happy", duration: 15000 });
        }
    }

    // ── lecture recording (with whisper.cpp: a transcript and notes too) ──
    property var lecture: ({ running: false, file: "", started: 0 })
    function lectureStart() {
        if (lecture.running) { say("mic", "Already recording", ""); return; }
        const dir = (Quickshell.env("XDG_MUSIC_DIR") || Quickshell.env("HOME") + "/Music") + "/Lectures";
        const name = (HaloCollege.on && Amazecc.current ? Amazecc.current.title + " " : "Lecture ") + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH.mm");
        const file = dir + "/" + name.replace(/[\/\\:]/g, "-") + ".opus";
        lecture = { running: true, file, started: Date.now() };
        recorder.command = ["sh", "-c", 'mkdir -p "$1" && exec ffmpeg -hide_banner -loglevel error -f pulse -i default -ac 1 -ar 16000 -c:a libopus -b:a 24k -y "$2"', "sh", dir, file];
        recorder.running = true;
        Halo.say({ key: "lecture", icon: "mic", title: "Recording the lecture", text: "Make sure recording is allowed. Say “stop recording” or press Stop.", level: "asked", duration: 8000,
                   actions: [{ label: "Stop", icon: "stop_circle", run: () => root.lectureStop() }] });
    }
    Process { id: recorder }
    function lectureStop() {
        if (!lecture.running) return;
        recorder.signal(2);                 // ffmpeg finishes the file on SIGINT
        const L = lecture;
        lecture = { running: false, file: L.file, started: L.started };
        const mins = Math.round((Date.now() - L.started) / 60000);
        Halo.say({ key: "lecture", icon: "graphic_eq", title: "Saved the lecture (" + mins + " min)", text: L.file.replace(Quickshell.env("HOME"), "~"), level: "asked", duration: 15000,
                   actions: [Voice.canListen ? { label: "Transcribe to notes", icon: "description", run: () => root.transcribe(L.file) } : null,
                             { label: "Show in folder", icon: "folder_open", run: () => Qt.openUrlExternally("file://" + L.file.replace(/\/[^\/]*$/, "")) }].filter(a => a) });
    }
    function transcribe(file) {
        say("hourglass_top", "Transcribing…", "This takes a few minutes for an hour of audio. I'll put it in Notes.", { duration: 6000 });
        job([scripts + "/halo-voice.py", "transcribe", file], out => {
            const t = out.trim();
            if (!t) { say("error", "Couldn't transcribe it", "Is whisper.cpp set up? (Settings → Halo → Voice)", { tone: "concerned" }); return; }
            const title = "Transcript — " + file.replace(/.*\//, "").replace(/\.opus$/, "");
            job(["sh", "-c", 'f=$("$1" --dir "$2" new "$3") && printf "%s\\n" "$4" >> "$2/$f" && echo "$f"', "sh", scripts + "/notes.py", Notes.dir, title, t], f => {
                Notes.refresh();
                say("description", "Transcript in Notes", title, { tone: "happy", actions: [
                    { label: "Open", icon: "open_in_new", run: () => Notes.launch(f.trim()) },
                    Ai.configured ? { label: "Make study notes", icon: "auto_awesome", run: () => { Ai.files = [Notes.pathOf(f.trim())]; Ai.show(); Ai.send("Turn this lecture transcript into clear study notes: key ideas, definitions, examples, and 5 revision questions."); } } : null].filter(a => a) });
            });
        });
    }

    IpcHandler {
        target: "extras"
        function tidy(): void { root.tidyPlan(); }
        function web(url: string): void { root.readWeb(url); }
        function coach(): void { root.batteryCoach(); }
        function updates(): void { root.updateButler(); }
        function wear(a: string): void { if (Quickshell.env("LUMEN_DEV") === "1") root.devWear = a; }
        function state(): string { return JSON.stringify({ sharing: root.sharing, accessory: root.accessory, activeMin: root.activeMin, lecture: root.lecture }); }
    }
}
