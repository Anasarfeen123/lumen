import QtQuick
import qs.theme
import qs.components

Column {
    property string icon: "folder_open"
    property string title: ""
    property string detail: ""
    spacing: Theme.space.s3
    LIcon { anchors.horizontalCenter: parent.horizontalCenter; icon: parent.icon; size: Theme.space.s8; color: Theme.textMuted }
    LText { width: parent.width; horizontalAlignment: Text.AlignHCenter; role: "heading"; text: parent.title; wrapMode: Text.Wrap; textFormat: Text.PlainText }
    LText { width: parent.width; horizontalAlignment: Text.AlignHCenter; role: "body"; color: Theme.textSecondary; text: parent.detail; wrapMode: Text.Wrap; lineHeight: 1.45; textFormat: Text.PlainText }
}
