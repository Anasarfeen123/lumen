// Drop Zone: the right edge of each screen. Normally only a 3 px strip in the
// window gap takes input — and only for drags, since a click there lands on
// nothing. When files are dragged onto it, a glass shelf slides in from the
// edge with targets; drop on one to act, drop on the shelf itself to park the
// files there. Esc, or dragging away, puts it back. Parked files wait in a
// small tab at the edge (hover it to open, drag files out of it).
// The top and bottom 140 px are left alone (hot corner, sidebar gestures),
// and nothing listens over fullscreen apps.
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
    readonly property string monName: monitor?.name ?? ""
    readonly property bool fullscreen: monitor?.activeWorkspace?.hasFullscreen ?? false
    readonly property bool isFocused: Quickshell.screens.length <= 1 || (Hyprland.focusedMonitor?.name ?? "") === monName
    // This screen's shelf is open (drags open it where they arrive; by hand, on the focused screen)
    readonly property bool expanded: DropZone.open && (DropZone.dragging ? DropZone.where === monName : isFocused)
    readonly property bool manual: expanded && !DropZone.dragging

    anchors { top: true; bottom: true; right: true }
    implicitWidth: 380
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-dropzone"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: manual ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    visible: true

    // Input: the whole zone while open; else the strip (for drags) and the shelf tab
    mask: Region {
        item: win.expanded ? zone : (win.fullscreen ? null : sensor)
        Region { item: !win.expanded && DropZone.shelf.length > 0 && !win.fullscreen ? tab : null }
    }

    // How many drop areas the drag is over; when it's none for a moment, fold away
    property int inside: 0
    function track(on) { inside = Math.max(0, inside + (on ? 1 : -1)); }
    Timer {
        id: fold
        interval: 320
        running: win.expanded && DropZone.dragging && win.inside === 0 && !DropZone.testHold
        onTriggered: DropZone.dragDone()
    }

    // ── The sensor: 3 px at the very edge ──
    Item {
        id: sensor
        x: win.width - 3; y: 140
        width: 3; height: win.height - 280
        DropArea {
            anchors.fill: parent
            onEntered: drag => { drag.accept(Qt.CopyAction); DropZone.where = win.monName; DropZone.dragEntered(drag.urls); }
            onContainsDragChanged: win.track(containsDrag)
        }
    }

    // ── The shelf tab: parked files wait here ──
    Item {
        id: tab
        visible: DropZone.shelf.length > 0 && !win.expanded
        width: 18; height: 72
        x: win.width - width; y: (win.height - height) / 2
        GlassSurface {
            anchors { fill: parent; rightMargin: -Theme.radius.md }
            level: "chrome"
            radius: Theme.radius.md
            Column {
                anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 3 }
                spacing: 2
                LIcon { icon: "inventory_2"; size: 12; color: Theme.accent }
                LText { role: "caption"; text: DropZone.shelf.length; width: 12; horizontalAlignment: Text.AlignHCenter }
            }
        }
        HoverHandler { id: tabHover; onHoveredChanged: if (hovered) tabOpen.restart(); else tabOpen.stop() }
        Timer { id: tabOpen; interval: 180; onTriggered: DropZone.show() }
        DropArea {
            anchors.fill: parent
            onEntered: drag => { drag.accept(Qt.CopyAction); DropZone.where = win.monName; DropZone.dragEntered(drag.urls); }
            onContainsDragChanged: win.track(containsDrag)
        }
    }

    // ── The zone: everything to the right of the shelf's far edge ──
    Item {
        id: zone
        anchors.fill: parent
        // Dropped on the zone but not on a target: park it on the shelf
        DropArea {
            anchors.fill: parent
            enabled: win.expanded
            onEntered: drag => drag.accept(Qt.CopyAction)
            onContainsDragChanged: win.track(containsDrag)
            onDropped: d => { d.accept(Qt.CopyAction); DropZone.run("shelve", DropZone.pathsOf(d.urls)); DropZone.dragDone(); }
        }
        // By hand: a click beside the shelf closes it
        MouseArea { anchors.fill: parent; enabled: win.manual; onClicked: DropZone.hide() }
        Keys.onEscapePressed: DropZone.hide()
        focus: win.manual
    }

    // Pointer wandered off a hand-opened shelf: close after a moment
    Timer {
        interval: 1400
        running: win.manual && !cardHover.hovered && !tabHover.hovered
        onTriggered: DropZone.hide()
    }

    GlassSurface {
        id: card
        level: "panel"
        radius: Theme.radius.lg
        width: 300
        height: Math.min(col.implicitHeight + Theme.space.s4 * 2, win.height - 120)
        y: (win.height - height) / 2
        x: win.expanded ? win.width - width - Theme.edgeGap - Theme.space.s2 : win.width + 16
        opacity: win.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on x { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: win.expanded ? Theme.curveEmphasized : Theme.curveAccelerate } }
        Behavior on opacity { NumberAnimation { duration: Theme.motion.micro } }
        Behavior on height { NumberAnimation { duration: Theme.motion.normal; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        HoverHandler { id: cardHover }
        MouseArea { anchors.fill: parent }       // clicks on the card don't close it

        Flickable {
            anchors { fill: parent; margins: Theme.space.s4 }
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height

            Column {
                id: col
                width: parent.width
                spacing: Theme.space.s2

                // Header
                Row {
                    width: parent.width
                    spacing: Theme.space.s3
                    bottomPadding: Theme.space.s1
                    Rectangle {
                        width: 36; height: 36; radius: 18
                        color: Theme.withAlpha(Theme.accent, 0.16)
                        border.width: 1; border.color: Theme.withAlpha(Theme.accent, 0.35)
                        LIcon { anchors.centerIn: parent; icon: DropZone.dragging ? "move_to_inbox" : "inventory_2"; fill: 1; color: Theme.accent }
                        SequentialAnimation on scale {
                            running: DropZone.dragging && !Theme.reducedMotion
                            loops: Animation.Infinite; alwaysRunToEnd: true
                            NumberAnimation { to: 1.08; duration: 520; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
                        }
                    }
                    Column {
                        width: parent.width - 36 - Theme.space.s3
                        anchors.verticalCenter: parent.verticalCenter
                        LText { role: "heading"; text: DropZone.dragging ? "Drop here" : "Shelf" }
                        LText {
                            width: parent.width; elide: Text.ElideMiddle
                            role: "caption"; color: Theme.textMuted
                            text: DropZone.subject.length ? DropZone.describe(DropZone.subject) : "Drag files to the right edge of the screen"
                        }
                    }
                }

                // Main targets
                DropTarget {
                    width: parent.width
                    visible: DropZone.phone !== null
                    icon: "send_to_mobile"; label: "Send to " + (DropZone.phone?.name ?? "phone"); sub: "Through KDE Connect"
                    usable: DropZone.subject.length > 0
                    onActivated: p => DropZone.run("send", p)
                    onContainsDragChanged: win.track(containsDrag)
                }
                DropTarget {
                    width: parent.width
                    icon: "content_copy"; label: "Copy"; sub: "Paste it into a folder or a chat"
                    usable: DropZone.subject.length > 0
                    onActivated: p => DropZone.run("copy", p)
                    onContainsDragChanged: win.track(containsDrag)
                }
                // Lumen Halo reads them (PDFs, text, code, images) — see Ai.askAboutFiles
                DropTarget {
                    width: parent.width
                    visible: Ai.provider !== "off"
                    icon: "auto_awesome"; label: "Ask Halo"; sub: Ai.local ? "Summarize or ask about it, on this computer" : "Summarize or ask about it (sent to Claude)"
                    usable: DropZone.subject.length > 0
                    onActivated: p => { const paths = (p && p.length) ? p : DropZone.subject; DropZone.hide(); Ai.askAboutFiles(paths, paths.every(f => /\.pdf$/i.test(f)) ? "pdf" : ""); }
                    onContainsDragChanged: win.track(containsDrag)
                }
                DropTarget {
                    width: parent.width
                    icon: "folder_zip"; label: "Compress"; sub: "A .zip next to it"
                    usable: DropZone.subject.length > 0
                    onActivated: p => DropZone.run("compress", p)
                    onContainsDragChanged: win.track(containsDrag)
                }
                DropTarget {
                    width: parent.width
                    visible: DropZone.dragging
                    icon: "inventory_2"; label: "Keep on shelf"; sub: "Park it at the edge, drag it out later"
                    onActivated: p => DropZone.run("shelve", p)
                    onContainsDragChanged: win.track(containsDrag)
                }

                // Open with…
                LText { visible: DropZone.apps.length > 0; topPadding: Theme.space.s2; role: "caption"; color: Theme.textMuted; text: "Open with" }
                Flow {
                    visible: DropZone.apps.length > 0
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: DropZone.apps
                        delegate: DropTarget {
                            required property var modelData
                            compact: true
                            iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                            icon: "open_in_new"
                            label: modelData.name
                            usable: DropZone.subject.length > 0
                            onActivated: p => DropZone.run("open", p, modelData.id)
                            onContainsDragChanged: win.track(containsDrag)
                        }
                    }
                }

                // Move to…
                LText { topPadding: Theme.space.s2; role: "caption"; color: Theme.textMuted; text: "Move to" }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: [{ id: "documents", label: "Documents", icon: "description" }, { id: "downloads", label: "Downloads", icon: "download" },
                                { id: "desktop", label: "Desktop", icon: "desktop_windows" }, { id: "pictures", label: "Pictures", icon: "image" },
                                { id: "projects", label: "Projects", icon: "code" }]
                        delegate: DropTarget {
                            required property var modelData
                            compact: true
                            icon: modelData.icon; label: modelData.label
                            usable: DropZone.subject.length > 0
                            onActivated: p => DropZone.run("move", p, modelData.id)
                            onContainsDragChanged: win.track(containsDrag)
                        }
                    }
                }

                // The shelf: parked files, drag them back out
                Item { width: 1; height: Theme.space.s1; visible: DropZone.shelf.length > 0 }
                Item {
                    visible: DropZone.shelf.length > 0
                    width: parent.width; height: 22
                    LText { anchors.verticalCenter: parent.verticalCenter; role: "caption"; color: Theme.textMuted; text: "On the shelf · drag out to use" }
                    HoverTarget {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        width: clearLbl.implicitWidth + 14; height: 22
                        onClicked: DropZone.clearShelf()
                        LText { id: clearLbl; anchors.centerIn: parent; role: "caption"; color: Theme.textSecondary; text: "Clear" }
                    }
                }
                Repeater {
                    model: DropZone.shelf
                    delegate: ShelfItem { required property string modelData; width: col.width; path: modelData }
                }
            }
        }
    }
}
