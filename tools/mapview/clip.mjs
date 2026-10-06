// Render a movement clip (motionclip.luau) to frames and a video.
//   node tools/mapview/clip.mjs clip.json out-dir [every]
// Writes out-dir/f0000.jpg ... and, with FFMPEG set, out-dir/clip.mp4. `every` renders every
// n-th frame only (for a quick contact sheet).
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const [jsonPath, outDir, everyArg] = process.argv.slice(2);
const every = Number(everyArg || 1);
const json = fs.readFileSync(jsonPath, 'utf8');
const clip = JSON.parse(json);
fs.mkdirSync(outDir, { recursive: true });
const html = fs.readFileSync(path.join(here, 'clip.html'), 'utf8')
  .replace('<script type="module">', `<script>window.CLIP = ${json};</script><script type="module">`);
const pagePath = path.join(here, '_clip.html');
fs.writeFileSync(pagePath, html);

const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'],
});
const page = await browser.newPage({ viewport: { width: 960, height: 540 } });
page.on('pageerror', (e) => console.error('page error:', e.message));
await page.goto('file://' + pagePath);
await page.waitForFunction(() => window.CLIP_READY === true, null, { timeout: 60000 });
let n = 0;
for (let i = 0; i < clip.frames.length; i += every) {
  const url = await page.evaluate((k) => window.renderFrame(k), i);
  fs.writeFileSync(path.join(outDir, `f${String(n).padStart(4, '0')}.jpg`), Buffer.from(url.split(',')[1], 'base64'));
  n++;
}
await browser.close();
fs.unlinkSync(pagePath);
console.log(`rendered ${n} frames`);
if (process.env.FFMPEG && every === 1) {
  execFileSync(process.env.FFMPEG, ['-y', '-loglevel', 'error', '-framerate', String(clip.fps), '-i', path.join(outDir, 'f%04d.jpg'),
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '20', path.join(outDir, 'clip.mp4')]);
  console.log('wrote', path.join(outDir, 'clip.mp4'));
}
