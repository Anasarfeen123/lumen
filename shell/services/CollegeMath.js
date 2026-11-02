.pragma library

function roomMatches(room, ranges) {
    const parts = String(room || "").match(/\d+/g);
    if (!parts) return false;
    const n = Number(parts[parts.length - 1]);
    const text = String(ranges || "").replace(/[–—]/g, "-");
    const pairs = text.match(/\d+\s*(?:-|to)\s*\d+/gi) || [];
    for (const pair of pairs) {
        const ns = pair.match(/\d+/g).map(Number);
        if (n >= ns[0] && n <= ns[1]) return true;
    }
    const singles = text.replace(/\d+\s*(?:-|to)\s*\d+/gi, "").match(/\d+/g) || [];
    return singles.map(Number).includes(n);
}
function dateKey(date) {
    return date.getFullYear() + "-" + String(date.getMonth()+1).padStart(2,"0") + "-" + String(date.getDate()).padStart(2,"0");
}
// Your laundry days of the month. `own` ("3, 17"): days you set yourself,
// replacing the published schedule when it's wrong for you. Otherwise the
// published rows that match your room.
function ownDays(own) {
    return [...new Set((String(own || "").match(/\d+/g) || []).map(Number).filter(d => d >= 1 && d <= 31))].sort((a, b) => a - b);
}
function scheduledOn(rows, room, date, own) {
    const days = ownDays(own);
    if (days.length) return days.includes(date.getDate()) ? (own ? "Your own days" : "") : null;
    for (const row of rows)
        if (Number(row.Date) === date.getDate() && roomMatches(room, row.RoomNumber)) return row.RoomNumber;
    return null;
}
// Is this date a laundry day for you? Overrides ({ "YYYY-MM-DD": "add" | "skip" })
// win over the schedule.
function isLaundryDay(rows, room, date, overrides, own) {
    const o = (overrides || {})[dateKey(date)];
    if (o === "add") return true;
    if (o === "skip") return false;
    return scheduledOn(rows, room, date, own) !== null;
}
function laundrySlots(rows, room, now, overrides, own) {
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const out = [];
    // the next two months, day by day (with the schedule or your own days), plus the overrides
    for (let i = 0; i < 62; i++) {
        const when = new Date(today.getFullYear(), today.getMonth(), today.getDate() + i);
        const o = (overrides || {})[dateKey(when)];
        if (o === "skip") continue;
        const rooms = scheduledOn(rows, room, when, own);
        if (o === "add" || rooms !== null)
            out.push({ date: dateKey(when), when: when.getTime(), rooms: o === "add" && rooms === null ? "Added by you" : rooms, overridden: !!o });
    }
    return out;
}
function prediction(rows, cgpa, earned) {
    const points = {S:10,A:9,B:8,C:7,D:6,E:5,F:0,N:0};
    let credits = 0, total = 0;
    for (const row of rows) {
        const c = Number(row.credits);
        if (!(c > 0) || !Number.isFinite(c) || points[row.grade] === undefined) continue;
        credits += c; total += c * points[row.grade];
    }
    const known = cgpa !== null && cgpa !== undefined && String(cgpa).trim() !== "" && Number.isFinite(Number(cgpa));
    const prior = Number(earned);
    return {credits:credits, sgpa:credits ? total/credits : null,
            cgpa:credits && known && prior > 0 ? (Number(cgpa)*prior+total)/(prior+credits) : null};
}
