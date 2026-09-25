// Recently used apps — a quiet row of icons under the search field.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Row {
    id: root
    spacing: Theme.space.s2
    signal done()

    Repeater {
        model: Apps.recent
        delegate: HoverTarget {
            required property var modelData
            width: 64; height: 64
            radius: Theme.radius.md
            onClicked: { Apps.launch(modelData); root.done(); }

            IconImage {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                width: 32; height: 32
                source: Apps.iconFor(modelData)
                asynchronous: true
            }
            LText {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 6 }
                width: parent.width - 8
                horizontalAlignment: Text.AlignHCenter
                role: "caption"
                color: Theme.textSecondary
                text: modelData.name
                elide: Text.ElideRight
            }
        }
    }
}
