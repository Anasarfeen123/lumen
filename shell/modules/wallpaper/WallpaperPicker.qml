// Wallpaper picker (Ctrl+Super+T). A frosted sheet over a dimmed desktop:
//
//   Wallpapers                          ◉ Match accent   ⤮ Shuffle
//   [All] [Plasma] [System] …
//   ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐
//   │     │ │  ✓  │ │     │ │     │     current = accent ring + check
//   └─────┘ └─────┘ └─────┘ └─────┘
//
// Keys: ←↑→↓ move · Enter apply (stays open so you can keep browsing) ·
//       Tab next category · R shuffle · A match accent · Esc close
// Applying cross-fades the real desktop behind the sheet.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.theme
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property bool isFocused: Quickshell.screens.length <= 1
                                      || (Hyprland.focusedMonitor?.name ?? "") === (monitor?.name ?? "")
    readonly property bool showing: Wallpapers.open && isFocused

    visible: showing || sheet.opacity > 0
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onShowingChanged: if (showing) {
        grid.currentIndex = Math.max(0, Wallpapers.visibleItems.findIndex(i => i.path === Wallpapers.current));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Center);
        sheet.forceActiveFocus();
    }

    // Light scrim: the desktop stays visible so you see each change land
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bg, 0.28)
        opacity: sheet.opacity
        MouseArea { anchors.fill: parent; onClicked: Wallpapers.hide() }
    }

    GlassSurface {
        id: sheet
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(win.width - 2 * Theme.space.s8, grid.cellWidth * 4 + Theme.space.s5 * 2)
        height: Math.min(win.height * 0.72, 620)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.showing ? Theme.space.s8 : Theme.space.s8 - 32

        opacity: win.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: win.showing ? Theme.motion.normal : Theme.motion.normal * Theme.motion.exitRatio } }
        Behavior on anchors.bottomMargin { NumberAnimation { duration: Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } }

        MouseArea { anchors.fill: parent }       // clicks on the sheet don't close it

        Keys.onEscapePressed: Wallpapers.hide()
        Keys.onPressed: event => {
            const cats = Wallpapers.categories;
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                const i = cats.indexOf(Wallpapers.category);
                const step = event.key === Qt.Key_Backtab ? -1 : 1;
                Wallpapers.category = cats[(i + step + cats.length) % cats.length];
                grid.currentIndex = 0;
            } else if (event.key === Qt.Key_R) Wallpapers.random();
            else if (event.key === Qt.Key_A) Wallpapers.setMatchAccent(!Wallpapers.matchAccent);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                const it = Wallpapers.visibleItems[grid.currentIndex];
                if (it) Wallpapers.apply(it.path);
            } else if (event.key === Qt.Key_Left) grid.moveCurrentIndexLeft();
            else if (event.key === Qt.Key_Right) grid.moveCurrentIndexRight();
            else if (event.key === Qt.Key_Up) grid.moveCurrentIndexUp();
            else if (event.key === Qt.Key_Down) grid.moveCurrentIndexDown();
            else return;
            event.accepted = true;
        }

        // Header
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s5 }
            height: 32
            LText { anchors.verticalCenter: parent.verticalCenter; role: "title"; text: "Wallpapers" }

            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s3

                // Match accent switch
                HoverTarget {
                    width: matchRow.implicitWidth + Theme.space.s3 * 2
                    height: 32
                    radius: Theme.radius.sm
                    onClicked: Wallpapers.setMatchAccent(!Wallpapers.matchAccent)
                    Row {
                        id: matchRow
                        anchors.centerIn: parent
                        spacing: Theme.space.s2
                        Rectangle {
                            width: 34; height: 20; radius: 10
                            anchors.verticalCenter: parent.verticalCenter
                            color: Wallpapers.matchAccent ? Theme.accent : Theme.surfaceHover
                            Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                            Rectangle {
                                width: 14; height: 14; radius: 7; y: 3
                                x: Wallpapers.matchAccent ? parent.width - width - 3 : 3
                                color: Wallpapers.matchAccent ? Theme.onAccent : Theme.textSecondary
                                Behavior on x { NumberAnimation { duration: Theme.motion.micro } }
                            }
                        }
                        LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; text: "Match accent" }
                    }
                }
                HoverTarget {
                    width: shuffleRow.implicitWidth + Theme.space.s3 * 2
                    height: 32
                    radius: Theme.radius.sm
                    onClicked: Wallpapers.random()
                    Row {
                        id: shuffleRow
                        anchors.centerIn: parent
                        spacing: Theme.space.s1
                        LIcon { icon: "shuffle"; size: Theme.size.iconSmall; anchors.verticalCenter: parent.verticalCenter }
                        LText { role: "bodyStrong"; text: "Shuffle"; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // Category chips
        Row {
            id: chips
            anchors { top: header.bottom; topMargin: Theme.space.s3; left: parent.left; leftMargin: Theme.space.s5 }
            spacing: Theme.space.s2
            Repeater {
                model: Wallpapers.categories
                delegate: HoverTarget {
                    required property string modelData
                    readonly property bool on: Wallpapers.category === modelData
                    width: chipLabel.implicitWidth + Theme.space.s4 * 2
                    height: 28
                    radius: 14
                    onClicked: { Wallpapers.category = modelData; grid.currentIndex = 0; }
                    Rectangle {
                        anchors.fill: parent; radius: 14
                        color: parent.on ? Theme.accent : "transparent"
                        border.width: 1
                        border.color: parent.on ? Theme.accent : Theme.border
                        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                    }
                    LText {
                        id: chipLabel
                        anchors.centerIn: parent
                        role: "bodyStrong"
                        color: parent.on ? Theme.onAccent : Theme.textSecondary
                        text: modelData
                    }
                }
            }
        }

        GridView {
            id: grid
            anchors { top: chips.bottom; topMargin: Theme.space.s4; left: parent.left; right: parent.right; bottom: parent.bottom
                      leftMargin: Theme.space.s5; rightMargin: Theme.space.s5; bottomMargin: Theme.space.s4 }
            clip: true
            cellWidth: 244
            cellHeight: 146
            model: Wallpapers.visibleItems
            boundsBehavior: Flickable.StopAtBounds
            highlightFollowsCurrentItem: false
            keyNavigationEnabled: false

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isCurrent: Wallpapers.current === modelData.path
                readonly property bool isSelected: GridView.isCurrentItem
                width: grid.cellWidth
                height: grid.cellHeight

                ClippingRectangle {
                    id: tile
                    anchors { fill: parent; margins: 6 }
                    radius: Theme.radius.md
                    color: Theme.surfaceElevated
                    scale: hover.containsMouse || cell.isSelected ? 1.03 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.thumbFor(cell.modelData.path)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(480, 270)
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                    }
                }
                // Ring: accent for current, soft white for keyboard selection
                Rectangle {
                    anchors { fill: tile; margins: -3 }
                    scale: tile.scale
                    radius: Theme.radius.md + 3
                    color: "transparent"
                    border.width: 2
                    border.color: cell.isCurrent ? Theme.accent : Theme.withAlpha(Theme.text, 0.7)
                    visible: cell.isCurrent || cell.isSelected
                }
                Rectangle {
                    visible: cell.isCurrent
                    anchors { right: tile.right; top: tile.top; margins: 8 }
                    width: 22; height: 22; radius: 11
                    color: Theme.accent
                    LIcon { anchors.centerIn: parent; icon: "check"; size: 16; fill: 1; color: Theme.onAccent }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { grid.currentIndex = cell.index; Wallpapers.apply(cell.modelData.path); }
                }
            }
        }

        LText {
            anchors.centerIn: grid
            visible: Wallpapers.visibleItems.length === 0
            color: Theme.textMuted
            text: "Put pictures in ~/Pictures/Wallpapers — sub-folders become categories"
        }
    }
}
