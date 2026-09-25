// Render snapshot JSON files to PNGs with Chromium.
//   node tools/uitest/shoot.mjs out/dir snap1.json [snap2.json ...]
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const [outDir, ...snaps] = process.argv.slice(2);
fs.mkdirSync(outDir, { recursive: true });
const template = fs.readFileSync(path.join(here, 'render.html'), 'utf8');

const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
for (const snap of snaps) {
  const json = fs.readFileSync(snap, 'utf8');
  const html = template.replace('<script>', `<script>window.SNAPSHOT = ${json};</script><script>`);
  const tmp = path.join(outDir, path.basename(snap, '.json') + '.html');
  fs.writeFileSync(tmp, html);
  await page.goto('file://' + path.resolve(tmp));
  await page.waitForFunction(() => document.body.dataset.ready === '1', null, { timeout: 20000 }).catch(() => {});
  const png = path.join(outDir, path.basename(snap, '.json') + '.png');
  await page.locator('#stage').screenshot({ path: png });
  console.log('wrote', png);
}
await browser.close();
