// Lumen Link in the control centre.
//   linked      a battery ring around the phone · name · how it's connected
//               Ring · Send file · Send clipboard · Screenshot → phone
//   not linked  one slim row: "Link your phone" → Settings → Lumen Link
import QtQuick
import qs.theme
import qs.components
import qs.services

Rectangle {
    id: root
    readonly property var d: Link.phone
    readonly property bool live: Link.connected
    visible: Link.available
    implicitHeight: d ? col.implicitHeight + Theme.space.s3 * 2 : 40
    radius: Theme.radius.md
    color: Theme.withAlpha(Theme.surfaceElevated, 0.85)
    border.width: 1; border.color: Theme.border
    Binding { target: Link; property: "watching"; value: Sidebar.open }

    // ── not linked: one row ──
    HoverTarget {
        visible: !root.d
        anchors.fill: parent
        radius: Theme.radius.md
        onClicked: { Sidebar.hide(); SettingsState.launch("phone"); }
        Row {
            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
            spacing: Theme.space.s2
            LIcon { icon: "phonelink"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "bodyStrong"; text: "Link your phone"; anchors.verticalCenter: parent.verticalCenter }
            LText { role: "caption"; color: Theme.textMuted; text: "Files, clipboard, battery, notifications"; anchors.verticalCenter: parent.verticalCenter }
        }
        LIcon { anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                icon: "chevron_right"; size: 16; color: Theme.textMuted }
    }

    component Act: HoverTarget {
        id: a
        property string icon
        property string label
        width: (col.width - 3 * 6) / 4; height: 30
        enabled: root.live
        opacity: enabled ? 1 : 0.4
        Rectangle { anchors.fill: parent; radius: height / 2; z: -1; color: Theme.withAlpha(Theme.text, 0.05); border.width: 1; border.color: Theme.border }
        Row { anchors.centerIn: parent; spacing: 5
              LIcon { icon: a.icon; size: 15; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
              LText { role: "caption"; text: a.label; anchors.verticalCenter: parent.verticalCenter } }
    }

    // ── linked ──
    Column {
        id: col
        visible: !!root.d
        x: Theme.space.s3; y: Theme.space.s3
        width: parent.width - Theme.space.s3 * 2
        spacing: Theme.space.s2

        Item {
            width: parent.width; height: 40
            // Battery ring around the phone glyph
            Canvas {
                id: ring
                width: 40; height: 40
                anchors.verticalCenter: parent.verticalCenter
                readonly property real level: Math.max(0, root.d?.battery ?? -1) / 100
                readonly property color tone: !root.live ? Theme.textMuted : (root.d?.battery ?? 100) <= 15 && !root.d?.charging ? Theme.error : root.d?.charging ? Theme.success : Theme.accent
                onLevelChanged: requestPaint()
                onToneChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d"); c.reset();
                    const r = width / 2 - 2.5;
                    c.lineWidth = 3; c.lineCap = "round";
                    c.strokeStyle = Theme.withAlpha(Theme.text, 0.1); c.beginPath(); c.arc(width / 2, height / 2, r, 0, 2 * Math.PI); c.stroke();
                    if ((root.d?.battery ?? -1) < 0) return;
                    c.strokeStyle = tone; c.beginPath(); c.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * level); c.stroke();
                }
                LIcon { anchors.centerIn: parent; icon: root.d?.type === "tablet" ? "tablet_android" : "smartphone"; size: 18; fill: root.live ? 1 : 0
                        color: root.live ? Theme.text : Theme.textMuted }
            }
            Column {
                anchors { left: ring.right; leftMargin: Theme.space.s3; right: pct.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: root.d?.name ?? "" }
                Row {
                    spacing: 4
                    LIcon { visible: root.live; icon: Link.viaIcon(root.d?.via ?? ""); size: 12; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "caption"; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter
                            text: !root.live ? "Not nearby" : "Linked over " + Link.viaLabel(root.d?.via ?? "wifi") + (root.d?.charging ? " · charging" : "") }
                }
            }
            LText {
                id: pct
                visible: (root.d?.battery ?? -1) >= 0
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                role: "heading"; font.features: { "tnum": 1 }
                color: root.live ? Theme.text : Theme.textMuted
                text: (root.d?.battery ?? 0) + "%"
            }
        }
        Row {
            spacing: 6
            Act { icon: "phone_in_talk"; label: "Ring"; onClicked: Link.ring() }
            Act { icon: "upload_file"; label: "File"; onClicked: { Sidebar.hide(); Link.pickAndSend(); } }
            Act { icon: "content_paste_go"; label: "Clip"; onClicked: Link.sendClipboard() }
            Act { icon: "screenshot_region"; label: "Shot"; onClicked: { Sidebar.hide(); Link.screenshotToPhone(); } }
        }
    }
}
