// Hosts one of your widgets (services/Widgets.qml): loads its QML, hands it
// the `lumen` API, asks for system samples if it said it needs them, and shows
// what went wrong if it doesn't load — the rest of the shell carries on.
import QtQuick
import qs.theme
import qs.components
import qs.services

Item {
    id: host
    required property var widget
    property bool live: true            // false while hidden: stats sampling stops
    implicitHeight: loader.status === Loader.Ready ? (loader.item.implicitHeight || 120) : err.implicitHeight + 24
    implicitWidth: loader.status === Loader.Ready ? (loader.item.implicitWidth || 280) : 280

    readonly property string sysKey: "widget:" + widget.id + ":" + Math.random().toString(36).slice(2)
    readonly property bool wantsSys: live && widget.needs.includes("system")
    onWantsSysChanged: Sysinfo.request(sysKey, wantsSys ? "detail" : "")
    Component.onCompleted: Sysinfo.request(sysKey, wantsSys ? "detail" : "")
    Component.onDestruction: Sysinfo.request(sysKey, "")

    Loader {
        id: loader
        width: host.width
        source: "file://" + host.widget.path + "/" + host.widget.entry
        asynchronous: true
        onLoaded: { if ("lumen" in item) item.lumen = Widgets.api; item.width = Qt.binding(() => host.width); }
    }
    Rectangle {
        visible: loader.status === Loader.Error
        anchors.fill: parent
        radius: Theme.radius.md
        color: Theme.withAlpha(Theme.error, 0.08); border.width: 1; border.color: Theme.withAlpha(Theme.error, 0.4)
        LText {
            id: err
            anchors { fill: parent; margins: 12 }
            wrapMode: Text.Wrap; role: "caption"; color: Theme.textSecondary
            text: "“" + host.widget.name + "” didn't load. Why: lumen widgets check " + host.widget.id
        }
    }
}
