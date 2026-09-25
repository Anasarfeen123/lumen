// Face ID (Gaze). Scope is deliberate: the Lumen lock screen only — never
// sudo, admin prompts or login — and your password always works.
//
// Enrolment is Gaze's own guided multi-angle capture from the live camera
// (`gaze add-face`); it opens in a small terminal because it needs your
// admin password (polkit) and shows its own camera guidance.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Face ID"
    subtitle: "Unlock the lock screen by looking at the camera. Your password always works too."

    property bool installed: false
    property bool running: false
    property var faces: []            // enrolled face names
    property string testResult: ""    // "" | testing | ok | fail
    // Gaze's liveness settings (read-only here; changed via gaze-admin.sh + pkexec)
    property bool livenessOn: true
    property real threshold: 0.8
    property bool diagnostics: false
    property bool applying: false
    readonly property string helper: Theme.lumenRoot + "/scripts/gaze-admin.sh"
    // Calibration result
    property var calib: null          // { frames, median, p75, best, above, luma, passed }
    property bool calibrating: false
    property real calibStart: 0
    readonly property bool ready: installed && running && faces.length > 0

    function refresh() { probe.running = true; }
    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) refresh()
    Timer { interval: 3000; repeat: true; running: page.visible; onTriggered: page.refresh() }

    Process {
        id: probe
        command: ["sh", "-c", "command -v gaze >/dev/null && echo installed; systemctl is-active -q gazed && echo running; " +
                  "{ [ -e /etc/systemd/system/gazed.service.d/lumen-debug.conf ] || [ -e /etc/systemd/system/gazed.service.d/debug.conf ]; } && echo diagnostics; " +
                  "sed -n '/^\\[liveness\\]/,/^\\[/p' /etc/gaze/config.toml 2>/dev/null | sed 's/^/cfg:/'; gaze list-faces 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                page.installed = lines.includes("installed");
                page.running = lines.includes("running");
                page.diagnostics = lines.includes("diagnostics");
                for (const l of lines) {
                    const m = l.match(/^cfg:(enabled|threshold) = (.+)$/);
                    if (!m) continue;
                    if (m[1] === "enabled") page.livenessOn = m[2].trim() === "true";
                    else page.threshold = parseFloat(m[2]);
                }
                // Face rows look like "  • default [RGB] [IR] (10 captures)"
                page.faces = lines.map(l => l.replace(/\x1b\[[0-9;]*m/g, ""))
                                  .filter(l => /\[(RGB|IR)\]/.test(l))
                                  .map(l => l.replace(/^[^A-Za-z0-9_.-]+/, "").split(/\s+/)[0])
                                  .filter(n => n !== "");
            }
        }
    }

    function inTerminal(title, cmd) {
        Quickshell.execDetached(["kitty", "--class", "lumen-faceid", "--title", title, "sh", "-c",
            cmd + "; echo; printf 'Press Enter to close… '; read _"]);
    }

    // Root changes: pkexec asks for your admin password every time
    Process {
        id: admin
        onExited: { page.applying = false; page.refresh(); }
    }
    function adminSet(args) {
        if (admin.running) return;
        page.applying = true;
        admin.command = ["pkexec", page.helper].concat(args);
        admin.running = true;
    }

    // Calibrate: one real face check, then read what gazed measured
    Process {
        id: calibAuth
        command: ["gaze", "auth", "--silent"]
        onExited: code => { calibRead.passed = code === 0; calibRead.running = true; }
    }
    Process {
        id: calibRead
        property bool passed: false
        command: ["sh", "-c", 'journalctl -u gazed --since "@$1" --no-pager -o cat 2>/dev/null | sed "s/\\x1b\\[[0-9;]*m//g" | grep -oE "computed score: [0-9.]+|mean_luma=[0-9]+"',
                  "sh", String(Math.floor(page.calibStart))]
        stdout: StdioCollector {
            onStreamFinished: {
                const scores = [], lumas = [];
                for (const l of text.split("\n")) {
                    let m = l.match(/computed score: ([0-9.]+)/); if (m) scores.push(parseFloat(m[1]));
                    m = l.match(/mean_luma=([0-9]+)/); if (m) lumas.push(parseInt(m[1]));
                }
                scores.sort((a, b) => a - b);
                const pick = f => scores.length ? scores[Math.min(scores.length - 1, Math.floor(scores.length * f))] : 0;
                page.calib = {
                    frames: scores.length,
                    median: pick(0.5), p75: pick(0.75), best: scores.length ? scores[scores.length - 1] : 0,
                    above: scores.length ? scores.filter(x => x >= page.threshold).length / scores.length : 0,
                    luma: lumas.length ? Math.round(lumas.reduce((a, b) => a + b, 0) / lumas.length) : -1,
                    passed: calibRead.passed
                };
                page.calibrating = false;
            }
        }
    }
    function calibrate() {
        page.calib = null;
        page.calibrating = true;
        page.calibStart = Date.now() / 1000 - 1;
        calibAuth.running = true;
    }
    // Suggested strictness: a little below your typical (75th-percentile) score
    readonly property real suggested: calib && calib.frames > 0 ? Math.max(0.05, Math.floor(calib.p75 * 20) / 20) : 0

    Process {
        id: tester
        command: ["gaze", "auth", "--silent"]
        onExited: code => page.testResult = code === 0 ? "ok" : "fail"
    }

    // ── Status ──
    Group {
        title: "Status"
        SetRow {
            icon: page.installed ? "check_circle" : "cancel"
            title: "Gaze"
            description: page.installed ? "Installed" : "Not installed — sudo dnf install gaze gaze-hyprlock"
        }
        SetRow {
            icon: page.running ? "check_circle" : "error"
            title: "Face service (gazed)"
            description: page.running ? "Running" : "Stopped — run this once in a terminal:  sudo systemctl enable --now gazed"
            Button {
                visible: !page.running && page.installed
                icon: "content_copy"; text: "Copy command"
                onActivated: Quickshell.execDetached(["wl-copy", "sudo systemctl enable --now gazed"])
            }
        }
        SetRow {
            icon: page.faces.length > 0 ? "check_circle" : "radio_button_unchecked"
            title: "Your face"
            description: page.faces.length > 0 ? page.faces.length + (page.faces.length === 1 ? " look enrolled" : " looks enrolled") : "Not set up yet"
        }
    }

    // ── Set up / manage ──
    Group {
        title: "Looks"
        visible: page.installed && page.running
        Repeater {
            model: page.faces
            delegate: SetRow {
                required property string modelData
                icon: "face"
                title: modelData
                description: "Used on the lock screen"
                Row {
                    spacing: Theme.space.s2
                    Button { icon: "auto_fix_high"; text: "Improve"; onActivated: page.inTerminal("Face ID — improve", "gaze refine-face " + modelData) }
                    Button { icon: "delete"; text: "Remove"; onActivated: page.inTerminal("Face ID — remove", "gaze remove-face " + modelData) }
                }
            }
        }
        SetRow {
            icon: "add_a_photo"
            title: page.faces.length === 0 ? "Set up Face ID" : "Add another look"
            description: page.faces.length === 0
                ? "A short guided scan: look at the camera and slowly turn your head as asked"
                : "e.g. with glasses, or in different light — each look is a separate profile"
            Button {
                primary: true
                text: page.faces.length === 0 ? "Set up" : "Add look"
                onActivated: page.inTerminal("Face ID — set up",
                    "gaze add-face " + (page.faces.length === 0 ? "default" : "look" + (page.faces.length + 1)))
            }
        }
        SetRow {
            visible: page.faces.length > 0
            icon: page.testResult === "ok" ? "verified" : page.testResult === "fail" ? "gpp_bad" : "center_focus_strong"
            title: "Test recognition"
            description: page.testResult === "testing" ? "Look at the camera…"
                       : page.testResult === "ok" ? "Recognised ✓"
                       : page.testResult === "fail" ? "Not recognised — try Improve, or add a look for this light"
                       : "Runs a real face check, including the anti-photo test"
            Row {
                spacing: Theme.space.s2
                Button {
                    text: page.testResult === "testing" ? "Testing…" : "Test"
                    enabled: page.testResult !== "testing"
                    onActivated: { page.testResult = "testing"; tester.running = true; }
                }
                // Gaze's own view with per-step scores (match %, liveness)
                Button { icon: "query_stats"; text: "Details"; onActivated: page.inTerminal("Face ID — details", "gaze auth --verbose") }
            }
        }
    }

    // ── Calibrate ──
    Group {
        title: "Calibrate"
        visible: page.installed && page.running && page.faces.length > 0
        SetRow {
            icon: "center_focus_weak"
            title: "Check light and liveness"
            description: page.calibrating ? "Look at the camera…"
                : "Runs one real scan and shows what the camera saw" + (page.diagnostics ? "" : " — turn on Diagnostics below to see liveness scores")
            Button { primary: true; text: page.calibrating ? "Scanning…" : "Calibrate"; enabled: !page.calibrating; onActivated: page.calibrate() }
        }
        SetRow {
            visible: page.calib !== null
            icon: page.calib && page.calib.luma >= 70 ? "light_mode" : "dark_mode"
            title: page.calib ? (page.calib.luma < 0 ? "Light: not measured"
                                 : "Light: " + page.calib.luma + " / 255" + (page.calib.luma < 50 ? " — too dark" : page.calib.luma < 70 ? " — dim" : " — good")) : ""
            description: page.calib && page.calib.luma >= 0 && page.calib.luma < 70
                ? "Face a lamp or a bright screen; avoid a window behind you. Light helps liveness more than anything else." : "Your face is lit well enough."
        }
        SetRow {
            visible: page.calib !== null
            icon: page.calib && page.calib.passed ? "verified" : "gpp_maybe"
            title: page.calib ? (page.calib.passed ? "Recognised and confirmed live ✓" : "Not unlocked this time") : ""
            description: {
                const c = page.calib;
                if (!c) return "";
                if (c.frames === 0) return page.diagnostics ? "No liveness scores were logged — try again." : "Turn on Diagnostics to see why.";
                return "Liveness — typical " + c.median.toFixed(2) + ", best " + c.best.toFixed(2) + ", threshold " + page.threshold.toFixed(2)
                     + " · " + Math.round(c.above * 100) + "% of frames passed.";
            }
        }
        SetRow {
            visible: page.calib !== null && page.calib.frames > 0 && !page.calib.passed && page.suggested < page.threshold
            icon: "tips_and_updates"
            title: "Suggested strictness: " + page.suggested.toFixed(2)
            description: page.suggested <= 0.15
                ? "That low, the anti-photo check barely protects anything. Better light first — or turn the check off knowingly."
                : "Just below your typical score, so you pass most scans. A little easier to fool with a photo."
            Button { text: "Use " + page.suggested.toFixed(2); enabled: !page.applying; onActivated: page.adminSet(["threshold", page.suggested.toFixed(2)]) }
        }
    }

    // ── Anti-photo check ──
    Group {
        title: "Anti-photo check (liveness)"
        visible: page.installed
        SetRow {
            icon: "shield_person"
            title: "Check that it's really you, not a photo"
            description: page.livenessOn
                ? "On. On a normal webcam this needs good light; if it never passes, try Calibrate."
                : "Off — a photo of you could unlock the screen. Your password still always works."
            LSwitch { checked: page.livenessOn; enabled: !page.applying; onToggled: page.adminSet(["liveness", checked ? "off" : "on"]) }
        }
        SetRow {
            visible: page.livenessOn
            icon: "tune"
            title: "Strictness"
            description: "Now " + page.threshold.toFixed(2) + ". Stricter blocks more spoofs but needs a clearer, brighter picture."
            Segmented {
                width: 300
                options: [{ id: "0.8", label: "Strict" }, { id: "0.5", label: "Balanced" }, { id: "0.3", label: "Relaxed" }]
                current: page.threshold >= 0.75 ? "0.8" : page.threshold >= 0.45 ? "0.5" : page.threshold >= 0.25 ? "0.3" : ""
                onPicked: id => page.adminSet(["threshold", id])
            }
        }
        SetRow {
            icon: "monitoring"
            title: "Diagnostics"
            description: "Logs per-frame liveness scores so Calibrate can show them. Turn off when done."
            LSwitch { checked: page.diagnostics; enabled: !page.applying; onToggled: page.adminSet(["debug", checked ? "off" : "on"]) }
        }
        SetRow {
            icon: "admin_panel_settings"
            title: "Changes ask for your admin password"
            description: "They edit Gaze's system settings (/etc/gaze/config.toml, [liveness] only); a backup of the original is kept."
        }
    }

    // ── Tips ──
    Group {
        title: "Tips"
        visible: page.faces.length > 0
        SetRow { icon: "light_mode"; title: "Light your face"; description: "The most common cause of failures is a dim room or a bright window behind you." }
        SetRow { icon: "keyboard"; title: "On battery, press F2"; description: "To save power, the camera only starts automatically on AC. On battery, press F2 on the lock screen." }
    }

    // ── How it's protected ──
    Group {
        title: "How it works"
        SetRow { icon: "lock"; title: "Lock screen only"; description: "Never used for sudo, admin prompts or logging in. Your password always works." }
        SetRow { icon: "videocam"; title: "Starts when you're there"; description: "On AC: after you touch a key or the pointer, or open the lid — not in the first seconds after you lock. On battery: only when you press F2." }
        SetRow { icon: "shield"; title: "Anti-photo check"; description: "Gaze checks liveness. On a normal webcam (no infrared), a good video or mask could still fool it — keep it for convenience, not high security." }
        SetRow { icon: "memory"; title: "Stays on this laptop"; description: "Face data never leaves the machine." }
    }
}
