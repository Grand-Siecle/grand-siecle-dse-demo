# Grand Siècle — démo DSE static


* build with [DSE-Static-Cookiecutter](https://github.com/acdh-oeaw/dse-static-cookiecutter)


## initial (one time) setup

The source data (raw TEI + registers of the Grand Siècle project) are not in this repo.
`data/editions/*.xml` (16 MB, prepared TEI) is gitignored and regenerated from them:

* `uv sync --locked`, then `uv run --locked pyscripts/import_data.py --src /path/to/grand-siecle-max-statique/data`
  (default: `$GS_SOURCE_DATA`, then `../grand-siecle-max-statique/data`) — writes
  `data/editions/` (5 TEI, one `pb` per printed page, `sourceDoc` removed) and
  `data/indices/` (persons, places, orgs, works cited by the 5 texts)
* run `ant` — one HTML page per printed page (`html/{ID}-page-{n}.html`), 888 in total
* search (optional): `TYPESENSE_API_KEY=<admin key> uv run pyscripts/make_ts_index.py` — one
  Typesense document per printed page, plus a search-only key written to
  `html/js/search-config.js` (gitignored); settings `TYPESENSE_HOST/PORT/PROTOCOL/COLLECTION`,
  and `TYPESENSE_PUBLIC_HOST/PORT/PROTOCOL` for the address seen by the browser
* or all at once: `TYPESENSE_API_KEY=... ./build.sh [--src ...]` (import, ant, index, link check);
  without `TYPESENSE_API_KEY` the index step is skipped and `search.html` says so
* tests: `node tools/test-search.mjs http://localhost:8000` (index size, a known query,
  search page without JavaScript error, message when the server is down);
  `node tools/compare-search.mjs <dseBase> <maxBase>` plays the same queries on this site and on
  the MaX/Pagefind site
* `uv run pyscripts/check_links.py html` — checks internal links

Differences from the template: no ACDH imprint download (`data/imprint.xml` is local),
no NoSketchEngine page; the search page uses a Typesense server of our own (local in the demo).

## start dev server

* `cd html/`
* `uv run -m http.server`
* go to [http://0.0.0.0:8000/](http://0.0.0.0:8000/)

## publication

This is a local, non public demo: the source data are not in this repository and the
GitHub Pages workflow of the template is disabled (`.github/workflows/build.yml`, `if: false`).

## screenshots

* `npm install` (installs playwright 1.61.1, which matches the Chromium headless shell
  revision 1228 cached in `~/.cache/ms-playwright`)
* `node tools/screenshots.mjs <outDir> name=http://localhost:8000/toc.html [...] [--full]`

## Python scripting
The project uses [uv](https://docs.astral.sh/uv/), as Python package and project manager.


## dockerize your application

* To build the image run: `docker build -f docker/Dockerfile -t grand-siecle-dse .`
* To run the container: `docker run -p 80:80 --rm --name grand-siecle-dse grand-siecle-dse`

## Licenses

This project is released under the [MIT License](LICENSE)

### third-party JavaScript libraries
The code for all third-party JavaScript libraries used is included in the `html/vendor` folder, their respective licenses can be found either in a `LICENSE.txt` file or directly in the header of the `.js` file

### SAXON-HE
The projects also includes Saxon-HE, which is licensed separately under the Mozilla Public License, Version 2.0 (MPL 2.0). See the dedicated [LICENSE.txt](saxon/notices/LICENSE.txt)

