"""Copy the Grand Siecle source files into data/, byte for byte (no transformation).

  {src}/*_reconciled.tei.xml  ->  data/editions/   (the TEI editions, as encoded by the project)
  {src}/registers/*.xml       ->  data/indices/    (the nine authority registers, complete)

Nothing is rewritten: the files are copied, then checked against the SHA-256 of the source,
and the sums are written to data/SHA256SUMS (`cd data && sha256sum -c SHA256SUMS` proves that
data/ holds the source files unchanged). Everything the site needs beyond the source
(page numbers, image addresses, register perimeter, mention counts, passages) is computed at
build time, outside the TEI (pyscripts/derive_mentions.py, xslt/).

Copies rather than symbolic links: the demo repository stays buildable on its own (as the
template's fetch_data.sh downloads the data into data/), and a change of the source is only
taken into account when this script is run again (the sums say which state is built).

Usage: uv run pyscripts/fetch_data.py [--src DIR]
Source directory defaults to $GS_SOURCE_DATA, then ../grand-siecle-max-statique/data.
"""

import argparse
import hashlib
import os
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
TARGETS = {"editions": "*_reconciled.tei.xml", "indices": "registers/*.xml"}


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    default_src = os.environ.get("GS_SOURCE_DATA", str(ROOT.parent / "grand-siecle-max-statique" / "data"))
    parser.add_argument("--src", default=default_src, help="directory holding *_reconciled.tei.xml and registers/")
    src = Path(parser.parse_args().src).resolve()
    lines = []
    for target, pattern in TARGETS.items():
        files = sorted(src.glob(pattern))
        if not files:
            sys.exit(f"ERROR: no {pattern} in {src}")
        out_dir = DATA / target
        out_dir.mkdir(parents=True, exist_ok=True)
        for old in out_dir.glob("*.xml"):
            old.unlink()
        for f in files:
            expected = sha256(f)
            out = out_dir / f.name
            shutil.copyfile(f, out)
            if sha256(out) != expected:
                sys.exit(f"ERROR: {out} differs from {f} after copy")
            lines.append(f"{expected}  {target}/{f.name}")
        print(f"  data/{target}: {len(files)} files copied unchanged from {src / pattern}")
    (DATA / "SHA256SUMS").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"  data/SHA256SUMS: {len(lines)} sums (check: cd data && sha256sum -c SHA256SUMS)")


if __name__ == "__main__":
    main()
