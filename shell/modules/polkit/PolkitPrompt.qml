// The admin password prompt (polkit), drawn by Lumen. See services/Polkit.qml.
//
// A frosted card over a dimmed, blurred desktop, on the focused screen, with
// exclusive keyboard focus (what you type can't reach another app).
//   what is asking · as whom · password (dots) · Cancel / Authenticate
//   Enter: authenticate · Esc: cancel · wrong password: shake + message
// "Details" reveals the polkit action id — what exactly is being allowed.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property var flow: Polkit.flow
    readonly property bool showing: flow !== null && isFocused
    property bool details: false
    property bool busy: false

    visible: showing || scrim.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-polkit"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: if (showing) { details = false; busy = false; field.text = ""; field.forceActiveFocus(); }

    function submit() {
        if (!flow || busy || !flow.isResponseRequired) return;
        busy = true;
        const v = field.text;
        field.text = "";
        flow.submit(v);
    }
    function cancel() { if (flow) flow.cancelAuthenticationRequest(); }

    Connections {
        target: win.flow
        ignoreUnknownSignals: true
        function onFailedChanged() { if (win.flow?.failed) { win.busy = false; shake.restart(); field.forceActiveFocus(); } }
        function onIsResponseRequiredChanged() { if (win.flow?.isResponseRequired) { win.busy = false; field.forceActiveFocus(); } }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.45)
        opacity: win.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        MouseArea { anchors.fill: parent }        // clicks outside do nothing (no accidental cancel)
    }

    GlassSurface {
        id: card
        level: "panel"
        width: 400
        height: body.implicitHeight + Theme.space.s5 * 2
        radius: Theme.radius.lg
        anchors.centerIn: parent
        opacity: win.showing ? 1 : 0
        scale: win.showing ? 1 : 0.94
        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
        Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Rectangle { anchors.fill: parent; radius: parent.radius; color: Theme.withAlpha(Theme.bg, 0.5) }

        SequentialAnimation {
            id: shake
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 10; duration: 70 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -6; duration: 60 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
        }

        Column {
            id: body
            x: Theme.space.s5; y: Theme.space.s5
            width: parent.width - Theme.space.s5 * 2
            spacing: Theme.space.s3

            // Shield
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 56; height: 56; radius: 18
                color: Theme.withAlpha(Theme.accent, 0.16)
                border.width: 1
                border.color: Theme.withAlpha(Theme.accent, 0.35)
                LIcon { anchors.centerIn: parent; icon: "admin_panel_settings"; size: 30; fill: 1; color: Theme.accent }
            }
            LText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                role: "heading"
                text: "Administrator access"
            }
            LText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.textSecondary
                text: win.flow?.message ?? ""
            }

            // As whom
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Theme.space.s2
                readonly property var ids: win.flow?.identities ?? []
                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: Theme.surfaceHover
                    anchors.verticalCenter: parent.verticalCenter
                    LText { anchors.centerIn: parent; role: "caption"; text: (win.flow?.selectedIdentity?.displayName ?? "?").charAt(0).toUpperCase() }
                }
                LText {
                    anchors.verticalCenter: parent.verticalCenter
                    role: "bodyStrong"
                    text: win.flow?.selectedIdentity?.displayName ?? ""
                }
                // More than one admin: click to switch
                LIcon {
                    visible: parent.ids.length > 1
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "swap_horiz"; size: 18; color: Theme.textMuted
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const ids = win.flow.identities;
                            const i = ids.indexOf(win.flow.selectedIdentity);
                            win.flow.selectedIdentity = ids[(i + 1) % ids.length];
                        }
                    }
                }
            }

            // Password
            FrostField {
                id: fieldBox
                width: parent.width
                failed: win.flow?.supplementaryIsError ?? false
                TextInput {
                    id: field
                    anchors { fill: parent; leftMargin: Theme.space.s4; rightMargin: Theme.space.s4 }
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: (win.flow?.responseVisible ?? false) ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "●"
                    maximumLength: 256
                    enabled: !win.busy
                    color: Theme.text
                    font.family: Theme.fontUi
                    font.pixelSize: 15
                    font.letterSpacing: echoMode === TextInput.Password ? 2 : 0
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    Keys.onReturnPressed: win.submit()
                    Keys.onEnterPressed: win.submit()
                    Keys.onEscapePressed: win.cancel()
                }
                LText {
                    anchors { left: parent.left; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                    visible: field.text === "" && !win.busy
                    color: Theme.textMuted
                    text: {
                        const p = (win.flow?.inputPrompt ?? "").replace(/:\s*$/, "");
                        return p && p.toLowerCase() !== "password" ? p : "Your password";
                    }
                }
                LIcon {
                    anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    visible: win.busy
                    icon: "progress_activity"
                    color: Theme.textSecondary
                    RotationAnimation on rotation { running: win.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                }
            }
            LText {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                role: "caption"
                color: (win.flow?.supplementaryIsError ?? false) ? Theme.error : Theme.textMuted
                text: win.flow?.supplementaryMessage ?? ""
            }

            // Details: exactly what is being allowed
            LText {
                width: parent.width
                visible: win.details
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAnywhere
                role: "caption"
                color: Theme.textMuted
                font.family: Theme.fontMono
                text: win.flow?.actionId ?? ""
            }

            Item {
                width: parent.width
                height: 40
                HoverTarget {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    width: detailsLabel.implicitWidth + Theme.space.s3 * 2; height: 32
                    onClicked: win.details = !win.details
                    LText { id: detailsLabel; anchors.centerIn: parent; role: "caption"; color: Theme.textMuted
                            text: win.details ? "Hide details" : "Details" }
                }
                Row {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s2
                    HoverTarget {
                        width: 96; height: 38
                        onClicked: win.cancel()
                        Rectangle { anchors.fill: parent; radius: height / 2; color: "transparent"; border.width: 1; border.color: Theme.border }
                        LText { anchors.centerIn: parent; text: "Cancel" }
                    }
                    HoverTarget {
                        width: 128; height: 38
                        enabled: field.text !== "" && !win.busy
                        onClicked: win.submit()
                        Rectangle { anchors.fill: parent; radius: height / 2; color: Theme.accent; opacity: parent.enabled ? 1 : 0.4 }
                        LText { anchors.centerIn: parent; role: "bodyStrong"; color: Theme.onAccent; text: "Authenticate" }
                    }
                }
            }
        }
    }

    // Pill-shaped input well
    component FrostField: Rectangle {
        property bool failed: false
        height: 46
        radius: height / 2
        color: Theme.withAlpha(Theme.text, 0.06)
        border.width: 1
        border.color: failed ? Theme.error : field.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
    }
}
