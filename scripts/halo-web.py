#!/usr/bin/env python3
"""halo-web.py — read a web page as plain text, for Halo (standard library only).

  halo-web.py read <url>     JSON: {title, url, text}  (text ≤ 15 000 chars) or {error}

Only http(s); one GET with a 15 s timeout, at most 3 MB; no cookies, no
JavaScript, nothing sent but the request itself. Scripts, styles, navigation
and footers are dropped.
"""
import html
import html.parser
import json
import re
import sys
import urllib.error
import urllib.request

SKIP = {"script", "style", "noscript", "svg", "nav", "footer", "header", "form", "button", "iframe", "aside"}
BLOCK = {"p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", "pre", "blockquote", "table", "ul", "ol"}


class Text(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out, self.skip, self.title, self.in_title = [], 0, "", False

    def handle_starttag(self, tag, attrs):
        if tag in SKIP:
            self.skip += 1
        elif tag == "title":
            self.in_title = True
        elif tag in BLOCK:
            self.out.append("\n")
        if tag in ("h1", "h2", "h3"):
            self.out.append("## ")
        if tag == "li":
            self.out.append("- ")

    def handle_endtag(self, tag):
        if tag in SKIP and self.skip:
            self.skip -= 1
        elif tag == "title":
            self.in_title = False
        elif tag in BLOCK:
            self.out.append("\n")

    def handle_data(self, data):
        if self.in_title:
            self.title += data
        elif not self.skip:
            self.out.append(data)


def read(url):
    if not re.match(r"^https?://", url):
        return {"error": "Only web addresses (http or https)."}
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Lumen-Halo/1.0", "Accept": "text/html,text/plain;q=0.9"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            kind = r.headers.get("Content-Type", "")
            raw = r.read(3_000_000)
            charset = r.headers.get_content_charset() or "utf-8"
            final = r.geturl()
    except urllib.error.HTTPError as e:
        return {"error": "The site answered %d %s." % (e.code, e.reason)}
    except (urllib.error.URLError, OSError, ValueError) as e:
        return {"error": "Couldn't reach it: %s" % getattr(e, "reason", e)}
    body = raw.decode(charset, "replace")
    if "html" not in kind and "<html" not in body[:2000].lower():
        text = body
        title = final.rsplit("/", 1)[-1]
    else:
        p = Text()
        p.feed(body)
        text, title = "".join(p.out), p.title
    text = html.unescape(text)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    text = re.sub(r"\n\s*\n+", "\n\n", text).strip()
    return {"title": re.sub(r"\s+", " ", title).strip(), "url": final, "text": text[:15000]}


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "read":
        print(json.dumps(read(sys.argv[2])))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
