// Text in the Lumen type system. `role` picks the style; numbers always use
// tabular figures so changing values never jitter (DESIGN.md §3).
import QtQuick
import qs.theme

Text {
    id: root
    property string role: "body"   // title | heading | body | bodyStrong | caption

    color: Theme.text
    font.family: Theme.fontUi
    font.pixelSize: ({ title: Theme.size.title, heading: Theme.size.heading, body: Theme.size.body,
                       bodyStrong: Theme.size.body, caption: Theme.size.caption, bar: Theme.size.bar, barCaption: Theme.size.barCaption, panelTitle: Theme.size.panelTitle, panelHeading: Theme.size.panelHeading, panelCaption: Theme.size.panelCaption })[role] ?? Theme.size.body
    font.weight: ({ title: Theme.weight.title, heading: Theme.weight.heading, body: Theme.weight.body,
                    bodyStrong: Theme.weight.bodyStrong, caption: Theme.weight.caption, bar: Theme.weight.bar, barCaption: Theme.weight.barCaption, panelTitle: Theme.weight.panelTitle, panelHeading: Theme.weight.panelHeading, panelCaption: Theme.weight.panelCaption })[role] ?? Font.Normal
    font.variableAxes: ({ "ROND": Theme.fontRoundness })
    font.letterSpacing: role === "caption" || role === "barCaption" ? 0.2 : 0
    font.features: ({ "tnum": 1, "cv11": 1 })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
}
