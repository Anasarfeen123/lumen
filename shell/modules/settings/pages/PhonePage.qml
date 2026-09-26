// Lumen Link: your phone and this computer, through KDE Connect (free on
// Android — F-Droid / Play — and iOS). Pair once; then files, clipboard,
// battery, notifications and media flow between them, never through the
// internet.
//
// "Can't find your phone?" runs scripts/link.sh doctor and offers the fixes
// that work on networks that keep devices apart (hostels, campuses, cafés):
// connect by address · USB tethering · Bluetooth · your phone's hotspot.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Lumen Link"
    subtitle: "Your phone and this computer as one: send files and links, share the clipboard, see its battery and notifications, find it when it's lost. Everything stays between your two devices."
    Component.onCompleted: { Link.watching = true; Link.search(); Link.refresh(); Link.diagnose(); }
    Component.onDestruction: Link.watching = false

    readonly property var doc: Link.doctor ?? ({})
    readonly property bool trouble: Link.available && Link.devices.length === 0

    // ── Your devices ──
    Group {
        title: "Your devices"
        visible: Link.available && Link.devices.length > 0
        Repeater {
            model: Link.devices
            delegate: SetRow {
                required property var modelData
                icon: modelData.type === "tablet" ? "tablet_android" : modelData.type === "desktop" || modelData.type === "laptop" ? "computer" : "smartphone"
                title: modelData.name
                description: !modelData.paired ? "Nearby — press Pair, then accept on the phone"
                    : (modelData.reachable ? "Linked over " + Link.viaLabel(modelData.via || "wifi") : "Paired · not nearby")
                      + (modelData.battery >= 0 ? " · " + modelData.battery + "%" + (modelData.charging ? " charging" : "") : "")
                Row {
                    spacing: Theme.space.s2
                    Button { visible: modelData.paired && modelData.reachable; icon: "phone_in_talk"; text: "Ring"; onActivated: Link.ring(modelData.id) }
                    Button { visible: modelData.paired && modelData.reachable; icon: "upload_file"; text: "Send files"; onActivated: Link.pickAndSend(modelData.id) }
                    Button { visible: modelData.paired && modelData.reachable; icon: "content_paste_go"; text: ""; onActivated: Link.sendClipboard(modelData.id) }
                    Button { primary: !modelData.paired; text: modelData.paired ? "Unpair" : "Pair"; onActivated: modelData.paired ? Link.unpair(modelData.id) : Link.pair(modelData.id) }
                }
            }
        }
        SetRow {
            visible: Link.phone?.paired ?? false
            icon: "content_paste_go"
            title: "Share clipboard with " + (Link.phone?.name ?? "your phone")
            description: Link.clipSync === "on" ? "Copy on one, paste on the other. When something arrives from the phone the island shows it (passwords stay hidden)."
                                                : "Off — nothing you copy leaves this computer"
            LSwitch { checked: Link.clipSync === "on"; onToggled: Link.setClipSync(!checked) }
        }
    }

    // ── Doctor ──
    Group {
        title: page.trouble ? "Can't find your phone?" : "Connection"
        visible: Link.available
        SetRow {
            icon: page.trouble ? "wifi_find" : "check_circle"
            title: Link.diagnosing ? "Checking…"
                 : page.trouble ? (page.doc.isolated ? "This network probably keeps devices apart" : "Looking for your phone…")
                 : "Your phone can be found"
            description: page.trouble
                ? (page.doc.isolated ? "Hostel, campus and café Wi-Fi often block devices from seeing each other. Any fix below works around it."
                                     : "Open KDE Connect on your phone. It should appear above within a few seconds.")
                : "Linked devices reconnect by themselves"
            Button { icon: "refresh"; text: "Check again"; onActivated: { Link.search(); Link.diagnose(); } }
        }
        SetRow {
            visible: !!page.doc.ssid || !!page.doc.address
            icon: "lan"
            title: "This computer: " + (page.doc.address ?? "").replace(/\/\d+$/, "")
            description: (page.doc.ssid ? "on " + page.doc.ssid : "on " + (page.doc.iface ?? "the network")) + " · your phone must be on the same network, or use a fix below"
        }
        SetRow {
            visible: page.doc.running === false
            icon: "error"; title: "KDE Connect isn't running"
            description: "Lumen starts it at login. Start it now:"
            Button { text: "Start"; onActivated: { Quickshell.execDetached(["kdeconnectd"]); Link.diagnose(); } }
        }
        SetRow {
            visible: page.doc.firewall === "closed"
            icon: "shield"; title: "The firewall blocks KDE Connect"
            description: "Allow it once: sudo firewall-cmd --permanent --add-service=kdeconnect && sudo firewall-cmd --reload"
        }
        SetRow {
            visible: page.doc.warp === true && page.trouble
            icon: "cloud"; title: "Cloudflare WARP is on"
            description: "A VPN can hide your phone. If it still doesn't appear, turn WARP off while you pair (Controls → WARP)."
        }
    }

    // ── Fixes, friendliest first ──
    Group {
        title: "Ways to link"
        visible: Link.available

        // 1 · By address
        SetRow {
            icon: "pin"
            title: "Connect by address"
            description: "Works on many networks that hide devices. On your phone: Settings → About → Status (or Wi-Fi details) shows its IP address, e.g. 172.20.165.40."
            LField {
                width: 190
                icon: "smartphone"
                placeholder: "Phone's IP address"
                onAccepted: t => { if (/^(\d{1,3}\.){3}\d{1,3}$/.test(t.trim())) Link.addAddress(t.trim()); }
            }
        }
        Repeater {
            model: Link.custom
            delegate: SetRow {
                required property string modelData
                icon: "subdirectory_arrow_right"
                title: modelData
                description: "KDE Connect contacts this address directly"
                Button { text: "Remove"; onActivated: Link.removeAddress(modelData) }
            }
        }

        // 2 · USB
        SetRow {
            icon: "usb"
            title: Link.tether ? "USB tethering is on (" + Link.tether + ")" : "USB cable"
            description: Link.tether ? "Your phone and this computer have their own private network over the cable — KDE Connect works across it."
                                     : "Always works: plug your phone in, then on the phone turn on Settings → Network → Hotspot & tethering → USB tethering."
        }

        // 3 · Bluetooth
        SetRow {
            icon: "bluetooth"
            title: "Over Bluetooth (beta)"
            description: (Link.backends.bluetooth ? "On — " : "") + "No Wi-Fi needed. Slower, fine for clipboard, notifications, battery and small files. Needs Bluetooth on both, and the phone app's Bluetooth option."
            LSwitch { checked: !!Link.backends.bluetooth; onToggled: Link.setBackend("bluetooth", !checked) }
        }

        // 4 · Phone hotspot
        SetRow {
            icon: "wifi_tethering"
            title: "Join your phone's hotspot"
            description: "Turn on the hotspot on your phone, then join it here — both are then on the same network. (Uses your phone's mobile data for the internet.)"
            Button { text: "Choose network"; onActivated: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "sidebar", "detail", "wifi"]) }
        }
    }

    // ── What you get ──
    Group {
        title: "What Lumen Link does"
        SetRow { icon: "send_to_mobile"; title: "Files and links"; description: "Send files (or drop them on the Drop Zone), links, text and screenshots. Files from your phone land in Downloads and the island offers Open / Show." }
        SetRow { icon: "content_paste_go"; title: "Clipboard"; description: "Copy on one, paste on the other (turn on Clipboard sync in the phone app)" }
        SetRow { icon: "notifications"; title: "Phone notifications"; description: "Arrive in the island and the notification centre like any other" }
        SetRow { icon: "battery_full"; title: "Battery"; description: "In the control centre, announced when your phone links, and a note when it runs low" }
        SetRow { icon: "phone_in_talk"; title: "Find my phone"; description: "Rings it at full volume, even on silent — from here, the control centre, or the overview (\"find my phone\")" }
        SetRow {
            icon: "videocam"
            title: "Phone as webcam or microphone"
            description: Link.hasScrcpy ? "scrcpy is installed: scrcpy --video-source=camera (webcam) · scrcpy --audio-source=mic --no-video (microphone), with the phone on USB and USB debugging on."
                : "Needs scrcpy, which isn't in Fedora's own repositories (it's in RPM Fusion). KDE Connect can't do this by itself."
        }
    }

    Group {
        visible: !Link.available
        title: "KDE Connect isn't installed"
        SetRow { icon: "info"; title: "Install it from your distribution"; description: "Fedora: sudo dnf install kdeconnectd · Arch: sudo pacman -S kdeconnect · Debian/Ubuntu: sudo apt install kdeconnect" }
    }
}
