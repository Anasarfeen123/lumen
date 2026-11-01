pragma Singleton
// lumen.toml (scripts/lumen-config.py): every setting in one readable file,
// kept in step with Settings both ways while the shell runs. Not in a test
// session (that one has its own settings file).
import QtQuick
import Quickshell
import qs.theme
import qs.components

Singleton {
    id: root
    readonly property bool on: Quickshell.env("LUMEN_NESTED") !== "1"
    SupervisedProcess {
        wanted: root.on
        command: [Theme.lumenRoot + "/scripts/lumen-config.py", "watch"]
    }
}
