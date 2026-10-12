// AmazeCC: your VIT timetable, attendance, marks and exams from VTOP, through
// an AmazeCC API (your own on this computer, by default). The login lives in
// the system keyring (scripts/amazecc.py); settings in
// ~/.local/state/lumen/amazecc.json; the synced data in amazecc-data.json
// (mode 600). Syncing and announcing is the shell's job (services/Amazecc).
import QtQuick
import Quickshell
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "AmazeCC"
    subtitle: "Your VIT day on the desktop: the next class in the island and the Ribbon, today's timetable in the planner, reminders before classes and exams, and a word when a mark arrives or attendance slips — on your phone too, through Lumen Link."
    Component.onCompleted: Amazecc.refreshStatus()

    readonly property var cfg: Amazecc.cfg
    function ago(ms) {
        if (!ms) return "never";
        const m = Math.round((Date.now() - ms) / 60000);
        return m < 1 ? "just now" : m < 60 ? m + " min ago" : m < 1440 ? Math.round(m / 60) + " h ago" : Qt.formatDateTime(new Date(ms), "d MMM, " + Theme.timeFormatFull);
    }

    // ── Account ──
    Group {
        title: "VTOP"
        SetRow {
            icon: "school"
            title: "Use AmazeCC in Lumen"
            description: page.cfg.enabled ? "Timetable, attendance, marks and exams" : "Off — nothing is synced or shown"
            LSwitch { checked: page.cfg.enabled; onToggled: page.cfg.enabled = !checked }
        }
        SetRow {
            visible: page.cfg.enabled && Amazecc.hasLogin
            icon: "account_circle"
            title: Amazecc.username
            description: "Signed in · the password is kept in your keyring, never in a file"
            Button { text: "Sign out"; onActivated: Amazecc.signOut() }
        }
        SetRow {
            visible: page.cfg.enabled && !Amazecc.hasLogin
            icon: "login"
            title: "Sign in to VTOP"
            description: Amazecc.signingIn ? "Checking with VTOP… this takes about 15 seconds"
                       : Amazecc.signInError !== "" ? Amazecc.signInError
                       : "Your VTOP username and password. They're checked once, then stored in the system keyring."
            Row {
                spacing: Theme.space.s2
                LField { id: userField; width: 130; icon: "person"; placeholder: "25BCE…"; clearOnAccept: false
                         onAccepted: passField.input.forceActiveFocus() }
                LField { id: passField; width: 150; icon: "key"; placeholder: "Password"; input.echoMode: TextInput.Password
                         onAccepted: t => Amazecc.signIn(userField.text, t) }
                Button { text: Amazecc.signingIn ? "Signing in…" : "Sign in"; primary: true; enabled: !Amazecc.signingIn
                         onActivated: { Amazecc.signIn(userField.text, passField.text); passField.text = ""; } }
            }
        }
        SetRow {
            visible: page.cfg.enabled && Amazecc.hasLogin
            icon: Amazecc.error !== "" ? "sync_problem" : "sync"
            title: Amazecc.syncing ? "Syncing…" : "Last synced " + page.ago(Amazecc.updated)
            description: Amazecc.error !== "" ? Amazecc.error
                       : Amazecc.ready ? Amazecc.courses.length + " courses · " + Amazecc.exams.length + " exams scheduled · " + Amazecc.semesterName(Amazecc.semesterId)
                       : "Nothing synced yet"
            Button { text: "Sync now"; enabled: !Amazecc.syncing; onActivated: Amazecc.requestSync() }
        }
        SetRow {
            visible: page.cfg.enabled
            icon: "calendar_month"
            title: "Semester"
            description: page.cfg.semester === ""
                ? "Follows AmazeCC's current semester — changes by itself when a new one starts"
                : "Pinned to " + Amazecc.semesterName(page.cfg.semester) + " (" + page.cfg.semester + ")"
            LDropdown {
                width: 230
                options: Amazecc.semesterOptions
                current: page.cfg.semester
                onPicked: id => Amazecc.setSemester(id)
            }
        }
        SetRow {
            visible: page.cfg.enabled && Amazecc.hasLogin
            icon: "schedule"
            title: "Sync every"
            description: "From 6 in the morning; each sync signs in to VTOP and takes about half a minute"
            Segmented {
                width: 240
                options: [{ id: "30", label: "30 min" }, { id: "60", label: "Hour" }, { id: "180", label: "3 hours" }]
                current: String(page.cfg.syncMinutes)
                onPicked: id => page.cfg.syncMinutes = parseInt(id)
            }
        }
    }

    // ── Where it shows ──
    Group {
        title: "Your day"
        visible: page.cfg.enabled
        SetRow {
            icon: "top_panel_open"
            title: "Next class in the island and the Ribbon"
            description: "Hover the island for the class you're in or the next one; the Ribbon shows it within the hour"
            LSwitch { checked: page.cfg.islandNext; onToggled: page.cfg.islandNext = !checked }
        }
        SetRow {
            icon: "lock"
            title: "Next class on the lock screen"
            description: "What, where and when — attendance only as a count of courses under the minimum, never which"
            LSwitch { checked: page.cfg.lockScreen; onToggled: page.cfg.lockScreen = !checked }
        }
        SetRow {
            icon: "notifications_active"
            title: "Class reminders"
            description: "The island tells you where to go before each class (not during Sleep focus)"
            LSwitch { checked: page.cfg.classReminders; onToggled: page.cfg.classReminders = !checked }
        }
        SetRow {
            visible: page.cfg.classReminders || page.cfg.phoneReminders
            icon: "timer"
            title: "Remind me"
            description: "Before each class starts"
            Segmented {
                width: 240
                options: [{ id: "5", label: "5 min" }, { id: "10", label: "10 min" }, { id: "15", label: "15 min" }]
                current: String(page.cfg.reminderMinutes)
                onPicked: id => page.cfg.reminderMinutes = parseInt(id)
            }
        }
        SetRow {
            icon: "edit_note"
            title: "Exam reminders"
            description: "The evening before, and an hour before (with venue and seat). Also: a word when an exam is scheduled or a seat allotted."
            LSwitch { checked: page.cfg.examReminders; onToggled: page.cfg.examReminders = !checked }
        }
        SetRow {
            icon: "event"
            title: "Exams in the planner's Agenda"
            LSwitch { checked: page.cfg.examsInAgenda; onToggled: page.cfg.examsInAgenda = !checked }
        }
        SetRow {
            icon: "beach_access"
            title: "Holidays and day-order changes in the Agenda"
            description: "From the academic calendar: \"no classes\", or a Saturday that follows Monday's timetable"
            LSwitch { checked: page.cfg.holidaysInAgenda; onToggled: page.cfg.holidaysInAgenda = !checked }
        }
    }

    Group {
        title: "Alerts"
        visible: page.cfg.enabled
        SetRow {
            icon: "grading"
            title: "New marks"
            description: "When a mark appears or changes on VTOP. Notifications follow your Focus and Do Not Disturb settings."
            LSwitch { checked: page.cfg.marksAlerts; onToggled: page.cfg.marksAlerts = !checked }
        }
        SetRow {
            icon: "warning"
            title: "Attendance"
            description: "When a course falls under the minimum, or comes within 5% of it — with how many you can miss or need to attend"
            LSwitch { checked: page.cfg.attendanceAlerts; onToggled: page.cfg.attendanceAlerts = !checked }
        }
        SetRow {
            icon: "percent"
            title: "Minimum attendance"
            description: "VIT's rule is 75%; aim higher to keep a margin"
            Segmented {
                width: 240
                options: [{ id: "75", label: "75%" }, { id: "80", label: "80%" }, { id: "85", label: "85%" }]
                current: String(page.cfg.threshold)
                onPicked: id => page.cfg.threshold = parseInt(id)
            }
        }
    }

    Group {
        title: "Halo"
        visible: page.cfg.enabled
        SetRow {
            icon: "auto_awesome"
            title: "Let Halo use this"
            description: (Ai.provider === "ollama" ? "Your local model" : Ai.provider === "anthropic" ? "Halo (Anthropic's servers)" : "Halo")
                         + " gets your timetable, attendance, marks and exams only for questions about them — \"can I skip Friday's class?\", \"what do I need in the FAT?\""
            LSwitch { checked: page.cfg.haloContext; onToggled: page.cfg.haloContext = !checked }
        }
    }

    Group {
        title: "On your phone"
        visible: page.cfg.enabled
        SetRow {
            icon: Link.connected ? "phonelink" : "phonelink_off"
            title: Link.connected ? (Link.phone?.name ?? "Your phone") : "Your phone isn't linked"
            description: Link.connected ? "Linked through Lumen Link — messages arrive as KDE Connect notifications"
                                        : "Set up Lumen Link to get these on your phone"
            Button { visible: !Link.connected; text: "Lumen Link"; onActivated: SettingsState.page = "phone" }
        }
        SetRow {
            icon: "notifications"
            title: "Alerts on the phone"
            description: "New marks, attendance and exam news"
            LSwitch { checked: page.cfg.phoneAlerts; onToggled: page.cfg.phoneAlerts = !checked }
        }
        SetRow {
            icon: "calendar_month"
            title: "Timetable in the phone's calendar"
            description: "Every class, exam and holiday in " + Amazecc.calendarPath.replace(Quickshell.env("HOME"), "~")
                         + " — it reaches the phone with your notes (Settings → Notes). Open it there with a calendar app, or subscribe to it with ICSx⁵ to keep it updated."
            LSwitch { checked: page.cfg.calendarFile; onToggled: page.cfg.calendarFile = !checked }
        }
        SetRow {
            icon: "alarm"
            title: "Reminders on the phone"
            description: "Before each class (with the room), and before exams"
            LSwitch { checked: page.cfg.phoneReminders; onToggled: page.cfg.phoneReminders = !checked }
        }
    }

    Group {
        title: "Connection"
        visible: page.cfg.enabled
        SetRow {
            icon: Amazecc.apiUp ? "dns" : "cloud_off"
            title: "AmazeCC API"
            description: (Amazecc.apiUp ? "Answering at " : "Not answering at ") + page.cfg.api
                         + (page.cfg.api.indexOf("127.0.0.1") >= 0 || page.cfg.api.indexOf("localhost") >= 0
                            ? " — your own, on this computer: VTOP is the only place your login goes"
                            : " — a server elsewhere: your VTOP login passes through it")
            Row {
                spacing: Theme.space.s2
                LField { id: apiField; width: 220; icon: "link"; text: page.cfg.api; clearOnAccept: false
                         onAccepted: t => { page.cfg.api = t.trim() || "http://127.0.0.1:3000"; Amazecc.refreshStatus(); } }
                Button { text: "Check"; onActivated: { page.cfg.api = apiField.text.trim() || "http://127.0.0.1:3000"; Amazecc.refreshStatus(); } }
            }
        }
        SetRow {
            icon: "privacy_tip"
            title: "What stays where"
            description: "Login: system keyring. Timetable, attendance, marks and exams: ~/.local/state/lumen/amazecc-data.json, readable only by you. Signing out removes all three."
        }
    }
}
