// Draw a weapon GLB next to its part-for-part rebuild, to check the conversion by eye.
//
//   python3 tools/weapons/convert_glb.py <weapon.glb> <out.json> --preview /tmp/prev.json
//   node tools/weapons/preview.mjs /tmp/prev.json /tmp/out.png [side|top|front|three]
//
// Left: the authored GLB. Right: only the rebuilt Blocks, Cylinders, Balls and Wedges.
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

// Playwright is installed once, for the map previewer.
const { chromium } = createRequire(import.meta.url)('../mapview/node_modules/playwright');

const here = path.dirname(fileURLToPath(import.meta.url));
const [jsonPath, outPath, view = 'three'] = process.argv.slice(2);
const spec = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
const three = path.join(here, '..', 'mapview', 'three');

const html = `<!doctype html><html><body style="margin:0;background:#9aa3ad">
<script type="importmap">{ "imports": { "three": "file://${three}/build/three.module.js",
  "three/addons/": "file://${three}/examples/jsm/" } }</script>
<script>window.SPEC = ${JSON.stringify(spec)}; window.VIEW = ${JSON.stringify(view)};</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
const W = 1280, H = 640;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.setScissorTest(true);
document.body.appendChild(renderer.domElement);
function scene() {
  const s = new THREE.Scene();
  s.background = new THREE.Color(0x9aa3ad);
  s.add(new THREE.HemisphereLight(0xffffff, 0x445566, 2.2));
  const key = new THREE.DirectionalLight(0xffffff, 2.5); key.position.set(1, 2, 1.5); s.add(key);
  const rim = new THREE.DirectionalLight(0xffffff, 1.2); rim.position.set(-1.5, 0.5, -1); s.add(rim);
  return s;
}
// Without a GLB (a Tool exported from the built place), both halves show the parts: the left
// from the side, the right from the chosen angle.
let original;
if (SPEC.glb) {
  const bytes = await (await fetch('file://' + SPEC.glb)).arrayBuffer();
  const gltf = await new Promise((ok, no) => new GLTFLoader().parse(bytes, '', ok, no));
  original = gltf.scene;
} else {
  original = new THREE.Group();
}
const rebuilt = new THREE.Group();
function wedgeGeometry(sx, sy, sz) {
  // Roblox wedge: full bottom, vertical back face (+Z), slope rising from front-bottom.
  const shape = new THREE.Shape();
  shape.moveTo(-sz / 2, -sy / 2);
  shape.lineTo(sz / 2, -sy / 2);
  shape.lineTo(sz / 2, sy / 2);
  shape.lineTo(-sz / 2, -sy / 2);
  const g = new THREE.ExtrudeGeometry(shape, { depth: sx, bevelEnabled: false });
  g.translate(0, 0, -sx / 2);
  g.rotateY(-Math.PI / 2);
  return g;
}
for (const p of SPEC.parts) {
  let geo;
  if (p.shape === 'Cylinder') {
    geo = new THREE.CylinderGeometry(p.size[1] / 2, p.size[1] / 2, p.size[0], 24);
    geo.rotateZ(-Math.PI / 2);
  } else if (p.shape === 'Ball') {
    geo = new THREE.SphereGeometry(p.size[0] / 2, 16, 12);
  } else if (p.shape === 'Wedge') {
    geo = wedgeGeometry(p.size[0], p.size[1], p.size[2]);
  } else {
    geo = new THREE.BoxGeometry(p.size[0], p.size[1], p.size[2]);
  }
  const mat = new THREE.MeshStandardMaterial({
    color: new THREE.Color(p.colour[0], p.colour[1], p.colour[2]),
    metalness: p.material === 'Metal' ? 0.6 : 0.1, roughness: 0.45,
    transparent: p.transparency > 0, opacity: 1 - p.transparency,
    emissive: p.material === 'Neon' ? new THREE.Color(p.colour[0], p.colour[1], p.colour[2]) : new THREE.Color(0),
  });
  const mesh = new THREE.Mesh(geo, mat);
  const ax = p.axes;
  const m = new THREE.Matrix4().makeBasis(
    new THREE.Vector3(ax[0][0], ax[1][0], ax[2][0]),
    new THREE.Vector3(ax[0][1], ax[1][1], ax[2][1]),
    new THREE.Vector3(ax[0][2], ax[1][2], ax[2][2]));
  m.setPosition(p.centre[0], p.centre[1], p.centre[2]);
  mesh.matrixAutoUpdate = false;
  mesh.matrix.copy(m);
  rebuilt.add(mesh);
}
if (!SPEC.glb) original.add(rebuilt.clone(true));
const left = scene(); left.add(original);
const right = scene(); right.add(rebuilt);
left.updateMatrixWorld(true);
right.updateMatrixWorld(true);
const box = new THREE.Box3().setFromObject(SPEC.glb ? original : rebuilt);
const centre = box.getCenter(new THREE.Vector3());
const gun = box.getSize(new THREE.Vector3()).length();
const dirs = { three: [-0.35, 0.45, 1], side: [0, 0.02, 1], top: [0, 1, 0.02], front: [1, 0.15, 0.3], back: [-1, 0.2, -0.4], tool: [1, 0.45, 0.35] };
const dist = gun * 1.35;
const cam = new THREE.PerspectiveCamera(35, (W / 2) / H, 0.001, 100);
cam.position.copy(centre).add(new THREE.Vector3(...(dirs[VIEW] || dirs.three)).normalize().multiplyScalar(dist));
cam.lookAt(centre);
console.log('frame', JSON.stringify(centre), gun);
// A Tool from the place is in Handle space (bore -Z), so its side is +X; the GLB's is +Z.
const sideCam = cam.clone();
sideCam.position.copy(centre).add(new THREE.Vector3(...(SPEC.glb ? [0, 0.02, 1] : [1, 0.02, 0])).normalize().multiplyScalar(dist));
sideCam.lookAt(centre);
for (const [x, s, c] of [[0, left, SPEC.glb ? cam : sideCam], [W / 2, right, cam]]) {
  renderer.setViewport(x, 0, W / 2, H);
  renderer.setScissor(x, 0, W / 2, H);
  renderer.render(s, c);
}
window.DONE = true;
</script></body></html>`;

const page_path = path.join(here, '_preview.html');
fs.writeFileSync(page_path, html);
const browser = await chromium.launch({
  executablePath: process.env.CHROMIUM || undefined,
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files'],
});
const page = await browser.newPage({ viewport: { width: 1280, height: 640 } });
page.on('pageerror', (e) => console.error('page error:', e.message));
page.on('console', (m) => console.error(m.text()));
await page.goto('file://' + page_path);
await page.waitForFunction(() => window.DONE === true, null, { timeout: 60000 });
await page.locator('canvas').screenshot({ path: outPath });
console.log('wrote', outPath);
await browser.close();
fs.unlinkSync(page_path);
