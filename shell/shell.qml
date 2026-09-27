//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// Lumen shell entry point. Each module owns its own windows; this file only
// instantiates them. Run: qs -p ~/.config/lumen/shell

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.bar
import qs.modules.island
import qs.modules.overview
import qs.modules.sidebar
import qs.modules.session
import qs.modules.background
import qs.modules.lock
import qs.modules.corners
import qs.modules.wallpaper
import qs.modules.cheatsheet
import qs.modules.settings
import qs.modules.polkit
import qs.modules.switcher
import qs.modules.planner
import qs.modules.ai
import qs.modules.dropzone
import qs.modules.inbox
import qs.modules.welcome

ShellRoot {
    // A desktop you use must not restart itself because a file changed on
    // disk (least of all while locked). Live reload is for development only
    // (LUMEN_DEV=1, set by lumen-session in nested test mode); otherwise
    // reload on purpose: Ctrl+Super+R, `lumen reload`.
    Component.onCompleted: Quickshell.watchFiles = Quickshell.env("LUMEN_DEV") === "1"

    IpcHandler {
        target: "shell"
        function reload(): string {
            if (Lock.locked) return "refused: screen is locked";
            Quickshell.reload(false);
            return "reloading";
        }
    }

    // Event sources, IPC and shortcuts for the island (no UI)
    IslandSources {}

    // Overview / launcher shortcuts and IPC (no UI)
    OverviewSources {}

    // Notification daemon, sidebar shortcuts and IPC (no UI)
    SidebarSources {}

    // Power menu shortcuts, night light / battery saver (no UI)
    SessionSources {}

    // Wallpaper picker shortcuts (no UI)
    WallpaperSources {}

    // Lumen Settings runs as its own app (shell/settings.qml); this only launches it
    SettingsSources {}

    // Screen lock (ext-session-lock; Super+L, idle, before sleep)
    LockScreen {}

    // One wallpaper, bar, island and overview per monitor
    Variants {
        model: Quickshell.screens
        delegate: Wallpaper {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: IslandWindow {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: SidebarWindow {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: Cheatsheet {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: WallpaperPicker {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: HotCorners {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: PowerMenu {
            required property var modelData
            screen: modelData
        }
    }
    // Left sidebar: weather, agenda, to-dos, notes
    Variants {
        model: Quickshell.screens
        delegate: PlannerWindow {
            required property var modelData
            screen: modelData
        }
    }
    // First-run welcome (services/Welcome.qml): shown once, on the focused monitor
    Variants {
        model: Quickshell.screens
        delegate: WelcomeWindow {
            required property var modelData
            screen: modelData
        }
    }
    // Drop Zone: drag files to the right edge for Send to phone, Copy, Compress…
    Variants {
        model: Quickshell.screens
        delegate: DropZoneWindow {
            required property var modelData
            screen: modelData
        }
    }
    // Messages (Lumen Inbox): quick reply, Super+Shift+W
    Variants {
        model: Quickshell.screens
        delegate: InboxPanel {
            required property var modelData
            screen: modelData
        }
    }
    // Lumen Halo (AI)
    Variants {
        model: Quickshell.screens
        delegate: AiPanel {
            required property var modelData
            screen: modelData
        }
    }
    // Alt+Tab window switcher
    Variants {
        model: Quickshell.screens
        delegate: SwitcherWindow {
            required property var modelData
            screen: modelData
        }
    }
    // Admin password prompt (Lumen's polkit agent)
    Variants {
        model: Quickshell.screens
        delegate: PolkitPrompt {
            required property var modelData
            screen: modelData
        }
    }
    Variants {
        model: Quickshell.screens
        delegate: OverviewWindow {
            required property var modelData
            screen: modelData
        }
    }
}
