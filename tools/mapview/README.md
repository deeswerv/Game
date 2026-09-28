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

## NPC lineup

`npcs.luau` dresses every NPC archetype the way the server does (NPCService/Outfit on the
players' own rig) and stands them in a row, with a few more of each behind wearing other draws
from their palette:

```sh
lune run tools/mapview/npcs.luau -- out/npcs.json                  # every archetype, 3 draws each
lune run tools/mapview/npcs.luau -- out/crew.json Thug,Gangster 5  # just these, 5 draws
node tools/mapview/shoot.mjs out/npcs.json out/npcs                # lineup, 3/4 view, a close-up each
```

The body parts are meshes in the game and boxes here, so judge the clothes and colours rather
than the body's silhouette.
