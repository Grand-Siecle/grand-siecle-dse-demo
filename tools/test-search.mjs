#!/usr/bin/env node
/**
 * Minimal search tests (J3). Needs the index (pyscripts/make_ts_index.py) and the site served.
 *   1. the collection holds 888 page documents (search q=* with the search-only key);
 *   2. a known query returns the right page first (Corfinium -> LIV0019-page-41);
 *   3. search.html loads without JavaScript error and displays results;
 *   4. with the Typesense server unreachable, search.html shows its error message.
 * Usage: node tools/test-search.mjs [siteBase]   (default http://localhost:8000)
 */
import { chromium } from 'playwright';
import fs from 'node:fs';

const base = process.argv[2] || 'http://localhost:8000';
const config = JSON.parse(fs.readFileSync('html/js/search-config.js', 'utf8')
  .replace(/^[\s\S]*?=\s*/, '').replace(/;\s*$/, ''));
const node = config.nodes[0];
const server = `${node.protocol}://${node.host}:${node.port}`;
let failures = 0;
const check = (ok, label, detail = '') => {
  console.log(`${ok ? 'ok  ' : 'FAIL'} ${label}${detail ? ' - ' + detail : ''}`);
  if (!ok) failures += 1;
};

async function search(params) {
  const url = `${server}/collections/${config.collection}/documents/search?` + new URLSearchParams(params);
  const res = await fetch(url, { headers: { 'X-TYPESENSE-API-KEY': config.apiKey } });
  return res.json();
}

const all = await search({ q: '*', query_by: 'text_mod', per_page: '0' });
check(all.found === 888, 'collection holds 888 pages', `found=${all.found}`);
const known = await search({ q: 'Corfinium', query_by: 'text_mod,text_orig', per_page: '3' });
check(known.hits?.[0]?.document.id === 'LIV0019-page-41', 'Corfinium -> LIV0019-page-41', known.hits?.map((h) => h.document.id).join(','));
const admin = await fetch(`${server}/collections`, { headers: { 'X-TYPESENSE-API-KEY': config.apiKey } });
check(admin.status === 401, 'the browser key cannot list collections', `HTTP ${admin.status}`);

const browser = await chromium.launch();
const page = await browser.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(e.message));
page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto(`${base}/search.html`);
await page.waitForSelector('.gs-hit', { timeout: 15000 }).catch(() => {});
check((await page.$$('.gs-hit')).length === 10, 'search.html shows 10 hits on load');
await page.fill('#searchbox input', 'Corfinium');
await page.waitForFunction(() => /^1 page/.test(document.querySelector('#stats')?.textContent || ''), null, { timeout: 10000 }).catch(() => {});
check((await page.getAttribute('.gs-hit-title a', 'href')) === 'LIV0019-page-41.html', 'typed query links to the reading page');
check(errors.length === 0, 'no JavaScript error', errors.join(' | '));

const down = await browser.newPage();
await down.route(`${server}/**`, (route) => route.abort());
await down.goto(`${base}/search.html`);
await down.waitForSelector('#search-error:not([hidden])', { timeout: 15000 }).catch(() => {});
check(await down.isVisible('#search-error'), 'unreachable server -> message', (await down.textContent('#search-error')).slice(0, 80));
await browser.close();
process.exit(failures ? 1 : 0);
