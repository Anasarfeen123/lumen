pragma Singleton
// Game mode: everything that costs frames goes away — animations, blur,
// shadows, gaps, rounding — and notifications hold (Do Not Disturb). Turning
// it off reloads the normal config, which restores all of it.
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool on: false
    property bool dndBefore: false

    function toggle() {
        on = !on;
        if (on) {
            dndBefore = Notifications.dnd;
            Notifications.setDnd(true);
            Quickshell.execDetached(["hyprctl", "--batch",
                "keyword animations:enabled 0; keyword decoration:blur:enabled 0; keyword decoration:shadow:enabled 0; " +
                "keyword general:gaps_in 0; keyword general:gaps_out 0; keyword general:border_size 1; keyword decoration:rounding 0"]);
        } else {
            Notifications.setDnd(dndBefore);
            Quickshell.execDetached(["hyprctl", "reload"]);
        }
        Island.system(on ? "sports_esports" : "sports_esports", on ? "Game mode on" : "Game mode off",
                      on ? "Effects off · notifications held" : "Effects restored");
    }
}
