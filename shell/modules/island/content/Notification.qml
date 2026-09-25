// notification — app, title, one-line preview; up to three action chips.
// A burst from one app updates this card in place ("3 new").
// Urgent (critical) notifications get an error-tone mark and stay until handled.
import QtQuick
import Quickshell.Widgets
import qs.theme
import qs.components

Item {
    id: root
    required property var info
    readonly property var actions: info.actions ?? []
    implicitWidth: Theme.island.expandedWidth - 2 * Theme.space.s4
    implicitHeight: Math.max(40, col.implicitHeight) + (actions.length ? 32 + Theme.space.s3 : 0)

    ClippingRectangle {
        id: icon
        width: 40; height: 40
        radius: Theme.radius.sm
        color: Theme.surfaceElevated
        anchors { top: parent.top; topMargin: Math.max(0, (Math.max(40, col.implicitHeight) - 40) / 2) }
        LIcon { anchors.centerIn: parent; visible: img.status !== Image.Ready; icon: root.info.critical ? "priority_high" : "notifications"; color: root.info.critical ? Theme.error : Theme.textSecondary }
        Image {
            id: img
            anchors.fill: parent
            source: root.info.image || ""
            sourceSize: Qt.size(80, 80)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
    }

    Column {
        id: col
        anchors { left: icon.right; leftMargin: Theme.space.s3; right: parent.right; top: parent.top }
        spacing: 2
        Row {
            spacing: Theme.space.s1
            LText { role: "caption"; color: root.info.critical ? Theme.error : Theme.textMuted; text: root.info.appName ?? "" }
            LText {
                visible: (root.info.burst ?? 1) > 1
                role: "caption"; color: Theme.textMuted
                text: "· " + root.info.burst + " new"
            }
        }
        LText { width: parent.width; role: "heading"; text: root.info.summary ?? ""; elide: Text.ElideRight; textFormat: Text.PlainText }
        LText { width: parent.width; role: "body"; color: Theme.textSecondary; text: root.info.body ?? ""; elide: Text.ElideRight; maximumLineCount: 1; textFormat: Text.PlainText; visible: text !== "" }
    }

    Row {
        visible: root.actions.length > 0
        anchors { left: col.left; bottom: parent.bottom }
        spacing: Theme.space.s2
        Repeater {
            model: root.actions
            delegate: HoverTarget {
                required property var modelData
                width: lbl.implicitWidth + Theme.space.s4 * 2
                height: 32
                radius: Theme.radius.sm
                Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.surfaceElevated; z: -1 }
                onClicked: root.info.invoke?.(modelData.id)
                LText { id: lbl; anchors.centerIn: parent; role: "bodyStrong"; text: modelData.text }
            }
        }
    }
}
