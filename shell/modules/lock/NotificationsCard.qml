// How many notifications are waiting, and from which apps. Never their
// content — the lock screen is visible to anyone at the desk.
import QtQuick
import qs.theme
import qs.components
import qs.services

FrostPane {
    id: root
    implicitWidth: 176
    implicitHeight: 176

    readonly property var apps: {
        Notifications.count;                       // re-evaluate on change
        const seen = [], out = [];
        for (let i = 0; i < Notifications.model.count && out.length < 3; i++) {
            const e = Notifications.model.get(i);
            if (!seen.includes(e.appName)) { seen.push(e.appName); out.push({ name: e.appName, icon: e.icon }); }
        }
        return out;
    }

    Column {
        anchors { fill: parent; margins: Theme.space.s4 }
        spacing: Theme.space.s1

        Text {
            text: Notifications.count
            color: Theme.text
            font.family: Theme.fontUi
            font.pixelSize: 40
            font.weight: Font.Light
            font.features: ({ "tnum": 1 })
        }
        LText { role: "caption"; color: Theme.textSecondary; text: Notifications.count === 1 ? "notification" : "notifications" }

        Item { width: 1; height: Theme.space.s2 }

        Repeater {
            model: root.apps
            delegate: Row {
                required property var modelData
                spacing: Theme.space.s2
                Image {
                    width: 16; height: 16
                    sourceSize: Qt.size(32, 32)
                    source: modelData.icon || ""
                    visible: status === Image.Ready
                    anchors.verticalCenter: parent.verticalCenter
                }
                LText { role: "caption"; text: modelData.name; width: 120; elide: Text.ElideRight }
            }
        }
    }
}
