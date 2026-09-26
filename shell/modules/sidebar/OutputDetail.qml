// Sound: pick the output device, and set each app's own volume.
//   devices   click to make it the default output
//   apps      one slider per app that's playing; click the icon to mute it
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

DetailPage {
    title: "Sound"
    emptyText: "No output devices"
    model: Audio.sinks.map(n => ({ kind: "device", node: n }))
           .concat(Audio.appGroups.length ? [{ kind: "header" }] : [])
           .concat(Audio.appGroups.map(g => ({ kind: "app", node: g })))
    delegate: Loader {
        required property var modelData
        width: ListView.view ? ListView.view.width : 300
        sourceComponent: modelData.kind === "device" ? deviceRow : modelData.kind === "header" ? headerRow : appRow
        property var node: modelData.node
    }

    Component {
        id: deviceRow
        ListRow {
            readonly property var node: parent ? parent.node : null
            readonly property string desc: Audio.label(node)
            icon: /headphone|headset/i.test(desc) ? "headphones" : /hdmi|displayport/i.test(desc) ? "tv" : "speaker"
            title: desc
            trailing: current ? "check" : ""
            current: Audio.sink === node
            onClicked: Audio.setSink(node)
        }
    }
    Component {
        id: headerRow
        Item {
            height: 34
            LText { anchors { left: parent.left; leftMargin: Theme.space.s2; bottom: parent.bottom; bottomMargin: 6 }
                    role: "caption"; color: Theme.textMuted; text: "APPS"; font.letterSpacing: 1 }
        }
    }
    Component {
        id: appRow
        Item {
            id: row
            height: 48
            readonly property var group: parent ? parent.node : null
            readonly property var entry: group ? Apps.entryFor(group.iconName, group.binary, group.name) : null
            readonly property bool muted: group ? Audio.groupMuted(group) : false
            readonly property real volume: group ? Audio.groupVolume(group) : 0
            HoverTarget {
                id: muteBtn
                width: 36; height: 36
                anchors { left: parent.left; leftMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
                onClicked: Audio.toggleGroupMute(row.group)
                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 24
                    opacity: row.muted ? 0.35 : 1
                    source: row.entry ? Apps.iconFor(row.entry) : Quickshell.iconPath(row.group?.binary || "audio-x-generic", "audio-x-generic")
                }
                LIcon { visible: row.muted; anchors { right: parent.right; bottom: parent.bottom }
                        icon: "volume_off"; size: 14; fill: 1; color: Theme.error }
            }
            Column {
                anchors { left: muteBtn.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                spacing: 3
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary
                        text: (row.entry?.name || row.group?.name || "App") + "  ·  " + (row.muted ? "muted" : Math.round(row.volume * 100) + "%") }
                LSlider {
                    width: parent.width
                    height: 22
                    value: row.volume
                    dimmed: row.muted
                    onMoved: v => Audio.setGroupVolume(row.group, v)
                }
            }
        }
    }
}
