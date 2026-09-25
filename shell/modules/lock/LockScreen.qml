// The lock: an ext-session-lock covering every screen (see services/Lock.qml
// for the security model). Triggered by Super+L, the power menu, hypridle
// (idle / before sleep) via `qs … ipc call lock lock`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

Scope {
    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface
            color: "black"
            LockSurface { anchors.fill: parent; screenName: surface.screen?.name ?? "" }
        }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { Lock.lock(); }
        function isLocked(): bool { return Lock.locked; }
        // After resume (hypridle after_sleep_cmd): lid opened → try Face ID at once
        function wake(): void { Lock.wake(); }
    }

    GlobalShortcut { appid: "lumen"; name: "lock"; description: "Lock the screen"; onPressed: Lock.lock() }
}
