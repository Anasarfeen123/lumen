// Peek (DESIGN.md §30): hover a window in the Ribbon's strip, or a workspace
// dot, and a quiet card drops under it — live previews of the windows, each
// with its title, workspace, CPU and memory, and what it's playing.
// Click a preview to go there; middle-click closes that window.
// It never takes the keyboard, and it leaves when the pointer does.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PopupWindow {
    id: pop
    required property var barWindow

    property var toplevels: []          // what to show
    property string heading: ""
    property real atX: 0                // where the pointer was, in bar coordinates
    property bool want: false           // the pointer is on a target (or on the card)
    readonly property int margin: 24
    readonly property int cardW: toplevels.length > 2 ? 220 : 260
    readonly property int cardH: Math.round(cardW * 9 / 16)

    // Called by the strip / dots. Showing waits a moment (a pass-over isn't a
    // request); hiding waits too, so the pointer can travel onto the card.
    function peek(list, title, x) {
        toplevels = list.slice(0, 4);
        heading = title;
        atX = x;
        want = toplevels.length > 0;
        if (visible) { stats.refresh(); return; }
        showTimer.restart();
    }
    function leave() { want = false; hideTimer.restart(); }

    // Dev only (LUMEN_DEV): peek a workspace's windows without a pointer
    IpcHandler {
        target: "peekTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1" && pop.barWindow.screen?.name === Hyprland.focusedMonitor?.name
        function workspace(id: int): void {
            const ws = Hyprland.workspaces.values.find(w => w.id === id);
            pop.peek(ws?.toplevels?.values ?? [], "Workspace " + id, 420);
        }
        function hide(): void { pop.want = false; pop.visible = false; }
    }

    Timer { id: showTimer; interval: 380; onTriggered: if (pop.want) { pop.visible = true; stats.refresh(); } }
    Timer { id: hideTimer; interval: 220; onTriggered: if (!pop.want && !cardHover.hovered) pop.visible = false }

    anchor.window: barWindow
    anchor.rect.x: Math.max(0, Math.min(barWindow.width - implicitWidth, atX - implicitWidth / 2))
    anchor.rect.y: Theme.edgeGap + Theme.barHeight + Theme.space.s1 - margin
    implicitWidth: panel.width + margin * 2
    implicitHeight: panel.height + margin * 2
    color: "transparent"
    visible: false
    mask: Region { item: panel }
    onVisibleChanged: if (!visible) toplevels = []

    // Per-window CPU / memory (process tree), refreshed while visible
    QtObject {
        id: stats
        property var data: ({})
        function refresh() {
            const pids = pop.toplevels.map(t => t.lastIpcObject?.pid).filter(p => p > 0);
            if (!pids.length || proc.running) return;
            proc.command = [Theme.lumenRoot + "/scripts/peek-stats.sh"].concat(pids.map(String));
            proc.running = true;
        }
    }
    Process {
        id: proc
        stdout: StdioCollector { onStreamFinished: { try { stats.data = JSON.parse(text); } catch (e) {} } }
    }
    Timer { interval: 2000; repeat: true; running: pop.visible; onTriggered: stats.refresh() }

    GlassSurface {
        id: panel
        x: pop.margin; y: pop.margin
        level: "panel"
        radius: Theme.radius.md
        width: cards.implicitWidth + Theme.space.s3 * 2
        height: col.implicitHeight + Theme.space.s3 * 2
        opacity: pop.visible ? 1 : 0
        transform: Translate { y: pop.visible ? 0 : -6; Behavior on y { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        HoverHandler { id: cardHover; onHoveredChanged: if (!hovered) pop.leave(); else pop.want = true }

        Column {
            id: col
            x: Theme.space.s3; y: Theme.space.s3
            spacing: Theme.space.s2
            LText { visible: pop.heading !== ""; role: "caption"; color: Theme.textMuted; text: pop.heading }
            Row {
                id: cards
                spacing: Theme.space.s2
                Repeater {
                    model: pop.toplevels
                    delegate: Column {
                        id: card
                        required property var modelData
                        readonly property var ipc: modelData.lastIpcObject ?? ({})
                        readonly property var entry: DesktopEntries.heuristicLookup(ipc.class ?? "")
                        readonly property var st: stats.data[String(ipc.pid)] ?? null
                        // A player that belongs to this app (by desktop entry or name)
                        readonly property var player: Media.players.find(p => {
                            const c = (ipc.class ?? "").toLowerCase();
                            return c && ((p.desktopEntry ?? "").toLowerCase().includes(c) || c.includes((p.identity ?? "#").toLowerCase()));
                        }) ?? null
                        spacing: 6
                        width: pop.cardW

                        ClippingRectangle {
                            width: pop.cardW; height: pop.cardH
                            radius: Theme.radius.sm
                            color: Theme.surfaceElevated
                            border.width: shotMouse.containsMouse ? 2 : 1
                            border.color: shotMouse.containsMouse ? Theme.accent : Theme.border
                            ScreencopyView {
                                id: live
                                anchors.fill: parent
                                captureSource: pop.visible ? card.modelData.wayland : null
                                live: true
                                constraintSize: Qt.size(pop.cardW * 2, pop.cardH * 2)
                            }
                            IconImage {
                                anchors.centerIn: parent
                                visible: !live.hasContent
                                width: 40; height: 40
                                source: card.entry ? Apps.iconFor(card.entry) : Quickshell.iconPath("application-x-executable")
                            }
                            MouseArea {
                                id: shotMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: m => {
                                    const addr = card.ipc.address ?? ("0x" + card.modelData.address);
                                    if (m.button === Qt.MiddleButton) Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr}" })`);
                                    else Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr}" })`);
                                    pop.visible = false;
                                }
                            }
                        }
                        Row {
                            spacing: 6
                            width: parent.width
                            IconImage {
                                width: 16; height: 16
                                anchors.verticalCenter: parent.verticalCenter
                                source: card.entry ? Apps.iconFor(card.entry) : ""
                            }
                            LText { width: parent.width - 22; role: "bodyStrong"; elide: Text.ElideRight; text: card.modelData.title || card.ipc.class || "Window"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            spacing: Theme.space.s3
                            Meta { icon: "space_dashboard"; text: "Workspace " + (card.ipc.workspace?.name ?? "?") }
                            Meta { visible: card.st !== null; icon: "speed"; text: (card.st?.cpu ?? 0) + "%"; hot: (card.st?.cpu ?? 0) > 80 }
                            Meta { visible: card.st !== null; icon: "memory"; text: card.st ? (card.st.mem >= 1024 ? (card.st.mem / 1024).toFixed(1) + " GB" : card.st.mem + " MB") : "" }
                        }
                        Meta {
                            visible: card.player !== null
                            maxWidth: pop.cardW
                            icon: card.player?.isPlaying ? "graphic_eq" : "pause_circle"
                            text: (card.player?.trackTitle ?? "") + (card.player?.trackArtist ? " · " + card.player.trackArtist : "")
                            accent: card.player?.isPlaying ?? false
                        }
                    }
                }
            }
        }
    }

    component Meta: Row {
        id: meta
        property string icon
        property string text
        property bool hot: false
        property bool accent: false
        property real maxWidth: 0          // 0 = as wide as the text
        spacing: 4
        LIcon { icon: meta.icon; size: 13; color: meta.hot ? Theme.warning : meta.accent ? Theme.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
        LText { role: "caption"; text: meta.text; color: meta.hot ? Theme.warning : Theme.textSecondary; elide: Text.ElideRight
                width: meta.maxWidth > 0 ? Math.min(implicitWidth, meta.maxWidth - 17) : implicitWidth; anchors.verticalCenter: parent.verticalCenter }
    }
}
