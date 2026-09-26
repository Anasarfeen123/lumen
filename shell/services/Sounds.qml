pragma Singleton
// Lumen's UI sounds: few, soft, and only where they confirm something you
// did or need to notice. Ocean (KDE's refined theme) first, freedesktop as
// the fallback. Played with pw-play at a low volume; off in Settings, and
// silent while Do Not Disturb / Game mode is on (except critical ones).
//
//   notify      a notification arrives           message-new-instant
//   volume      volume key (throttled, like macOS) audio-volume-change
//   shutter     screenshot taken                  screen-capture / camera-shutter
//   lock/unlock                                   desktop-logout / desktop-login
//   plug        device or charger connected       device-added / power-plug
//   unplug      device or charger removed         device-removed / power-unplug
//   warning     battery low                       battery-low / dialog-warning
import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property bool enabled: Persist.data.uiSounds

    readonly property var map: ({
        notify:  ["ocean/stereo/message-new-instant.oga", "freedesktop/stereo/message-new-instant.oga"],
        volume:  ["ocean/stereo/audio-volume-change.oga", "freedesktop/stereo/audio-volume-change.oga"],
        shutter: ["freedesktop/stereo/screen-capture.oga", "freedesktop/stereo/camera-shutter.oga"],
        lock:    ["ocean/stereo/desktop-logout.oga", "freedesktop/stereo/service-logout.oga"],
        unlock:  ["ocean/stereo/desktop-login.oga", "freedesktop/stereo/service-login.oga"],
        plug:    ["ocean/stereo/device-added.oga", "freedesktop/stereo/device-added.oga"],
        unplug:  ["ocean/stereo/device-removed.oga", "freedesktop/stereo/device-removed.oga"],
        power:   ["freedesktop/stereo/power-plug.oga", "ocean/stereo/device-added.oga"],
        warning: ["ocean/stereo/battery-low.oga", "freedesktop/stereo/dialog-warning.oga"],
        alarm:   ["ocean/stereo/alarm-clock-elapsed.oga", "freedesktop/stereo/alarm-clock-elapsed.oga", "freedesktop/stereo/complete.oga"],
        done:    ["freedesktop/stereo/complete.oga", "ocean/stereo/complete-media-burn.oga"],
    })
    property real lastVolumeSound: 0

    // critical: play even in Do Not Disturb (e.g. battery nearly empty)
    function play(name, critical) {
        if (!enabled) return;
        if (!critical && (Notifications.dnd || GameMode.on)) return;
        if (name === "volume") {
            const now = Date.now();
            if (now - lastVolumeSound < 120) return;       // key repeat → one tick per burst step
            lastVolumeSound = now;
        }
        const files = map[name];
        if (!files) return;
        // First existing file wins; quiet (40 %) and detached
        Quickshell.execDetached(["sh", "-c",
            'for f in "$@"; do [ -r "/usr/share/sounds/$f" ] && exec pw-play --volume 0.4 "/usr/share/sounds/$f"; done', "sh"].concat(files));
    }
}
