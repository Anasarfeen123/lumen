# Security and privacy

Lumen runs with your user's permissions. The few things that need root are separate, readable scripts, and each one asks for your password every time.

## What runs as root

Only through `pkexec`, so polkit asks for your password each time. Each helper accepts a fixed set of validated arguments:

| Helper | Accepts | Does |
|---|---|---|
| `scripts/power-admin.sh` | `charge-limit 60…100` | Sets the battery charge limit and keeps it across reboots (one tmpfiles entry) |
| `scripts/gaze-admin.sh` | `liveness on/off`, `threshold 0.05…0.95`, `debug on/off` | Edits only Gaze's `[liveness]` section (keeping a one-time backup), then restarts `gazed` |
| `scripts/update-admin.sh` | `upgrade` | Runs your package manager's full upgrade (`dnf`, `pacman`, `apt-get` or `zypper`) |

The installer uses `sudo` only for your package manager and, if you ask, for one login-screen entry.

## Face ID

- **Lock screen only.** Face ID uses its own PAM service (`hyprlock-gaze`) and is never added to `sudo`, login or polkit.
- **Your password always works** alongside it.
- **The camera starts only on intent:** a key, the pointer, or opening the lid. On battery it never starts by itself; press <kbd>F2</kbd>.
- **The anti-photo check (liveness)** is Gaze's setting and your choice. Lumen never changes it for you.

## Admin prompts

Lumen is the session's polkit agent. polkit itself checks the password, and Lumen only draws the prompt and passes your typed text through. The prompt takes exclusive keyboard focus, so nothing you type there reaches another app. "Details" shows the exact action being authorised.

## What goes online

Nothing goes online until you set it up:

| Feature | When | What's sent |
|---|---|---|
| Weather | After you type a city | The city name, once, to Open-Meteo's geocoder; then its coordinates, every 30 minutes |
| Lumen Halo, Claude | Only when you press Enter | Your question, plus the selection or screenshot, but only if you turned those chips on |
| Lumen Halo, Ollama | Only when you press Enter | Nothing leaves your computer |
| WhatsApp | Never by Lumen | Lumen only reads notifications WhatsApp Web already shows and opens chats with text filled in; you send. Message text stays in memory, never on disk |
| Lyrics | Only while the expanded player is open (Settings → Sound) | The song's artist, title, album and length, to lrclib.net |
| Halo model downloads | Only when you press Download in Settings → Halo | The model name, to Ollama's registry (the same one `ollama pull` uses) |
| Updates | Every 6 hours in a real session | Your package manager's normal metadata check |

- Sunrise and sunset are calculated on your machine.
- OCR (copy text from the screen) runs locally with Tesseract.
- There is no telemetry.

## Your AI key

- Stored in `~/.local/state/lumen/ai/anthropic.key`, mode 600, outside the git repository.
- Written only when you paste it into Settings → AI. It's never shown again.
- Handed to `curl` on standard input, never as a command-line argument (which other processes could read).
- Conversations live in memory only.

## Data on disk

Everything Lumen keeps is in `~/.local/state/lumen` (plain JSON and Markdown files) and `$XDG_RUNTIME_DIR`, which is RAM and cleared at logout. Clipboard image thumbnails live in `$XDG_RUNTIME_DIR/lumen-clip` (mode 700).

## Reporting a problem

Please open a private security advisory on the repository instead of a public issue.
