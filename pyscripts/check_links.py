"""Check internal links (href/src) of the generated site in html/.

Usage: uv run pyscripts/check_links.py [html_dir]
Exit code 1 if at least one internal link points to a missing file.
"""

import re
import sys
from collections import Counter
from pathlib import Path
from urllib.parse import unquote, urlsplit

ATTR_RE = re.compile(r'\b(?:href|src)="([^"]*)"')


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "html").resolve()
    pages = sorted(root.rglob("*.html"))
    pages = [p for p in pages if "vendor" not in p.relative_to(root).parts]
    checked, broken = 0, Counter()
    examples = {}
    for page in pages:
        for url in ATTR_RE.findall(page.read_text(encoding="utf-8")):
            parts = urlsplit(url)
            if parts.scheme or url.startswith(("#", "//", "mailto:", "javascript:")) or not parts.path:
                continue
            checked += 1
            target = (page.parent / unquote(parts.path)).resolve()
            if not target.exists():
                broken[parts.path] += 1
                examples.setdefault(parts.path, page.name)
    print(f"{len(pages)} HTML pages, {checked} internal links checked, "
          f"{sum(broken.values())} broken ({len(broken)} distinct targets)")
    for target, n in broken.most_common(20):
        print(f"  {n:5d}  {target}  (e.g. in {examples[target]})")
    sys.exit(1 if broken else 0)


if __name__ == "__main__":
    main()
