// Desktop widgets (Settings → Appearance → Desktop widgets): a clock with the
// date, the weather and what's playing, on the wallpaper below the windows —
// seen on an empty workspace. Click-through except the play button.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win
    visible: Persist.data.desktopWidgets ?? false
    anchors { top: true; left: true; bottom: true }
    implicitWidth: 520
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-desktop-widgets"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: Media.present ? playBtn : null }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        x: 56
        anchors.bottom: parent.bottom; anchors.bottomMargin: 72
        spacing: 6
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.scrim; shadowBlur: 0.8; shadowOpacity: 0.45; shadowVerticalOffset: 2; shadowHorizontalOffset: 0 }

        Text {
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Theme.withAlpha(Theme.onMedia, 0.85)
            font.family: Theme.fontUi; font.pixelSize: 22; font.weight: Font.Medium
        }
        Row {
            Text {
                id: big
                text: Theme.timeDigits(clock.date)
                color: Theme.onMedia
                font.family: Theme.fontUi; font.pixelSize: 112
                font.variableAxes: ({ "wght": 280, "ROND": 100 }); font.letterSpacing: -4
                font.features: ({ "tnum": 1 })
            }
            Text {
                visible: Theme.clock12h
                anchors.baseline: big.baseline; leftPadding: 8
                text: Theme.timePeriod(clock.date)
                color: Theme.withAlpha(Theme.onMedia, 0.7)
                font.family: Theme.fontUi; font.pixelSize: 26
            }
        }
        // the weather
        Row {
            visible: Weather.ready
            spacing: 8
            LIcon { icon: Weather.icon(Weather.now?.code ?? 0, Weather.now?.isDay); size: 24; fill: 1; color: Theme.onMedia; anchors.verticalCenter: parent.verticalCenter }
            Text { text: Math.round(Weather.now?.temp ?? 0) + "°  " + Weather.describe(Weather.now?.code ?? 0) + (Weather.place ? "  ·  " + Weather.place.name : "")
                   color: Theme.withAlpha(Theme.onMedia, 0.9); font.family: Theme.fontUi; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter }
        }
        Item { width: 1; height: 8 }
        // what's playing, in glass
        Rectangle {
            visible: Media.present
            width: 360; height: 64; radius: 18
            color: Theme.withAlpha(Theme.scrim, 0.35)
            border.width: 1; border.color: Theme.withAlpha(Theme.onMedia, 0.15)
            ClippingRectangle {
                id: art
                x: 10; anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 44; radius: 10; color: Theme.withAlpha(Theme.onMedia, 0.1)
                Image { anchors.fill: parent; source: Media.artUrl; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(88, 88); asynchronous: true }
            }
            Column {
                anchors { left: art.right; leftMargin: 12; right: playBtn.left; rightMargin: 8; verticalCenter: parent.verticalCenter }
                Text { width: parent.width; elide: Text.ElideRight; text: Media.title; color: Theme.onMedia; font.family: Theme.fontUi; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text { width: parent.width; elide: Text.ElideRight; text: Media.artist; color: Theme.withAlpha(Theme.onMedia, 0.7); font.family: Theme.fontUi; font.pixelSize: 13 }
            }
            MouseArea {
                id: playBtn
                anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                width: 36; height: 36
                cursorShape: Qt.PointingHandCursor
                onClicked: Media.toggle()
                Rectangle { anchors.fill: parent; radius: 18; color: Theme.withAlpha(Theme.onMedia, parent.containsMouse ? 0.3 : 0.2) }
                LIcon { anchors.centerIn: parent; icon: Media.playing ? "pause" : "play_arrow"; size: 22; fill: 1; color: Theme.onMedia }
                hoverEnabled: true
            }
        }
    }
}
