// A notification in the centre. Hover shows ×; swipe right (or ×) dismisses.
// Live notifications show their action buttons and, if supported, a reply field.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    required property int index
    required property int nid
    required property string appName
    required property string icon
    required property string summary
    required property string body
    required property int urgency
    required property real time
    required property bool canReply
    property real now: Date.now()

    readonly property var liveNotif: Notifications.live[nid] ?? null
    readonly property var actions: (liveNotif?.actions ?? []).filter(a => a.identifier !== "default")
    readonly property bool critical: urgency === 2

    width: ListView.view?.width ?? 0
    height: card.height + Theme.space.s2

    Rectangle {
        id: card
        x: drag.active ? drag.xOffset : 0
        width: parent.width
        height: content.implicitHeight + Theme.space.s3 * 2
        radius: Theme.radius.md
        color: hover.hovered ? Theme.surfaceHover : Theme.surfaceElevated
        opacity: 1 - Math.min(0.7, Math.max(0, x) / (width * 0.8))
        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
        Behavior on x { enabled: !drag.active; NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

        // Urgent: thin error-tone edge
        Rectangle {
            visible: root.critical
            width: 3; radius: 1.5
            color: Theme.error
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: Theme.space.s2 }
        }

        HoverHandler { id: hover }
        TapHandler { onTapped: Notifications.activate(root.nid) }
        DragHandler {
            id: drag
            xAxis.enabled: true; yAxis.enabled: false
            xAxis.minimum: 0
            property real xOffset: Math.max(0, translation.x)
            onActiveChanged: if (!active && translation.x > card.width * 0.35) Notifications.dismiss(root.nid)
        }

        Item {
            id: content
            anchors { fill: parent; margins: Theme.space.s3 }
            implicitHeight: col.implicitHeight

            ClippingRectangle {
                id: iconBox
                width: 32; height: 32
                radius: Theme.radius.sm
                color: Theme.surfaceHover
                LIcon { anchors.centerIn: parent; visible: img.status !== Image.Ready; icon: "notifications"; size: Theme.size.iconSmall; color: Theme.textMuted }
                Image { id: img; anchors.fill: parent; source: root.icon; sourceSize: Qt.size(64, 64); fillMode: Image.PreserveAspectCrop; asynchronous: true }
            }

            Column {
                id: col
                anchors { left: iconBox.right; leftMargin: Theme.space.s3; right: parent.right }
                spacing: 2

                Item {
                    width: parent.width; height: title.implicitHeight
                    LText { id: title; anchors { left: parent.left; right: meta.left; rightMargin: Theme.space.s2 }
                            role: "bodyStrong"; text: root.summary; elide: Text.ElideRight; textFormat: Text.PlainText }
                    Item {
                        id: meta
                        anchors.right: parent.right
                        width: Math.max(timeLabel.implicitWidth, 20); height: parent.height
                        LText { id: timeLabel; anchors.right: parent.right; visible: !hover.hovered; role: "caption"; color: Theme.textMuted
                                text: Notifications.relativeTime(root.time, root.now) }
                        HoverTarget {
                            visible: hover.hovered
                            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                            width: 20; height: 20
                            onClicked: Notifications.dismiss(root.nid)
                            LIcon { anchors.centerIn: parent; icon: "close"; size: 14; color: Theme.textSecondary }
                        }
                    }
                }
                LText {
                    width: parent.width
                    visible: root.body !== ""
                    role: "body"; color: Theme.textSecondary
                    text: root.body
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    linkColor: Theme.accent
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                Flow {
                    width: parent.width
                    visible: root.actions.length > 0
                    spacing: Theme.space.s2
                    topPadding: Theme.space.s1
                    Repeater {
                        model: root.actions
                        delegate: HoverTarget {
                            required property var modelData
                            width: al.implicitWidth + Theme.space.s3 * 2; height: 28
                            radius: Theme.radius.sm
                            Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.surfaceHover; z: -1 }
                            onClicked: Notifications.invoke(root.nid, modelData.identifier)
                            LText { id: al; anchors.centerIn: parent; role: "caption"; color: Theme.text; text: modelData.text }
                        }
                    }
                }

                QQC.TextField {
                    visible: root.canReply && root.liveNotif !== null
                    width: parent.width
                    placeholderText: root.liveNotif?.inlineReplyPlaceholder || "Reply…"
                    placeholderTextColor: Theme.textMuted
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: Theme.size.body
                    background: Rectangle { radius: Theme.radius.sm; color: Theme.surface; border.width: 1; border.color: parent.activeFocus ? Theme.accent : Theme.border }
                    onAccepted: Notifications.reply(root.nid, text)
                }
            }
        }
    }
}
