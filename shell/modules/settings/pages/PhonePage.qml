// Phone (Lumen Connect): pair your phone once, then find it, send files and
// your clipboard, see its battery, get its notifications. Built on KDE
// Connect — the app is free on Android (F-Droid / Play) and iOS.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Phone"
    subtitle: "Lumen Connect: your phone and this computer, on the same Wi-Fi. Files, clipboard, battery, notifications and media — nothing goes through the internet."
    Component.onCompleted: { Connect.watching = true; Quickshell.execDetached([Connect.script, "refresh"]); Connect.refresh(); }
    Component.onDestruction: Connect.watching = false

    Group {
        title: "Your devices"
        visible: Connect.available
        Repeater {
            model: Connect.devices
            delegate: SetRow {
                required property var modelData
                icon: modelData.type === "tablet" ? "tablet_android" : modelData.type === "desktop" || modelData.type === "laptop" ? "computer" : "smartphone"
                title: modelData.name
                description: !modelData.paired ? "Nearby — not paired"
                    : (modelData.reachable ? "Connected" : "Paired · not nearby")
                      + (modelData.battery >= 0 ? " · " + modelData.battery + "%" + (modelData.charging ? " charging" : "") : "")
                Row {
                    spacing: Theme.space.s2
                    Button { visible: modelData.paired && modelData.reachable; icon: "phone_in_talk"; text: "Find"; onActivated: Connect.act("ring", modelData.id) }
                    Button { visible: modelData.paired && modelData.reachable; icon: "upload_file"; text: "Send file"; onActivated: Connect.act("pick-and-share", modelData.id) }
                    Button { primary: !modelData.paired; text: modelData.paired ? "Unpair" : "Pair"; onActivated: Connect.act(modelData.paired ? "unpair" : "pair", modelData.id) }
                }
            }
        }
        SetRow {
            visible: Connect.devices.length === 0
            icon: "wifi_find"
            title: "Looking for devices…"
            description: "Open KDE Connect on your phone, on the same Wi-Fi as this computer"
            Button { icon: "refresh"; text: "Search again"; onActivated: { Quickshell.execDetached([Connect.script, "refresh"]); Connect.refresh(); } }
        }
    }

    Group {
        title: "Set up (once)"
        SetRow { icon: "download"; title: "1 · Install KDE Connect on your phone"; description: "Free on Android (F-Droid or Google Play) and iOS (App Store)" }
        SetRow { icon: "wifi"; title: "2 · Same Wi-Fi"; description: "Your phone and this computer need to be on the same network" }
        SetRow { icon: "link"; title: "3 · Pair"; description: "Your phone appears above — press Pair, then accept on the phone" }
        SetRow { icon: "tune"; title: "4 · Choose what to share"; description: "In the phone app: clipboard, notifications, files, media control… Lumen shows them automatically" }
    }

    Group {
        title: "What you get"
        SetRow { icon: "content_paste_go"; title: "Clipboard"; description: "Copy on one, paste on the other (turn on Clipboard sync in the app)" }
        SetRow { icon: "notifications"; title: "Phone notifications"; description: "Arrive in the island and the notification centre like any other" }
        SetRow { icon: "music_note"; title: "Media"; description: "What your phone plays shows in the island; control it from here" }
        SetRow { icon: "battery_full"; title: "Battery"; description: "In the control centre, with a note when it runs low" }
    }

    Group {
        visible: !Connect.available
        title: "KDE Connect isn't installed"
        SetRow { icon: "info"; title: "Install it from your distribution"; description: "Fedora: sudo dnf install kdeconnectd · Arch: sudo pacman -S kdeconnect · Debian/Ubuntu: sudo apt install kdeconnect" }
    }
}
