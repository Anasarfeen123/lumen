// Markdown → the small HTML subset Qt's rich text understands, styled for
// Halo: headings, paragraphs with real spacing, lists, inline code, code
// blocks, bold/italic, links. Fast enough to run on every streamed batch, and
// tolerant of half-written input (an unclosed ``` while an answer streams).
.pragma library

function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function inline(s, c) {
    s = esc(s);
    // `code` first, so its contents stay literal
    const codes = [];
    s = s.replace(/`([^`\n]+)`/g, (_, x) => { codes.push(x); return "\u0000" + (codes.length - 1) + "\u0000"; });
    s = s.replace(/\*\*([^*\n]+)\*\*/g, "<b>$1</b>")
         .replace(/(^|[^*])\*([^*\n]+)\*(?!\*)/g, "$1<i>$2</i>")
         .replace(/(^|\W)_([^_\n]+)_(?=\W|$)/g, "$1<i>$2</i>")
         .replace(/\[([^\]\n]+)\]\((https?:[^)\s]+)\)/g, '<a href="$2" style="color:' + c.accent + ';text-decoration:none">$1</a>');
    return s.replace(/\u0000(\d+)\u0000/g, (_, i) =>
        '<span style="font-family:\'' + c.mono + '\';background-color:' + c.codeBg + ';">&#8201;' + codes[+i] + '&#8201;</span>');
}

// c: { text, muted, accent, codeBg, blockBg, mono }
function toHtml(src, c) {
    const out = [];
    const parts = src.split(/```/);
    for (let p = 0; p < parts.length; p++) {
        if (p % 2 === 1) {
            // A code block: first line may be the language
            const nl = parts[p].indexOf("\n");
            const code = (nl >= 0 ? parts[p].slice(nl + 1) : "").replace(/\n$/, "");
            out.push('<table width="100%" cellpadding="8" style="margin-top:4px;margin-bottom:8px;background-color:' + c.blockBg + ';"><tr><td>'
                     + '<pre style="font-family:\'' + c.mono + '\';font-size:12px;margin:0;">' + esc(code) + '</pre></td></tr></table>');
            continue;
        }
        const lines = parts[p].split("\n");
        let para = [], list = null;
        const flushPara = () => { if (para.length) { out.push('<p style="margin-top:0;margin-bottom:8px;">' + para.map(l => inline(l, c)).join(" ") + "</p>"); para = []; } };
        const flushList = () => { if (list) { out.push("<" + list.tag + ' style="margin-top:0;margin-bottom:8px;margin-left:-14px;">' + list.items.map(i => '<li style="margin-bottom:3px;">' + inline(i, c) + "</li>").join("") + "</" + list.tag + ">"); list = null; } };
        for (let li = 0; li < lines.length; li++) {
            const line = lines[li].replace(/\s+$/, "");
            const next = (lines[li + 1] ?? "").trim();
            let m;
            // "Title\n=====" or "Title\n-----": a heading (setext style)
            if (line.trim() !== "" && !list && /^(=+|-+)$/.test(next) && next.length >= 3) {
                flushPara(); flushList();
                out.push('<p style="margin-top:6px;margin-bottom:6px;"><span style="font-size:' + (next[0] === "=" ? 16 : 14.5) + 'px;font-weight:600;">' + inline(line.trim(), c) + "</span></p>");
                li++;
                continue;
            }
            // --- / *** on its own: a quiet divider
            if (/^\s*([-*_])(\s*\1){2,}\s*$/.test(line)) {
                flushPara(); flushList();
                out.push('<p style="margin-top:2px;margin-bottom:8px;color:' + c.muted + ';">· · ·</p>');
                continue;
            }
            // | a | b | tables
            if (/^\s*\|.*\|\s*$/.test(line)) {
                flushPara(); flushList();
                const rows = [];
                while (li < lines.length && /^\s*\|.*\|\s*$/.test(lines[li])) { rows.push(lines[li].trim().slice(1, -1).split("|").map(x => x.trim())); li++; }
                li--;
                const body = rows.filter(r => !r.every(x => /^:?-{2,}:?$/.test(x)));
                out.push('<table cellpadding="5" cellspacing="0" style="margin-bottom:8px;">' + body.map((r, ri) =>
                    "<tr>" + r.map(x => '<td style="border-bottom:1px solid ' + c.codeBg + ';' + (ri === 0 ? "font-weight:600;" : "") + '">' + inline(x, c) + "</td>").join("") + "</tr>").join("") + "</table>");
                continue;
            }
            if ((m = /^(#{1,6})\s+(.*)$/.exec(line))) {
                flushPara(); flushList();
                const size = m[1].length <= 2 ? 16 : 14.5;
                out.push('<p style="margin-top:6px;margin-bottom:6px;"><span style="font-size:' + size + 'px;font-weight:600;">' + inline(m[2], c) + "</span></p>");
            } else if ((m = /^\s*[-*+•]\s+(.*)$/.exec(line))) {
                flushPara();
                if (!list || list.tag !== "ul") { flushList(); list = { tag: "ul", items: [] }; }
                list.items.push(m[1]);
            } else if ((m = /^\s*\d+[.)]\s+(.*)$/.exec(line))) {
                flushPara();
                if (!list || list.tag !== "ol") { flushList(); list = { tag: "ol", items: [] }; }
                list.items.push(m[1]);
            } else if (/^\s*$/.test(line)) {
                flushPara(); flushList();
            } else if (/^\s*>\s?/.test(line)) {
                flushPara(); flushList();
                out.push('<p style="margin-top:0;margin-bottom:8px;color:' + c.muted + ';">▍ ' + inline(line.replace(/^\s*>\s?/, ""), c) + "</p>");
            } else {
                if (list) flushList();
                para.push(line);
            }
        }
        flushPara(); flushList();
    }
    return out.join("");
}


// A finished answer as text and code pieces, so code blocks can be drawn as
// cards with their own Copy / Run (an unclosed ``` stays text).
function segments(src) {
    const out = [];
    const re = /```([\w+-]*)[^\n]*\n([\s\S]*?)```/g;
    let last = 0, m;
    while ((m = re.exec(src)) !== null) {
        const before = src.slice(last, m.index);
        if (before.trim() !== "") out.push({ code: false, text: before });
        out.push({ code: true, lang: m[1].toLowerCase(), text: m[2].replace(/\n$/, "") });
        last = re.lastIndex;
    }
    const rest = src.slice(last);
    if (rest.trim() !== "" || out.length === 0) out.push({ code: false, text: rest });
    return out;
}
