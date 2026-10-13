---
tags: [dev]
---
# How the repo works

Back to [[Home]].

## Layout
| Path | What it is |
|---|---|
| `place/base.rbxl` | The place exactly as first uploaded. Never edited. |
| `src/` | Every script as a `.luau` file, laid out like the Explorer |
| `tools/patches/` | Changes to non-script instances (lighting, removals, the kit import) |
| `tools/models/` | The Blender kit script ([[Blender City Kit]]) |
| `tools/uitest/` | Automated suites that run the game's own scripts in an emulator |
| `tools/mapview/` | Renders maps to images with three.js (the previews in these notes) |
| `assets/models/` | The kit's GLB/FBX and preview renders |
| `build/Game.rbxl` | base + src + patches: **the file you open in Studio** |
| `notes/` | This vault |

A new `Name.luau` in `src/` becomes a ModuleScript, `.client.luau` a LocalScript, `.server.luau`
a Script, at the matching place in the Explorer.

## Build and test
```sh
lune run tools/build.luau            # writes build/Game.rbxl and compile-checks every script
lune run tools/uitest/hanami.luau    # any suite: hanami, district, meshkit, citymeshes, caralarms...
python tools/models/build_kit.py     # rebuild the Blender kit (needs Blender's bpy)
```

## Working in Studio too
If you change things in Studio, download a fresh copy of the place, replace `place/base.rbxl`
and run `lune run tools/export.luau` so `src/` matches Studio. Otherwise the next build from
`src/` would not have your Studio edits.

## Branch
Work lands on `claude/roblox-gameplay-improvements-itfwjz`.
