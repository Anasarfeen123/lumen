// Workspace indicator: calm dots, one accent capsule for the active workspace
// that glides between slots (motion-large, emphasized) — DESIGN.md §7.
//   empty: faint dot · occupied: solid dot · active: accent capsule
// Click a slot to switch; scroll anywhere on the pill to step through.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

GlassSurface {
    id: root
    required property var screen

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var workspaces: Hyprland.workspaces.values.filter(
        ws => ws.id > 0 && ws.monitor?.name === monitor?.name)
    readonly property var occupied: {
        const set = {};
        for (const ws of workspaces)
            if ((ws.toplevels?.values?.length ?? 0) > 0) set[ws.id] = true;
        return set;
    }
    // Always show at least 5 slots; grow to fit the highest workspace in use.
    readonly property int count: Math.max(5, activeId, ...workspaces.map(ws => ws.id))

    readonly property int slot: 22           // slot pitch
    readonly property int pad: Theme.space.s3

    implicitWidth: pad * 2 + count * slot
    implicitHeight: Theme.barHeight
    Behavior on implicitWidth { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }

    // Active capsule — sits under the dots and travels to the active slot.
    // Its two edges move at different speeds: the leading edge darts ahead
    // (motion-normal), the trailing edge follows (motion-large), so the capsule
    // stretches toward where you're going and settles back — motion that says
    // "you moved right/left", not just "something changed" (DESIGN.md §7).
    Rectangle {
        id: capsule
        readonly property int index: root.activeId - 1
        readonly property real baseWidth: root.slot + 8
        property bool movingRight: true
        property real edgeL: 0
        property real edgeR: 0

        function targetLeft(i) { return root.pad + i * root.slot + (root.slot - baseWidth) / 2; }
        function place(animated) {
            leftAnim.enabled = rightAnim.enabled = animated && !Theme.reducedMotion;
            // Compute from the target, never read edgeL back: it is animated,
            // so reading it mid-flight returns the old position.
            const l = targetLeft(index);
            edgeL = l;
            edgeR = l + baseWidth;
        }
        property int previous: -1
        onIndexChanged: {
            movingRight = index > previous;
            previous = index;
            place(true);
        }
        Component.onCompleted: { previous = index; place(false); }

        x: edgeL
        width: edgeR - edgeL
        height: 10
        radius: height / 2
        color: Theme.accent
        y: (root.height - height) / 2
        visible: root.activeId >= 1 && root.activeId <= root.count

        Behavior on edgeL {
            id: leftAnim
            NumberAnimation {
                duration: capsule.movingRight ? Theme.motion.large : Theme.motion.normal
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized
            }
        }
        Behavior on edgeR {
            id: rightAnim
            NumberAnimation {
                duration: capsule.movingRight ? Theme.motion.normal : Theme.motion.large
                easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized
            }
        }
    }

    Row {
        x: root.pad
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: root.count
            delegate: MouseArea {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === root.activeId
                readonly property bool isOccupied: root.occupied[wsId] === true

                width: root.slot
                height: Theme.barHeight
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                // Right-click: the tray drawer (background apps)
                onClicked: m => m.button === Qt.RightButton ? TrayState.toggle(root.screen?.name ?? "") : Hypr.workspace(wsId)

                Rectangle {
                    anchors.centerIn: parent
                    property real d: cell.isActive ? 0 : cell.containsMouse ? 9 : cell.isOccupied ? 7 : 5
                    width: d
                    height: d
                    radius: d / 2
                    color: cell.isOccupied || cell.containsMouse ? Theme.textSecondary : Theme.textMuted
                    opacity: cell.isOccupied || cell.containsMouse ? 1 : 0.55
                    Behavior on d { NumberAnimation { duration: Theme.motion.micro } }
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Hypr.workspace(event.angleDelta.y > 0 ? "r-1" : "r+1")
    }
}
