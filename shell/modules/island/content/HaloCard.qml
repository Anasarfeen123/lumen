// halo — Halo speaking up: the living ring, what it has to say, and what you
// can do about it. Also the live view of a spoken question:
//   listening → "Listening…" (the ring follows your voice; click to stop)
//   thinking  → what you said
//   writing   → the answer as it arrives, then the answer with Open in Halo
//   info: { key, icon, title, text, tone, actions: [{ label, icon, run }], live? }
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property var info
    readonly property bool live: info.live === true
    readonly property var actions: live ? liveActions : (info.actions ?? [])
    readonly property var liveActions: Voice.listening ? [{ label: "Done talking", icon: "stop_circle", run: () => Voice.stopListening() },
                                                         { label: "Cancel", icon: "close", run: () => Voice.cancel() }]
                                     : Ai.busy ? [{ label: "Stop", icon: "stop", run: () => { Ai.stop(); Halo.session = false; } },
                                                  { label: "Open in Halo", icon: "open_in_full", run: () => Ai.show() }] : []
    readonly property string title: !live ? (info.title ?? "")
        : Voice.listening ? (Voice.heardSpeech ? "Listening…" : "Listening — go ahead")
        : Voice.transcribing ? "Got it…"
        : Halo.heard ? "“" + Halo.heard + "”" : Halo.name
    readonly property string body: !live ? (info.text ?? "")
        : Voice.listening ? "I'll stop when you pause."
        : Ai.busy ? (Ai.streamText ? tail(Voice.speakable(Ai.streamText) || Ai.streamText) : (Ai.slow ? "Still thinking — the first answer takes a moment…" : "Thinking…"))
        : ""
    function tail(t) { return t.length > 260 ? "…" + t.slice(-260) : t; }
    readonly property color tone: info.tone === "concerned" ? Theme.warning : Theme.accent

    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: Math.max(orbBox.height, col.implicitHeight)

    Item {
        id: orbBox
        width: 48; height: 48
        HaloOrb {
            anchors.centerIn: parent
            visible: Halo.present
            size: 40
            face: Persist.data.haloFace ?? true
            mood: root.live || Ai.busy || Voice.listening || Voice.speaking ? Halo.mood
                : info.tone === "concerned" ? "concerned" : info.tone === "happy" ? "happy" : Halo.mood
            level: Voice.level
            // arrives like it just looked up
            scale: 0.6
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveOvershoot } }
        }
        Rectangle {
            visible: !Halo.present
            anchors.centerIn: parent
            width: 44; height: 44; radius: Theme.radius.md
            color: Theme.withAlpha(root.tone, 0.14); border.width: 1; border.color: Theme.withAlpha(root.tone, 0.3)
            LIcon { anchors.centerIn: parent; icon: root.info.icon ?? "auto_awesome"; size: 22; fill: 1; color: root.tone }
        }
    }

    Column {
        id: col
        anchors { left: orbBox.right; leftMargin: Theme.space.s3; right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 3
        Row {
            spacing: 6
            width: parent.width
            LIcon { visible: Halo.present && !root.live && (root.info.icon ?? "") !== ""; icon: root.info.icon ?? ""; size: 15; fill: 1
                    color: root.info.tone === "concerned" ? Theme.warning : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            LText {
                width: parent.width - (x > 0 ? 21 : 0)
                role: "bodyStrong"; text: root.title; textFormat: Text.PlainText
                elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
            }
        }
        LText {
            visible: text !== ""
            width: parent.width
            role: "body"; color: Theme.textSecondary; textFormat: Text.PlainText
            text: root.body
            wrapMode: Text.Wrap; maximumLineCount: root.live ? 5 : 4; elide: Text.ElideRight
        }
        Item { width: 1; height: root.actions.length ? 4 : 0 }
        Flow {
            visible: root.actions.length > 0
            width: parent.width
            spacing: 6
            Repeater {
                model: root.actions
                Act {
                    required property var modelData
                    required property int index
                    icon: modelData.icon ?? ""; label: modelData.label; primary: index === 0
                    onClicked: { const a = modelData; if (!root.live) Island.dismiss(); a.run?.(); }
                }
            }
        }
    }

    component Act: HoverTarget {
        id: act
        property string icon
        property string label
        property bool primary: false
        width: actRow.implicitWidth + 20; height: 28
        Rectangle {
            anchors.fill: parent; radius: height / 2; z: -1
            color: act.primary ? Theme.withAlpha(root.tone, 0.18) : Theme.withAlpha(Theme.text, act.containsMouse ? 0.1 : 0.06)
            border.width: 1; border.color: act.primary ? Theme.withAlpha(root.tone, 0.4) : Theme.border
            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        }
        Row { id: actRow; anchors.centerIn: parent; spacing: 5
              LIcon { visible: act.icon !== ""; icon: act.icon; size: 14; color: act.primary ? root.tone : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: act.label; color: act.primary ? root.tone : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }
}
