// A pick-one list in Lumen style: a pill showing the choice, and a frosted
// popup (LumenPopup) listing the options under it — the current one ticked,
// a second line of detail if given. Click, ↑/↓ + Enter, or Esc to close.
//   LDropdown { options: [{ id, label, detail? }]; current: "…"; onPicked: id => … }
import QtQuick
import Quickshell
import qs.theme

HoverTarget {
    id: root
    property var options: []
    property string current: ""
    property string placeholder: "Choose…"
    property int maxVisible: 7
    signal picked(string id)

    readonly property var chosen: options.find(o => o.id === current) ?? null
    width: 220; height: 34
    radius: height / 2
    activeFocusOnTab: true
    onClicked: toggle()
    Keys.onReturnPressed: toggle()
    Keys.onSpacePressed: toggle()
    function toggle() { if (pop.visible) pop.close(); else { list.currentIndex = Math.max(0, options.findIndex(o => o.id === current)); pop.open(); } }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.withAlpha(Theme.text, root.containsMouse || pop.shown ? 0.08 : 0.05)
        border.width: 1
        border.color: pop.shown || root.activeFocus ? Theme.withAlpha(Theme.accent, 0.6) : Theme.border
        Behavior on border.color { ColorAnimation { duration: Theme.motion.micro } }
    }
    LText {
        anchors { left: parent.left; leftMargin: Theme.space.s3; right: caret.left; rightMargin: Theme.space.s1; verticalCenter: parent.verticalCenter }
        elide: Text.ElideRight
        role: "body"
        color: root.chosen ? Theme.text : Theme.textMuted
        text: root.chosen?.label ?? root.placeholder
    }
    LIcon {
        id: caret
        anchors { right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
        icon: "expand_more"; size: 18; color: Theme.textMuted
        rotation: pop.shown ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutCubic } }
    }

    LumenPopup {
        id: pop
        anchor.item: root
        anchor.rect.x: -margin
        anchor.rect.y: root.height + 4 - margin
        contentWidth: Math.max(root.width, 220)
        contentHeight: Math.min(root.options.length, root.maxVisible) * 40 + Theme.space.s1 * 2

        ListView {
            id: list
            anchors { fill: parent; margins: Theme.space.s1 }
            clip: true
            model: root.options
            focus: pop.shown
            keyNavigationWraps: true
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            Keys.onReturnPressed: { const o = root.options[currentIndex]; if (o) choose(o.id); }
            Keys.onEscapePressed: pop.close()
            function choose(id) { pop.close(); if (id !== root.current) root.picked(id); }
            delegate: HoverTarget {
                id: opt
                required property var modelData
                required property int index
                readonly property bool isCurrent: modelData.id === root.current
                width: ListView.view.width; height: 40
                radius: Theme.radius.sm
                onClicked: list.choose(modelData.id)
                onContainsMouseChanged: if (containsMouse) list.currentIndex = index
                Rectangle {
                    anchors.fill: parent; radius: parent.radius; z: -1
                    color: opt.ListView.isCurrentItem ? Theme.withAlpha(Theme.text, 0.07) : "transparent"
                }
                Column {
                    anchors { left: parent.left; leftMargin: Theme.space.s3; right: tick.left; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                    LText { width: parent.width; elide: Text.ElideRight; role: opt.isCurrent ? "bodyStrong" : "body"
                            color: opt.isCurrent ? Theme.accent : Theme.text; text: opt.modelData.label }
                    LText { visible: !!opt.modelData.detail; width: parent.width; elide: Text.ElideRight
                            role: "caption"; color: Theme.textMuted; text: opt.modelData.detail ?? "" }
                }
                LIcon { id: tick; anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                        visible: opt.isCurrent; icon: "check"; size: 16; color: Theme.accent }
            }
        }
    }
}
