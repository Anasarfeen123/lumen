pragma Singleton
// The left sidebar's data: to-dos, agenda events and a scratchpad note.
// Stored in ~/.local/state/lumen/planner.json and notes.md (plain files you
// can read or back up). Events get an island reminder 10 minutes before.
//
// Quick event entry understands:  [day] [time] title
//   day   today · tomorrow · mon…sun (next one) · 2026-10-02 · 2/10 (d/m)
//   time  18:00 · 9:30 · 6pm · 9.30am        e.g. "fri 6pm Gym", "tomorrow 9:30 Standup"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool open: false
    function toggle() { open = !open; }
    GlobalShortcut { appid: "lumen"; name: "planner"; description: "Your day: weather, agenda, to-dos, notes"; onPressed: root.toggle() }
    // Dev only (LUMEN_DEV)
    IpcHandler {
        target: "plannerTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function event(t: string): string { return root.addEvent(t) ? "added" : "unparsed"; }
        function parse(t: string): string { const e = root.parse(t); return e ? e.title + " @ " + new Date(e.when).toString() : "null"; }
        function todo(t: string): void { root.addTodo(t); }
        function reset(): void { data.todos = []; data.events = []; }
        function place(q: string): void { Weather.setPlace(q); }
        function noPlace(): void { Weather.clearPlace(); }
        function sunInfo(): string { return Sun.phase + " rise " + Qt.formatTime(Sun.sunrise, "HH:mm") + " set " + Qt.formatTime(Sun.sunset, "HH:mm") + (Sun.known ? " (" + Sun.place.name + ")" : " (default)") + " light: " + NightLight.wanted() + " slot: " + Wallpapers.slotFor(Sun.phase); }
    }
    IpcHandler { target: "planner"; function toggle(): void { root.toggle(); } function open(): void { root.open = true; } function close(): void { root.open = false; } }

    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen"
    readonly property alias todos: data.todos
    readonly property alias events: data.events
    property string notes: ""

    FileView {
        id: file
        path: root.dir + "/planner.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: data
            property var todos: []        // { text, done }
            property var events: []       // { title, when (ms), reminded }
        }
    }
    FileView {
        id: notesFile
        path: root.dir + "/notes.md"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.notes = text()
    }
    Timer { id: notesSave; interval: 600; onTriggered: notesFile.setText(root.notes) }
    function setNotes(t) { if (t === notes) return; notes = t; notesSave.restart(); }

    // ── to-dos ──
    function addTodo(t) { t = t.trim(); if (t) data.todos = data.todos.concat([{ text: t, done: false }]); }
    function toggleTodo(i) { const a = data.todos.slice(); a[i] = { text: a[i].text, done: !a[i].done }; data.todos = a; }
    function removeTodo(i) { data.todos = data.todos.filter((_, j) => j !== i); }
    function clearDone() { data.todos = data.todos.filter(t => !t.done); }

    // ── events ──
    readonly property var upcoming: {
        // Timed: keep for an hour after they start · all-day: until the day ends
        const now = Date.now();
        return (data.events ?? []).map((e, i) => Object.assign({ index: i }, e))
                                   .filter(e => e.allDay ? e.when + 86400000 > now : e.when >= now - 3600000)
                                   .sort((a, b) => a.when - b.when);
    }
    function addEvent(input) {
        const e = parse(input);
        if (!e) return false;
        data.events = data.events.concat([{ title: e.title, when: e.when, allDay: e.allDay, reminded: e.allDay }]);
        return true;
    }
    function removeEvent(i) { data.events = data.events.filter((_, j) => j !== i); }

    function parse(input) {
        let s = input.trim();
        if (!s) return null;
        const now = new Date();
        let day = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        let m;
        const days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
        if ((m = s.match(/^(today|tonight)\b\s*/i))) s = s.slice(m[0].length);
        else if ((m = s.match(/^(tomorrow|tmr|tmrw)\b\s*/i))) { day.setDate(day.getDate() + 1); s = s.slice(m[0].length); }
        else if ((m = s.match(/^(sun|mon|tue|wed|thu|fri|sat)[a-z]*\b\s*/i))) {
            const want = days.indexOf(m[1].toLowerCase());
            let diff = (want - day.getDay() + 7) % 7; if (diff === 0) diff = 7;
            day.setDate(day.getDate() + diff); s = s.slice(m[0].length);
        } else if ((m = s.match(/^(\d{4})-(\d{1,2})-(\d{1,2})\b\s*/))) {
            day = new Date(+m[1], +m[2] - 1, +m[3]); s = s.slice(m[0].length);
        } else if ((m = s.match(/^(\d{1,2})\/(\d{1,2})\b\s*/))) {
            day = new Date(now.getFullYear(), +m[2] - 1, +m[1]);
            if (day < new Date(now.getFullYear(), now.getMonth(), now.getDate())) day.setFullYear(day.getFullYear() + 1);
            s = s.slice(m[0].length);
        }
        const dayGiven = s !== input.trim();
        let h = 0, min = 0, timed = false;
        if ((m = s.match(/^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)\b\s*/i)) || (m = s.match(/^(\d{1,2})[:.](\d{2})\b\s*/))) {
            h = +m[1]; min = +(m[2] ?? 0);
            const ap = (m[3] ?? "").toLowerCase();
            if (ap === "pm" && h < 12) h += 12;
            if (ap === "am" && h === 12) h = 0;
            timed = true; s = s.slice(m[0].length);
        }
        const title = s.trim();
        if (!title || h > 23 || min > 59) return null;
        day.setHours(h, min, 0, 0);
        // "9:30 Standup" typed at 10:00 means tomorrow
        if (timed && !dayGiven && day.getTime() < now.getTime()) day.setDate(day.getDate() + 1);
        return { title, when: day.getTime(), timed, allDay: !timed };
    }

    function whenLabel(ms, allDay) {
        const d = new Date(ms), now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const dd = Math.round((new Date(d.getFullYear(), d.getMonth(), d.getDate()) - today) / 86400000);
        const time = allDay ? "all day" : Qt.formatTime(d, Theme.timeFormatFull);
        if (dd === 0) return "Today · " + time;
        if (dd === 1) return "Tomorrow · " + time;
        if (dd < 7) return Qt.formatDate(d, "dddd") + " · " + time;
        return Qt.formatDate(d, "ddd d MMM") + " · " + time;
    }

    // Reminders: 10 minutes before, once
    Timer {
        interval: 30000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            const now = Date.now();
            let changed = false;
            const a = (data.events ?? []).map(e => {
                if (!e.reminded && !e.allDay && e.when - now <= 10 * 60 * 1000 && e.when - now > -5 * 60 * 1000) {
                    const mins = Math.max(0, Math.round((e.when - now) / 60000));
                    Island.system("event", e.title, mins === 0 ? "Starting now" : "In " + mins + " min");
                    changed = true;
                    return { title: e.title, when: e.when, allDay: false, reminded: true };
                }
                return e;
            });
            if (changed) data.events = a;
        }
    }
}
