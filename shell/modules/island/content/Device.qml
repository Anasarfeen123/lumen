// device — something was plugged in: a drive, a display, or a device this
// computer has never seen. A glyph tile, the name, what it is, and what you
// might do next (Open · Eject for drives, Arrange for displays).
//   info: { icon, title, detail, badge?, actions: [{ icon, label, cmd?, page? }] }
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property var info
    readonly property var actions: info.actions ?? []
    implicitWidth: Theme.island.expandedWidth - Theme.space.s4 * 2
    implicitHeight: row.implicitHeight

    component Act: HoverTarget {
        id: act
        property string icon
        property string label
        property bool primary: false
        width: actRow.implicitWidth + 20; height: 28
        Rectangle {
            anchors.fill: parent; radius: height / 2; z: -1
            color: act.primary ? Theme.withAlpha(Theme.accent, 0.18) : Theme.withAlpha(Theme.text, 0.06)
            border.width: 1; border.color: act.primary ? Theme.withAlpha(Theme.accent, 0.4) : Theme.border
        }
        Row { id: actRow; anchors.centerIn: parent; spacing: 5
              LIcon { icon: act.icon; size: 14; color: act.primary ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: act.label; color: act.primary ? Theme.accent : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }

    function run(a) {
        Island.dismiss();
        if (a.page) SettingsState.launch(a.page);
        else if (a.cmd) Quickshell.execDetached(a.cmd);
    }

    Row {
        id: row
        width: parent.width
        spacing: Theme.space.s3

        // Glyph tile: the device's kind at a glance
        Rectangle {
            id: tile
            width: 52; height: 52
            radius: Theme.radius.md
            color: Theme.withAlpha(Theme.accent, 0.14)
            border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.3)
            LIcon { anchors.centerIn: parent; icon: root.info.icon ?? "devices"; size: 26; fill: 1; color: Theme.accent }
            // Arrives with a small settle, like something set down on a desk
            scale: 0.8
            Component.onCompleted: scale = 1
            Behavior on scale { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveOvershoot } }
        }

        Column {
            width: parent.width - tile.width - parent.spacing
            spacing: 8
            Column {
                width: parent.width
                Row {
                    spacing: 6
                    width: parent.width
                    LText { id: name; role: "bodyStrong"; text: root.info.title ?? ""; elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - (badge.visible ? badge.width + 6 : 0)) }
                    Rectangle {
                        id: badge
                        visible: (root.info.badge ?? "") !== ""
                        anchors.verticalCenter: name.verticalCenter
                        width: badgeText.implicitWidth + 10; height: 16; radius: 8
                        color: Theme.accent
                        LText { id: badgeText; anchors.centerIn: parent; role: "caption"; font.pixelSize: 10; font.weight: Font.DemiBold
                                color: Theme.onAccent; text: root.info.badge ?? "" }
                    }
                }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: root.info.detail ?? "" }
            }
            Flow {
                visible: root.actions.length > 0
                width: parent.width
                spacing: 6
                Repeater {
                    model: root.actions
                    Act { required property var modelData; required property int index
                          icon: modelData.icon; label: modelData.label; primary: index === 0
                          onClicked: root.run(modelData) }
                }
            }
        }
    }
}
