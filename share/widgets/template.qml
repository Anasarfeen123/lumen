// Your widget. `lumen` is everything it can use (docs/WIDGETS.md):
//   lumen.theme (colours: accent, text, surface…), lumen.media, lumen.weather,
//   lumen.battery, lumen.sysinfo, lumen.planner, lumen.college, lumen.notifications,
//   lumen.run(cmd), lumen.open(url), lumen.askHalo(text), lumen.say(title, text)
// Save the file, then Settings → Appearance → Your widgets → refresh.
import QtQuick

Rectangle {
    id: root
    property var lumen: null
    readonly property var t: lumen ? lumen.theme : null
    implicitHeight: 80
    radius: 16
    color: t ? t.withAlpha(t.surfaceElevated, 0.85) : "#222"
    border.width: 1
    border.color: t ? t.border : "#444"

    Text {
        anchors.centerIn: parent
        text: lumen && lumen.media.present ? "♪ " + lumen.media.title : "Hello from your widget"
        color: t ? t.text : "white"
        font.pixelSize: 15
    }
    MouseArea { anchors.fill: parent; onClicked: if (root.lumen) root.lumen.say("Widget", "You clicked me") }
}
