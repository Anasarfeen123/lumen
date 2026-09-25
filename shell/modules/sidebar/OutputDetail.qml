// Audio output picker. Selecting a device makes it the default sink; the
// island confirms the switch through its normal volume/device feedback.
import QtQuick
import qs.theme
import qs.components
import qs.services

DetailPage {
    title: "Sound output"
    emptyText: "No output devices"
    model: Audio.sinks
    delegate: ListRow {
        required property var modelData
        readonly property string desc: Audio.label(modelData)
        icon: /headphone|headset/i.test(desc) ? "headphones" : /hdmi|displayport/i.test(desc) ? "tv" : "speaker"
        title: desc
        trailing: current ? "check" : ""
        current: Audio.sink === modelData
        onClicked: Audio.setSink(modelData)
    }
}
