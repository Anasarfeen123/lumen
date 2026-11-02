# College and hostel in Lumen

Open **AmazeCC** with Ctrl+Super+A. **Laundry**, **Mess menu** and **Grades** are
also available from search and the Today tab in the left planner sidebar.

## Laundry and mess

The native app uses the same public unmessify schedules as AmazeCC. Choose your
hostel group, block, room and mess type under **Change hostel details**. If you
have synced VTOP hostel details, **Use VTOP details** follows those instead.
The public pages also work without a VTOP login.

Laundry highlights your room's dates, shows the next collection and lets you
inspect any month. These are repeating day-of-month schedules. Invalid dates
(such as 31 February) are omitted. Collection times are not supplied by the
feed. Optional laundry-day reminders arrive once between 08:00 and 17:00,
respecting sleep mode and the notification service's DND handling.

Mess menus retain the source's week qualifiers; week 1 is days 1–7 and week 4
covers day 22 onward. No meal times are inferred.

Offline schedules are the default. **Enable live schedules** explicitly opts in to
requests to unmessify that identify the selected hostel group/block and mess type.
With this enabled, Refresh fetches the public schedules. If the network fails, the last successful
copy is retained. If none exists, the bundled copy is used. The UI shows both
fetch time and source publication date, so an old source is not presented as a
new timetable. Source data and attribution: `scripts/amazecc-campus-data/README.md`.

## Grades

**Refresh grades** reads VTOP's grade summary, all-semester results, assessment
breakdowns, curriculum credits and hostel details through the configured
AmazeCC API. These also refresh with a manual full Sync and periodically with
the existing extras sync. Sign in under Settings → AmazeCC first.

Semester GPA and CGPA are the values VTOP publishes. Missing marks and GPA stay
unknown; zero scores stay zero. Failed semesters keep their saved results.
Expand a course to see assessments, segment labels, weightage and grade ranges
when the API returns them. Search filters course titles, codes and grades.

The GPA scenario is separate from published records. Enter credits and a grade
for every included course; unknown credits stay blank. Remove pass/fail,
non-credit and already-counted courses. The simulator uses S=10 through E=5,
F/N=0. It adds the scenario to the published earned-credit total; replacement
and repeated-course rules are not inferred. Scenarios are temporary and do not
change VTOP records. Existing grade privacy settings apply to these views.

## Data and privacy

New local state files (mode 600): `amazecc-campus.json` for the chosen profile
and public schedules; `amazecc-campus-cache.json` for public resources, keyed by
source. Grade history and hostel details extend `amazecc-extra.json`. Sign out
clears the synced academic and hostel snapshots. Public schedule paths identify the selected hostel group/block and mess type.
They send no account,
room, password or VTOP cookies to unmessify. Existing keyring login is reused
only by the configured AmazeCC API.

App navigation uses the shared interruptible page transition and reduced-motion
settings. Tab reaches controls; Enter or Space activates buttons; Ctrl+Tab and
Ctrl+Shift+Tab switch pages; Ctrl+R syncs; Ctrl+W closes.
