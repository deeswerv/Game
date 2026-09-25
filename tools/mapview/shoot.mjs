// Render a map JSON (from arenas.luau / region.luau) to PNGs, one per camera.
//   node tools/mapview/shoot.mjs map.json out-prefix
// Needs three.js in tools/mapview/three (npm i three@0.160 && copy node_modules/three there).
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const [jsonPath, prefix] = process.argv.slice(2);
const json = fs.readFileSync(jsonPath, 'utf8');
const html = fs.readFileSync(path.join(here, 'view.html'), 'utf8')
  .replace('<script type="module">', `<script>window.MAP = ${json};</script><script type="module">`);
const page_path = path.join(here, '_render.html');
fs.writeFileSync(page_path, html);

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
page.on('pageerror', (e) => console.error('page error:', e.message));
await page.goto('file://' + page_path);
await page.waitForFunction(() => window.MAP_READY === true, null, { timeout: 60000 });
const count = await page.evaluate(() => window.renderView(0));
for (let i = 0; i < count; i++) {
  await page.evaluate((n) => window.renderView(n), i);
  const out = `${prefix}_${i}.png`;
  await page.locator('canvas').screenshot({ path: out });
  console.log('wrote', out);
}
await browser.close();
fs.unlinkSync(page_path);
