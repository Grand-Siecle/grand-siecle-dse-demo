"""Compare two builds of the site (regression check): same files, same pages.

  uv run pyscripts/compare_sites.py OLD_HTML_DIR NEW_HTML_DIR [--allow NAME ...]

For every *.html, *.xml and *.txt at the top of the two directories (assets are not compared):
  * files present on one side only are listed;
  * files present on both sides are compared byte for byte; when they differ, the visible
    text (HTML: text content of <body>, whitespace collapsed) is compared too, and the first
    differing line is shown.
Categories: reading pages ({ID}-page-{n}.html), document pages ({ID}.html), entity pages
({type}-{000000}.html), entity TEI exports, other pages, other XML/TXT.
With --mask-page-numbers, page numbers in links and passages ("{ID}-page-41.html", "p. 41")
are replaced by a placeholder before comparing, so that a correction of the page numbers is
reported apart ("page numbers only") from any other change.
Exit status 1 if a reading page or an entity page differs (other than by page numbers when
masked), or if a page of these two kinds is missing on one side; other differences are
reported only (--allow is informational: names expected to differ are marked as such).
"""

import argparse
import difflib
import re
import sys
from pathlib import Path

from lxml import html as lxml_html

CATEGORIES = [
    ("reading pages", re.compile(r"^.+-page-\d+\.html$")),
    ("document pages", re.compile(r"^LIV\w+\.html$")),
    ("entity pages", re.compile(r"^[a-z]+-\d{6}\.html$")),
    ("entity TEI exports", re.compile(r"^[a-z]+-\d{6}\.xml$")),
    ("other HTML pages", re.compile(r"^.+\.html$")),
    ("other XML / TXT", re.compile(r"^.+\.(xml|txt)$")),
]
STRICT = {"reading pages", "entity pages"}
# page numbers in links ("LIV0019-page-41.html") and in passages ("p. 41")
PAGE_RE = re.compile(rb'(-page-|lang="fr">p\. )\d+')


def category(name):
    return next(label for label, rx in CATEGORIES if rx.match(name))


def visible_text(path):
    if path.suffix != ".html":
        return path.read_text(encoding="utf-8")
    doc = lxml_html.fromstring(path.read_bytes())
    body = doc.find("body")
    return "\n".join(" ".join(t.split()) for t in (body if body is not None else doc).itertext() if t.strip())


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("old")
    parser.add_argument("new")
    parser.add_argument("--allow", nargs="*", default=[], help="file names expected to differ")
    parser.add_argument("--mask-page-numbers", action="store_true",
                        help="report differences limited to page numbers separately")
    args = parser.parse_args()
    old, new = Path(args.old), Path(args.new)
    names = lambda d: {p.name for p in d.iterdir() if p.is_file() and p.suffix in (".html", ".xml", ".txt")}
    old_names, new_names = names(old), names(new)
    failed = False
    stats = {label: {"identical": 0, "text identical": 0, "pages only": 0, "different": 0, "only old": [], "only new": []}
             for label, _ in CATEGORIES}
    mask = lambda b: PAGE_RE.sub(rb"\1#", b)
    for n in sorted(old_names - new_names):
        stats[category(n)]["only old"].append(n)
    for n in sorted(new_names - old_names):
        stats[category(n)]["only new"].append(n)
    shown = 0
    for n in sorted(old_names & new_names):
        cat = category(n)
        a, b = (old / n).read_bytes(), (new / n).read_bytes()
        if a == b:
            stats[cat]["identical"] += 1
            continue
        if args.mask_page_numbers and mask(a) == mask(b):
            stats[cat]["pages only"] += 1
            continue
        ta, tb = visible_text(old / n), visible_text(new / n)
        if ta == tb:
            stats[cat]["text identical"] += 1
            continue
        stats[cat]["different"] += 1
        if cat in STRICT and n not in args.allow:
            failed = True
        if shown < 12:
            shown += 1
            diff = [l for l in difflib.unified_diff(ta.splitlines(), tb.splitlines(), lineterm="", n=0)
                    if l[:1] in "+-" and not l.startswith(("+++", "---"))][:4]
            mark = " (expected)" if n in args.allow else ""
            print(f"  {n}{mark}:\n    " + "\n    ".join(d[:160] for d in diff))
    print(f"{'category':22} {'identical':>9} {'text id.':>9} {'pages':>9} {'different':>9} {'only old':>9} {'only new':>9}")
    for label, s in stats.items():
        print(f"{label:22} {s['identical']:9} {s['text identical']:9} {s['pages only']:9} {s['different']:9} "
              f"{len(s['only old']):9} {len(s['only new']):9}")
        for side in ("only old", "only new"):
            if s[side]:
                print(f"    {side}: {' '.join(s[side][:8])}{' ...' if len(s[side]) > 8 else ''}")
                if label in STRICT:
                    failed = True
    print("RESULT:", "FAIL (reading or entity pages differ)" if failed else "OK (reading and entity pages unchanged)")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
