// now playing — art + title, shown for a few seconds when a track starts.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.island.height
    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.space.s2
        Art { source: Media.artUrl; size: 20; anchors.verticalCenter: parent.verticalCenter }
        LText {
            role: "bodyStrong"; text: Media.title
            elide: Text.ElideRight; width: Math.min(implicitWidth, 200)
            anchors.verticalCenter: parent.verticalCenter
        }
        Equalizer { anchors.verticalCenter: parent.verticalCenter }
    }
}
