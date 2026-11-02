# Desktop tools

Search for **Screenshot workbench**, **Folder portals**, **File operation queue**,
**Storage explorer**, **Colour clipboard**, or **Meeting tray** in the launcher.
Controls (Super+A) also has shortcuts. In Tools, Ctrl+1–6 switches pages and Esc
closes. The panel opens on the focused monitor.

## Screenshot workbench

Super+Alt+PrtSc opens the workbench. It shows the latest 100 images from your XDG
Pictures/Screenshots folder. Capture a region or screen, preview older captures,
copy an image, extract its text, add it to the shelf, or open its folder.

**Edit in Swappy** opens Swappy's crop, annotation, text and blur tools. Saving
creates a separate `-edited-xxxxxx.png`; the original stays untouched. **Copy
text** needs Tesseract. Missing tools and failed actions appear in the panel.
Clicking a new screenshot in the island or its notification opens the workbench.

## Folder portals and temporary shelf

Super+Alt+F opens Folders. Home, Downloads, Documents, Pictures and Projects use
your actual XDG paths. Enter another folder path, browse into a subfolder, go
up, filter names, show hidden items, and pin/unpin the current folder. Up to 20
custom portals are kept in `~/.local/state/lumen/tools.json`.

Use **+** to collect a file or folder on the shelf, or drop files onto its shelf
area. Collect across folders and workspaces. Drag an item or **Drag all** into
another app; **Copy all** offers the collection as files on the clipboard.
Super+X still opens the edge shelf. Removing/clearing shelf items never deletes
the underlying files. The shelf holds up to 500 references for this shell
session; it is cleared when the shell restarts. File names with spaces, Unicode,
`#` and `?` are encoded correctly for drag and drop.

The folder button in the top bar opens a compact portal with Downloads, Projects
and your first six pinned folders. Browse and open files or add them to the shelf
without leaving your current app. Open Folders & shelf for the full view.

Directory portals list up to 2,000 entries. **File manager** opens the complete
folder. Pinning saves a path, not a copy of its contents.

## File operation queue

With files on the shelf, choose **Copy shelf here**, **Move shelf here** or
**ZIP shelf here** in Folders. Drop Zone's Move and Compress use the same queue.
Jobs run one at a time, with byte progress for copies/compression, cancellation,
error details, retry of remaining items, and an Open destination button. The
queue tracks operations started by Lumen, not operations in other applications.
Phone sends continue to use KDE Connect's own transfer handling.

- Existing destination names are never overwritten, including a file created
  after the job was queued. Rename conflicting files or choose another folder.
- Cancellation removes the current incomplete output. Items already completed
  stay in place; the original sources of copy/compress jobs remain untouched.
- Moves use Linux's atomic no-overwrite rename. Across filesystems, use Copy;
  the source is kept and the queue explains why the move could not proceed.
- A destination inside a source folder and duplicate source base names are
  rejected. Archives preserve empty folders and refuse symlinks rather than
  following them. Copies preserve symlinks and do not copy devices or FIFOs.
- Closing Tools leaves jobs running. Queue history is in memory, capped at 30
  completed jobs plus active jobs. Restarting the shell does not resume jobs;
  let active jobs finish or cancel them before reloading the shell.

## Storage explorer

Choose a folder and Scan. Direct children are ordered by allocated disk space;
open a subfolder to drill down, or choose Parent. The filesystem capacity bar is
separate from the selected folder's total. Hidden files are included, hard links
count once, symlinks and other filesystems are skipped, and inaccessible entries
are reported. A stopped scan keeps the previous completed result. Scanning is
on request, and there are no delete or cleanup actions in this explorer.

## Colour clipboard

Super+Shift+C now picks a colour and saves it here. Pick from the screen or
enter a six-digit HEX value, name it, and copy HEX, RGB or HSL. Up to 60 colours
are retained in `tools.json`; adding an existing colour brings it to the front
and preserves its name. Removing a swatch affects only this palette.

## Meeting tray

Click the Ribbon's on-air chip, or search for Meeting tray. Mute the system mic,
choose a microphone or speaker device, run a ten-second live mic-level check,
return to the detected call, create
meeting notes, hold notifications, keep awake, and request a camera preview.
The mic check keeps no recording and stops on closing Tools or leaving the page.
Activity indicators reuse Meeting mode's detection and the compositor's capture
events. They do not identify the exact shared window. Manage camera and sharing
in the meeting app. Changing the default device may require selecting that
device in an app that pins its own input/output.

## Visual system

Bar, clock and panel type roles live in `theme/tokens.toml`. The bar is 40 logical
pixels tall; side panels default to 408 pixels. The controls, planner and popups
share `MotionSurface`: source-aligned scaling, a short translation, quicker exits,
and opacity-only reduced motion. The island keeps its own size morph with more
damping, fixed-width content during transitions, and quieter clock typography.
Notification titles and message bodies have separate weights and line spacing.

Nested test sessions use `tools-test.json` instead of the live preferences.
Run `python3 -m unittest discover -s tests -v` for file safety regressions.

## Circle to Search fixes

Super+Z now waits for a completed crop before enabling image actions. Copy image
and Copy text wait for the clipboard command to succeed; a failure stays in the
sheet with its error so you can retry. Save uses your XDG Pictures directory and
a unique filename. Phone sharing starts after the saved copy exists. Selecting
again invalidates old crop/OCR responses, and closing cleans only that capture's
private runtime directory. The action sheet consumes clicks across its whole
background so clicks do not fall through and erase the selection.
