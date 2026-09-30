#!/usr/bin/env bash
# Full build of the Grand Siecle demo, in order:
#   1. data     data/editions + data/indices hold the project's source files, unchanged;
#               copied by pyscripts/fetch_data.py only if data/editions is empty (or with
#               --fetch); data/SHA256SUMS says whether they still match the copied sources
#   2. derive   build/derived/mentions.xml (pyscripts/derive_mentions.py): mentions, pages and
#               passages read from the TEI, kept outside the TEI (not versioned)
#   3. ant      static site in html/ (XSLT)
#   4. index    Typesense collection + html/js/search-config.js (pyscripts/make_ts_index.py),
#               only if TYPESENSE_API_KEY is set; otherwise the site works without search
#               (search.html explains that the index is missing)
#   5. check    internal links
# Options: --fetch [--src DIR] copies the sources again (default source: $GS_SOURCE_DATA,
# then ../grand-siecle-max-statique/data). The site is built from whatever TEI files are in
# data/editions: remove or add one and run ./build.sh again.
# Typesense settings: TYPESENSE_HOST/PORT/PROTOCOL/API_KEY/COLLECTION (see make_ts_index.py).
set -euo pipefail
cd "$(dirname "$0")"

step() { printf '\n== %s\n' "$1"; }

fetch=0
fetch_args=()
while [ $# -gt 0 ]; do
    case "$1" in
        --fetch) fetch=1 ;;
        --src) fetch_args+=(--src "$2"); fetch=1; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

step "1/5 data"
if [ "$fetch" = 1 ] || ! compgen -G "data/editions/*.xml" > /dev/null; then
    uv run --locked pyscripts/fetch_data.py "${fetch_args[@]}"
fi
# informative only: a file removed, added or edited in data/ on purpose is allowed
if (cd data && sha256sum --quiet -c SHA256SUMS > /dev/null 2>&1); then
    echo "data/ matches data/SHA256SUMS (source files unchanged)"
else
    echo "WARNING: data/ differs from data/SHA256SUMS (file removed, added or modified since the copy)"
fi

step "2/5 derive"
uv run --locked pyscripts/derive_mentions.py

step "3/5 ant"
ant -q

step "4/5 search index"
if [ -n "${TYPESENSE_API_KEY:-}" ]; then
    uv run --locked pyscripts/make_ts_index.py
else
    echo "TYPESENSE_API_KEY not set: search index not built (the rest of the site is complete)."
fi

step "5/5 links"
uv run --locked pyscripts/check_links.py html
