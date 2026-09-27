// Lock screen: widgets, Face ID shortcut, what locks it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Lock screen"
    readonly property string lockAfter: (Theme.tokens.idle ?? {}).lock ?? "5"
    subtitle: "Super+L locks. " + (lockAfter === "never" ? "It" : "It also locks after " + lockAfter + " minutes idle and")
              + " always locks before sleep."

    // Profile picture (~/.face): a version counter busts the image cache
    property int faceVersion: 0
    readonly property string facePath: Quickshell.env("HOME") + "/.face"
    Process { id: avatar; onExited: faceVersion++ }

    Group {
        title: "You"
        SetRow {
            title: Quickshell.env("USER")
            description: "Your picture on the lock screen"
            leading: Item {
                width: 44; height: 44
                Rectangle {
                    anchors.fill: parent; radius: 22
                    color: Theme.withAlpha(Theme.accent, 0.85)
                    visible: pic.status !== Image.Ready
                    LText { anchors.centerIn: parent; role: "heading"; color: Theme.onAccent
                            text: (Quickshell.env("USER") ?? "?").charAt(0).toUpperCase() }
                }
                ClippingRectangle {
                    anchors.fill: parent
                    radius: 22
                    color: "transparent"
                    visible: pic.status === Image.Ready
                    Image {
                        id: pic
                        anchors.fill: parent
                        source: "file://" + facePath + "?v=" + faceVersion
                        cache: false
                        sourceSize: Qt.size(88, 88)
                        fillMode: Image.PreserveAspectCrop
                    }
                }
            }
            Row {
                spacing: Theme.space.s2
                Button { text: "Choose picture…"; onActivated: { avatar.command = [Theme.lumenRoot + "/scripts/avatar.sh", "pick"]; avatar.running = true; } }
                Button { text: "Remove"; visible: pic.status === Image.Ready
                         onActivated: { avatar.command = [Theme.lumenRoot + "/scripts/avatar.sh", "remove"]; avatar.running = true; } }
            }
        }
    }

    Group {
        title: "Widgets"
        SetRow { icon: "music_note"; title: "Now playing"; description: "Artwork and controls while music plays"
                 LSwitch { checked: Persist.data.lockMedia; onToggled: Persist.data.lockMedia = !checked } }
        SetRow { icon: "battery_full"; title: "Battery"; description: "Charge ring and time remaining"
                 LSwitch { checked: Persist.data.lockBattery; onToggled: Persist.data.lockBattery = !checked } }
        SetRow { icon: "calendar_month"; title: "Calendar"; description: "This month"
                 LSwitch { checked: Persist.data.lockCalendar; onToggled: Persist.data.lockCalendar = !checked } }
        SetRow { icon: "notifications"; title: "Notifications"; description: "A count and app names only — never their content"
                 LSwitch { checked: Persist.data.lockNotifications; onToggled: Persist.data.lockNotifications = !checked } }
        SetRow { icon: "smartphone"; title: "Phone"; description: "Your phone's battery and whether it's linked (Lumen Link)"
                 LSwitch { checked: Persist.data.lockPhone; onToggled: Persist.data.lockPhone = !checked } }
        SetRow { icon: "forum"; title: "Messages"; description: "How many unread chats — counts only, never names or messages"
                 LSwitch { checked: Persist.data.lockMessages; onToggled: Persist.data.lockMessages = !checked } }
    }

    Group {
        title: "Unlocking"
        SetRow {
            icon: "face"
            title: "Face ID"
            description: "Set up, calibrate and adjust the anti-photo check"
            Button { text: "Open Face ID"; onActivated: SettingsState.page = "faceid" }
        }
        SetRow { icon: "password"; title: "Password"; description: "Always works, whatever Face ID does" }
    }
}
