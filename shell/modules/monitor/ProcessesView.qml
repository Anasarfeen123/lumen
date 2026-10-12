// Processes: grouped the way you think of them — Apps (anything with a window,
// with every process under it), Background (yours) and System (everyone
// else's) — or one flat list. Click a column to sort (again to reverse). Cells
// warm up with load. Select a row: End task (Delete), Force (Shift+Delete),
// Suspend, Details (Enter) with priority, memory, files, ports and children.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: view
    property string query: ""
    property string sortKey: "cpu"
    property bool desc: true
    property bool flat: false
    property var collapsed: ({ system: true })     // sections folded
    property var expanded: ({})                    // app groups unfolded
    property string selected: ""                   // a group or process key
    property bool detailsOpen: false

    readonly property var cols: [
        { key: "name", label: "Name", w: -1 },
        { key: "status", label: "Status", w: 96 },
        { key: "cpu", label: "CPU", w: 76, total: () => Math.round(SystemMonitor.s.cpu ?? 0) + "%" },
        { key: "mem", label: "Memory", w: 96, total: () => { const m = SystemMonitor.s.mem ?? {}; return m.total ? Math.round(100 * (m.total - m.available) / m.total) + "%" : ""; } },
        { key: "disk", label: "Disk", w: 96, total: () => { let a = 0; for (const d in SystemMonitor.s.disks ?? {}) a = Math.max(a, SystemMonitor.s.disks[d].active); return Math.round(a) + "%"; } },
        { key: "net", label: "Network", w: 96, total: () => { let t = 0; for (const n in SystemMonitor.s.net ?? {}) t += SystemMonitor.s.net[n].rx + SystemMonitor.s.net[n].tx; return SystemMonitor.bits(t); } },
        { key: "gpu", label: "GPU", w: 70, total: () => { const g = (SystemMonitor.s.gpus ?? []).find(x => x.kind === "amd" || x.state === "active"); return g?.util !== undefined && g?.util !== null ? Math.round(g.util) + "%" : ""; } },
        { key: "pid", label: "PID", w: 86 },
        { key: "user", label: "User", w: 96 },
        { key: "threads", label: "Threads", w: 70 },
    ]
    // On a narrow window the least useful columns step aside, in this order
    readonly property var dropOrder: ["threads", "user", "status", "pid", "disk", "gpu"]
    readonly property var hidden: {
        const avail = table.width - 216;                     // the name keeps at least 200 px
        let used = cols.reduce((a, c) => a + (c.w > 0 ? c.w : 0), 0);
        const out = [];
        for (const k of dropOrder) {
            if (used <= avail) break;
            used -= cols.find(c => c.key === k).w;
            out.push(k);
        }
        return out;
    }
    function shown(k) { return !hidden.includes(k); }
    readonly property var visibleCols: cols.filter(c => shown(c.key))
    readonly property real fixedW: visibleCols.reduce((a, c) => a + (c.w > 0 ? c.w : 0), 0)

    function matches(g) {
        const q = query.trim().toLowerCase();
        if (!q) return true;
        return g.members.some(m => m.name.toLowerCase().includes(q) || String(m.pid) === q || m.cmd.toLowerCase().includes(q)) || g.name.toLowerCase().includes(q);
    }
    function sortVal(g) {
        return ({ name: g.name.toLowerCase(), status: g.suspended ? 1 : 0, cpu: g.cpu, mem: g.mem, disk: g.rd + g.wr,
                  pid: g.pid, user: g.user, threads: g.threads, net: g.net, gpu: g.gpu })[sortKey];
    }
    function sorted(list) {
        const d = desc ? -1 : 1;
        return list.slice().sort((a, b) => { const x = sortVal(a), y = sortVal(b); return x < y ? -d : x > y ? d : a.pid - b.pid; });
    }
    function memberGroup(p) { return SystemMonitor.group("m:" + p.pid, p.name, p.cmd, [p], "", p.pid); }

    // One flat model for the list: section headers, groups, and unfolded members
    readonly property var rows: {
        const G = SystemMonitor.groups;
        const out = [];
        if (flat) {
            const all = SystemMonitor.procs.map(p => memberGroup(p)).filter(g => matches(g));
            for (const g of sorted(all)) out.push({ type: "group", g, depth: 0 });
            return out;
        }
        const sections = [{ id: "apps", label: "Apps", list: G.apps }, { id: "background", label: "Background processes", list: G.background }, { id: "system", label: "System", list: G.system }];
        const searching = query.trim() !== "";
        for (const sec of sections) {
            const list = sorted(sec.list.filter(g => matches(g)));
            if (!list.length) continue;
            out.push({ type: "section", id: sec.id, label: sec.label, count: list.length });
            if (collapsed[sec.id] && !searching) continue;
            for (const g of list) {
                out.push({ type: "group", g, depth: 0 });
                if (g.count > 1 && (expanded[g.key] || searching && sec.id === "apps"))
                    for (const m of sorted(g.members.map(p => memberGroup(p)))) out.push({ type: "group", g: m, depth: 1 });
            }
        }
        return out;
    }
    readonly property var sel: {
        for (const r of rows) if (r.type === "group" && r.g.key === selected) return r.g;
        return null;
    }
    onSelChanged: if (detailsOpen && sel) SystemMonitor.loadDetail(sel.pid)
    Timer { interval: 2000; repeat: true; running: view.detailsOpen && !!view.sel; onTriggered: SystemMonitor.loadDetail(view.sel.pid) }

    function heat(v, lo, hi) {
        const t = Math.max(0, Math.min(1, (v - lo) / (hi - lo)));
        return t <= 0 ? "transparent" : Theme.withAlpha(t > 0.66 ? Theme.error : t > 0.33 ? Theme.warning : Theme.accent, 0.06 + t * 0.2);
    }
    function sortBy(k) { if (k === "status") return; if (sortKey === k) desc = !desc; else { sortKey = k; desc = k !== "name" && k !== "user" && k !== "pid"; } }

    Keys.onPressed: e => {
        if (!sel) return;
        if (e.key === Qt.Key_Delete) { SystemMonitor.endTask(sel, e.modifiers & Qt.ShiftModifier); e.accepted = true; }
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { detailsOpen = true; SystemMonitor.loadDetail(sel.pid); e.accepted = true; }
    }

    // ── mode ──
    Row {
        id: modeRow
        x: Theme.space.s5
        spacing: Theme.space.s3
        Segmented {
            width: 210
            options: [{ id: "grouped", label: "Grouped" }, { id: "flat", label: "All processes" }]
            current: view.flat ? "flat" : "grouped"
            onPicked: id => view.flat = id === "flat"
        }
        LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted
                text: SystemMonitor.groups.apps.length + " apps · " + SystemMonitor.groups.background.length + " background · " + SystemMonitor.groups.system.length + " system" }
    }

    // ── the table ──
    Item {
        id: table
        anchors { top: modeRow.bottom; topMargin: Theme.space.s3; bottom: actions.top; left: parent.left; right: details.left; leftMargin: Theme.space.s3; rightMargin: Theme.space.s3 }
        readonly property real nameW: width - view.fixedW - 16

        // Column heads, with the machine's totals
        Row {
            id: head
            width: parent.width; height: 46
            Repeater {
                model: view.visibleCols
                delegate: HoverTarget {
                    required property var modelData
                    width: modelData.w > 0 ? modelData.w : table.nameW
                    height: head.height; radius: Theme.radius.sm
                    onClicked: view.sortBy(modelData.key)
                    readonly property bool numeric: ["cpu", "mem", "disk", "net", "gpu", "pid", "threads"].includes(modelData.key)
                    Column {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.numeric ? undefined : parent.left; right: parent.numeric ? parent.right : undefined; leftMargin: Theme.space.s3; rightMargin: Theme.space.s2 }
                        LText { anchors.right: parent.parent.numeric ? parent.right : undefined; role: "title"; font.pixelSize: 15
                                visible: !!modelData.total; text: modelData.total ? (SystemMonitor.samples, modelData.total()) : "" }
                        Row {
                            anchors.right: parent.parent.numeric ? parent.right : undefined
                            spacing: 2
                            LText { role: "caption"; color: view.sortKey === modelData.key ? Theme.accent : Theme.textSecondary; text: modelData.label }
                            LIcon { visible: view.sortKey === modelData.key; icon: view.desc ? "arrow_downward" : "arrow_upward"; size: 12; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
        Rectangle { anchors.top: head.bottom; width: parent.width; height: 1; color: Theme.border }

        ListView {
            id: list
            anchors { top: head.bottom; topMargin: 1; bottom: parent.bottom; left: parent.left; right: parent.right }
            clip: true
            model: view.rows
            boundsBehavior: Flickable.StopAtBounds
            reuseItems: true
            QQC.ScrollBar.vertical: QQC.ScrollBar {
                id: sbar; width: 10; padding: 2; background: null
                contentItem: Rectangle { implicitWidth: 4; radius: 2; color: Theme.withAlpha(Theme.text, 0.25); opacity: sbar.active || sbar.hovered ? 1 : 0.35 }
            }
            delegate: Loader {
                required property var modelData
                width: list.width
                sourceComponent: modelData.type === "section" ? sectionC : rowC
                property var d: modelData
            }
        }
        Component {
            id: sectionC
            HoverTarget {
                readonly property var d: parent.d
                height: 36; radius: Theme.radius.sm
                width: parent ? parent.width : 0
                onClicked: { const c = Object.assign({}, view.collapsed); c[d.id] = !c[d.id]; view.collapsed = c; }
                Row {
                    anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter; verticalCenterOffset: 4 }
                    spacing: Theme.space.s1
                    LIcon { icon: view.collapsed[parent.parent.d.id] && view.query.trim() === "" ? "chevron_right" : "expand_more"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "bodyStrong"; color: Theme.textSecondary; text: parent.parent.d.label + " (" + parent.parent.d.count + ")"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
        Component {
            id: rowC
            HoverTarget {
                id: r
                readonly property var g: parent.d.g
                readonly property int depth: parent.d.depth
                readonly property bool isSel: view.selected === g.key
                width: parent ? parent.width : 0
                height: 34; radius: Theme.radius.sm
                onClicked: { view.selected = g.key; view.forceActiveFocus(); }
                onDoubleClicked: { view.selected = g.key; view.detailsOpen = true; SystemMonitor.loadDetail(g.pid); }
                Rectangle { anchors.fill: parent; radius: parent.radius; z: -1
                            color: r.isSel ? Theme.withAlpha(Theme.accent, 0.16) : r.containsMouse ? Theme.withAlpha(Theme.text, 0.04) : "transparent" }
                Row {
                    height: parent.height
                    // Name
                    Item {
                        width: table.nameW; height: parent.height
                        Row {
                            anchors { left: parent.left; leftMargin: Theme.space.s2 + r.depth * 26; right: parent.right; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s2
                            HoverTarget {
                                width: 18; height: 18; radius: 9
                                anchors.verticalCenter: parent.verticalCenter
                                visible: r.depth === 0 && r.g.count > 1 && !view.flat
                                onClicked: { const x = Object.assign({}, view.expanded); x[r.g.key] = !x[r.g.key]; view.expanded = x; }
                                LIcon { anchors.centerIn: parent; icon: view.expanded[r.g.key] ? "expand_more" : "chevron_right"; size: 16; color: Theme.textMuted }
                            }
                            Item { width: 18; height: 18; visible: !(r.depth === 0 && r.g.count > 1 && !view.flat); anchors.verticalCenter: parent.verticalCenter }
                            Image {
                                id: ic
                                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                                anchors.verticalCenter: parent.verticalCenter
                                source: r.depth === 0 ? SystemMonitor.iconFor(r.g) : ""
                                visible: status === Image.Ready
                                asynchronous: true
                            }
                            LIcon { visible: ic.status !== Image.Ready; icon: r.g.kernel ? "memory" : r.depth ? "subdirectory_arrow_right" : "terminal"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            LText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.min(implicitWidth, table.nameW - 90 - r.depth * 26)
                                elide: Text.ElideRight
                                role: r.depth === 0 && r.g.key.startsWith("app:") ? "bodyStrong" : "body"
                                text: r.g.name + (r.depth === 0 && r.g.count > 1 ? "  (" + r.g.count + ")" : "")
                            }
                        }
                    }
                    Cell { visible: view.shown("status"); w: 96; text: r.g.suspended ? "Suspended" : ""; tone: Theme.warning; alignLeft: true }
                    Cell { w: 76; text: r.g.cpu >= 0.05 ? r.g.cpu.toFixed(1) + "%" : "0%"; bg: view.heat(r.g.cpu, 0.5, 40) }
                    Cell { w: 96; text: SystemMonitor.bytes(r.g.mem); bg: view.heat(r.g.mem, 200 * 1048576, 3 * 1073741824) }
                    Cell { visible: view.shown("disk"); w: 96; text: r.g.rd + r.g.wr > 0 ? SystemMonitor.rate(r.g.rd + r.g.wr) : "0"; bg: view.heat(r.g.rd + r.g.wr, 100 * 1024, 60 * 1048576) }
                    Cell { w: 96; text: r.g.net > 0 ? SystemMonitor.bits(r.g.net) : "0"; bg: view.heat(r.g.net, 20 * 1024, 4 * 1048576) }
                    Cell { visible: view.shown("gpu"); w: 70; text: r.g.gpu >= 0.1 ? r.g.gpu.toFixed(1) + "%" : "0%"; bg: view.heat(r.g.gpu, 1, 50) }
                    Cell { visible: view.shown("pid"); w: 86; text: String(r.g.pid); muted: true }
                    Cell { visible: view.shown("user"); w: 96; text: r.g.user; muted: true; alignLeft: true }
                    Cell { visible: view.shown("threads"); w: 70; text: String(r.g.threads); muted: true }
                }
            }
        }
    }
    component Cell: Rectangle {
        property real w: 80
        property string text: ""
        property color tone: Theme.text
        property bool muted: false
        property bool alignLeft: false
        property color bg: "transparent"
        width: w; height: 34
        color: bg
        LText {
            anchors { verticalCenter: parent.verticalCenter; right: parent.alignLeft ? undefined : parent.right; left: parent.alignLeft ? parent.left : undefined; leftMargin: Theme.space.s3; rightMargin: Theme.space.s2 }
            width: Math.min(implicitWidth, parent.width - Theme.space.s3)
            elide: Text.ElideRight
            role: "body"; font.features: { "tnum": 1 }
            color: parent.muted ? Theme.textMuted : parent.tone
            text: parent.text
        }
    }

    // ── actions for the selection ──
    Item {
        id: actions
        anchors { bottom: parent.bottom; left: parent.left; right: details.left; leftMargin: Theme.space.s5; rightMargin: Theme.space.s3 }
        height: 48
        LText {
            anchors { left: parent.left; right: btns.left; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            elide: Text.ElideRight; role: "caption"; color: Theme.textMuted
            text: view.sel ? view.sel.name + " · PID " + view.sel.pid + (view.sel.count > 1 ? " · " + view.sel.count + " processes" : "") + " · " + SystemMonitor.stateName(view.sel.members[0]?.state ?? "")
                           : "Select a process. Delete ends it, Enter shows details."
        }
        Row {
            id: btns
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s2
            enabled: !!view.sel
            opacity: enabled ? 1 : 0.45
            Btn { icon: "info"; text: "Details"; onClicked: { view.detailsOpen = !view.detailsOpen; if (view.detailsOpen && view.sel) SystemMonitor.loadDetail(view.sel.pid); } }
            Btn { icon: view.sel?.suspended ? "play_arrow" : "pause"; text: view.sel?.suspended ? "Resume" : "Suspend"; onClicked: SystemMonitor.suspend(view.sel, !view.sel.suspended) }
            Btn {
                id: endBtn
                property bool armedForce: false
                icon: armedForce ? "dangerous" : "close"
                text: armedForce ? "Force end" : "End task"
                danger: true
                onClicked: { SystemMonitor.endTask(view.sel, armedForce); armedForce = false; }
                onPressAndHold: armedForce = true
            }
            Btn { icon: "dangerous"; text: "Force"; danger: true; visible: !endBtn.armedForce; onClicked: SystemMonitor.endTask(view.sel, true) }
        }
    }
    component Btn: HoverTarget {
        id: b
        property string icon
        property string text
        property bool danger: false
        width: bRow.implicitWidth + 24; height: 34; radius: 17
        Rectangle { anchors.fill: parent; radius: 17; z: -1; color: b.danger ? Theme.withAlpha(Theme.error, b.containsMouse ? 0.22 : 0.12) : Theme.withAlpha(Theme.text, b.containsMouse ? 0.1 : 0.06)
                    border.width: 1; border.color: b.danger ? Theme.withAlpha(Theme.error, 0.4) : Theme.border }
        Row { id: bRow; anchors.centerIn: parent; spacing: 6
              LIcon { icon: b.icon; size: 16; color: b.danger ? Theme.error : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "body"; color: b.danger ? Theme.error : Theme.text; text: b.text; anchors.verticalCenter: parent.verticalCenter } }
    }

    // ── details ──
    Rectangle {
        id: details
        anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
        width: view.detailsOpen && view.sel ? 360 : 0
        clip: true
        color: Theme.withAlpha(Theme.surface, 0.5)
        Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutCubic } }
        Rectangle { anchors { top: parent.top; bottom: parent.bottom; left: parent.left } width: 1; color: Theme.border }
        readonly property var d: SystemMonitor.detail && view.sel && SystemMonitor.detail.pid === view.sel.pid ? SystemMonitor.detail : null
        QQC.ScrollView {
            anchors { fill: parent; margins: Theme.space.s4 }
            contentWidth: availableWidth
            Column {
                width: 328
                spacing: Theme.space.s3
                Item {
                    width: parent.width; height: 28
                    LText { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 34; elide: Text.ElideRight; role: "heading"; text: details.d?.name ?? view.sel?.name ?? "" }
                    IconButton { anchors { right: parent.right; verticalCenter: parent.verticalCenter } icon: "close"; onActivated: view.detailsOpen = false }
                }
                LText { visible: details.d?.ok === false; role: "caption"; color: Theme.error; text: details.d?.error ?? "" }
                // Command line
                Rectangle {
                    width: parent.width; height: cmdText.implicitHeight + 16; radius: Theme.radius.sm
                    color: Theme.withAlpha(Theme.text, 0.05)
                    TextEdit {
                        id: cmdText
                        x: 8; y: 8; width: parent.width - 16
                        readOnly: true; selectByMouse: true; wrapMode: TextEdit.WrapAnywhere
                        color: Theme.textSecondary; font.family: "monospace"; font.pixelSize: 11
                        text: details.d?.cmd || view.sel?.members[0]?.cmd || "(kernel thread)"
                    }
                }
                Row {
                    spacing: Theme.space.s2
                    Btn { icon: "content_copy"; text: "Copy command"; onClicked: Quickshell.execDetached(["wl-copy", cmdText.text]) }
                    Btn { icon: "folder_open"; text: "Location"; visible: !!details.d?.exe
                          onClicked: Quickshell.execDetached(["dbus-send", "--session", "--type=method_call", "--dest=org.freedesktop.FileManager1", "/org/freedesktop/FileManager1", "org.freedesktop.FileManager1.ShowItems", "array:string:file://" + details.d.exe, "string:"]) }
                }
                // Priority
                Column {
                    width: parent.width; spacing: 6
                    LText { role: "caption"; color: Theme.textMuted; text: "PRIORITY"; font.letterSpacing: 1 }
                    Segmented {
                        width: parent.width
                        options: [{ id: "-5", label: "High" }, { id: "0", label: "Normal" }, { id: "10", label: "Low" }, { id: "19", label: "Lowest" }]
                        current: { const n = details.d?.nice ?? 0; return n < 0 ? "-5" : n === 0 ? "0" : n < 15 ? "10" : "19"; }
                        onPicked: id => { SystemMonitor.renice(view.sel.pid, parseInt(id)); Qt.callLater(() => SystemMonitor.loadDetail(view.sel.pid)); }
                    }
                }
                // Facts
                Repeater {
                    model: details.d && details.d.ok ? [
                        ["Status", SystemMonitor.stateName((details.d.state ?? "").charAt(0))],
                        ["User", details.d.user], ["PID · parent", details.d.pid + " · " + details.d.ppid],
                        ["Started", details.d.start ? Qt.formatDateTime(new Date(details.d.start * 1000), "d MMM, " + Theme.timeFormatFull) : "–"],
                        ["CPU time", details.d.cpuTime !== null ? SystemMonitor.duration(details.d.cpuTime) : "–"],
                        ["Memory (resident)", SystemMonitor.bytes(details.d.rss)],
                        ["  private · files · shared", SystemMonitor.bytes(details.d.anon) + " · " + SystemMonitor.bytes(details.d.file) + " · " + SystemMonitor.bytes(details.d.shmem)],
                        ["Swapped out", SystemMonitor.bytes(details.d.swap)], ["Peak", SystemMonitor.bytes(details.d.peak)],
                        ["Virtual", SystemMonitor.bytes(details.d.virt)],
                        ["Threads · open files", details.d.threads + " · " + (details.d.fds ?? "hidden")],
                        ["Context switches", details.d.ctxVoluntary.toLocaleString() + " · " + details.d.ctxInvoluntary.toLocaleString() + " forced"],
                        ["systemd unit", details.d.unit || "–"],
                        ["Working folder", details.d.cwd || "hidden"],
                        ["Program", details.d.exe || "hidden"],
                    ] : []
                    delegate: Column {
                        required property var modelData
                        width: 328
                        LText { role: "caption"; color: Theme.textMuted; text: modelData[0] }
                        LText { width: parent.width; wrapMode: Text.WrapAnywhere; role: "body"; text: modelData[1] }
                    }
                }
                // Listening ports
                Column {
                    visible: (details.d?.ports ?? []).length > 0
                    width: parent.width; spacing: 3
                    LText { role: "caption"; color: Theme.textMuted; text: "LISTENING"; font.letterSpacing: 1 }
                    Repeater { model: details.d?.ports ?? []; delegate: LText { required property var modelData; role: "body"; font.family: "monospace"; text: modelData.proto + "  " + modelData.local } }
                }
                // Children
                Column {
                    visible: (details.d?.children ?? []).length > 0
                    width: parent.width; spacing: 3
                    LText { role: "caption"; color: Theme.textMuted; text: "STARTED " + (details.d?.children ?? []).length + " PROCESSES"; font.letterSpacing: 1 }
                    Repeater {
                        model: (details.d?.children ?? []).slice(0, 12)
                        delegate: HoverTarget {
                            required property var modelData
                            width: 328; height: 24; radius: Theme.radius.sm
                            onClicked: { view.selected = "m:" + modelData.pid; view.flat = true; view.selected = "m:" + modelData.pid; }
                            LText { anchors.verticalCenter: parent.verticalCenter; x: 4; role: "body"; text: modelData.name + "  ·  " + modelData.pid }
                        }
                    }
                }
            }
        }
    }
}
