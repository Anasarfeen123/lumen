// Find my laptop (services/FindMy.qml, scripts/findmy.py): ring, lock, locate
// and photograph this laptop from your phone, wherever it is.
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Find my laptop"
    subtitle: "Ring it, lock it and see where it is from your phone — near or far. Messages go through ntfy.sh, a free public relay, sealed end to end: the relay sees only scrambled text."
    property bool armed: false              // "New keys" asks twice (DESIGN §0)
    Timer { id: disarm; interval: 5000; onTriggered: page.armed = false }

    Group {
        title: "Find my laptop"
        SetRow {
            icon: "travel_explore"
            title: "Find my laptop"
            description: !FindMy.enabled ? "Off. Turning it on makes a private channel and a key for your phone."
                       : FindMy.status === "listening" ? "On — listening for your phone"
                       : FindMy.status === "offline" ? "On — offline; it listens again when the internet is back"
                       : "On" + (FindMy.status ? " — " + FindMy.status : "")
            LSwitch { checked: FindMy.enabled; onToggled: FindMy.enable(!checked) }
        }
        SetRow {
            visible: FindMy.enabled
            icon: "phonelink"
            title: "Your phone's remote"
            description: "A web page with this laptop's key inside — open it in your phone's browser (and bookmark it). Anyone with it can ring and lock the laptop: keep it on your phone only."
                       + (FindMy.info.remote ? " Made before; send it again any time." : "")
            Button { text: Link.connected ? "Send to my phone" : "Make it"; onActivated: FindMy.sendRemote() }
        }
        SetRow {
            visible: FindMy.enabled
            icon: "volume_up"
            title: "Try the alarm"
            description: "What a ring sounds like here — loud, through the laptop's speakers, even with headphones in"
            Button { text: FindMy.ringing ? "Stop" : "Ring now"; onActivated: FindMy.ringing ? FindMy.stop() : FindMy.ring("", false) }
        }
    }

    Group {
        title: "Lost mode"
        visible: FindMy.enabled
        SetRow {
            icon: "lock_person"
            title: "Lost mode"
            description: (FindMy.lost.on ?? false) ? "On — your message is on the lock screen, your notifications are hidden there, and it reports where it is every 15 minutes"
                                                    : "Usually turned on from your phone (Lock it). Shows your message and number on the lock screen."
            LSwitch { checked: FindMy.lost.on ?? false; onToggled: FindMy.setLost(!checked, msg.text, phone.text) }
        }
        SetRow {
            icon: "chat"
            title: "Message for whoever finds it"
            LField { id: msg; width: 300; placeholder: "This laptop is lost. Please call me."; text: FindMy.lost.message ?? ""; clearOnAccept: false
                     onAccepted: t => FindMy.setLost(FindMy.lost.on ?? false, t, phone.text) }
        }
        SetRow {
            icon: "call"
            title: "Your phone number"
            LField { id: phone; width: 300; placeholder: "+91 …"; text: FindMy.lost.phone ?? ""; clearOnAccept: false
                     onAccepted: t => FindMy.setLost(FindMy.lost.on ?? false, msg.text, t) }
        }
    }

    Group {
        title: "Good to know"
        visible: FindMy.enabled
        SetRow {
            icon: "my_location"
            title: "How it finds itself"
            description: "Locate sends the Wi-Fi networks around the laptop to BeaconDB, an open location database — only when you ask, or every 15 minutes in lost mode. Where BeaconDB doesn't know the networks yet (much of India), it's only as close as the city."
        }
        SetRow {
            icon: "photo_camera"
            title: "Photos"
            description: "A webcam picture is taken only when your phone asks; the camera light comes on. Pictures travel sealed and the relay deletes them after about 3 hours."
        }
        SetRow {
            icon: "key"
            title: "New keys"
            description: "If your phone is lost: replace the channel and key, then send the remote again. The old page stops working."
            Button { text: page.armed ? "Click again to replace them" : "New keys"
                     onActivated: { if (!page.armed) { page.armed = true; disarm.restart(); return; } page.armed = false; FindMy.rotate(); } }
        }
    }
}
