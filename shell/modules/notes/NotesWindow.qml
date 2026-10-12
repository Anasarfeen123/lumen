// Lumen Notes — the app window (Super+O). Notes on the left (pinned first,
// newest next; search looks inside them too), the open note on the right:
// write in Markdown, or read it formatted. Saves as you type; a note changed
// elsewhere (Obsidian, or your phone through Syncthing) updates in place, and
// if you were both editing it, you choose which to keep.
//   Ctrl+N new · Ctrl+F search · Ctrl+E write/read · Ctrl+P pin · Ctrl+W close
//   in a note: Ctrl+B bold · Ctrl+I italic · Ctrl+K link · Ctrl+L checkbox ·
//   Enter continues a list · Tab / Shift+Tab indent a list item · Ctrl+V pastes images too
//   [[Note title]] links notes · #tags gather them (click a tag under the search)
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services

FloatingWindow {
    id: win
    title: current ? (Notes.all.find(n => n.file === current)?.title ?? current.replace(/\.md$/, "")) + " — Notes" : "Lumen Notes"
    implicitWidth: 1100
    implicitHeight: 720
    minimumSize: Qt.size(760, 480)
    color: Theme.withAlpha(Theme.bg, 0.9)

    property string initial: ""
    property string current: ""              // the open note's file name
    readonly property bool reading: Notes.cfg.preview
    SystemClock { id: clock; precision: SystemClock.Minutes }

    property bool shownOnce: false
    onVisibleChanged: { if (visible) shownOnce = true; else if (shownOnce) { saveNow(); Qt.quit(); } }
    Component.onCompleted: Qt.callLater(() => handle(initial))

    // ── what to open ──
    function handle(what) {
        if (what === "+new") Notes.create("");
        else if (what.startsWith("+new:")) Notes.create(what.slice(5));
        else if (what) openNote(what);
        else if (!current && Notes.cfg.last) openNote(Notes.cfg.last);
    }
    function openNote(file) {
        if (file === current) { focusEditor(); return; }
        saveNow();
        loading = true;
        editor.text = "";
        loading = false;
        conflict = false; theirs = "";
        current = file;
        Notes.cfg.last = file;
    }
    function closeNote() { saveNow(); current = ""; }
    function focusEditor() { if (reading) return; editor.forceActiveFocus(); }
    Connections {
        target: Notes
        function onCreated(file) { win.openNote(file); win.justCreated = true; }
        function onRenamed(from, to) { if (win.current === from) { win.current = to; Notes.cfg.last = to; } }
    }
    property bool justCreated: false

    // ── the open note on disk ──
    property bool loading: false             // setting the editor's text ourselves
    property bool dirty: false
    property string lastWritten: ""
    property real savedAt: 0
    property bool conflict: false            // changed elsewhere while you had unsaved edits
    property string theirs: ""
    property real updatedElsewhereAt: 0
    FileView {
        id: noteFile
        path: win.current ? Notes.pathOf(win.current) : ""
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const t = text();
            if (t === win.lastWritten || t === editor.text) { win.lastWritten = t; return; }
            const first = editor.text === "" && !win.dirty;
            if (win.dirty && !first) { win.conflict = true; win.theirs = t; return; }
            win.setEditorText(t, !first);
            if (!first) win.updatedElsewhereAt = Date.now();
            win.lastWritten = t;
            if (first && win.justCreated) {
                win.justCreated = false;
                Qt.callLater(() => { win.focusEditor(); editor.cursorPosition = editor.length; });
            }
        }
        onLoadFailed: error => { if (error === FileViewError.FileNotFound && win.current) win.current = ""; }
    }
    function setEditorText(t, keepCursor) {
        const pos = editor.cursorPosition;
        loading = true;
        editor.text = t;
        loading = false;
        editor.cursorPosition = keepCursor ? Math.min(pos, t.length) : 0;
        dirty = false;
    }
    Timer { id: saveTimer; interval: 450; onTriggered: win.saveNow() }
    function saveNow() {
        if (!dirty || !current || conflict) return;
        lastWritten = editor.text;
        noteFile.setText(editor.text);
        dirty = false;
        savedAt = Date.now();
    }
    function keepMine() { conflict = false; theirs = ""; dirty = true; saveNow(); }
    function useTheirs() { const t = theirs; conflict = false; theirs = ""; setEditorText(t, true); lastWritten = t; }

    // ── Markdown helpers ──
    function lineStart(pos) { return editor.text.lastIndexOf("\n", pos - 1) + 1; }
    function lineEnd(pos) { const i = editor.text.indexOf("\n", pos); return i < 0 ? editor.length : i; }
    function wrap(pre, post) {
        if (reading) return;
        const s = editor.selectionStart, e = editor.selectionEnd, sel = editor.selectedText;
        if (sel.startsWith(pre) && sel.endsWith(post) && sel.length >= pre.length + post.length) {
            editor.remove(s, e); editor.insert(s, sel.slice(pre.length, sel.length - post.length));
            editor.select(s, e - pre.length - post.length);
            return;
        }
        editor.remove(s, e);
        editor.insert(s, pre + sel + post);
        if (sel) editor.select(s + pre.length, s + pre.length + sel.length);
        else editor.cursorPosition = s + pre.length;
        editor.forceActiveFocus();
    }
    // Toggle a line marker: "# ", "- ", "- [ ] ", "1. ", "> "
    function linePrefix(prefix) {
        if (reading) return;
        const ls = lineStart(editor.cursorPosition), le = lineEnd(editor.cursorPosition);
        const line = editor.text.slice(ls, le);
        const m = /^(\s*)(#{1,6} |[-*+] \[[ xX]\] |[-*+] |\d+\. |> )?/.exec(line);
        const indent = m[1], had = m[2] ?? "";
        const next = had === prefix ? "" : prefix;
        editor.remove(ls, ls + indent.length + had.length);
        editor.insert(ls, indent + next);
        editor.cursorPosition = Math.min(lineEnd(ls), ls + indent.length + next.length + (line.length - indent.length - had.length));
        editor.forceActiveFocus();
    }
    function toggleCheck() {
        const ls = lineStart(editor.cursorPosition), le = lineEnd(editor.cursorPosition);
        const line = editor.text.slice(ls, le);
        const m = /^(\s*[-*+] \[)([ xX])(\] )/.exec(line);
        if (!m) { linePrefix("- [ ] "); return; }
        const at = ls + m[1].length;
        const pos = editor.cursorPosition;
        editor.remove(at, at + 1);
        editor.insert(at, m[2] === " " ? "x" : " ");
        editor.cursorPosition = pos;
    }
    function insertLink() {
        const sel = editor.selectedText;
        if (/^https?:\/\//.test(sel)) wrap("[](", ")");
        else { wrap("[", "](https://)"); }
    }
    // Enter inside a list continues it; Enter on an empty item ends the list
    function continueList() {
        const pos = editor.cursorPosition, ls = lineStart(pos);
        const before = editor.text.slice(ls, pos);
        const m = /^(\s*)([-*+] \[[ xX]\] |[-*+] |(\d+)\. |> )/.exec(before);
        if (!m) return false;
        if (before === m[0] && lineEnd(pos) === pos) {
            editor.remove(ls, pos);
            return true;
        }
        const marker = m[3] ? (parseInt(m[3]) + 1) + ". " : m[2].replace(/\[[xX]\]/, "[ ]");
        editor.insert(pos, "\n" + m[1] + marker);
        return true;
    }
    function indentLine(out) {
        const ls = lineStart(editor.cursorPosition);
        const line = editor.text.slice(ls, lineEnd(ls));
        if (!/^\s*([-*+] |\d+\. )/.test(line)) return false;
        const pos = editor.cursorPosition;
        if (out) {
            const n = Math.min(2, line.length - line.trimStart().length);
            if (!n) return true;
            editor.remove(ls, ls + n); editor.cursorPosition = Math.max(ls, pos - n);
        } else { editor.insert(ls, "  "); editor.cursorPosition = pos + 2; }
        return true;
    }

    // ── pasting an image: saved next to the notes (attachments/), linked in Markdown ──
    function smartPaste() {
        const name = "attachments/" + Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss") + ".png";
        pasteProc.name = name;
        pasteProc.command = ["sh", "-c", 'wl-paste -l 2>/dev/null | grep -qx "image/png" || exit 3; mkdir -p "$1/attachments" && wl-paste -t image/png > "$1/$2"', "sh", Notes.dir, name];
        pasteProc.running = true;
    }
    Process {
        id: pasteProc
        property string name: ""
        onExited: code => {
            if (code === 0) { editor.insert(editor.cursorPosition, "![](" + name + ")\n"); }
            else editor.paste();                 // not an image: an ordinary paste
        }
    }

    // ── PDF: Qt turns the Markdown into HTML, a headless browser prints it ──
    property string exporting: ""
    function exportPdf() {
        const title = titleInput.current || "Note";
        const html = "<!doctype html><meta charset=utf-8><title>" + title.replace(/</g, "&lt;") + "</title>"
                   + "<style>body{font-family:sans-serif;max-width:720px;margin:40px auto;line-height:1.5;color:#111}img{max-width:100%}"
                   + "code{background:#f3f3f3;padding:1px 4px;border-radius:3px}blockquote{border-left:3px solid #ccc;margin:0;padding-left:12px;color:#555}</style>"
                   + "<base href=\"file://" + Notes.dir + "/\">" + mdToHtml.getFormattedText(0, mdToHtml.length);
        exportHtml.setText(html);
        const dir = Quickshell.env("HOME") + "/Documents/Notes PDFs";
        const out = dir + "/" + title.replace(/[\/:*?"<>|]/g, " ").trim() + ".pdf";
        exporting = out;
        pdfProc.command = ["sh", "-c", 'mkdir -p "$1" && for b in chromium-browser chromium brave-browser brave-origin google-chrome-stable; do command -v "$b" >/dev/null && exec "$b" --headless=new --disable-gpu --no-pdf-header-footer --print-to-pdf="$2" "file://$3"; done; exit 9',
                           "sh", dir, out, exportHtml.path];
        Qt.callLater(() => pdfProc.running = true);
    }
    TextEdit { id: mdToHtml; visible: false; textFormat: TextEdit.MarkdownText; text: editor.text }
    FileView { id: exportHtml; path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-notes-export.html"; printErrors: false }
    Process {
        id: pdfProc
        onExited: code => {
            if (code === 0) Quickshell.execDetached(["notify-send", "-a", "Notes", "-i", "picture_as_pdf", "Saved as PDF", win.exporting.replace(Quickshell.env("HOME"), "~")]);
            else Quickshell.execDetached(["notify-send", "-a", "Notes", "Couldn't make the PDF", code === 9 ? "No Chromium-based browser found" : "The browser failed"]);
            win.exporting = "";
        }
    }

    // [[Note title]] → a link to that note in the read view
    function wikiLinks(t) {
        return t.replace(/\[\[([^\]\n]{1,80})\]\]/g, (m, name) => "[" + name + "](note:" + encodeURIComponent(name) + ")");
    }
    function openByTitle(name) {
        const n = name.trim().toLowerCase();
        const hit = Notes.all.find(x => x.title.toLowerCase() === n) ?? Notes.all.find(x => x.file.toLowerCase() === n + ".md");
        if (hit) openNote(hit.file); else Notes.create(name.trim());   // a link to nothing yet makes it
    }

    // ── small helpers ──
    function whenLabel(ms) {
        const d = new Date(ms), now = clock.date;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (ms >= today) return Qt.formatTime(d, Theme.timeFormatFull);
        if (ms >= today - 86400000) return "Yesterday";
        if (ms >= today - 6 * 86400000) return Qt.formatDate(d, "dddd");
        return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
    }
    readonly property var stats: {
        const t = editor.text;
        return { words: (t.match(/\S+/g) ?? []).length, open: (t.match(/^\s*[-*+] \[ \]/gm) ?? []).length,
                 done: (t.match(/^\s*[-*+] \[[xX]\]/gm) ?? []).length };
    }

    // ═════ layout ═════
    Item {
        id: rootItem
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            const ctrl = e.modifiers & Qt.ControlModifier;
            if (ctrl && e.key === Qt.Key_N) Notes.create("");
            else if (ctrl && e.key === Qt.Key_F) { search.input.forceActiveFocus(); search.input.selectAll(); }
            else if (ctrl && e.key === Qt.Key_E && win.current) Notes.cfg.preview = !Notes.cfg.preview;
            else if (ctrl && e.key === Qt.Key_P && win.current) Notes.togglePin(win.current);
            else if (ctrl && e.key === Qt.Key_W) win.visible = false;
            else if (ctrl && e.key === Qt.Key_S) win.saveNow();
            else return;
            e.accepted = true;
        }

        // ── the list ──
        Rectangle {
            id: side
            width: 310
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Theme.withAlpha(Theme.surface, 0.55)
            Rectangle { anchors { top: parent.top; bottom: parent.bottom; right: parent.right } width: 1; color: Theme.border }

            Column {
                id: sideHead
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s4; topMargin: Theme.space.s5 }
                spacing: Theme.space.s3
                Item {
                    width: parent.width; height: 32
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.space.s2
                        LIcon { icon: "edit_note"; size: 22; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        LText { role: "heading"; text: "Notes"; anchors.verticalCenter: parent.verticalCenter }
                        LText { role: "caption"; color: Theme.textMuted; text: Notes.all.length; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        // Phone sync: state at a glance, click for Settings → Notes
                        HoverTarget {
                            width: 32; height: 32; radius: 16
                            onClicked: SettingsState.launch("notes")
                            LIcon {
                                anchors.centerIn: parent; size: 18
                                icon: !Notes.syncOn ? "phonelink_off" : Notes.phoneConnected ? "mobile_friendly" : Notes.phones.length ? "phonelink" : "phonelink_setup"
                                color: Notes.phoneConnected ? Theme.success : Theme.textMuted
                            }
                        }
                        IconButton { icon: "edit_square"; tone: Theme.accent; onActivated: Notes.create("") }
                    }
                }
                LField {
                    id: search
                    width: parent.width
                    icon: "search"
                    placeholder: "Search notes"
                    clearOnAccept: false
                    onTextChanged: Notes.query = text
                    onAccepted: t => { const first = (Notes.query ? Notes.hits : Notes.sorted)[0]; if (first) win.openNote(first.file); }
                    input.Keys.onEscapePressed: { search.text = ""; rootItem.forceActiveFocus(); }
                    input.Keys.onDownPressed: { list.forceActiveFocus(); list.currentIndex = 0; }
                }
                // #tags across your notes: click one to see its notes
                Flow {
                    readonly property var tags: { const c = {}; for (const n of Notes.all) for (const t of n.tags ?? []) c[t] = (c[t] ?? 0) + 1;
                                                  return Object.keys(c).sort((a, b) => c[b] - c[a] || a.localeCompare(b)).slice(0, 12); }
                    visible: tags.length > 0
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: parent.tags
                        delegate: HoverTarget {
                            required property string modelData
                            readonly property bool on: search.text.trim().toLowerCase() === "#" + modelData
                            width: tagText.implicitWidth + 16; height: 24; radius: 12
                            onClicked: search.text = on ? "" : "#" + modelData
                            Rectangle { anchors.fill: parent; radius: 12; z: -1; color: parent.on ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.text, 0.05)
                                        border.width: 1; border.color: parent.on ? Theme.withAlpha(Theme.accent, 0.45) : Theme.border }
                            LText { id: tagText; anchors.centerIn: parent; role: "caption"; color: parent.on ? Theme.accent : Theme.textSecondary; text: "#" + modelData }
                        }
                    }
                }
            }

            ListView {
                id: list
                anchors { top: sideHead.bottom; topMargin: Theme.space.s3; bottom: sideFoot.top; left: parent.left; right: parent.right }
                clip: true
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationWraps: false
                readonly property bool searching: Notes.query.trim() !== ""
                model: searching ? Notes.hits : Notes.sorted.map(n => Object.assign({ group: Notes.isPinned(n.file) ? "Pinned" : "Notes" }, n))
                section.property: searching ? "" : "group"
                section.delegate: LText {
                    required property string section
                    x: Theme.space.s5; height: 28; verticalAlignment: Text.AlignBottom; bottomPadding: 4
                    role: "caption"; color: Theme.textMuted; font.letterSpacing: 1; text: section.toUpperCase()
                }
                Keys.onReturnPressed: { const n = model[currentIndex]; if (n) win.openNote(n.file); }
                Keys.onUpPressed: e => { if (currentIndex <= 0) search.input.forceActiveFocus(); else e.accepted = false; }
                QQC.ScrollBar.vertical: QQC.ScrollBar {
                    id: lbar
                    width: 10; padding: 2; background: null
                    contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.22)
                                             opacity: lbar.active || lbar.hovered ? 1 : 0; Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } } }
                }

                delegate: HoverTarget {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool open: modelData.file === win.current
                    readonly property bool isHit: list.searching
                    x: Theme.space.s2
                    width: list.width - Theme.space.s2 * 2
                    height: isHit ? 58 : 64
                    radius: Theme.radius.sm
                    onClicked: win.openNote(modelData.file)
                    Rectangle {
                        anchors.fill: parent; radius: parent.radius; z: -1
                        color: row.open ? Theme.withAlpha(Theme.accent, 0.14)
                             : row.ListView.isCurrentItem && list.activeFocus ? Theme.withAlpha(Theme.text, 0.07)
                             : row.containsMouse ? Theme.withAlpha(Theme.text, 0.045) : "transparent"
                    }
                    Column {
                        anchors { left: parent.left; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        spacing: 2
                        Item {
                            width: parent.width; height: 20
                            LText {
                                anchors { left: parent.left; right: meta.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight; role: "bodyStrong"
                                color: row.open ? Theme.accent : Theme.text
                                text: row.modelData.title
                            }
                            Row {
                                id: meta
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 4
                                LIcon { visible: !row.isHit && Notes.isPinned(row.modelData.file); icon: "keep"; size: 13; fill: 1; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                LText { role: "caption"; color: Theme.textMuted; text: win.whenLabel(row.modelData.mtime); anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                        LText {
                            width: parent.width; elide: Text.ElideRight; role: "caption"
                            color: Theme.textSecondary; maximumLineCount: row.isHit ? 1 : 2; wrapMode: Text.Wrap
                            text: row.isHit ? (row.modelData.line > 0 ? "…" : "") + row.modelData.text
                                            : (row.modelData.preview || "Empty note")
                        }
                        Row {
                            visible: !row.isHit && row.modelData.open > 0
                            spacing: 3
                            LIcon { icon: "check_box_outline_blank"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; font.pixelSize: 10; color: Theme.accent; text: row.modelData.open + " to do"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                // Nothing yet / nothing found
                Column {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    spacing: Theme.space.s2
                    LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: list.searching ? "search_off" : "note_stack"; size: 32; color: Theme.textMuted }
                    LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted
                            text: list.searching ? "Nothing matches “" + Notes.query + "”" : "No notes yet — Ctrl+N" }
                }
            }

            // ── foot: trash, the folder ──
            Item {
                id: sideFoot
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: trashOpen ? Math.min(220, 44 + Notes.trashed.length * 34) : 44
                property bool trashOpen: false
                Behavior on height { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutCubic } }
                clip: true
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Row {
                    x: Theme.space.s3; y: 6
                    spacing: 2
                    HoverTarget {
                        width: tRow.implicitWidth + 16; height: 32; radius: 16
                        onClicked: { sideFoot.trashOpen = !sideFoot.trashOpen; if (sideFoot.trashOpen) Notes.refreshTrash(); }
                        Row { id: tRow; anchors.centerIn: parent; spacing: 5
                              LIcon { icon: "delete"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                              LText { role: "caption"; color: Theme.textSecondary; text: "Recently deleted"; anchors.verticalCenter: parent.verticalCenter } }
                    }
                    HoverTarget {
                        width: fRow.implicitWidth + 16; height: 32; radius: 16
                        onClicked: Quickshell.execDetached(["xdg-open", Notes.dir])
                        Row { id: fRow; anchors.centerIn: parent; spacing: 5
                              LIcon { icon: "folder_open"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                              LText { role: "caption"; color: Theme.textSecondary; text: Notes.dir.replace(Quickshell.env("HOME"), "~"); anchors.verticalCenter: parent.verticalCenter } }
                    }
                }
                ListView {
                    anchors { top: parent.top; topMargin: 44; bottom: parent.bottom; left: parent.left; right: parent.right }
                    clip: true
                    model: Notes.trashed
                    delegate: Item {
                        required property var modelData
                        width: ListView.view.width; height: 34
                        LText { anchors { left: parent.left; leftMargin: Theme.space.s5; right: put.left; verticalCenter: parent.verticalCenter }
                                elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: modelData.title }
                        HoverTarget { id: put; width: 70; height: 26; radius: 13; anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                                      onClicked: Notes.restore(modelData.name)
                                      LText { anchors.centerIn: parent; role: "caption"; color: Theme.accent; text: "Restore" } }
                    }
                    LText { visible: Notes.trashed.length === 0; x: Theme.space.s5; y: 6; role: "caption"; color: Theme.textMuted; text: "Nothing here." }
                }
            }
        }

        // ── the open note ──
        Item {
            id: pane
            anchors { top: parent.top; bottom: parent.bottom; left: side.right; right: parent.right }

            // Nothing open
            Column {
                anchors.centerIn: parent
                visible: !win.current
                spacing: Theme.space.s3
                LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: "edit_note"; size: 56; color: Theme.withAlpha(Theme.accent, 0.7) }
                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "heading"; text: "Pick a note, or start one" }
                LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted
                        text: "Ctrl+N new · Ctrl+F search · Super+Shift+O from anywhere" }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nb.implicitWidth + 32; height: 36; radius: 18; color: Theme.accent
                    Row { id: nb; anchors.centerIn: parent; spacing: 6
                          LIcon { icon: "add"; size: 16; color: Theme.onAccent; anchors.verticalCenter: parent.verticalCenter }
                          LText { role: "bodyStrong"; color: Theme.onAccent; text: "New note"; anchors.verticalCenter: parent.verticalCenter } }
                    HoverTarget { anchors.fill: parent; radius: 18; onClicked: Notes.create("") }
                }
            }

            // Title bar
            Item {
                id: bar
                visible: !!win.current
                anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: Theme.space.s4; leftMargin: Theme.space.s6; rightMargin: Theme.space.s4 }
                height: 40
                TextInput {
                    id: titleInput
                    anchors { left: parent.left; right: tools.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    readonly property string current: Notes.all.find(n => n.file === win.current)?.title ?? win.current.replace(/\.md$/, "")
                    text: current
                    color: Theme.text
                    selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                    font.family: Theme.fontUi; font.pixelSize: 22; font.weight: Font.DemiBold
                    clip: true
                    onEditingFinished: if (text.trim() && text.trim() !== current) { win.saveNow(); Notes.rename(win.current, text.trim()); }
                    Keys.onEscapePressed: { text = current; editor.forceActiveFocus(); }
                    Keys.onReturnPressed: editor.forceActiveFocus()
                    onCurrentChanged: text = current
                }
                Row {
                    id: tools
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s1
                    Segmented {
                        width: 150
                        anchors.verticalCenter: parent.verticalCenter
                        options: [{ id: "write", label: "Write" }, { id: "read", label: "Read" }]
                        current: win.reading ? "read" : "write"
                        onPicked: id => Notes.cfg.preview = id === "read"
                    }
                    IconButton { icon: "keep"; tone: Notes.isPinned(win.current) ? Theme.accent : Theme.textSecondary; onActivated: Notes.togglePin(win.current) }
                    IconButton { icon: "send_to_mobile"; visible: Link.connected; onActivated: Link.sendFiles([Notes.pathOf(win.current)]) }
                    IconButton { icon: "content_copy"; onActivated: { Quickshell.execDetached(["wl-copy", editor.text]); copied.restart(); } }
                    IconButton { icon: win.exporting ? "hourglass_top" : "picture_as_pdf"; enabled: !win.exporting; onActivated: win.exportPdf() }
                    IconButton {
                        id: del
                        property bool armed: false
                        icon: armed ? "delete_forever" : "delete"
                        tone: armed ? Theme.error : Theme.textSecondary
                        onActivated: { if (armed) { armed = false; const f = win.current; win.current = ""; Notes.trash(f); } else { armed = true; disarm.restart(); } }
                        Timer { id: disarm; interval: 2500; onTriggered: del.armed = false }
                    }
                }
            }

            // Formatting (writing only)
            Row {
                id: fmt
                visible: !!win.current && !win.reading
                anchors { top: bar.bottom; topMargin: Theme.space.s2; left: parent.left; leftMargin: Theme.space.s5 }
                spacing: 2
                component Fmt: HoverTarget {
                    property string icon
                    property string tip
                    width: 30; height: 28; radius: Theme.radius.sm
                    LIcon { anchors.centerIn: parent; icon: parent.icon; size: 17; color: Theme.textSecondary }
                }
                Fmt { icon: "title"; onClicked: win.linePrefix("## ") }
                Fmt { icon: "format_bold"; onClicked: win.wrap("**", "**") }
                Fmt { icon: "format_italic"; onClicked: win.wrap("*", "*") }
                Fmt { icon: "strikethrough_s"; onClicked: win.wrap("~~", "~~") }
                Fmt { icon: "code"; onClicked: win.wrap("`", "`") }
                Rectangle { width: 1; height: 18; color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
                Fmt { icon: "format_list_bulleted"; onClicked: win.linePrefix("- ") }
                Fmt { icon: "format_list_numbered"; onClicked: win.linePrefix("1. ") }
                Fmt { icon: "check_box"; onClicked: win.toggleCheck() }
                Fmt { icon: "format_quote"; onClicked: win.linePrefix("> ") }
                Fmt { icon: "link"; onClicked: win.insertLink() }
            }

            // Changed elsewhere while you were editing
            Rectangle {
                id: banner
                visible: win.conflict
                anchors { top: fmt.visible ? fmt.bottom : bar.bottom; topMargin: Theme.space.s2; left: parent.left; right: parent.right; leftMargin: Theme.space.s5; rightMargin: Theme.space.s5 }
                height: 44; radius: Theme.radius.sm
                color: Theme.withAlpha(Theme.warning, 0.12)
                border.width: 1; border.color: Theme.withAlpha(Theme.warning, 0.4)
                Row {
                    anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s2
                    LIcon { icon: "sync_problem"; size: 18; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "caption"; text: "This note changed on another device while you were editing."; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s1
                    HoverTarget { width: 92; height: 30; radius: 15; onClicked: win.keepMine()
                                  LText { anchors.centerIn: parent; role: "caption"; color: Theme.accent; text: "Keep mine" } }
                    HoverTarget { width: 92; height: 30; radius: 15; onClicked: win.useTheirs()
                                  LText { anchors.centerIn: parent; role: "caption"; text: "Use theirs" } }
                }
            }

            // Writing
            QQC.ScrollView {
                id: writeView
                visible: !!win.current && !win.reading
                anchors { top: banner.visible ? banner.bottom : fmt.bottom; topMargin: Theme.space.s3; bottom: status.top; left: parent.left; right: parent.right }
                contentWidth: availableWidth
                QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded
                QQC.TextArea {
                    id: editor
                    // A comfortable measure on wide windows
                    readonly property real measure: Math.min(760, writeView.availableWidth - Theme.space.s6 * 2)
                    // Lined up with the title; the line length stays comfortable on wide windows
                    leftPadding: Theme.space.s6
                    rightPadding: Math.max(Theme.space.s6, writeView.availableWidth - measure - Theme.space.s6)
                    topPadding: Theme.space.s2
                    bottomPadding: Theme.space.s8
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    placeholderText: "Start writing…  Markdown works: # heading, - list, - [ ] to-do, **bold**"
                    placeholderTextColor: Theme.textMuted
                    selectionColor: Theme.withAlpha(Theme.accent, 0.4)
                    selectByMouse: true
                    persistentSelection: true
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    background: null
                    onTextChanged: if (!win.loading) { win.dirty = true; saveTimer.restart(); }
                    Keys.onPressed: e => {
                        const ctrl = e.modifiers & Qt.ControlModifier;
                        if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) e.accepted = win.continueList();
                        else if (e.key === Qt.Key_Tab) e.accepted = win.indentLine(false);
                        else if (e.key === Qt.Key_Backtab) e.accepted = win.indentLine(true);
                        else if (ctrl && e.key === Qt.Key_B) { win.wrap("**", "**"); e.accepted = true; }
                        else if (ctrl && e.key === Qt.Key_I) { win.wrap("*", "*"); e.accepted = true; }
                        else if (ctrl && e.key === Qt.Key_K) { win.insertLink(); e.accepted = true; }
                        else if (ctrl && e.key === Qt.Key_L) { win.toggleCheck(); e.accepted = true; }
                        else if (ctrl && e.key === Qt.Key_V && !(e.modifiers & Qt.ShiftModifier)) { win.smartPaste(); e.accepted = true; }
                    }
                }
            }

            // Reading
            QQC.ScrollView {
                id: readView
                visible: !!win.current && win.reading
                anchors { top: banner.visible ? banner.bottom : bar.bottom; topMargin: Theme.space.s4; bottom: status.top; left: parent.left; right: parent.right }
                contentWidth: availableWidth
                QQC.Label {
                    readonly property real measure: Math.min(760, readView.availableWidth - Theme.space.s6 * 2)
                    x: Theme.space.s6
                    width: measure
                    bottomPadding: Theme.space.s8
                    textFormat: Text.MarkdownText
                    // The title bar already shows a leading "# Title"
                    text: win.wikiLinks(editor.text.replace(/^\s*#\s+(.*)\n/, (m, t) => t.trim() === titleInput.current ? "" : m) || "*Empty note.*")
                          // Qt's Markdown ignores linkColor: colour the labels ourselves
                          .replace(/\[([^\]\n]+)\]\(([^)\s]+)\)/g, (m, label, url) => "[<font color=\"" + Theme.accent + "\">" + label + "</font>](" + url + ")")
                    wrapMode: Text.Wrap
                    color: Theme.text
                    palette.link: Theme.accent
                    palette.linkVisited: Theme.accent
                    linkColor: Theme.accent
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    lineHeight: 1.15
                    baseUrl: "file://" + Notes.dir + "/"
                    onLinkActivated: link => link.startsWith("note:") ? win.openByTitle(decodeURIComponent(link.slice(5))) : Qt.openUrlExternally(link)
                    HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
                }
            }

            // Status line
            Item {
                id: status
                visible: !!win.current
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: Theme.space.s6; rightMargin: Theme.space.s5 }
                height: 34
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.space.s3
                    LText { role: "caption"; color: Theme.textMuted; text: win.stats.words + (win.stats.words === 1 ? " word" : " words") }
                    LText { visible: win.stats.open + win.stats.done > 0; role: "caption"; color: Theme.textMuted
                            text: win.stats.done + " of " + (win.stats.open + win.stats.done) + " done" }
                    LText { visible: copied.running; role: "caption"; color: Theme.accent; text: "Copied" }
                    Timer { id: copied; interval: 1600 }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s2
                    LText {
                        visible: justNow.running
                        role: "caption"; color: Theme.accent; text: "Updated from another device"
                        Timer { id: justNow; interval: 6000 }
                        Connections { target: win; function onUpdatedElsewhereAtChanged() { justNow.restart(); } }
                    }
                    LText { role: "caption"; color: Theme.textMuted
                            text: win.conflict ? "Not saved — choose above" : win.dirty ? "Saving…" : win.savedAt ? "Saved" : "" }
                    Row {
                        visible: Notes.syncOn
                        spacing: 4
                        LIcon { icon: Notes.phoneConnected ? "mobile_friendly" : "phonelink"; size: 14; color: Notes.phoneConnected ? Theme.success : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        LText { role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                                text: Notes.phoneConnected ? "Syncing with " + (Notes.phones.find(p => p.connected)?.name ?? "phone") : Notes.phones.length ? "Phone away · syncs when it's back" : "Sync on · no phone yet" }
                    }
                }
            }
        }
    }
}
