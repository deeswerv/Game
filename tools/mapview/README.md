# Map previewer

Builds a duel map in Lune exactly as the server would, and renders it with three.js so a map
can be looked at (and iterated on) without opening Studio.

```sh
lune run tools/build.luau                                   # build/Game.rbxl
lune run tools/mapview/arenas.luau -- Dockyard out/dock.json
node tools/mapview/shoot.mjs out/dock.json out/dock         # out/dock_0.png ... _3.png
```

Cameras: a high overview, each spawn's eye-level view down the map, and a low side view.

One-time setup (three.js is not committed):

```sh
cd tools/mapview
npm i three@0.160 && cp -r node_modules/three three
npm link playwright   # or npm i playwright
```

The render is an approximation (no Future lighting, no terrain), but shapes, materials,
colours, neon glow, lights and sign text all come through, which is what matters for layout.
