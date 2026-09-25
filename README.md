# Project Zee

## Play the upgraded build

1. Download **`build/Game.rbxl`** from this branch (click the file on GitHub, then the download button).
2. In Roblox Studio: **File → Open from File…** and pick `Game.rbxl`.
3. Press **Play**.

To put it live, publish from that file with **File → Publish to Roblox As…** and choose your
existing experience. Keep a copy of your current place first; `place/base.rbxl` is the original
as uploaded.

## What is in this repo

| Path | What it is |
| --- | --- |
| `place/base.rbxl` | The place exactly as uploaded. Never edited. |
| `src/` | Every script in the game as a `.luau` file, laid out like the Explorer. |
| `tools/patches/` | Changes to non-script instances (removals, lighting). |
| `build/Game.rbxl` | `base.rbxl` + `src/` + patches: the file you open. |

Scripts are edited in `src/`. A new `.luau` file becomes a new script at the matching place
(`Name.luau` = ModuleScript, `.client.luau` = LocalScript, `.server.luau` = Script); deleting a
file retires that script.

## Rebuilding

Needs [Lune](https://github.com/lune-org/lune) 0.10.5 or newer:

```sh
lune run tools/build.luau    # writes build/Game.rbxl and compile-checks every script
lune run tools/export.luau   # re-exports src/ from place/base.rbxl (overwrites src/)
```

If you keep working in Studio directly, download a fresh copy of the place, replace
`place/base.rbxl` with it and run the export so `src/` matches what is in Studio.
