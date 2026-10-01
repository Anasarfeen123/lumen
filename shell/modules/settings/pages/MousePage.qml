// Mouse & touchpad: how the pointer moves and scrolls, the touchpad's taps,
// and typing (repeat, layouts). Each change rebuilds the generated config and
// reloads Hyprland, so it applies at once. Your local.lua still wins.
import QtQuick
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Mouse & touchpad"
    subtitle: "How the pointer moves, how scrolling feels, and how keys repeat. Changes apply immediately."

    readonly property var prefs: Theme.tokens.prefs ?? ({})
    function set(k, v) { SettingsState.lumen(["set", k, v]); }
    function on(k, d) { return (prefs[k] ?? d) === "on"; }

    Group {
        title: "Pointer"
        SetRow {
            icon: "speed"
            title: "Pointer speed"
            description: speed.shown === 0 ? "Default" : (speed.shown > 0 ? "Faster · +" : "Slower · ") + speed.shown
            PrefSlider { id: speed; key: "pointer_speed"; lo: -100; hi: 100; current: Number(page.prefs.pointer_speed ?? 0) }
        }
        SetRow {
            icon: "trending_up"
            title: "Acceleration"
            description: (page.prefs.accel ?? "adaptive") === "flat" ? "Flat: the pointer moves exactly as far as your hand (good for games)"
                                                                     : "Adaptive: quick flicks travel further, slow moves stay precise"
            Segmented {
                width: 220
                options: [{ id: "adaptive", label: "Adaptive" }, { id: "flat", label: "Flat" }]
                current: page.prefs.accel ?? "adaptive"
                onPicked: id => page.set("accel", id)
            }
        }
        SetRow {
            icon: "swap_horiz"
            title: "Left-handed"
            description: "Swap the primary and secondary buttons"
            LSwitch { checked: page.on("left_handed", "off"); onToggled: page.set("left_handed", checked ? "off" : "on") }
        }
    }

    Group {
        title: "Touchpad"
        SetRow {
            icon: "touch_app"
            title: "Tap to click"
            description: "One finger taps to click, two to right-click"
            LSwitch { checked: page.on("tap_click", "on"); onToggled: page.set("tap_click", checked ? "off" : "on") }
        }
        SetRow {
            icon: "swipe_vertical"
            title: "Natural scrolling"
            description: page.on("natural_scroll", "on") ? "Content follows your fingers, like a phone" : "Fingers move the scrollbar"
            LSwitch { checked: page.on("natural_scroll", "on"); onToggled: page.set("natural_scroll", checked ? "off" : "on") }
        }
        SetRow {
            icon: "unfold_more"
            title: "Scroll speed"
            description: scroll.shown + "% · how far one swipe scrolls"
            PrefSlider { id: scroll; key: "scroll_speed"; lo: 25; hi: 200; current: Number(page.prefs.scroll_speed ?? 70) }
        }
        SetRow {
            icon: "keyboard_hide"
            title: "Ignore the touchpad while typing"
            description: "Palms resting on it don't move the pointer or click"
            LSwitch { checked: page.on("dwt", "on"); onToggled: page.set("dwt", checked ? "off" : "on") }
        }
        SetRow {
            icon: "gesture"
            title: "Gestures"
            description: "3 fingers move a window (pinch: fullscreen / float) · 4 fingers switch workspaces, open the overview (pinch: minimise / show) · hold Alt to resize, Super to zoom or open the scratchpad"
            Button { text: "All gestures"; onActivated: SettingsState.shellCall("cheatsheet", "open") }
        }
    }

    Group {
        title: "Typing"
        SetRow {
            icon: "hourglass_top"
            title: "Repeat delay"
            description: delay.shown + " ms before a held key repeats"
            PrefSlider { id: delay; key: "kb_repeat_delay"; lo: 150; hi: 800; current: Number(page.prefs.kb_repeat_delay ?? 250) }
        }
        SetRow {
            icon: "fast_forward"
            title: "Repeat speed"
            description: rate.shown + " characters a second while held"
            PrefSlider { id: rate; key: "kb_repeat_rate"; lo: 10; hi: 80; current: Number(page.prefs.kb_repeat_rate ?? 35) }
        }
        SetRow {
            icon: "language"
            title: "Keyboard layouts"
            description: "Comma-separated, e.g. us or us,in or us,de(nodeadkeys) · with two or more, Alt+Shift switches"
            LField {
                width: 200
                icon: "keyboard"
                clearOnAccept: false
                text: page.prefs.kb_layout ?? "us"
                placeholder: "us"
                onAccepted: t => page.set("kb_layout", t.trim().toLowerCase().replace(/\s+/g, ""))
            }
        }
    }
}
