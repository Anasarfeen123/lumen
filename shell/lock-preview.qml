//@ pragma UseQApplication
// DEV ONLY — renders the lock surface in an ordinary window so its design can
// be reviewed without locking the session. Run in client mode so it never
// becomes the notification server:
//   LUMEN_SETTINGS_APP=1 qs -p ~/.config/lumen/shell/lock-preview.qml
import QtQuick
import Quickshell
import qs.modules.lock

FloatingWindow {
    title: "Lumen lock preview"
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"
    LockSurface { anchors.fill: parent; screenName: "" }
}
