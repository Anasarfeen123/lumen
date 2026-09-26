// Wallpaper, drawn by the shell so changes cross-fade instead of cutting.
// Source of truth: ~/.local/state/lumen/wallpaper (one path), written by
// scripts/wallpaper.sh — the picker, keybinds and CLI all go through it.
//
// Two image layers: the new picture loads invisibly on top, and only once it
// has fully decoded does it fade in (motion-large); then the layers swap
// roles. A slow decode never shows a blank frame.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.theme
import qs.services

PanelWindow {
    id: win

    anchors { top: true; bottom: true; left: true; right: true }
    color: Theme.bg
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "lumen-wallpaper"
    WlrLayershell.layer: WlrLayer.Background
    mask: Region {}

    property string path: ""
    property bool frontIsA: true

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const p = text().trim();
            if (p !== "" && p !== win.path) win.path = p;
        }
    }

    onPathChanged: {
        const back = frontIsA ? b : a;
        back.opacity = 0;
        back.source = path ? "file://" + path : "";
    }

    component Layer: Image {
        required property bool isA
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(win.width * win.screen.devicePixelRatio, win.height * win.screen.devicePixelRatio)
        asynchronous: true
        cache: false
        smooth: true
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large; easing.type: Easing.Bezier; easing.bezierCurve: Theme.curveStandard } }
        onStatusChanged: {
            const isBack = win.frontIsA ? !isA : isA;
            if (status === Image.Ready && isBack) {
                opacity = 1;
                z = 1;
                (win.frontIsA ? a : b).z = 0;
                win.frontIsA = !win.frontIsA;
                release.restart();
            }
        }
    }

    Layer { id: a; isA: true }
    Layer { id: b; isA: false }

    // Focus profiles dim the wallpaper a little, so windows come forward
    Rectangle {
        anchors.fill: parent
        color: "black"
        z: 10                                   // above both picture layers (they swap z 0/1)
        opacity: Focus.dimWallpaper ? 0.32 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.motion.large * 2 } }
    }

    // Free the old picture after the fade (a 4K image is ~30 MB decoded)
    Timer {
        id: release
        interval: Theme.motion.large + 100
        onTriggered: {
            const old = win.frontIsA ? b : a;
            old.opacity = 0;
            old.source = "";
        }
    }
}
