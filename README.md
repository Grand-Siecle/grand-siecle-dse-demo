# Grand Siècle — démo DSE static


* build with [DSE-Static-Cookiecutter](https://github.com/acdh-oeaw/dse-static-cookiecutter)


## initial (one time) setup

The source data (raw TEI + registers of the Grand Siècle project) are not in this repo.
`data/editions/*.xml` (16 MB, prepared TEI) is gitignored and regenerated from them:

* `uv run pyscripts/import_data.py --src /path/to/grand-siecle-max-statique/data`
  (default: `$GS_SOURCE_DATA`, then `../grand-siecle-max-statique/data`) — writes
  `data/editions/` (5 TEI, one `pb` per printed page, `sourceDoc` removed) and
  `data/indices/` (persons, places, orgs, works cited by the 5 texts)
* run `ant` — one HTML page per printed page (`html/{ID}-page-{n}.html`), 888 in total
* `uv run pyscripts/check_links.py html` — checks internal links

Differences from the template: no ACDH imprint download (`data/imprint.xml` is local),
no Typesense search page, no NoSketchEngine page.

## set up GitHub repo
* create a public, new, and empty (without README, .gitignore, license) GitHub repo https://github.com/Grand-Siecle/grand-siecle-dse 
* run `git init` in the root folder of your application grand-siecle-dse
* execute the commands described under `…or push an existing repository from the command line` in your new created GitHub repo https://github.com/Grand-Siecle/grand-siecle-dse

## start dev server

* `cd html/`
* `uv run -m http.server`
* go to [http://0.0.0.0:8000/](http://0.0.0.0:8000/)

## publish as GitHub Page

* go to https://https://github.com/Grand-Siecle/grand-siecle-dse/actions/workflows/build.yml
* click the `Run workflow` button

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

