// recording — live dot + elapsed time. Click the island to stop; right-click
// pauses and resumes (the clock leaves paused time out).
// The pulse is the only continuous animation in the shell: it means "live".
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: root
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height
    property int elapsed: 0

    Timer {
        interval: 1000; repeat: true; running: root.visible; triggeredOnStart: true
        onTriggered: {
            const now = Island.recordingPaused ? Island.recordingPausedAt : Date.now();
            root.elapsed = Math.max(0, Math.floor((now - Island.recordingSince.getTime() - Island.recordingPausedTotal) / 1000));
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2
        Rectangle {
            width: 8; height: 8; radius: 4
            color: Island.recordingPaused ? Theme.textMuted : Theme.error
            anchors.verticalCenter: parent.verticalCenter
            SequentialAnimation on opacity {
                running: !Theme.reducedMotion && !Island.recordingPaused
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        LText { role: "bodyStrong"; text: Media.formatTime(root.elapsed); color: Island.recordingPaused ? Theme.textMuted : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        LText { visible: Island.recordingPaused; role: "caption"; color: Theme.textMuted; text: "Paused"; anchors.verticalCenter: parent.verticalCenter }
        LIcon { icon: Island.recordingPaused ? "play_circle" : "stop_circle"; size: Theme.size.iconSmall; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
    }
}
