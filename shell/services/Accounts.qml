pragma Singleton
// Your calendars and inbox, for Halo — read-only, set up in Settings → Halo:
//   calendars   iCal links (Google Calendar's secret address, Outlook, college…)
//               → events in the planner's agenda, briefs, "what's on tomorrow",
//               and the agent's calendar tool (scripts/halo-ics.py, every 30 min)
//   email       IMAP with an app password → "any new emails?", "emails from
//               Arya", a quiet card when something new arrives, the count in
//               "while you were away". Headers only, nothing marked read.
//               "email arya@… about the lab report" opens Gmail's compose page
//               filled in — you press Send (scripts/halo-mail.py)
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property string scripts: Theme.lumenRoot + "/scripts"
    readonly property bool active: Persist.automates || dev
    property bool dev: false

    // ── calendars ──
    property var calendars: []          // [{ name, host }]
    property var events: []             // [{ title, when, end, allDay, location, calendar, external, source }]
    property string calError: ""
    function refreshCalendars() { if (!calList.running) calList.running = true; }
    Process { id: calList; running: true; command: [root.scripts + "/halo-ics.py", "list"]
              stdout: StdioCollector { onStreamFinished: { try { root.calendars = JSON.parse(text); } catch (e) {} if (root.calendars.length) root.fetchEvents(); else root.events = []; } } }
    function fetchEvents() { if (!calEvents.running) calEvents.running = true; }
    Process {
        id: calEvents
        command: [root.scripts + "/halo-ics.py", "events", "30"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = []; try { d = JSON.parse(text); } catch (e) { return; }
                root.calError = d.filter(x => x.error).map(x => x.error).join("; ");
                root.events = d.filter(x => !x.error).map(e => Object.assign({ external: true, source: "calendar" }, e));
            }
        }
    }
    Timer { interval: 30 * 60000; repeat: true; running: root.calendars.length > 0; onTriggered: root.fetchEvents() }
    function addCalendar(name, url, then) {
        job([scripts + "/halo-ics.py", "add", name.trim() || "Calendar", url.trim()], out => { let r = {}; try { r = JSON.parse(out); } catch (e) {} refreshCalendars(); if (then) then(r); });
    }
    function removeCalendar(name) { job([scripts + "/halo-ics.py", "remove", name], () => refreshCalendars()); }

    // ── email ──
    property var mail: ({ configured: false, user: "", host: "" })
    property var unread: []
    property string mailError: ""
    property var seenUids: []
    function refreshMail() { if (!mailStatus.running) mailStatus.running = true; }
    Process { id: mailStatus; running: true; command: [root.scripts + "/halo-mail.py", "status"]
              stdout: StdioCollector { onStreamFinished: { try { root.mail = JSON.parse(text); } catch (e) {} if (root.mail.configured) root.checkMail(); } } }
    function checkMail() { if (mail.configured && !mailCheck.running) mailCheck.running = true; }
    Process {
        id: mailCheck
        command: [root.scripts + "/halo-mail.py", "unread", "25"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d = []; try { d = JSON.parse(text); } catch (e) { return; }
                if (!Array.isArray(d)) { root.mailError = d.error ?? ""; return; }
                root.mailError = "";
                const fresh = root.seenUids.length ? d.filter(m => !root.seenUids.includes(m.uid)) : [];
                root.unread = d;
                root.seenUids = d.map(m => m.uid).concat(root.seenUids).slice(0, 200);
                if (fresh.length && root.active)
                    Halo.say({ key: "mail", icon: "mail", title: fresh.length === 1 ? "Email from " + fresh[0].from : fresh.length + " new emails",
                               text: fresh.slice(0, 4).map(m => (fresh.length > 1 ? m.from + ": " : "") + m.subject).join("\n"), level: "chatter", duration: 9000,
                               actions: [{ label: "Open Gmail", icon: "open_in_new", run: () => root.openInbox() }] });
            }
        }
    }
    Timer { interval: 10 * 60000; repeat: true; running: root.mail.configured && root.active; onTriggered: root.checkMail() }
    function setMail(host, user, password, then) {
        const p = mailSet;
        p.cb = then;
        p.command = [scripts + "/halo-mail.py", "set", host.trim() || "imap.gmail.com", user.trim()];
        p.pw = password;
        p.running = true;
    }
    Process {
        id: mailSet
        property var cb: null
        property string pw: ""
        stdinEnabled: true
        onStarted: { write(pw + "\n"); pw = ""; }
        stdout: StdioCollector { onStreamFinished: { let r = {}; try { r = JSON.parse(text); } catch (e) {} const f = mailSet.cb; mailSet.cb = null; root.refreshMail(); if (f) f(r); } }
    }
    function removeMail() { job([scripts + "/halo-mail.py", "remove"], () => { unread = []; refreshMail(); }); }
    function openInbox() { Qt.openUrlExternally(/gmail/.test(mail.host) ? "https://mail.google.com/mail/u/0/#inbox" : "mailto:"); }
    // a draft in your mail, to send yourself
    function compose(to, subject, body) {
        if (/gmail/.test(mail.host) || !mail.configured)
            Qt.openUrlExternally("https://mail.google.com/mail/?view=cm&fs=1&to=" + encodeURIComponent(to) + "&su=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body));
        else Qt.openUrlExternally("mailto:" + encodeURIComponent(to) + "?subject=" + encodeURIComponent(subject) + "&body=" + encodeURIComponent(body));
    }

    function job(cmd, then) { const p = runner.createObject(root, { cb: then }); p.command = cmd; p.running = true; }
    Component { id: runner; Process { id: rp; property var cb: null; stdout: StdioCollector { onStreamFinished: { const f = rp.cb; rp.cb = null; if (f) f(text); rp.destroy(); } } } }

    // ── what Halo understands here ──
    function intent(q) {
        const l = q.toLowerCase().replace(/[?.!]+$/, "").trim();
        let m;
        if (/^(any (new )?(e-?mails?|mail)|check (my )?(e-?mail|mail|inbox)|(do i have|have i got) (any )?(new )?(e-?mails?|mail)|my (e-?mails?|inbox)|unread (e-?mails?|mail))$/.test(l)) {
            if (!mail.configured) return { glyph: "mail", title: "Email isn't set up", own: () => Halo.say({ key: "mail", icon: "mail", title: "Email isn't set up", text: "Add your inbox in Settings → Halo → Calendar & email (read-only, with an app password).", level: "asked", actions: [{ label: "Set it up", icon: "settings", run: () => SettingsState.launch("ai") }] }) };
            return { glyph: "mail", title: "Your inbox", own: () => { checkMail(); Halo.say({ key: "mail", icon: "mail", title: unread.length ? unread.length + " unread" : "No unread email",
                text: unread.slice(0, 6).map(m => m.from + ": " + m.subject).join("\n"), level: "asked", duration: 14000,
                actions: [{ label: "Open Gmail", icon: "open_in_new", run: () => root.openInbox() }].concat(unread.length > 2 && Ai.configured ? [{ label: "Summarise", icon: "auto_awesome", run: () => root.summariseMail() }] : []) }); } };
        }
        if ((m = /^(?:any )?(?:e-?mails?|mail) from (.+)$/.exec(l)) && mail.configured) {
            const who = m[1].trim();
            const hits = unread.filter(x => (x.from + " " + x.email).toLowerCase().includes(who));
            return { glyph: "mail", title: "Email from " + who, own: () => Halo.say({ key: "mail", icon: "mail", title: hits.length ? hits.length + " unread from " + who : "Nothing unread from " + who,
                     text: hits.map(x => x.subject).join("\n"), level: "asked" }) };
        }
        if (/^summari[sz]e my (e-?mails?|inbox)$/.test(l) && mail.configured) return { glyph: "auto_awesome", title: "Summarising", own: () => root.summariseMail() };
        if ((m = /^(?:e-?mail|write an e-?mail to|draft an e-?mail to|mail) (\S+@\S+|[\w .'-]+?)(?: (?:about|saying|re|regarding) (.+))?$/i.exec(q)) && !/^(e-?mails?|mail) from/i.test(q)) {
            const to = m[1].trim(), about = (m[2] ?? "").trim();
            const addr = /@/.test(to) ? to : (unread.find(x => x.from.toLowerCase().includes(to.toLowerCase()))?.email ?? "");
            return { glyph: "edit", title: "A draft to " + to, own: () => {
                compose(addr, about ? about.charAt(0).toUpperCase() + about.slice(1) : "", "");
                Halo.say({ key: "mail", icon: "edit", title: "Draft opened" + (addr ? " to " + addr : ""), text: addr ? "Write it and press Send — I never send mail myself." : "I don't know " + to + "'s address — add it in the draft.", level: "asked", duration: 6000 });
            } };
        }
        if (/^(what'?s|what is) (on )?(my calendar|on) (today|tomorrow)$|^(what'?s|anything) (on )?tomorrow$|^my (schedule|calendar)( today| tomorrow)?$/.test(l) && events.length) {
            const tomorrow = /tomorrow/.test(l);
            const day = new Date(); day.setHours(0, 0, 0, 0); if (tomorrow) day.setDate(day.getDate() + 1);
            const list = (Planner.upcoming ?? []).filter(e => e.when >= day.getTime() && e.when < day.getTime() + 86400000);
            return { glyph: "event_note", title: tomorrow ? "Tomorrow" : "Today", own: () => Halo.say({ key: "calendar", icon: "event_note", title: (tomorrow ? "Tomorrow" : "Today") + ": " + (list.length ? list.length + (list.length === 1 ? " thing" : " things") : "nothing on the calendar"),
                     text: list.map(e => (e.allDay ? "All day" : Qt.formatTime(new Date(e.when), Theme.timeFormatFull)) + " — " + e.title + (e.location ? " · " + e.location : "")).join("\n"), level: "asked", duration: 14000 }) };
        }
        return null;
    }
    function summariseMail() {
        Ai.show();
        Ai.askWith("Summarise my unread email", "Here are my unread emails (sender and subject only). Group them: what needs a reply or action first, then the rest in a line.\n\n"
                   + unread.map(m => "- " + m.from + " <" + m.email + ">: " + m.subject).join("\n"), ["mail"]);
    }
}
