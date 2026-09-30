#!/usr/bin/env node
/**
 * Play the same queries on two search pages and measure what the browser sees:
 *   - DSE demo (Typesense + instantsearch): <dseBase>/search.html
 *   - MaX static site (Pagefind UI):        <maxBase>/search.html
 * For each query: result count, first result, perceived time (from typing to the result
 * count being displayed, measured in the page with performance.now()), bytes received for
 * the query (Typesense JSON responses / Pagefind index files), plus Typesense's search_time_ms
 * and network round trip measured with a direct call using the search-only key.
 *
 * Usage: node tools/compare-search.mjs [dseBase] [maxBase] [outJson] [screenshotDir]
 * Defaults: http://localhost:8898  http://localhost:8899/grand-siecle
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const [dseBase = 'http://localhost:8898', maxBase = 'http://localhost:8899/grand-siecle',
  outJson = '', shotDir = ''] = process.argv.slice(2);

export const QUERIES = [
  'éloquence', 'eloquence', 'sçavoir', 'savoir', 'estre', 'être',
  'Cicéron', 'Cicéorn', 'Rome', 'Polonia', 'langue françoise',
];

const config = JSON.parse(fs.readFileSync('html/js/search-config.js', 'utf8')
  .replace(/^[\s\S]*?=\s*/, '').replace(/;\s*$/, ''));

async function typesenseDirect(q) {
  const node = config.nodes[0];
  const url = `${node.protocol}://${node.host}:${node.port}/collections/${config.collection}/documents/search?` +
    new URLSearchParams({ q, query_by: 'text_mod,text_orig,lemmas', query_by_weights: '4,3,1',
      sort_by: '_text_match:desc,page_n:asc', per_page: '10', exclude_fields: 'lemmas' });
  const t0 = performance.now();
  const res = await fetch(url, { headers: { 'X-TYPESENSE-API-KEY': config.apiKey } });
  const body = await res.json();
  return { found: body.found, first: body.hits[0]?.document.id ?? null,
    search_time_ms: body.search_time_ms, roundtrip_ms: Math.round(performance.now() - t0) };
}

// counted on the browser context, so that requests made by Web Workers (Pagefind) are included;
// engine files (Pagefind wasm, loader, metadata) are counted apart from per-query index data
const ENGINE = /pagefind\.js$|wasm\.[a-z]+\.pagefind$|\.pf_meta$|pagefind-entry\.json|pagefind-worker\.js$/;
function counter(context, match) {
  const state = { bytes: 0, requests: 0, engine: 0 };
  context.on('requestfinished', async (req) => {
    const url = req.url().split('?')[0];
    if (!match(url)) return;
    const sizes = await req.sizes().catch(() => null);
    if (!sizes) return;
    if (ENGINE.test(url)) { state.engine += sizes.responseBodySize; return; }
    state.bytes += sizes.responseBodySize; state.requests += 1;
  });
  return state;
}

async function runSite(browser, site) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await context.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  const net = counter(context, site.match);
  await page.goto(site.url, { waitUntil: 'load' });
  await page.waitForSelector(site.input, { timeout: 30000 });
  await page.waitForLoadState('networkidle').catch(() => {});
  const init = { bytes: net.bytes, requests: net.requests };
  const rows = [];
  for (const q of QUERIES) {
    await page.fill(site.input, '');
    await page.waitForTimeout(800);
    await page.waitForLoadState('networkidle').catch(() => {});
    const before = { bytes: net.bytes, requests: net.requests };
    const ms = await page.evaluate(({ sel, q, done }) => new Promise((resolve) => {
      const input = document.querySelector(sel);
      const previous = (document.querySelector(done.sel) || {}).textContent || '';
      const t0 = performance.now();
      const check = () => {
        const txt = (document.querySelector(done.sel) || {}).textContent || '';
        // the displayed count must have been refreshed (not the text left by the previous state)
        if (txt !== previous && new RegExp(done.re, 'i').test(txt) && (!done.needsQuery || txt.includes(q))) {
          resolve(Math.round(performance.now() - t0));
        } else if (performance.now() - t0 > 20000) resolve(null);
        else requestAnimationFrame(check);
      };
      input.value = q;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      requestAnimationFrame(check);
    }), { sel: site.input, q, done: site.done });
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.waitForTimeout(300);
    const res = await page.evaluate(site.read);
    rows.push({ q, perceived_ms: ms, bytes: net.bytes - before.bytes, requests: net.requests - before.requests, ...res });
    if (shotDir && site.shot && site.shot.includes(q)) {
      await page.screenshot({ path: path.join(shotDir, `${site.name}-search-${q.normalize('NFD').replace(/[^\w]+/g, '')}-desktop.png`) });
    }
  }
  const facets = await page.evaluate(site.facets);
  await context.close();
  return { init, engine_bytes: net.engine, rows, facets, errors };
}

const browser = await chromium.launch();
const dse = await runSite(browser, {
  name: 'dse',
  url: `${dseBase}/search.html`,
  match: (u) => u.includes(':' + config.nodes[0].port + '/'),
  input: '#searchbox input',
  done: { sel: '#stats', re: 'trouvée|Aucune', needsQuery: false },
  read: () => ({
    count: (document.querySelector('#stats').textContent.match(/^([\d\s ]+)/) || ['', '0'])[1].replace(/\D/g, '') || '0',
    first: document.querySelector('.gs-hit-title a')?.getAttribute('href') ?? null,
  }),
  facets: () => Array.from(document.querySelectorAll('.gs-facet-title')).map((h) => h.textContent.trim()),
  shot: ['éloquence', 'sçavoir', 'Cicéorn'],
});
const max = await runSite(browser, {
  name: 'max',
  url: `${maxBase}/search.html`,
  match: (u) => u.includes('/pagefind/') && !/pagefind-(ui|component-ui|modular-ui|highlight)\.(js|css)$/.test(u),
  input: '.pagefind-ui__search-input',
  done: { sel: '.pagefind-ui__message', re: 'résultat', needsQuery: true },
  read: () => ({
    count: ((document.querySelector('.pagefind-ui__message') || {}).textContent || '').match(/^(\d+)/)?.[1] ?? '0',
    first: document.querySelector('.pagefind-ui__result-link')?.getAttribute('href') ?? null,
  }),
  facets: () => Array.from(document.querySelectorAll('.pagefind-ui__filter-name, .pagefind-ui__filter-block summary'))
    .map((h) => h.textContent.trim()),
  shot: ['éloquence', 'sçavoir', 'Cicéorn'],
});
await browser.close();

const direct = [];
for (const q of QUERIES) direct.push({ q, ...(await typesenseDirect(q)) });

const report = { date: new Date().toISOString(), dse, max, typesense_direct: direct };
if (outJson) fs.writeFileSync(outJson, JSON.stringify(report, null, 1));
console.log('query | DSE count | DSE first | DSE ms | DSE bytes | TS found | TS first | TS search_time_ms | TS roundtrip ms | MaX count | MaX first | MaX ms | MaX bytes');
QUERIES.forEach((q, i) => {
  const d = dse.rows[i], m = max.rows[i], t = direct[i];
  console.log([q, d.count, d.first, d.perceived_ms, d.bytes, t.found, t.first, t.search_time_ms, t.roundtrip_ms, m.count, m.first, m.perceived_ms, m.bytes].join(' | '));
});
console.log('init bytes: DSE', dse.init, 'MaX', max.init, '| engine bytes (Pagefind wasm/loader/meta):', max.engine_bytes);
console.log('facets: DSE', dse.facets, '| MaX', max.facets);
console.log('errors: DSE', dse.errors, '| MaX', max.errors);
