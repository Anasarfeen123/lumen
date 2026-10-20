// A settings page: large title, optional subtitle, optional tabs, then groups
// stacked with consistent rhythm. Scrolls when taller than the window.
// Tabs: `tabs: [{ id, label, icon }]`, `tab` is the open one; a group shows
// itself with `visible: page.tab === "…"`. Picking a tab emits tabPicked(id).
import QtQuick
import qs.theme
import qs.components

Flickable {
    id: root
    property string title: ""
    property string subtitle: ""
    property var tabs: []
    property string tab: ""
    signal tabPicked(string id)
    default property alias content: col.data

    contentHeight: col.implicitHeight + Theme.space.s8 * 2
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onTabChanged: { contentY = 0; tabSwap.restart(); }

    Column {
        id: col
        x: Theme.space.s8
        y: Theme.space.s8
        width: root.width - Theme.space.s8 * 2
        spacing: Theme.space.s5
        transform: Translate { id: tabShift }

        Column {
            width: parent.width
            spacing: Theme.space.s1
            LText { role: "title"; font.pixelSize: 26; text: root.title }
            LText { visible: text !== ""; width: parent.width; wrapMode: Text.WordWrap; color: Theme.textSecondary; text: root.subtitle }

            // ── tabs: pills on a track, the open one lifted ──
            Item { width: 1; height: root.tabs.length ? Theme.space.s3 : 0 }
            Rectangle {
                id: track
                visible: root.tabs.length > 0
                width: Math.min(parent.width, tabRow.implicitWidth + 8)
                height: 40
                radius: 20
                color: Theme.withAlpha(Theme.surfaceElevated, 0.7)
                border.width: 1
                border.color: Theme.border

                // the lifted pill, gliding to the open tab
                Rectangle {
                    id: pill
                    readonly property Item target: tabRow.children[Math.max(0, root.tabs.findIndex(t => t.id === root.tab))] ?? null
                    x: 4 + (target?.x ?? 0); y: 4
                    width: target?.width ?? 0; height: 32; radius: 16
                    color: Theme.withAlpha(Theme.accent, 0.18)
                    border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.45)
                    Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                    Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                }
                Row {
                    id: tabRow
                    x: 4; y: 4
                    Repeater {
                        model: root.tabs
                        delegate: MouseArea {
                            required property var modelData
                            readonly property bool on: root.tab === modelData.id
                            width: tabLabel.implicitWidth + tabIcon.width + Theme.space.s4 * 2 + 6
                            height: 32
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tabPicked(modelData.id)
                            Rectangle { anchors.fill: parent; radius: 16; color: Theme.withAlpha(Theme.text, parent.containsMouse && !parent.on ? 0.06 : 0) }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                LIcon { id: tabIcon; icon: modelData.icon ?? ""; visible: icon !== ""; size: 16; fill: parent.parent.on ? 1 : 0
                                        color: parent.parent.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                LText { id: tabLabel; text: modelData.label; role: parent.parent.on ? "bodyStrong" : "body"
                                        color: parent.parent.on ? Theme.text : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            }
                        }
                    }
                }
            }
        }
    }

    // a soft change between tabs
    SequentialAnimation {
        id: tabSwap
        PropertyAction { target: tabShift; property: "y"; value: 10 }
        PropertyAction { target: col; property: "opacity"; value: 0.4 }
        ParallelAnimation {
            NumberAnimation { target: col; property: "opacity"; to: 1; duration: Theme.reducedMotion ? 0 : Theme.motion.normal }
            NumberAnimation { target: tabShift; property: "y"; to: 0; duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
        }
    }
}
