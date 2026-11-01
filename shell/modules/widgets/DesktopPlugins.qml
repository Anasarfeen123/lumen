// Your desktop widgets (kind "desktop", services/Widgets.qml): a column on the
// wallpaper, top-right, below the windows. Only the widgets themselves take
// clicks; the rest of the wallpaper stays the wallpaper.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.theme
import qs.services

PanelWindow {
    id: win
    visible: Widgets.desktop.length > 0
    anchors { top: true; right: true; bottom: true }
    implicitWidth: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-desktop-plugins"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: col }

    Column {
        id: col
        x: win.width - width - 40
        y: Theme.barHeight + 48
        width: 320
        spacing: Theme.space.s4
        Repeater {
            model: Widgets.desktop
            WidgetHost { required property var modelData; widget: modelData; width: col.width; live: !Lock.locked }
        }
    }
}
