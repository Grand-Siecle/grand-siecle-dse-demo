"""Data derived from the TEI editions for the register pages: mentions, pages, passages.

Reads (never writes) the TEI editions of data/editions/ and writes one derived file,
build/derived/mentions.xml, that the XSLT build reads next to the registers:

  <mentions>
    <doc id="LIV0019" file="LIV0019_reconciled.tei.xml" pages="129" title="Lettres ..."/>
    <entity id="person-000001">                 every register id referenced in <text>
      <in doc="LIV0019" n="3" first="12" truncated="true">   n = mentions, first = first page
        <kwic page="12" lang="fr"><left>…</left><kw>Ciceron</kw><right>…</right></kwic>
      </in>                                      one passage per text block, 5 max
    </entity>
  </mentions>

The file is regenerated at every build (build.sh), is not versioned and is not a source:
deleting it loses nothing. The document id is taken from the file name
(LIV0019_reconciled.tei.xml -> LIV0019, same rule as xslt/partials/doc_meta.xsl).
Everything that involves the registers (perimeter of the 665 entries, co-occurrences,
labels, full register size) is computed by the XSLT (xslt/partials/registres.xsl).

Why a script and not XSLT: the passages in context (KWIC) are those of the MaX edition
(port of scripts/build-entities.mjs), computed on the raw XML text: block of the mention,
reg layer preferred, words cut at a line end de-duplicated, 80 characters on each side,
and a raw 1500/2000 character window for mentions outside ab|p|head|item|l (31 mentions in
marginal notes). A tree-based XSLT version would give different passages for these.

Rules (unchanged from the J4 import):
  * a document cites an entity if an element of its <text> carries a @ref token "#type-000000";
  * mentions: elements persName|placeName|orgName|title|rs|material|date|objectName with
    ref="#type-000000", page = rank of the preceding <pb> (as the reading pages {ID}-page-{n});
  * KWIC: see kwic_for().

Usage: uv run pyscripts/derive_mentions.py [--out build/derived/mentions.xml]
"""

import argparse
import re
import sys
import time
import unicodedata
from pathlib import Path

from lxml import etree

TEI_NS = "http://www.tei-c.org/ns/1.0"
NS = {"tei": TEI_NS}
ROOT = Path(__file__).resolve().parent.parent
REF_RE = re.compile(r"^#([a-z]+)-(\d{6})$")

MAX_KWIC_PER_DOC = 5
KWIC_SIDE = 80

MENTION_RE = re.compile(
    r'<(persName|placeName|orgName|title|rs|material|date|objectName)\b[^>]*?\bref="#([a-z]+)-(\d{6})"[^>]*>')
BLOCK_RE = re.compile(r"<(ab|p|head|item|l)\b[^>]*>.*?</\1>", re.S)
PB_RE = re.compile(r"<pb\b[^>]*>")
CHOICE_RE = re.compile(r"<choice>(.*?)</choice>", re.S)
REG_RE = re.compile(r"<reg\b[^>]*>(.*?)</reg>", re.S)
ORIG_RE = re.compile(r"<orig\b[^>]*>(.*?)</orig>", re.S)
FIRST_W_RE = re.compile(r"<w\b([^>]*)>")
TAG_RE = re.compile(r"<[^>]*>")
LANG_RE = re.compile(r'^<[^>]*\bxml:lang="([a-z]+)"')
# ISO 639-2/3 of the TEI -> BCP 47 (same mapping as gs:lang in xslt/editions.xsl)
LANGS = {"fra": "fr", "lat": "la", "ita": "it", "grc": "grc"}

# sentinels: mention start/end, line boundary, line boundary starting with a re-joined word
S, E, SEG, SEGDUP = "\x01", "\x02", "\x03", "\x04"
NAMED = {"amp": "&", "lt": "<", "gt": ">", "quot": '"', "apos": "'"}


def tei(tag):
    return f"{{{TEI_NS}}}{tag}"


def decode_entities(s):
    s = re.sub(r"&#x([0-9a-fA-F]+);", lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r"&#(\d+);", lambda m: chr(int(m.group(1))), s)
    return re.sub(r"&(amp|lt|gt|quot|apos);", lambda m: NAMED[m.group(1)], s)


def fold(s):
    """lower case, no diacritics, letters and digits only (edge token comparison, sort key)"""
    s = unicodedata.normalize("NFD", str(s or "").lower())
    return "".join(c for c in s if not unicodedata.combining(c) and c.isalnum())


def edit_distance_le(a, b, limit):
    if abs(len(a) - len(b)) > limit:
        return False
    dp = list(range(len(a) + 1))
    for j in range(1, len(b) + 1):
        prev, dp[0] = dp[0], j
        row_min = dp[0]
        for i in range(1, len(a) + 1):
            tmp = dp[i]
            dp[i] = min(dp[i] + 1, dp[i - 1] + 1, prev + (a[i - 1] != b[j - 1]))
            prev = tmp
            row_min = min(row_min, dp[i])
        if row_min > limit:
            return False
    return dp[len(a)] <= limit


def same_edge_token(a, b):
    fa, fb = fold(a), fold(b)
    if not fa or not fb:
        return False
    if fa == fb:
        return True
    shortest = min(len(fa), len(fb))
    return shortest >= 4 and edit_distance_le(fa, fb, 2 if shortest >= 6 else 1)


class Doc:
    """Raw text of one source TEI with its mentions, page offsets and text blocks."""

    def __init__(self, path, doc_id):
        self.id = doc_id
        self.xml = Path(path).read_text(encoding="utf-8")
        m = re.search(r"<text[\s>]", self.xml)
        start = m.start() if m else 0
        # finditer(pos=start) already returns absolute offsets; J4 added start a second time,
        # which put every mention on page 1 (fixed here, as scripts/build-entities.mjs of MaX)
        self.pb = [m.start() for m in PB_RE.finditer(self.xml, start)]
        self.mentions = []
        for m in MENTION_RE.finditer(self.xml, start):
            self.mentions.append({
                "id": f"{m.group(2)}-{m.group(3)}", "el": m.group(1), "off": m.start(),
                "tag_len": len(m.group(0)), "page": self.page_of(m.start()),
            })
        self.blocks = sorted((m.start(), m.end()) for m in BLOCK_RE.finditer(self.xml, start))
        self._block_starts = [b[0] for b in self.blocks]

    def page_of(self, off):
        """1-based rank of the last <pb> before off (bisect)"""
        lo, hi, ans = 0, len(self.pb) - 1, 0
        while lo <= hi:
            mid = (lo + hi) >> 1
            if self.pb[mid] <= off:
                ans, lo = mid + 1, mid + 1
            else:
                hi = mid - 1
        return max(1, ans)

    def block_of(self, off):
        lo, hi, ans = 0, len(self.blocks) - 1, -1
        while lo <= hi:
            mid = (lo + hi) >> 1
            if self._block_starts[mid] <= off:
                ans, lo = mid, mid + 1
            else:
                hi = mid - 1
        return ans if ans >= 0 and off < self.blocks[ans][1] else -1


def kwic_for(doc, mention):
    """(left, keyword, right, BCP 47 language of the block) around one mention, or None."""
    bi = doc.block_of(mention["off"])
    lang = ""
    if bi >= 0:
        b_start, b_end = doc.blocks[bi]
        raw, rel = doc.xml[b_start:b_end], mention["off"] - b_start
        m = LANG_RE.match(raw)
        lang = LANGS.get(m.group(1), m.group(1)) if m else ""
    else:
        start = max(0, mention["off"] - 1500)
        raw, rel = doc.xml[start:mention["off"] + 2000], mention["off"] - start
    # 1. mark the mention content
    open_end = rel + mention["tag_len"]
    close = raw.find(f"</{mention['el']}>", open_end)
    if close < 0:
        return None
    raw = raw[:open_end] + S + raw[open_end:close] + E + raw[close:]

    # 2. one layer per <choice>: reg, else orig; the layer holding the mention if any
    def resolve(m):
        inner = m.group(1)
        reg, orig = REG_RE.search(inner), ORIG_RE.search(inner)
        first_w = FIRST_W_RE.search(orig.group(1)) if orig else None
        mark = SEGDUP if first_w and re.search(r'\bpart="F"', first_w.group(1)) else SEG
        if S in inner:
            if reg and S in reg.group(1):
                layer = reg.group(1)
            elif orig and S in orig.group(1):
                layer = orig.group(1)
            else:
                layer = inner.replace(orig.group(0), " ", 1) if orig else inner
        else:
            layer = reg.group(1) if reg else orig.group(1) if orig else inner
        return f" {mark}{layer} "

    resolved = CHOICE_RE.sub(resolve, raw)

    # 3. flatten, then drop the word repeated across a line boundary
    flat_raw = re.sub(r"\s+", " ", decode_entities(TAG_RE.sub(" ", resolved))).strip()
    tokens = []
    for part in re.split(f"(?=[{SEG}{SEGDUP}])", flat_raw):
        dup = part[:1] == SEGDUP
        part = re.sub(f"^[{SEG}{SEGDUP}]\\s*", "", part).strip()
        if not part:
            continue
        words = part.split(" ")
        if dup and tokens and words:
            prev, cur = tokens[-1], words[0]
            if same_edge_token(prev, cur):
                if S in cur or E in cur:
                    tokens.pop()
                else:
                    words.pop(0)
        tokens.extend(w for w in words if w)
    flat = " ".join(tokens)
    i, j = flat.find(S), flat.find(E)
    if i < 0 or j < 0 or j <= i:
        return None
    kw = flat[i + 1:j].strip()
    if not kw:
        return None
    left, right = flat[:i].rstrip(), flat[j + 1:].lstrip()
    if len(left) > KWIC_SIDE:
        left = "…" + re.sub(r"^\S*\s", "", left[-KWIC_SIDE:], count=1)
    if len(right) > KWIC_SIDE:
        right = re.sub(r"\s\S*$", "", right[:KWIC_SIDE], count=1) + "…"
    return left, kw, right, lang


def doc_id(path):
    """LIV0019_reconciled.tei.xml -> LIV0019 (LIV0019.xml -> LIV0019)"""
    return re.sub(r"(_reconciled)?(\.tei)?\.xml$", "", Path(path).name)


def cited_ids(tree):
    """Register ids referenced by any @ref token inside <text> (J4 import rule)."""
    text = tree.getroot().find(tei("text"))
    cited = set()
    for el in text.iter() if text is not None else ():
        for token in (el.get("ref") or "").split() if isinstance(el.tag, str) else ():
            m = REF_RE.match(token)
            if m:
                cited.add(f"{m.group(1)}-{m.group(2)}")
    return cited


def derive(files):
    root = etree.Element("mentions")
    per_entity = {}
    for path in files:
        d = doc_id(path)
        tree = etree.parse(str(path), etree.XMLParser(huge_tree=True))
        title = tree.findtext("tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title", namespaces=NS) or ""
        pages = len(tree.findall("tei:text//tei:pb", NS))
        etree.SubElement(root, "doc", id=d, file=Path(path).name, pages=str(pages), title=title)
        doc = Doc(path, d)
        occ = {}
        for m in doc.mentions:
            occ.setdefault(m["id"], []).append(m)
        for eid in sorted(cited_ids(tree) | set(occ)):
            per_entity.setdefault(eid, []).append((doc, occ.get(eid, [])))
        del tree

    kwic_total = 0
    for eid in sorted(per_entity):
        ent = etree.SubElement(root, "entity", id=eid)
        for doc, ms in per_entity[eid]:
            inside = etree.SubElement(ent, "in", doc=doc.id, n=str(len(ms)), first=str(ms[0]["page"] if ms else 1))
            seen, lines = set(), 0
            for m in ms:
                bi = doc.block_of(m["off"])
                key = f"b{bi}" if bi >= 0 else f"o{m['off']}"
                if key in seen:
                    continue
                seen.add(key)
                k = kwic_for(doc, m)
                if not k:
                    continue
                if lines >= MAX_KWIC_PER_DOC:
                    inside.set("truncated", "true")
                    break
                lines += 1
                kwic = etree.SubElement(inside, "kwic", page=str(m["page"]))
                if k[3]:
                    kwic.set("lang", k[3])
                for part, text in zip(("left", "kw", "right"), k[:3]):
                    etree.SubElement(kwic, part).text = text
            kwic_total += lines
    return root, kwic_total


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--editions", default=str(ROOT / "data" / "editions"))
    parser.add_argument("--out", default=str(ROOT / "build" / "derived" / "mentions.xml"))
    args = parser.parse_args()
    t0 = time.perf_counter()
    files = sorted(Path(args.editions).glob("*.xml"))
    if not files:
        sys.exit(f"ERROR: no TEI in {args.editions} (run pyscripts/fetch_data.py)")
    root, kwic_total = derive(files)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    etree.ElementTree(root).write(str(out), encoding="UTF-8", xml_declaration=True, pretty_print=True)
    docs = root.findall("doc")
    mentions = sum(int(i.get("n")) for i in root.iter("in"))
    print(f"  {len(docs)} documents ({sum(int(d.get('pages')) for d in docs)} pages), "
          f"{len(root.findall('entity'))} entity ids referenced, {mentions} mentions, {kwic_total} passages "
          f"-> {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out} in {time.perf_counter() - t0:.1f} s")


if __name__ == "__main__":
    main()
