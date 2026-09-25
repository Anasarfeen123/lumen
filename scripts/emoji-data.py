#!/usr/bin/env python3
"""Generate the emoji list used by the launcher's emoji mode.

Writes <out> as "emoji<TAB>name" lines, built from Python's bundled Unicode
database (no network, no extra packages). Run automatically by the shell on
first use; safe to re-run.   usage: emoji-data.py <out-file>
"""
import sys
import unicodedata
from pathlib import Path

RANGES = [
    (0x1F600, 0x1F64F),  # emoticons
    (0x1F300, 0x1F5FF),  # symbols & pictographs
    (0x1F680, 0x1F6FF),  # transport & map
    (0x1F900, 0x1F9FF),  # supplemental symbols & pictographs
    (0x1FA70, 0x1FAFF),  # symbols & pictographs extended-A
    (0x2600, 0x26FF),    # misc symbols
    (0x2700, 0x27BF),    # dingbats
]
SKIP = ("EMOJI MODIFIER", "REGIONAL INDICATOR", "TAG ")


def main() -> int:
    out = Path(sys.argv[1] if len(sys.argv) > 1 else "emoji.tsv")
    lines = []
    for lo, hi in RANGES:
        for cp in range(lo, hi + 1):
            name = unicodedata.name(chr(cp), "")
            if not name or name.startswith(SKIP):
                continue
            ch = chr(cp)
            # Text-default symbols in the BMP need VS16 to render as emoji
            if cp < 0x1F000:
                ch += "️"
            lines.append(f"{ch}\t{name.lower()}")
    out.parent.mkdir(parents=True, exist_ok=True)
    tmp = out.with_suffix(".tmp")
    tmp.write_text("\n".join(lines) + "\n")
    tmp.replace(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
