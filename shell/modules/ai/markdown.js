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
        for (const raw of lines) {
            const line = raw.replace(/\s+$/, "");
            let m;
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
