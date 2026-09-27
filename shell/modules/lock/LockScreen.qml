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

    // Dev only (LUMEN_DEV — set by lumen-session for nested test sessions,
    // never in a real login): unlock without a password, to review the lock
    // screen in a test session.
    IpcHandler {
        target: "lockTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1" && !!Quickshell.env("LUMEN_NESTED")
        function unlock(): void { if (Lock.locked) Lock.succeed(); }
    }
}
