// Caffeine options: how long to stay awake, and whether to keep running with
// the lid closed. Right-click (or hold) the Caffeine toggle to get here.
import QtQuick
import qs.theme
import qs.components
import qs.services

DetailPage {
    id: page
    title: "Caffeine"
    showSwitch: true
    switchOn: Caffeine.on
    onSwitchToggled: Caffeine.toggle()
    status: Caffeine.on ? Caffeine.label : ""

    readonly property var choices: [
        { min: 30, label: "30 minutes", icon: "timer" },
        { min: 60, label: "1 hour", icon: "timer" },
        { min: 120, label: "2 hours", icon: "timer" },
        { min: 240, label: "4 hours", icon: "timer" },
        { min: 0, label: "Until I turn it off", icon: "all_inclusive" },
        { min: -1, label: "Keep running with the lid closed", icon: "laptop_chromebook", lid: true },
    ]
    model: choices
    delegate: ListRow {
        required property var modelData
        readonly property bool isLid: modelData.lid === true
        current: isLid ? Caffeine.lid : (Caffeine.on && Caffeine.chosen === modelData.min)
        section: isLid ? "Lid" : (modelData.min === 30 ? "Stay awake" : "")
        icon: modelData.icon
        title: modelData.label
        subtitle: isLid ? (Caffeine.lid ? "On — closing the lid won't sleep while Caffeine is on" : "For downloads, music on a speaker, a long build") : ""
        trailing: current ? "check" : ""
        onClicked: isLid ? Caffeine.setLid(!Caffeine.lid) : Caffeine.start(modelData.min)
    }
    footerText: Caffeine.on && Caffeine.until > 0 ? "Add 30 minutes" : ""
    onFooterActivated: Caffeine.extend(30)
}
