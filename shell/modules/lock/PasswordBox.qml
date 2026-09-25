// The password pill. The real TextInput is invisible; what you see is one
// dot per character (they pop in), a spinner while PAM checks, a check on
// success, and a shake + red edge on failure.
//   Enter: unlock · Esc: clear
import QtQuick
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    property alias input: input
    implicitWidth: 300
    implicitHeight: 48
    radius: height / 2
    edge: Lock.status === "failed" ? Theme.error
        : input.activeFocus && input.text !== "" ? Theme.withAlpha(Theme.text, 0.35) : Theme.border

    Connections {
        target: Lock
        function onFailed() { shake.restart(); }
    }

    TextInput {
        id: input
        anchors.fill: parent
        opacity: 0
        focus: true
        echoMode: TextInput.Password
        maximumLength: 256
        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
        Keys.onReturnPressed: { const pw = text; text = ""; Lock.submit(pw); }
        Keys.onEnterPressed: { const pw = text; text = ""; Lock.submit(pw); }
        Keys.onEscapePressed: text = ""
        // F2: scan my face now (the only trigger on battery).
        // Any other key is "I'm here": starts Face ID on AC power.
        Keys.onPressed: event => {
            if (event.key === Qt.Key_F2) { Lock.requestFace(); event.accepted = true; return; }
            Lock.intent();
            event.accepted = false;
        }
        onTextChanged: if (text !== "" && Lock.status === "failed") Lock.status = "idle"
    }

    // Dots
    Row {
        anchors.centerIn: parent
        spacing: 7
        visible: Lock.status === "idle" || Lock.status === "failed"
        Repeater {
            model: Math.min(input.text.length, 20)
            delegate: Rectangle {
                width: 8; height: 8; radius: 4
                color: Theme.text
                scale: 0
                Component.onCompleted: scale = 1
                Behavior on scale { NumberAnimation { duration: Theme.motion.micro; easing.type: Easing.OutBack } }
            }
        }
    }

    LText {
        anchors.centerIn: parent
        visible: input.text === "" && (Lock.status === "idle" || Lock.status === "failed")
        role: "body"
        color: Theme.textMuted
        text: "Enter password"
    }

    LIcon {
        anchors.centerIn: parent
        visible: Lock.status === "checking"
        icon: "progress_activity"
        color: Theme.textSecondary
        RotationAnimation on rotation { running: Lock.status === "checking"; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
    }

    LIcon {
        anchors.centerIn: parent
        visible: Lock.status === "success"
        icon: "check"
        fill: 1
        color: Theme.success
    }

    // Enter hint
    LIcon {
        anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
        visible: input.text !== "" && Lock.status !== "checking"
        icon: "arrow_forward"
        size: Theme.size.iconSmall
        color: Theme.textSecondary
    }

    SequentialAnimation {
        id: shake
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 3; duration: 50 }
        NumberAnimation { target: root; property: "anchors.horizontalCenterOffset"; to: 0; duration: 40 }
    }
}
