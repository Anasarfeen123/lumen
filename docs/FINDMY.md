# Find my laptop

Ring, lock, locate and photograph this laptop from your phone, near or far.
Settings → Privacy → Find my laptop.

## How it works

- `scripts/findmy.py serve` (started by `services/FindMy.qml` in the main shell,
  only when it's turned on) listens on a private [ntfy](https://ntfy.sh) channel.
  ntfy.sh is a free public relay; Lumen uses it to reach the laptop wherever it is.
- The channel name is a long random secret, and **every message both ways is sealed
  with AES-256-GCM** under a random 256-bit key that only the laptop and your phone's
  remote hold. The relay only ever carries ciphertext. A message that doesn't open
  with the key is ignored, so learning the channel name isn't enough to command the
  laptop. Each command has an id (replays are ignored) and a time: a ring sent more
  than 10 minutes ago (while the laptop was offline) is skipped; other commands keep
  for the 12 hours ntfy.sh stores messages.
- The remote is one web page (`findmy.py remote` → `~/.local/state/lumen/findmy-remote.html`,
  mode 600) with the key inside. Lumen sends it to your phone over Lumen Link; open it
  in the phone's browser. It seals commands and opens replies in the browser
  (WebCrypto). If your phone is lost, use **New keys** and send the remote again.

## Commands

| From the phone | What the laptop does |
|---|---|
| Ring | Full-volume alarm through its own speakers (even with headphones in), the screen saying it's lost, for 3 minutes or until stopped. Volume and mute go back afterwards. |
| Stop | Stops the alarm. |
| Locate | Nearby Wi-Fi networks → [BeaconDB](https://beacondb.net) (an open location database) → a map link, plus battery and network. Where BeaconDB doesn't know the networks (much of India), only city-level. |
| Status | Battery, network, uptime, lost mode. |
| Photo | One webcam picture (the camera light comes on). |
| Screenshot | What's on screen. |
| Lock it | Locks, turns on lost mode, reports where it is. |
| Found it | Lost mode off. |

**Lost mode**: your message and number lead the lock screen (and the ring screen);
notifications, calendar, class and glance cards are hidden there; and the laptop sends
a location report every 15 minutes. Pictures are sealed too; the relay deletes files
after about 3 hours.

## Limits

It needs Lumen running and an internet connection. It can't survive a wiped disk or
another operating system, and it can't wake a laptop that's asleep or off.
Needs `python3-cryptography` (`sudo dnf install python3-cryptography`).

## Files

`~/.local/state/lumen/findmy.json` (channel, key, last message; 600) ·
`findmy-lost.json` (lost mode, for the lock screen) · `findmy-remote.html` (600).
