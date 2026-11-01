# Your own widgets

A widget is a folder in `~/.local/share/lumen/widgets/<id>/` with two files:

```
widget.json   { "name": "…", "description": "…", "kind": "card" | "desktop",
                "entry": "main.qml", "needs": ["system"], "version": "1.0" }
main.qml      the widget: one root item with `property var lumen`
```

- **card**: a card in the Controls sidebar, in its own section ("Your widgets"; move or hide
  it in Settings → Bar & Island → Sidebar).
- **desktop**: on the wallpaper, top-right, below the windows.
- `needs: ["system"]` asks Lumen to sample CPU, memory and temperature while the widget shows.

Not in `~/.config/lumen`: that's the Lumen repository, and widgets are yours.

**A widget is code that runs inside the shell.** A new one is off until you turn it on in
Settings → Appearance → Your widgets. Turn on only what you've read or trust.

## The `lumen` object (version 1)

| | |
|---|---|
| `lumen.theme` | colours and tokens: `accent`, `text`, `textMuted`, `surface`, `surfaceElevated`, `border`, `onMedia`, `warning`, `error`, `withAlpha(color, a)`, `radius`, `space`, `fontUi` |
| `lumen.media` | `present`, `playing`, `title`, `artist`, `artUrl`, `toggle()`, `next()`, `previous()` |
| `lumen.weather` | `ready`, `now` (`temp`, `code`, `isDay`), `describe(code)`, `icon(code, isDay)` |
| `lumen.battery` | `available`, `percentage` (0–1), `pluggedIn`, `low` |
| `lumen.sysinfo` | `cpu` (0–1), `memUsed`, `memTotal` (GiB), `cpuTemp` (°C), `disk` (0–1) — with `needs: ["system"]` |
| `lumen.planner` | `todos`, `upcoming`, `addTodo(text)` |
| `lumen.college` | AmazeCC: `current`, `next` (classes), `nextExam`, `daysTo(ms)` |
| `lumen.notifications` | `count`, `dnd` |
| `lumen.focus` | `mode` |
| `lumen.run(cmd)` | run a command (a string for `sh -c`, or an array) |
| `lumen.open(url)` | open a link or file |
| `lumen.askHalo(text)` | open Halo and ask |
| `lumen.say(title, text)` | a small Halo card |

Import only `QtQuick` (and its own modules such as `QtQuick.Shapes`). Lumen's internal modules
(`qs.*`) aren't for widgets: they change, `lumen` doesn't.

## The command

```
lumen widgets new my-card           start from the template
lumen widgets examples              Lumen's examples (System glance, Exam countdown)
lumen widgets add <git-url> [ref]   install from git: lists every file and asks first
lumen widgets sync                  install what widgets.lock lists, at its commits
lumen widgets list | remove <id> | check <id>
```

`widgets.lock` records each installed repository's URL, commit and a hash of its files;
`lumen widgets sync` on a new computer installs exactly those and refuses files that don't
match. `lumen sync export` carries the widgets folder and the lockfile with the rest of your
setup.
