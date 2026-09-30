"""Entity data computed from the full text, written into the register index files (J4).

Called by import_data.py on the freshly written data/indices files (staging), before they
replace data/indices. Everything that needs a scan of the 5 texts is computed here, once,
at import time; the XSLT build (xslt/listentity.xsl, entites.xsl, carte.xsl,
chronologie.xsl) only renders what it finds in the index files.

Added to each entry (TEI, so that the index files stay the single source of the pages):

  <noteGrp type="mentions" n="56">            n = mentions in the 5 texts (inline @ref)
    <note type="mentions" target="LIV0017.xml" n="28" subtype="truncated">
      <title>Dialogue des causes ...</title>        document title
      <ptr type="page" target="LIV0017-page-12.html"/>   first page citing the entity
      <cit type="kwic" n="12">                       one passage per text block, 5 max
        <quote xml:lang="fr"><seg type="left">…</seg><seg type="kw">Ciceron</seg><seg type="right">…</seg></quote>
        <ptr target="LIV0017-page-12.html"/>
      </cit>
    </note>
  </noteGrp>
  <linkGrp type="cooccurrence">                 up to 14 entities sharing documents
    <ptr target="#place-000001" n="2"/>          n = number of shared documents
  </linkGrp>

and to each index file header:
  <extent><measure unit="entry" type="register-total" quantity="7439"/></extent>
  (entries of the full register, shown on the hub as "... dans le corpus complet").

Port of scripts/build-entities.mjs of the MaX edition (same rules, same output), so that
the two publications show the same passages and co-occurrences:
  * mentions: elements carrying ref="#type-000000" inside <text>, page = rank of the
    preceding <pb> (same numbering as the DSE reading pages {ID}-page-{n}.html);
  * KWIC: block (ab|p|head|item|l) of the mention, reg layer preferred, the layer holding
    the mention inside its own <choice>; words cut at a line end and repeated at the
    start of the next reg line are de-duplicated; 80 characters on each side;
  * co-occurrences: entities of the perimeter sharing at least one document, corpus
    count @n > 1, sorted by shared documents, then @n, then label; 14 max.
"""

import re
import time
import unicodedata
from pathlib import Path

from lxml import etree

TEI_NS = "http://www.tei-c.org/ns/1.0"
XML_ID = "{http://www.w3.org/XML/1998/namespace}id"
NS = {"tei": TEI_NS}

# index file -> (register file, entry tag, id prefix): used to count the full register
INDEX_FILES = {
    "listperson.xml": ("persons.xml", "person", "person"),
    "listplace.xml": ("places.xml", "place", "place"),
    "listorg.xml": ("organizations.xml", "org", "org"),
    "listbibl.xml": ("works.xml", "bibl", "work"),
    "listevent.xml": ("events.xml", "event", "event"),
    "listartwork.xml": ("artworks.xml", "object", "artwork"),
    "listmaterial.xml": ("materials.xml", "category", "material"),
    "listtechnique.xml": ("techniques.xml", "category", "technique"),
    "listdate.xml": ("dates.xml", "item", "date"),
}
# name element of each entry type, for the sort key (type sort, else main, else first)
NAME_TAG = {"person": "persName", "place": "placeName", "org": "orgName", "work": "title",
            "event": "label", "artwork": "objectName", "material": "term", "technique": "term",
            "date": "date"}

MAX_KWIC_PER_DOC = 5
MAX_COOCCUR = 14
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


def sort_key(s):
    """approximation of Intl.Collator('fr'): accents and case ignored first, then raw text"""
    base = unicodedata.normalize("NFD", (s or "").lower())
    return ("".join(c for c in base if not unicodedata.combining(c)), s or "")


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
        self.pb = [start + m.start() for m in PB_RE.finditer(self.xml, start)]
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


def entry_sort_key(entry, prefix):
    tag = NAME_TAG[prefix]
    names = entry.findall(f".//tei:{tag}", NS)
    by_type = {}
    for n in names:
        by_type.setdefault(n.get("type") or "", " ".join("".join(n.itertext()).split()))
    label = by_type.get("sort") or by_type.get("main") or (
        " ".join("".join(names[0].itertext()).split()) if names else "")
    return sort_key(label)


def enrich(indices_dir, src_dir, doc_ids, titles):
    """Rewrite the index files of indices_dir in place; return a summary dict."""
    t0 = time.perf_counter()
    indices_dir, src_dir = Path(indices_dir), Path(src_dir)
    docs = {d: Doc(src_dir / f"{d}_reconciled.tei.xml", d) for d in doc_ids}

    # mentions per entity and document
    occ = {}
    for d, doc in docs.items():
        for m in doc.mentions:
            occ.setdefault(m["id"], {}).setdefault(d, []).append(m)

    trees, entries = {}, {}
    for name in INDEX_FILES:
        tree = etree.parse(str(indices_dir / name))
        trees[name] = tree
        for el in tree.iter():
            eid = el.get(XML_ID) if isinstance(el.tag, str) else None
            if eid and re.fullmatch(r"[a-z]+-\d{6}", eid):
                grp = el.find(tei("noteGrp"))
                cited = [n.get("target")[:-4] for n in grp.findall(tei("note"))] if grp is not None else []
                entries[eid] = {"el": el, "docs": cited, "n": int(el.get("n") or 0),
                                "key": entry_sort_key(el, eid.split("-")[0])}

    # documents -> entities (perimeter), for the co-occurrences
    by_doc = {d: [] for d in doc_ids}
    for eid, e in entries.items():
        for d in e["docs"]:
            by_doc[d].append(eid)

    kwic_total = 0
    for eid, e in entries.items():
        el = e["el"]
        old = el.find(tei("noteGrp"))
        if old is not None:
            el.remove(old)
        per_doc = occ.get(eid, {})
        grp = etree.SubElement(el, tei("noteGrp"), type="mentions",
                               n=str(sum(len(per_doc.get(d, [])) for d in e["docs"])))
        for d in e["docs"]:
            ms = per_doc.get(d, [])
            note = etree.SubElement(grp, tei("note"), type="mentions", target=f"{d}.xml", n=str(len(ms)))
            etree.SubElement(note, tei("title")).text = titles[d]
            first = ms[0]["page"] if ms else 1
            etree.SubElement(note, tei("ptr"), type="page", target=f"{d}-page-{first}.html")
            seen, lines = set(), 0
            for m in ms:
                bi = docs[d].block_of(m["off"])
                key = f"b{bi}" if bi >= 0 else f"o{m['off']}"
                if key in seen:
                    continue
                seen.add(key)
                k = kwic_for(docs[d], m)
                if not k:
                    continue
                if lines >= MAX_KWIC_PER_DOC:
                    note.set("subtype", "truncated")
                    break
                lines += 1
                cit = etree.SubElement(note, tei("cit"), type="kwic", n=str(m["page"]))
                quote = etree.SubElement(cit, tei("quote"))
                if k[3]:
                    quote.set("{http://www.w3.org/XML/1998/namespace}lang", k[3])
                for part, text in zip(("left", "kw", "right"), k[:3]):
                    etree.SubElement(quote, tei("seg"), type=part).text = text
                etree.SubElement(cit, tei("ptr"), target=f"{d}-page-{m['page']}.html")
            kwic_total += lines

        # co-occurrences
        shared = {}
        for d in e["docs"]:
            for other in by_doc[d]:
                if other != eid:
                    shared[other] = shared.get(other, 0) + 1
        ranked = sorted(
            ((o, nd) for o, nd in shared.items() if entries[o]["n"] > 1),
            key=lambda x: (-x[1], -entries[x[0]]["n"], entries[x[0]]["key"]))[:MAX_COOCCUR]
        if ranked:
            links = etree.SubElement(el, tei("linkGrp"), type="cooccurrence")
            for o, nd in ranked:
                etree.SubElement(links, tei("ptr"), target=f"#{o}", n=str(nd))

    # full register size, in each index header
    for name, (reg_file, tag, prefix) in INDEX_FILES.items():
        text = (src_dir / "registers" / reg_file).read_text(encoding="utf-8")
        total = len(re.findall(rf'<{tag}\b[^>]*xml:id="{prefix}-\d{{6}}"', text))
        root = trees[name].getroot()
        file_desc = root.find("tei:teiHeader/tei:fileDesc", NS)
        extent = etree.Element(tei("extent"))
        etree.SubElement(extent, tei("measure"), unit="entry", type="register-total", quantity=str(total))
        file_desc.insert(1, extent)  # after titleStmt
        trees[name].write(str(indices_dir / name), encoding="UTF-8", xml_declaration=True, pretty_print=True)

    return {"entries": len(entries), "mentions": sum(len(d.mentions) for d in docs.values()),
            "kwic": kwic_total, "seconds": time.perf_counter() - t0}
