// Display: screens (layout, resolution, refresh, scale), brightness, night light.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Display"

    // ── Screens: drag them into place, pick a mode and a scale; Apply sets it
    // live and asks to keep it (15 s, then it goes back by itself) ──
    property var screens: []            // the edited layout: { name, desc, mode, modes, x, y, scale, w, h }
    property var original: []           // as it was, for Revert
    property int selected: 0
    property int keepLeft: 0            // > 0: waiting for "Keep these settings?"
    readonly property bool dirty: JSON.stringify(screens.map(m => [m.mode, m.x, m.y, m.scale])) !== JSON.stringify(original.map(m => [m.mode, m.x, m.y, m.scale]))
    function layoutJson(list) { return JSON.stringify(list.map(m => ({ name: m.name, mode: m.mode, x: m.x, y: m.y, scale: m.scale }))); }
    function setScreen(i, patch) { const a = screens.slice(); a[i] = Object.assign({}, a[i], patch); screens = a; }
    function dims(m) { const r = /^(\d+)x(\d+)/.exec(m.mode); return { w: (r ? +r[1] : m.w) / m.scale, h: (r ? +r[2] : m.h) / m.scale }; }
    // edges snap together: put screen i next to the nearest edge of another
    function snap(i) {
        const me = screens[i], d = dims(me);
        let best = null;
        for (let j = 0; j < screens.length; j++) {
            if (j === i) continue;
            const o = screens[j], od = dims(o);
            const cands = [{ x: o.x + od.w, y: me.y }, { x: o.x - d.w, y: me.y }, { x: me.x, y: o.y + od.h }, { x: me.x, y: o.y - d.h }];
            for (const c of cands) {
                // keep it touching: align to the other screen's top or left when close
                if (c.x !== me.x) c.y = Math.abs(me.y - o.y) < 120 ? o.y : Math.max(o.y - d.h + 40, Math.min(me.y, o.y + od.h - 40));
                else c.x = Math.abs(me.x - o.x) < 120 ? o.x : Math.max(o.x - d.w + 40, Math.min(me.x, o.x + od.w - 40));
                const dist = Math.hypot(c.x - me.x, c.y - me.y);
                if (!best || dist < best.dist) best = { x: Math.round(c.x), y: Math.round(c.y), dist };
            }
        }
        if (best) setScreen(i, { x: best.x, y: best.y });
    }
    Process {
        id: lister
        running: true
        command: [Theme.lumenRoot + "/scripts/monitors.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                let l = []; try { l = JSON.parse(text); } catch (e) {}
                const s = l.filter(m => !m.disabled).map(m => {
                    const cur = m.width + "x" + m.height + "@" + m.refresh;
                    const mode = m.modes.find(x => x === cur) ?? m.modes.find(x => x.startsWith(m.width + "x" + m.height + "@")) ?? cur;
                    return { name: m.name, desc: m.description, mode, modes: m.modes, x: m.x, y: m.y, scale: m.scale, w: m.width, h: m.height };
                });
                page.screens = s; page.original = s.map(m => Object.assign({}, m));
            }
        }
    }
    Process { id: applier; onExited: code => { if (code !== 0) Island.system("monitor", "Couldn't change the screens", "Nothing was kept", "warning"); } }
    function apply() { applier.command = [Theme.lumenRoot + "/scripts/monitors.py", "apply", layoutJson(screens)]; applier.running = true; keepLeft = 15; }
    function keep() { keepLeft = 0; applier.command = [Theme.lumenRoot + "/scripts/monitors.py", "save", layoutJson(screens)]; applier.running = true; original = screens.map(m => Object.assign({}, m)); }
    function revert() { keepLeft = 0; screens = original.map(m => Object.assign({}, m)); applier.command = [Theme.lumenRoot + "/scripts/monitors.py", "apply", layoutJson(original)]; applier.running = true; }
    Timer { running: page.keepLeft > 0; repeat: true; interval: 1000; onTriggered: { page.keepLeft--; if (page.keepLeft === 0) page.revert(); } }

    Group {
        title: "Screens"
        // the map
        Item {
            id: map
            width: parent.width; height: 210
            readonly property var box: {
                let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
                for (const m of page.screens) { const d = page.dims(m); x0 = Math.min(x0, m.x); y0 = Math.min(y0, m.y); x1 = Math.max(x1, m.x + d.w); y1 = Math.max(y1, m.y + d.h); }
                return page.screens.length ? { x0, y0, w: x1 - x0, h: y1 - y0 } : { x0: 0, y0: 0, w: 1, h: 1 };
            }
            // room to drag around: the layout at most half the map's width
            readonly property real k: Math.min(width * 0.5 / box.w, (height - 30) * 0.8 / box.h)
            readonly property real ox: (width - box.w * k) / 2
            readonly property real oy: (height - box.h * k) / 2
            Rectangle { anchors.fill: parent; radius: Theme.radius.md; color: Theme.withAlpha(Theme.text, 0.04); border.width: 1; border.color: Theme.border }
            Repeater {
                model: page.screens
                Rectangle {
                    id: scr
                    required property var modelData
                    required property int index
                    readonly property var d: page.dims(modelData)
                    x: ma.drag.active ? x : map.ox + (modelData.x - map.box.x0) * map.k
                    y: ma.drag.active ? y : map.oy + (modelData.y - map.box.y0) * map.k
                    width: d.w * map.k; height: d.h * map.k
                    radius: 8
                    color: index === page.selected ? Theme.withAlpha(Theme.accent, 0.28) : Theme.withAlpha(Theme.text, 0.1)
                    border.width: index === page.selected ? 2 : 1
                    border.color: index === page.selected ? Theme.accent : Theme.border
                    Behavior on x { enabled: !scr.dragging; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                    Behavior on y { enabled: !scr.dragging; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                    readonly property bool dragging: ma.drag.active
                    Column {
                        anchors.centerIn: parent
                        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "bodyStrong"; text: scr.modelData.name }
                        LText { anchors.horizontalCenter: parent.horizontalCenter; role: "caption"; color: Theme.textMuted; text: scr.modelData.mode.replace("@", " · ") + " Hz" }
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        cursorShape: page.screens.length > 1 ? Qt.SizeAllCursor : Qt.PointingHandCursor
                        drag.target: page.screens.length > 1 ? scr : null
                        onPressed: page.selected = scr.index
                        onReleased: if (page.screens.length > 1) {
                            page.setScreen(scr.index, { x: Math.round((scr.x - map.ox) / map.k + map.box.x0), y: Math.round((scr.y - map.oy) / map.k + map.box.y0) });
                            page.snap(scr.index);
                        }
                    }
                }
            }
            LText { anchors { left: parent.left; bottom: parent.bottom; margins: 8 } role: "caption"; color: Theme.textMuted
                    text: page.screens.length > 1 ? "Drag a screen to where it sits on your desk; edges snap together" : "Plug in another screen to arrange them" }
        }
        SetRow {
            readonly property var cur: page.screens[page.selected] ?? null
            icon: "aspect_ratio"
            title: "Resolution and refresh rate"
            description: cur ? cur.name + (cur.desc ? " · " + cur.desc : "") : ""
            LDropdown {
                width: 220
                options: (parent.cur?.modes ?? []).map(m => ({ id: m, label: m.replace("@", " · ") + " Hz" }))
                current: parent.cur?.mode ?? ""
                onPicked: id => page.setScreen(page.selected, { mode: id })
            }
        }
        SetRow {
            icon: "zoom_in"
            title: "Scale"
            description: "Bigger text and controls; 1 is sharpest"
            Segmented {
                width: 260
                options: [{ id: "1", label: "100%" }, { id: "1.25", label: "125%" }, { id: "1.5", label: "150%" }, { id: "2", label: "200%" }]
                current: String(page.screens[page.selected]?.scale ?? 1)
                onPicked: id => page.setScreen(page.selected, { scale: Number(id) })
            }
        }
        SetRow {
            icon: page.keepLeft > 0 ? "timer" : "check"
            title: page.keepLeft > 0 ? "Keep these settings?" : "Apply"
            description: page.keepLeft > 0 ? "Going back in " + page.keepLeft + " s" : page.dirty ? "Changes take effect right away; you get 15 seconds to keep them" : "Nothing changed"
            Row {
                spacing: Theme.space.s2
                Repeater {
                    model: page.keepLeft > 0 ? [{ id: "keep", label: "Keep" }, { id: "revert", label: "Go back" }] : [{ id: "apply", label: "Apply" }]
                    HoverTarget {
                        required property var modelData
                        enabled: modelData.id !== "apply" || page.dirty
                        opacity: enabled ? 1 : 0.4
                        width: lb.implicitWidth + 28; height: 32; radius: 16
                        onClicked: modelData.id === "keep" ? page.keep() : modelData.id === "revert" ? page.revert() : page.apply()
                        Rectangle { anchors.fill: parent; radius: 16; z: -1; color: modelData.id === "revert" ? "transparent" : Theme.accent; border.width: 1; border.color: modelData.id === "revert" ? Theme.border : Theme.accent }
                        LText { id: lb; anchors.centerIn: parent; role: "bodyStrong"; text: modelData.label; color: modelData.id === "revert" ? Theme.text : Theme.onAccent }
                    }
                }
            }
        }
    }

    Group {
        title: "Brightness"
        SetRow {
            icon: "brightness_6"
            title: "Screen brightness"
            LSlider { width: 260; icon: "light_mode"; value: Brightness.value; onMoved: v => Brightness.set(v) }
        }
    }

    Group {
        title: "Night light"
        SetRow {
            icon: "nightlight"
            title: "Night light"
            description: "Warmer colours to ease your eyes in the evening"
            // Writes the preference; the main shell's NightLight service runs hyprsunset
            LSwitch { checked: Persist.data.nightLight; onToggled: Persist.data.nightLight = !checked }
        }
        SetRow {
            icon: "thermostat"
            title: "Warmth"
            description: Persist.data.nightLightTemp + " K"
            LSlider {
                width: 260
                icon: "wb_sunny"
                // 6500 K (neutral) → 2500 K (very warm), left to right
                value: (6500 - Persist.data.nightLightTemp) / 4000
                onMoved: v => Persist.data.nightLightTemp = Math.round((6500 - v * 4000) / 100) * 100
            }
        }
        SetRow {
            icon: "wb_twilight"
            title: "Automatically"
            description: Persist.data.nightLightAuto === "sun"
                ? "On at sunset (" + Qt.formatTime(Sun.sunset, Theme.timeFormatFull) + "), off at sunrise (" + Qt.formatTime(Sun.sunrise, Theme.timeFormatFull) + ")"
                  + (Sun.known ? "" : " — set your city in the left sidebar for exact times")
                : Persist.data.nightLightAuto === "custom" ? "On and off at the hours you choose" : "Only when you switch it"
            Segmented {
                width: 340
                options: [{ id: "off", label: "Off" }, { id: "sun", label: "Sunset → sunrise" }, { id: "custom", label: "Custom" }]
                current: Persist.data.nightLightAuto ?? "off"
                onPicked: id => Persist.data.nightLightAuto = id
            }
        }
        SetRow {
            visible: Persist.data.nightLightAuto === "custom"
            icon: "schedule"
            title: "Hours"
            Row {
                spacing: Theme.space.s2
                LField { width: 78; clearOnAccept: false; text: Persist.data.nightLightFrom
                         onAccepted: t => { if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(t.trim())) Persist.data.nightLightFrom = t.trim(); else text = Persist.data.nightLightFrom; } }
                LText { text: "to"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                LField { width: 78; clearOnAccept: false; text: Persist.data.nightLightTo
                         onAccepted: t => { if (/^([01]?\d|2[0-3]):[0-5]\d$/.test(t.trim())) Persist.data.nightLightTo = t.trim(); else text = Persist.data.nightLightTo; } }
            }
        }
        SetRow {
            icon: "palette"
            title: "Not in colour work"
            description: "Night light steps aside while one of these apps is the window you're using" + (NightLight.excepted ? " — paused now" : "")
            LField {
                width: 300; clearOnAccept: false
                text: (Persist.data.nightLightExcept ?? []).join(", ")
                placeholder: "gimp, krita, inkscape…"
                onAccepted: t => Persist.data.nightLightExcept = t.split(",").map(x => x.trim().toLowerCase()).filter(x => x)
            }
        }
    }
}
