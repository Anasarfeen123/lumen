// Shortcuts and IPC for the overview (no UI).
//   bindr = SUPER, Super_L, global, lumen:overviewTap   (tap Super — fires on release)
//   bind  = SUPER, Tab,     global, lumen:overview
//   bind  = SUPER, V,       global, lumen:clipboard
//   bind  = SUPER, period,  global, lumen:emoji
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    GlobalShortcut { appid: "lumen"; name: "overview"; description: "Overview & search"; onPressed: Overview.toggle("search") }
    // Tapping Super alone is a *release* bind (bindr), and Hyprland reports
    // release binds to global shortcuts as a release — so this one listens
    // for onReleased. (Listening for onPressed is why a bare Super tap did nothing.)
    GlobalShortcut { appid: "lumen"; name: "overviewTap"; description: "Overview (tap Super)"; onReleased: Overview.toggle("search") }
    GlobalShortcut { appid: "lumen"; name: "overviewOpen"; description: "Open overview"; onPressed: if (!Overview.open) Overview.show("search") }
    GlobalShortcut { appid: "lumen"; name: "overviewClose"; description: "Close overview"; onPressed: Overview.hide() }
    GlobalShortcut { appid: "lumen"; name: "clipboard"; description: "Clipboard history"; onPressed: Overview.toggle("clipboard") }
    GlobalShortcut { appid: "lumen"; name: "emoji"; description: "Emoji picker"; onPressed: Overview.toggle("emoji") }

    IpcHandler {
        target: "overview"
        function toggle(): void { Overview.toggle("search"); }
        function open(mode: string): void { Overview.show(mode || "search"); }
        function close(): void { Overview.hide(); }
        function search(text: string): void { Overview.show("search"); Overview.query = text; }
        function state(): string { return JSON.stringify({ open: Overview.open, mode: Overview.mode, query: Overview.query, emoji: Emoji.all.length }); }
        function results(): string { return JSON.stringify(Search.results.map(r => ({ kind: r.kind, title: r.title, badge: r.badge }))); }
    }
}
