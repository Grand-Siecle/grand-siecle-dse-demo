#!/usr/bin/env bash
# Full build of the Grand Siecle demo, in order:
#   1. import   data/editions + data/indices from the Grand Siecle sources (pyscripts/import_data.py)
#   2. ant      static site in html/ (XSLT)
#   3. index    Typesense collection + html/js/search-config.js (pyscripts/make_ts_index.py),
#               only if TYPESENSE_API_KEY is set; otherwise the site works without search
#               (search.html explains that the index is missing)
#   4. check    internal links
# Arguments are passed to the import script (e.g. --src /path/to/grand-siecle/data).
# Typesense settings: TYPESENSE_HOST/PORT/PROTOCOL/API_KEY/COLLECTION (see make_ts_index.py).
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\n== %s\n' "$1"; }

step "1/4 import"
uv run --locked pyscripts/import_data.py "$@"

step "2/4 ant"
ant -q

step "3/4 search index"
if [ -n "${TYPESENSE_API_KEY:-}" ]; then
    uv run --locked pyscripts/make_ts_index.py
else
    echo "TYPESENSE_API_KEY not set: search index not built (the rest of the site is complete)."
fi

step "4/4 links"
uv run --locked pyscripts/check_links.py html
