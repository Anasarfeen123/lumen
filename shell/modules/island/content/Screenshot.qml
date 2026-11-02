// screenshot — a card: the picture, "Copied to clipboard", and what you
// might do next. The island stays open while the pointer is on it.
//   Workbench · Copy text (OCR) · Show in folder · Shelf
import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property var info
    implicitWidth: Theme.island.expandedWidth - Theme.space.s4 * 2
    implicitHeight: row.implicitHeight

    component Act: HoverTarget {
        id: act
        property string icon
        property string label
        width: act.label === "" ? 28 : actRow.implicitWidth + 16; height: 28
        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.withAlpha(Theme.text, 0.06); border.width: 1; border.color: Theme.border; z: -1 }
        Row { id: actRow; anchors.centerIn: parent; spacing: 5
              LIcon { icon: act.icon; size: 14; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { visible: act.label !== ""; role: "caption"; text: act.label; anchors.verticalCenter: parent.verticalCenter } }
    }
    function run(args) { Island.dismiss(); Quickshell.execDetached(args); }

    Row {
        id: row
        width: parent.width
        spacing: Theme.space.s3
        ClippingRectangle {
            width: 96; height: 62
            radius: Theme.radius.sm
            color: Theme.surfaceElevated
            border.width: 1; border.color: Theme.border
            Image {
                anchors.fill: parent
                source: root.info.path ? "file://" + root.info.path : ""
                sourceSize: Qt.size(224, 140)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        Column {
            width: parent.width - 96 - parent.spacing
            spacing: 8
            Column {
                width: parent.width
                LText { role: "bodyStrong"; text: "Screenshot copied" }
                LText { width: parent.width; elide: Text.ElideMiddle; role: "caption"; color: Theme.textMuted
                        text: (root.info.path ?? "").replace(Quickshell.env("HOME"), "~") }
            }
            Flow {
                width: parent.width
                spacing: 6
                Act { icon: "edit"; label: "Workbench"; onClicked: { Island.dismiss(); DesktopTools.inspectScreenshot(root.info.path); } }
                Act { icon: "document_scanner"; label: "Copy text"
                      onClicked: { Island.dismiss(); DesktopTools.inspectScreenshot(root.info.path); DesktopTools.imageAction("ocr"); } }
                Act { visible: WhatsApp.enabled && WhatsApp.available; icon: "forum"; label: ""; onClicked: { Island.dismiss(); Inbox.share("", [root.info.path]); } }
                Act { icon: "folder_open"; label: ""; onClicked: root.run(["xdg-open", root.info.path.replace(/\/[^/]+$/, "")]) }
                Act { icon: "inventory_2"; label: ""; onClicked: DropZone.run("shelve", [root.info.path]) }
            }
        }
    }
}
