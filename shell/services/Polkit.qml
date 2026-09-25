pragma Singleton
// Lumen's polkit agent: the "an app wants admin rights" password prompt.
//
// The shell registers as the session's authentication agent; the password is
// checked by polkit itself (polkit-agent-helper-1, PAM service polkit-1) —
// Lumen only draws the dialog and passes the typed text through. Face ID is
// never used here (DESIGN.md §16).
//
// Not registered in: the Settings app (client) and nested test sessions, which
// would otherwise answer prompts for the session they're nested in.
// Fallback: if registration fails, KDE's agent is started so prompts never
// go unanswered.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit

Singleton {
    id: root

    readonly property bool enabled: Quickshell.env("LUMEN_SETTINGS_APP") !== "1" && !Quickshell.env("LUMEN_NESTED")
    readonly property var agent: loader.item
    readonly property bool registered: agent?.isRegistered ?? false
    // The live request (or the dev mock); null when nothing is asking
    readonly property var flow: mockFlow.showing ? mockFlow : (agent?.isActive ? agent.flow : null)

    LazyLoader {
        id: loader
        active: root.enabled
        PolkitAgent {}
    }

    // Registration fallback (KDE's agent), once
    Timer {
        running: root.enabled
        interval: 5000
        onTriggered: if (!root.registered) {
            console.warn("Polkit: Lumen agent not registered — starting KDE's");
            Quickshell.execDetached(["sh", "-c",
                'a=/usr/libexec/kf6/polkit-kde-authentication-agent-1; [ -x "$a" ] && ! pgrep -u "$(id -u)" -f "$a" >/dev/null && exec "$a"']);
        }
    }

    // ── Dev mock (LUMEN_DEV only): `ipc call polkit mock` shows a fake request
    // with the same shape as AuthFlow, so the dialog can be reviewed without
    // registering a real agent. Any password "fails"; Esc cancels.
    QtObject {
        id: mockFlow
        property bool showing: false
        readonly property string message: "Authentication is required to change the battery charge limit"
        readonly property string iconName: ""
        readonly property string actionId: "org.freedesktop.policykit.exec"
        readonly property var identities: []
        readonly property var selectedIdentity: ({ displayName: Quickshell.env("USER") })
        property bool isResponseRequired: true
        readonly property string inputPrompt: "Password:"
        readonly property bool responseVisible: false
        property string supplementaryMessage: ""
        property bool supplementaryIsError: false
        property bool failed: false
        function submit(v) { supplementaryMessage = "Sorry, that didn't work. Try again."; supplementaryIsError = true; failed = true; }
        function cancelAuthenticationRequest() { showing = false; failed = false; supplementaryMessage = ""; }
    }
    IpcHandler {
        target: "polkit"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void { mockFlow.showing = true; }
        function mockFail(): void { mockFlow.submit(""); }
        function mockClose(): void { mockFlow.cancelAuthenticationRequest(); }
        function status(): string { return root.enabled ? (root.registered ? "registered" : "not registered") : "disabled"; }
    }
}
