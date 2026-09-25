pragma Singleton

// Small fuzzy matcher tuned for app names. Returns 0 for no match, higher is
// better. Order of preference: exact > prefix > word-start > substring >
// in-order subsequence (with a penalty for gaps).
import QtQuick
import Quickshell

Singleton {
    function score(needle, hay) {
        if (!needle) return 1;
        if (!hay) return 0;
        const n = needle.toLowerCase(), h = hay.toLowerCase();
        if (h === n) return 1000;
        if (h.startsWith(n)) return 900 - Math.min(100, h.length - n.length);
        const words = h.split(/[\s\-_.]+/);
        if (words.some(w => w.startsWith(n))) return 750;
        // initials: "vsc" → "Visual Studio Code"
        const initials = words.map(w => w[0] ?? "").join("");
        if (initials.startsWith(n)) return 700;
        const idx = h.indexOf(n);
        if (idx >= 0) return 600 - Math.min(200, idx * 4);
        // subsequence
        let hi = 0, gaps = 0, last = -1;
        for (const ch of n) {
            const found = h.indexOf(ch, hi);
            if (found < 0) return 0;
            if (last >= 0) gaps += found - last - 1;
            last = found;
            hi = found + 1;
        }
        return Math.max(1, 300 - gaps * 12);
    }
}
