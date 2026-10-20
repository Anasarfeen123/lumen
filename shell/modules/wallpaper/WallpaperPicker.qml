// Wallpaper picker (Ctrl+Super+T). A frosted sheet rises over a dimmed desktop
// with a coverflow of wallpapers: the focused one large in the middle, its
// neighbours turned away on either side, all gliding as you move.
//
//   Wallpapers · 48                              ◉ Match accent   ⤮ Shuffle
//   [All] [Plasma] [System] …
//        ╱▔▔╲  ╱▔▔╲ ┌──────────┐ ╱▔▔╲  ╱▔▔╲
//        ▏  ▕  ▏  ▕ │  focused │ ▏  ▕  ▏  ▕       current = accent ring + ✓
//        ╲▁▁╱  ╲▁▁╱ └──────────┘ ╲▁▁╱  ╲▁▁╱
//                   Name · 12 / 48
//
// ←/→ or scroll: move · click a side one: bring it to the middle · click the
// middle one or Enter: apply (stays open) · Tab: next category · R: shuffle ·
// A: match accent · Esc: close. Applying cross-fades the real desktop behind.
import QtQuick
import QtQuick.Effects
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
    property real shown: showing ? 1 : 0
    Behavior on shown { NumberAnimation { duration: Theme.reducedMotion ? 0 : (win.showing ? Theme.motion.large : Theme.motion.normal); easing.type: Easing.Bezier; easing.bezierCurve: win.showing ? Theme.curveEmphasized : Theme.curveAccelerate } }

    visible: showing || shown > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-wallpapers"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property var items: Wallpapers.visibleItems
    readonly property var focused: items[view.currentIndex] ?? null
    // a file's name — or, for a KDE wallpaper package (…/Name/contents/images/2560x1600.jpg), the package's
    function name(p) {
        const m = /([^/]+)\/contents\/images(_dark)?\/[^/]+$/.exec(p ?? "");
        return (m ? m[1] + (m[2] ? " (dark)" : "") : (p ?? "").replace(/^.*\//, "").replace(/\.[^.]+$/, "")).replace(/[_-]+/g, " ");
    }
    function goCurrent() {
        const i = items.findIndex(i => i.path === Wallpapers.current);
        view.positionViewAtIndex(Math.max(0, i), PathView.Center);
        view.currentIndex = Math.max(0, i);
    }
    function applyFocused() {
        if (!focused) return;
        Wallpapers.apply(focused.path);
        applied.restart();
    }
    function pickCategory(c) {
        Wallpapers.category = c;
        Qt.callLater(goCurrent);
    }

    onShowingChanged: if (showing) { Qt.callLater(goCurrent); sheet.forceActiveFocus(); }

    // The desktop stays in view (lightly dimmed) so each change lands where you see it
    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.bg, 0.32)
        opacity: win.shown
        MouseArea { anchors.fill: parent; onClicked: Wallpapers.hide() }
    }

    GlassSurface {
        id: sheet
        level: "panel"
        radius: Theme.radius.lg
        width: Math.min(win.width - 2 * Theme.space.s8, 1320)
        height: Math.min(win.height * 0.62, 470)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space.s8 - 48 * (1 - win.shown)
        opacity: Math.min(1, win.shown * 1.4)
        scale: 0.96 + 0.04 * win.shown
        transformOrigin: Item.Bottom

        MouseArea { anchors.fill: parent; onWheel: w => { if (w.angleDelta.y > 0 || w.angleDelta.x > 0) view.decrementCurrentIndex(); else view.incrementCurrentIndex(); } }

        Keys.onEscapePressed: Wallpapers.hide()
        Keys.onPressed: event => {
            const cats = Wallpapers.categories;
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                const i = cats.indexOf(Wallpapers.category);
                win.pickCategory(cats[(i + (event.key === Qt.Key_Backtab ? -1 : 1) + cats.length) % cats.length]);
            } else if (event.key === Qt.Key_R) Wallpapers.random();
            else if (event.key === Qt.Key_A) Wallpapers.setMatchAccent(!Wallpapers.matchAccent);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) win.applyFocused();
            else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) view.decrementCurrentIndex();
            else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) view.incrementCurrentIndex();
            else if (event.key === Qt.Key_Home) view.currentIndex = 0;
            else if (event.key === Qt.Key_End) view.currentIndex = Math.max(0, win.items.length - 1);
            else return;
            event.accepted = true;
        }

        // ── header ──
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: Theme.space.s5 }
            height: 34
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.space.s2
                LText { role: "title"; text: "Wallpapers"; anchors.baseline: parent.verticalCenter; anchors.baselineOffset: 8 }
                LText { role: "body"; color: Theme.textMuted; text: Wallpapers.items.length; anchors.baseline: parent.verticalCenter; anchors.baselineOffset: 8 }
            }
            Row {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                spacing: Theme.space.s2
                Pill {
                    on: Wallpapers.matchAccent
                    onClicked: Wallpapers.setMatchAccent(!Wallpapers.matchAccent)
                    Rectangle {
                        width: 30; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Wallpapers.matchAccent ? Theme.accent : Theme.surfaceHover
                        Behavior on color { ColorAnimation { duration: Theme.motion.micro } }
                        Rectangle {
                            width: 12; height: 12; radius: 6; y: 3
                            x: Wallpapers.matchAccent ? parent.width - width - 3 : 3
                            color: Wallpapers.matchAccent ? Theme.onAccent : Theme.textSecondary
                            Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                        }
                    }
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "bodyStrong"; text: "Match accent" }
                }
                Pill {
                    onClicked: { Wallpapers.random(); Qt.callLater(win.goCurrent); }
                    LIcon { icon: "shuffle"; size: 17; anchors.verticalCenter: parent.verticalCenter }
                    LText { role: "bodyStrong"; text: "Shuffle"; anchors.verticalCenter: parent.verticalCenter }
                }
                Pill {
                    onClicked: Wallpapers.hide()
                    LIcon { icon: "close"; size: 17; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // ── categories: chips with a gliding highlight ──
        Item {
            id: chips
            anchors { top: header.bottom; topMargin: Theme.space.s3; left: parent.left; leftMargin: Theme.space.s5 }
            width: chipRow.implicitWidth; height: 30
            visible: Wallpapers.categories.length > 2
            Rectangle {
                readonly property Item target: chipRow.children[Math.max(0, Wallpapers.categories.indexOf(Wallpapers.category))] ?? null
                x: target?.x ?? 0; width: target?.width ?? 0; height: 30; radius: 15
                color: Theme.accent
                Behavior on x { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
                Behavior on width { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveEmphasized } }
            }
            Row {
                id: chipRow
                spacing: Theme.space.s1
                Repeater {
                    model: Wallpapers.categories
                    delegate: MouseArea {
                        required property string modelData
                        readonly property bool on: Wallpapers.category === modelData
                        width: chipLabel.implicitWidth + Theme.space.s4 * 2; height: 30
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: win.pickCategory(modelData)
                        Rectangle { anchors.fill: parent; radius: 15; color: "transparent"; border.width: parent.on ? 0 : 1
                                    border.color: parent.containsMouse ? Theme.borderStrong : Theme.border }
                        LText { id: chipLabel; anchors.centerIn: parent; role: "bodyStrong"; text: modelData
                                color: parent.on ? Theme.onAccent : Theme.textSecondary
                                Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
                    }
                }
            }
        }

        // ── the coverflow ──
        PathView {
            id: view
            anchors { top: chips.visible ? chips.bottom : header.bottom; topMargin: Theme.space.s3; left: parent.left; right: parent.right; bottom: caption.top; bottomMargin: Theme.space.s2 }
            clip: true
            model: win.items
            pathItemCount: Math.min(win.items.length, Math.max(3, Math.floor(width / (tileW * 0.42)) | 1))
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: Theme.reducedMotion ? 0 : 420
            snapMode: PathView.SnapToItem
            maximumFlickVelocity: 2400
            cacheItemCount: 4
            interactive: win.items.length > 1

            readonly property real tileH: Math.max(120, height - 24)
            readonly property real tileW: tileH * 16 / 9
            path: Path {
                startX: -view.tileW * 0.2; startY: view.height / 2
                PathAttribute { name: "itemScale"; value: 0.58 }
                PathAttribute { name: "itemAngle"; value: 48 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemFade"; value: 0.35 }
                PathLine { x: view.width / 2 - view.tileW * 0.62; y: view.height / 2 }
                PathPercent { value: 0.42 }
                PathAttribute { name: "itemScale"; value: 0.72 }
                PathAttribute { name: "itemAngle"; value: 38 }
                PathAttribute { name: "itemZ"; value: 5 }
                PathAttribute { name: "itemFade"; value: 0.75 }
                PathLine { x: view.width / 2; y: view.height / 2 }
                PathPercent { value: 0.5 }
                PathAttribute { name: "itemScale"; value: 1 }
                PathAttribute { name: "itemAngle"; value: 0 }
                PathAttribute { name: "itemZ"; value: 10 }
                PathAttribute { name: "itemFade"; value: 1 }
                PathLine { x: view.width / 2 + view.tileW * 0.62; y: view.height / 2 }
                PathPercent { value: 0.58 }
                PathAttribute { name: "itemScale"; value: 0.72 }
                PathAttribute { name: "itemAngle"; value: -38 }
                PathAttribute { name: "itemZ"; value: 5 }
                PathAttribute { name: "itemFade"; value: 0.75 }
                PathLine { x: view.width + view.tileW * 0.2; y: view.height / 2 }
                PathPercent { value: 1 }
                PathAttribute { name: "itemScale"; value: 0.58 }
                PathAttribute { name: "itemAngle"; value: -48 }
                PathAttribute { name: "itemZ"; value: 0 }
                PathAttribute { name: "itemFade"; value: 0.35 }
            }

            delegate: Item {
                id: cell
                required property var modelData
                required property int index
                readonly property bool isCurrent: Wallpapers.current === modelData.path
                readonly property bool centered: PathView.isCurrentItem
                width: view.tileW; height: view.tileH
                z: PathView.itemZ ?? 0
                scale: (PathView.itemScale ?? 0.6) * (hover.containsMouse && centered ? 1.02 : 1)
                opacity: (PathView.itemFade ?? 0) * win.shown
                Behavior on scale { enabled: hover.containsMouse; NumberAnimation { duration: Theme.motion.normal } }
                transform: Rotation {
                    origin.x: cell.width / 2; origin.y: cell.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: cell.PathView.itemAngle ?? 0
                }

                // the picture, rounded, with a soft shadow under the middle one
                RectangularShadow {
                    anchors.fill: tile; radius: Theme.radius.lg; blur: 30; spread: 0; offset.y: 10
                    color: Theme.withAlpha("#000000", cell.centered ? 0.5 : 0.25)
                }
                ClippingRectangle {
                    id: tile
                    anchors.fill: parent
                    radius: Theme.radius.lg
                    color: Theme.surfaceElevated
                    Image {
                        anchors.fill: parent
                        source: Wallpapers.thumbFor(cell.modelData.path)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(640, 360)
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                    }
                    // the side ones sit a little in shadow
                    Rectangle { anchors.fill: parent; color: "#000000"; opacity: cell.centered ? 0 : 0.28
                                Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } } }
                    // a soft sheen across the middle one
                    Rectangle {
                        anchors.fill: parent
                        visible: cell.centered
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0; color: Theme.withAlpha("#ffffff", 0.10) }
                            GradientStop { position: 0.35; color: "transparent" }
                        }
                    }
                }
                // ring: accent for the current wallpaper, soft white for the focused one
                Rectangle {
                    anchors { fill: tile; margins: -4 }
                    radius: Theme.radius.lg + 4
                    color: "transparent"
                    border.width: cell.isCurrent ? 3 : 2
                    border.color: cell.isCurrent ? Theme.accent : Theme.withAlpha(Theme.text, 0.75)
                    opacity: cell.isCurrent || cell.centered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                }
                // ✓ on the current one; it pops when you apply
                Rectangle {
                    id: badge
                    anchors { right: tile.right; top: tile.top; margins: 12 }
                    width: 28; height: 28; radius: 14
                    color: Theme.accent
                    scale: cell.isCurrent ? 1 : 0
                    Behavior on scale { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
                    LIcon { anchors.centerIn: parent; icon: "check"; size: 18; fill: 1; color: Theme.onAccent }
                }
                // the middle one, hovered: say what a click does
                Rectangle {
                    anchors { horizontalCenter: tile.horizontalCenter; bottom: tile.bottom; bottomMargin: 14 }
                    width: hint.implicitWidth + 24; height: 30; radius: 15
                    color: Theme.withAlpha(Theme.bg, 0.78)
                    border.width: 1; border.color: Theme.border
                    opacity: cell.centered && hover.containsMouse && !cell.isCurrent ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.motion.normal } }
                    Row { id: hint; anchors.centerIn: parent; spacing: 6
                          LIcon { icon: "wallpaper"; size: 16; color: Theme.text; anchors.verticalCenter: parent.verticalCenter }
                          LText { role: "bodyStrong"; text: "Set as wallpaper"; anchors.verticalCenter: parent.verticalCenter } }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (cell.centered) win.applyFocused(); else view.currentIndex = cell.index; }
                }
            }
        }

        // a flash over the middle when a wallpaper is applied
        Rectangle {
            id: flash
            anchors.centerIn: view
            width: view.tileW; height: view.tileH; radius: Theme.radius.lg
            color: "transparent"
            border.width: 3; border.color: Theme.accent
            opacity: 0
            SequentialAnimation {
                id: applied
                ParallelAnimation {
                    NumberAnimation { target: flash; property: "opacity"; from: 0.9; to: 0; duration: 650; easing.type: Easing.OutCubic }
                    NumberAnimation { target: flash; property: "scale"; from: 1; to: 1.08; duration: 650; easing.type: Easing.OutCubic }
                }
            }
        }

        // ── what's in the middle ──
        Item {
            id: caption
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.space.s5; bottomMargin: Theme.space.s4 }
            height: 22
            LText {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 200)
                elide: Text.ElideMiddle
                role: "bodyStrong"
                text: win.focused ? win.name(win.focused.path) + (win.focused.path === Wallpapers.current ? "  ·  current" : "") : ""
            }
            LText {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                role: "caption"; color: Theme.textMuted
                font.features: ({ "tnum": 1 })
                text: win.items.length ? (view.currentIndex + 1) + " / " + win.items.length : ""
            }
            LText {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                role: "caption"; color: Theme.textMuted
                text: "← → move · Enter set · Tab category"
            }
        }

        LText {
            anchors.centerIn: view
            visible: win.items.length === 0
            color: Theme.textMuted
            text: "Put pictures in ~/Pictures/Wallpapers — sub-folders become categories"
        }
    }

    component Pill: MouseArea {
        id: pl
        property bool on: false
        default property alias content: pillRow.data
        width: pillRow.implicitWidth + Theme.space.s3 * 2
        height: 34
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Rectangle { anchors.fill: parent; radius: 17; color: pl.containsMouse ? Theme.surfaceHover : Theme.withAlpha(Theme.surfaceElevated, 0.6)
                    border.width: 1; border.color: Theme.border
                    Behavior on color { ColorAnimation { duration: Theme.motion.micro } } }
        Row { id: pillRow; anchors.centerIn: parent; spacing: Theme.space.s2 }
        scale: pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: Theme.motion.micro } }
    }
}
