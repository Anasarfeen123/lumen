// Lumen Settings — a real app window (Super+I). Frosted sidebar of pages,
// large content area; page changes slide and fade (motion-normal).
//   ↑/↓ in the sidebar change page · Esc closes · Ctrl+W closes
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import "pages"

FloatingWindow {
    id: win
    title: "Lumen Settings"
    visible: SettingsState.open
    implicitWidth: 1020
    implicitHeight: 760
    minimumSize: Qt.size(820, 560)
    color: Theme.withAlpha(Theme.bg, 0.86)

    // Closing the window (Super+Q, ×) keeps the state in sync — but only once
    // it has really been on screen (creation can report a transient "hidden")
    property bool shownOnce: false
    onVisibleChanged: {
        if (visible) shownOnce = true;
        else if (shownOnce) { shownOnce = false; SettingsState.open = false; }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: SettingsState.open = false
        Keys.onPressed: event => {
            const ps = SettingsState.pages, i = ps.findIndex(p => p.id === SettingsState.page);
            if (event.key === Qt.Key_Down && i < ps.length - 1) SettingsState.page = ps[i + 1].id;
            else if (event.key === Qt.Key_Up && i > 0) SettingsState.page = ps[i - 1].id;
            else if (event.key === Qt.Key_W && event.modifiers & Qt.ControlModifier) SettingsState.open = false;
            else if (event.key === Qt.Key_F && event.modifiers & Qt.ControlModifier) searchInput.forceActiveFocus();
            else return;
            event.accepted = true;
        }

        // ── Sidebar ──
        Rectangle {
            id: sidebar
            width: 244
            anchors { top: parent.top; bottom: parent.bottom; left: parent.left }
            color: Theme.withAlpha(Theme.surface, 0.55)
            Rectangle {
                anchors { top: parent.top; bottom: parent.bottom; right: parent.right }
                width: 1
                color: Theme.border
            }

            Column {
                anchors { fill: parent; margins: Theme.space.s4; topMargin: Theme.space.s6 }
                spacing: 2

                Row {
                    spacing: Theme.space.s2
                    leftPadding: Theme.space.s2
                    bottomPadding: Theme.space.s5
                    LumenLogo { size: 30 }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "heading"; text: "Settings" }
                }

                // Search: filters pages by name and keywords; Enter opens the first
                Rectangle {
                    width: sidebar.width - Theme.space.s4 * 2
                    height: 34
                    radius: 17
                    color: Theme.surfaceElevated
                    border.width: 1
                    border.color: searchInput.activeFocus ? Theme.accent : Theme.border
                    LIcon { id: searchGlyph; anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            icon: "search"; size: Theme.size.iconSmall; color: Theme.textMuted }
                    TextInput {
                        id: searchInput
                        anchors { left: searchGlyph.right; leftMargin: Theme.space.s2; right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        color: Theme.text
                        font.family: Theme.fontUi
                        font.pixelSize: Theme.size.body
                        clip: true
                        onTextChanged: SettingsState.search = text
                        Keys.onReturnPressed: if (SettingsState.visiblePages.length > 0) SettingsState.page = SettingsState.visiblePages[0].id
                        Keys.onEscapePressed: event => { if (text !== "") { text = ""; event.accepted = true; } else event.accepted = false; }
                        LText { visible: parent.text === ""; color: Theme.textMuted; text: "Search"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Item { width: 1; height: Theme.space.s2 }

                Repeater {
                    model: SettingsState.visiblePages
                    delegate: HoverTarget {
                        required property var modelData
                        readonly property bool on: SettingsState.page === modelData.id
                        width: sidebar.width - Theme.space.s4 * 2
                        height: 38
                        radius: Theme.radius.sm
                        highlighted: on
                        onClicked: SettingsState.page = modelData.id

                        Rectangle {
                            visible: parent.on
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3; height: 18; radius: 2
                            color: Theme.accent
                        }
                        Row {
                            anchors { left: parent.left; leftMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                            spacing: Theme.space.s3
                            LIcon { icon: modelData.icon; size: Theme.size.iconSmall; fill: parent.parent.on ? 1 : 0; color: parent.parent.on ? Theme.accent : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            LText { role: parent.parent.on ? "bodyStrong" : "body"; text: modelData.label; color: parent.parent.on ? Theme.text : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        // ── Content ──
        Item {
            id: contentArea
            anchors { top: parent.top; bottom: parent.bottom; left: sidebar.right; right: parent.right }
            clip: true

            Loader {
                id: pageLoader
                anchors.fill: parent
                property string shown: SettingsState.page
                sourceComponent: ({
                    appearance: appearanceC, wallpaper: wallpaperC, bar: barC, display: displayC,
                    sound: soundC, faceid: faceC, power: powerC, keyboard: keyboardC, about: aboutC,
                    windows: windowsC, notifications: notificationsC, network: networkC, bluetooth: bluetoothC, lock: lockC, ai: aiC, updates: updatesC
                })[shown] ?? appearanceC

                // Slide + fade between pages
                opacity: 1
                transform: Translate { id: shift; y: 0 }
                Connections {
                    target: SettingsState
                    function onPageChanged() { swap.restart(); }
                }
                SequentialAnimation {
                    id: swap
                    NumberAnimation { target: pageLoader; property: "opacity"; to: 0; duration: Theme.reducedMotion ? 0 : 90 }
                    ScriptAction { script: { pageLoader.shown = SettingsState.page; shift.y = 14; } }
                    ParallelAnimation {
                        NumberAnimation { target: pageLoader; property: "opacity"; to: 1; duration: Theme.motion.normal }
                        NumberAnimation { target: shift; property: "y"; to: 0; duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized }
                    }
                }
            }
        }
    }

    Component { id: appearanceC; AppearancePage {} }
    Component { id: wallpaperC; WallpaperPage {} }
    Component { id: barC; BarPage {} }
    Component { id: displayC; DisplayPage {} }
    Component { id: soundC; SoundPage {} }
    Component { id: faceC; FaceIdPage {} }
    Component { id: powerC; PowerPage {} }
    Component { id: keyboardC; KeyboardPage {} }
    Component { id: aboutC; AboutPage {} }
    Component { id: windowsC; WindowsPage {} }
    Component { id: notificationsC; NotificationsPage {} }
    Component { id: networkC; NetworkPage {} }
    Component { id: bluetoothC; BluetoothPage {} }
    Component { id: lockC; LockPage {} }
    Component { id: aiC; AiPage {} }
    Component { id: updatesC; UpdatesPage {} }
}
