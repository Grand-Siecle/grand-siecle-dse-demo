"""Import the Grand Siecle demo corpus into the DSE data layout.

Reads (read-only) the raw "reconciled" TEI files and the authority registers of
the Grand Siecle project and writes:

  data/editions/{ID}.xml       one TEI per document, prepared for the XSLT build
  data/indices/listperson.xml  persons  cited by the 5 documents
  data/indices/listplace.xml   places   cited by the 5 documents
  data/indices/listorg.xml     orgs     cited by the 5 documents
  data/indices/listbibl.xml    works    cited by the 5 documents

Preparation applied to each TEI (the rest of the file is kept as is):
  * every tei:pb gets @n (1-based sequence), @xml:id ("{ID}-page-{n}") and
    @facs (IIIF image URL resolved from pb/@corresp -> sourceDoc/surface/graphic);
    these are what xslt/editions.xsl uses to write one HTML page per pb;
  * tei:sourceDoc (ALTO-derived zones/lines, ~68 % of the file) is removed;
  * known header error on LIV0001 (author forename "s") is corrected, as the MaX
    pipeline does (scripts/prepare-tei.mjs, AUTHOR_NAME_OVERRIDES).

Register perimeter (same rule as the MaX pipeline, scripts/build-entities.mjs):
  entity kept if it is referenced by an @ref in one of the 5 texts OR if its
  note[@type='sources'] lists one of the 5 documents.

Usage:
  uv run pyscripts/import_data.py [--src /path/to/grand-siecle/data]
Source directory defaults to $GS_SOURCE_DATA, then ../grand-siecle-max-statique/data.
"""

import argparse
import copy
import os
import re
import sys
import time
from collections import defaultdict
from pathlib import Path

from lxml import etree

TEI_NS = "http://www.tei-c.org/ns/1.0"
XML_ID = "{http://www.w3.org/XML/1998/namespace}id"
NS = {"tei": TEI_NS}

DOC_IDS = ["LIV0001", "LIV0010", "LIV0017", "LIV0019", "LIV0020"]
EXPECTED_TOTAL_PAGES = 888  # same control as the MaX pipeline

# Header corrections (display only), mirrored from the MaX pipeline.
AUTHOR_FORENAME_OVERRIDES = {"LIV0001": "Judocus"}

# register file -> (DSE index file, list element, entry element, id prefix, title)
REGISTERS = {
    "persons.xml": ("listperson.xml", "listPerson", "person", "person", "Personnes"),
    "places.xml": ("listplace.xml", "listPlace", "place", "place", "Lieux"),
    "organizations.xml": ("listorg.xml", "listOrg", "org", "org", "Organisations"),
    "works.xml": ("listbibl.xml", "listBibl", "bibl", "work", "Œuvres"),
}
# Registers of the project with no DSE index counterpart (not imported in J1).
SKIPPED_REGISTERS = ["events", "artworks", "materials", "techniques", "dates"]

REF_RE = re.compile(r"^#([a-z]+)-(\d{6})$")

ROOT = Path(__file__).resolve().parent.parent
EDITIONS_DIR = ROOT / "data" / "editions"
INDICES_DIR = ROOT / "data" / "indices"


def tei(tag):
    return f"{{{TEI_NS}}}{tag}"


def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def prepare_document(src_dir, doc_id):
    """Prepare one TEI; return (page count, set of cited entity ids, title)."""
    src = src_dir / f"{doc_id}_reconciled.tei.xml"
    parser = etree.XMLParser(huge_tree=True, remove_blank_text=False)
    tree = etree.parse(str(src), parser)
    root = tree.getroot()

    # 1. facsimile map: surface/@xml:id -> IIIF URL (1200 px high, as in MaX)
    source_doc = root.find(tei("sourceDoc"))
    if source_doc is None:
        fail(f"{doc_id}: no sourceDoc")
    facs = {}
    for surface in source_doc.findall(tei("surface")):
        graphic = surface.find(tei("graphic"))
        url = graphic.get("url") if graphic is not None else None
        if not url:
            fail(f"{doc_id}: surface {surface.get(XML_ID)} without graphic/@url")
        facs[surface.get(XML_ID)] = url.replace("full/full/0/native", "full/,1200/0/native")

    # 2. invariant: body = one div whose children are pb|ab|fw|note only
    divs = root.findall("tei:text/tei:body/tei:div", NS)
    if len(divs) != 1:
        fail(f"{doc_id}: expected one body/div, found {len(divs)}")
    allowed = {tei(n) for n in ("pb", "ab", "fw", "note")}
    for child in divs[0]:
        if isinstance(child.tag, str) and child.tag not in allowed:
            fail(f"{doc_id}: unexpected body/div child {child.tag}")
    if divs[0].find(tei("pb")) is None or divs[0][0].tag != tei("pb"):
        fail(f"{doc_id}: body/div does not start with a pb")

    # 3. number the page beginnings and resolve their image
    pbs = root.findall(".//tei:text//tei:pb", NS)
    for n, pb in enumerate(pbs, start=1):
        corresp = (pb.get("corresp") or "").lstrip("#")
        if corresp not in facs:
            fail(f"{doc_id}: pb {n} @corresp={corresp!r} has no surface")
        pb.set("n", str(n))
        pb.set(XML_ID, f"{doc_id}-page-{n}")
        pb.set("facs", facs[corresp])

    # 4. drop the sourceDoc
    root.remove(source_doc)

    # 5. header correction
    if doc_id in AUTHOR_FORENAME_OVERRIDES:
        fore = root.find("tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:author/tei:persName/tei:forename", NS)
        if fore is not None:
            fore.text = AUTHOR_FORENAME_OVERRIDES[doc_id]

    # 6. entity references in the text
    cited = set()
    text = root.find(tei("text"))
    for el in text.iter():
        ref = el.get("ref") if isinstance(el.tag, str) else None
        if ref:
            for token in ref.split():
                m = REF_RE.match(token)
                if m:
                    cited.add(f"{m.group(1)}-{m.group(2)}")

    out = EDITIONS_DIR / f"{doc_id}.xml"
    tree.write(str(out), encoding="UTF-8", xml_declaration=True)

    # 7. output controls
    check = etree.parse(str(out), etree.XMLParser(huge_tree=True))
    n_pb = len(check.findall(".//tei:text//tei:pb[@facs]", NS))
    if n_pb != len(pbs) or check.find(tei("sourceDoc")) is not None:
        fail(f"{doc_id}: output control failed ({n_pb} pb with @facs, expected {len(pbs)})")

    title = root.findtext("tei:teiHeader/tei:fileDesc/tei:titleStmt/tei:title", namespaces=NS)
    size = out.stat().st_size / 1e6
    print(f"  {doc_id}: {len(pbs)} pages, {len(cited)} entity ids cited, {size:.2f} MB  ({title})")
    return len(pbs), cited, title


def index_skeleton(title):
    root = etree.Element(tei("TEI"), nsmap={None: TEI_NS})
    header = etree.SubElement(root, tei("teiHeader"))
    file_desc = etree.SubElement(header, tei("fileDesc"))
    title_stmt = etree.SubElement(file_desc, tei("titleStmt"))
    etree.SubElement(title_stmt, tei("title")).text = title
    pub = etree.SubElement(file_desc, tei("publicationStmt"))
    etree.SubElement(pub, tei("p")).text = "Projet Grand Siècle (UNIL) — démonstration DSE"
    source = etree.SubElement(file_desc, tei("sourceDesc"))
    etree.SubElement(source, tei("p")).text = (
        "Extrait des registres d'autorité du projet, réduit aux entités citées par les 5 documents de la démonstration."
    )
    body = etree.SubElement(etree.SubElement(root, tei("text")), tei("body"))
    return root, body


def build_indices(src_dir, cited_by_doc, titles):
    all_cited = set().union(*cited_by_doc.values())
    demo = set(DOC_IDS)
    known = set()
    for reg_file, (out_name, list_tag, entry_tag, prefix, title) in REGISTERS.items():
        reg = etree.parse(str(src_dir / "registers" / reg_file), etree.XMLParser(huge_tree=True))
        root, body = index_skeleton(title)
        out_list = etree.SubElement(body, tei(list_tag))
        kept = by_ref = by_source = 0
        for entry in reg.iter(tei(entry_tag)):
            eid = entry.get(XML_ID) or ""
            if not eid.startswith(f"{prefix}-"):
                continue
            known.add(eid)
            sources = set((entry.findtext("tei:note[@type='sources']", namespaces=NS) or "").split("|"))
            docs = sorted({d for d in DOC_IDS if eid in cited_by_doc[d]} | (sources & demo))
            if not docs:
                continue
            kept += 1
            by_ref += eid in all_cited
            by_source += eid not in all_cited
            new = copy.deepcopy(entry)
            # DSE back-link convention (see xslt/partials/entities.xsl)
            grp = etree.SubElement(new, tei("noteGrp"))
            for d in docs:
                note = etree.SubElement(grp, tei("note"), type="mentions", target=f"{d}.xml")
                note.text = titles[d]
            out_list.append(new)
        etree.ElementTree(root).write(
            str(INDICES_DIR / out_name), encoding="UTF-8", xml_declaration=True, pretty_print=True
        )
        print(f"  {out_name}: {kept} entries ({by_ref} referenced in the texts, {by_source} only via note[@type='sources'])")
    orphans = {e for e in all_cited if e.split("-")[0] in {p[3] for p in REGISTERS.values()}} - known
    other = {e for e in all_cited if e.split("-")[0] not in {p[3] for p in REGISTERS.values()}}
    print(f"  refs without register entry: {len(orphans)}; refs to registers not imported ({', '.join(SKIPPED_REGISTERS)}): {len(other)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    default_src = os.environ.get("GS_SOURCE_DATA", str(ROOT.parent / "grand-siecle-max-statique" / "data"))
    parser.add_argument("--src", default=default_src, help="directory holding *_reconciled.tei.xml and registers/")
    args = parser.parse_args()
    src_dir = Path(args.src).resolve()
    t0 = time.perf_counter()

    EDITIONS_DIR.mkdir(parents=True, exist_ok=True)
    INDICES_DIR.mkdir(parents=True, exist_ok=True)
    for old in list(EDITIONS_DIR.glob("*.xml")) + list(INDICES_DIR.glob("*.xml")):
        old.unlink()

    print(f"Editions (source: {src_dir})")
    cited_by_doc, titles, total = {}, {}, 0
    for doc_id in DOC_IDS:
        pages, cited_by_doc[doc_id], titles[doc_id] = prepare_document(src_dir, doc_id)
        total += pages
    print(f"  total pages: {total} (expected {EXPECTED_TOTAL_PAGES})")
    if total != EXPECTED_TOTAL_PAGES:
        fail("page count mismatch")

    print("Indices")
    build_indices(src_dir, cited_by_doc, titles)
    print(f"Done in {time.perf_counter() - t0:.1f} s")


if __name__ == "__main__":
    main()
