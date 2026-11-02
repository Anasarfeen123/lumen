import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    Flow {
        id: header; width: parent.width; spacing: Theme.space.s2
        ToolButton { glyph: "colorize"; label: "Pick from screen"; primary: true; enabled: !DesktopTools.picking; onClicked: DesktopTools.pickColour() }
        LField { width: Math.min(260, root.width); height: 40; placeholder: "Add HEX · #52D1E9"; icon: "add"; onAccepted: value => DesktopTools.addColour(value) }
    }
    ListView {
        id: list
        anchors { top: header.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom }
        clip: true; spacing: Theme.space.s3; model: DesktopTools.colours
        delegate: Rectangle {
            id: colour
            required property var modelData
            width: list.width; height: content.implicitHeight + Theme.space.s3 * 2
            radius: Theme.radius.md; color: Theme.surfaceElevated
            Rectangle {
                x: Theme.space.s3; y: Theme.space.s3; width: 48; height: 48
                radius: Theme.radius.sm; color: colour.modelData.hex
                border.width: 1; border.color: Theme.borderStrong
            }
            Column {
                id: content
                x: 48 + Theme.space.s3 * 2; y: Theme.space.s3; width: parent.width - x - Theme.space.s3; spacing: Theme.space.s2
                Row {
                    width: parent.width; spacing: Theme.space.s2
                    LField { width: parent.width - remove.width - Theme.space.s2; height: remove.height; text: colour.modelData.name; placeholder: "Name this colour · Enter to save"; clearOnAccept: false; onAccepted: value => DesktopTools.renameColour(colour.modelData.hex, value) }
                    ToolButton { id: remove; glyph: "close"; label: ""; Accessible.name: "Remove " + colour.modelData.hex; onClicked: DesktopTools.removeColour(colour.modelData.hex) }
                }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    ToolButton { label: colour.modelData.hex; onClicked: DesktopTools.copyText(colour.modelData.hex) }
                    ToolButton { label: DesktopTools.rgb(colour.modelData.hex); onClicked: DesktopTools.copyText(DesktopTools.rgb(colour.modelData.hex)) }
                    ToolButton { label: DesktopTools.hsl(colour.modelData.hex); onClicked: DesktopTools.copyText(DesktopTools.hsl(colour.modelData.hex)) }
                }
            }
        }
    }
    EmptyState { anchors.centerIn: list; width: Math.min(360, list.width); visible: !list.count; icon: "palette"; title: "Keep a colour close"; detail: "Pick a colour anywhere on screen or enter its HEX value. Save up to 60 colours with names; click a format to copy it." }
}
