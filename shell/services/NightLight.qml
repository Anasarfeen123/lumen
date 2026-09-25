pragma Singleton

// Night light via hyprsunset. The process exists only while night light is
// on; stopping it hands the screen back to normal colours.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

Singleton {
    id: root
    readonly property bool enabled: Persist.data.nightLight
    readonly property int temperature: Persist.data.nightLightTemp

    function toggle() { Persist.data.nightLight = !Persist.data.nightLight; }

    // Restarted automatically if it dies (e.g. across suspend/resume)
    SupervisedProcess {
        wanted: root.enabled
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
}
