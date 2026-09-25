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
                       bodyStrong: Theme.size.body, caption: Theme.size.caption })[role] ?? Theme.size.body
    font.weight: ({ title: Font.DemiBold, heading: Font.DemiBold, body: Font.Normal,
                    bodyStrong: Font.Medium, caption: Font.Medium })[role] ?? Font.Normal
    font.letterSpacing: role === "caption" ? 0.2 : 0
    font.features: ({ "tnum": 1, "cv11": 1 })
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter

    Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
}
