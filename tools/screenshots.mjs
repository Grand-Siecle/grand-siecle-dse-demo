#!/usr/bin/env node
/**
 * Take screenshots of pages at desktop (1440x900) and mobile (390x844) sizes.
 *
 * Usage:
 *   node tools/screenshots.mjs <outDir> <name>=<url> [<name>=<url> ...] [--full]
 * Writes <outDir>/<name>-desktop.png and <outDir>/<name>-mobile.png.
 * --full captures the whole page instead of the first screen.
 *
 * Requires `npm i -D playwright` (Chromium headless shell from ~/.cache/ms-playwright).
 */
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';

const args = process.argv.slice(2);
const fullPage = args.includes('--full');
const [outDir, ...targets] = args.filter((a) => a !== '--full');
if (!outDir || targets.length === 0) {
  console.error('usage: node tools/screenshots.mjs <outDir> <name>=<url> ... [--full]');
  process.exit(2);
}
fs.mkdirSync(outDir, { recursive: true });

const VIEWPORTS = {
  desktop: { width: 1440, height: 900 },
  mobile: { width: 390, height: 844 },
};

const browser = await chromium.launch();
let failed = 0;
for (const target of targets) {
  const i = target.indexOf('=');
  const name = target.slice(0, i);
  const url = target.slice(i + 1);
  for (const [label, viewport] of Object.entries(VIEWPORTS)) {
    const page = await browser.newPage({ viewport, deviceScaleFactor: 1 });
    try {
      await page.goto(url, { waitUntil: 'load', timeout: 60000 });
      // let lazy IIIF images and web fonts settle
      await page.waitForLoadState('networkidle', { timeout: 20000 }).catch(() => {});
      // IIIF images from Gallica can be slow: wait (max 30 s) for the images in view
      await page.waitForFunction(() => Array.from(document.images)
        .filter((i) => i.getBoundingClientRect().top < window.innerHeight)
        .every((i) => i.complete), null, { timeout: 30000 }).catch(() => {});
      const file = path.join(outDir, `${name}-${label}.png`);
      await page.screenshot({ path: file, fullPage });
      console.log(`ok   ${file}`);
    } catch (err) {
      failed += 1;
      console.error(`FAIL ${name} ${label}: ${err.message}`);
    } finally {
      await page.close();
    }
  }
}
await browser.close();
process.exit(failed ? 1 : 0);
