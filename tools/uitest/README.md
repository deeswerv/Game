# UI test harness

Runs the game's client interface outside Roblox, under [Lune](https://github.com/lune-org/lune),
to catch what would break it in Studio -- and renders it so it can be looked at.

- `runtime.luau` -- instances backed by Roblox's reflection database: an unknown member, a
  read-only property or a wrong-typed value errors exactly as it does in the engine. Signals,
  tweens, remotes and attributes are simulated.
- `world.luau` -- services, a local player with a character, the place's ReplicatedStorage and
  StarterPlayer (read from `build/Game.rbxl`), `require`, key presses, clicks and a clock.
- `fixtures.luau` -- what the server would answer, in the shapes the real services return.
- `smoke.luau` -- builds the UI, opens and closes every menu, clicks the "+" and holds Tab;
  fails on any error, including a `WaitForChild` that would yield forever.
- `gallery.luau` + `snapshot.luau` + `render.html` + `shoot.mjs` -- snapshots every screen and
  renders it with Chromium. Images and 3D previews are placeholders.

```sh
lune run tools/build.luau
lune run tools/uitest/smoke.luau                    # everything up
lune run tools/uitest/smoke.luau -- drop=PromptPurchase   # a server service failed to start
lune run tools/uitest/gallery.luau -- out/ui && node tools/uitest/shoot.mjs out/ui out/ui/*.json
```

## Game-rule suites

Each checks one system end to end and exits non-zero on a failure:
`arenas`, `guns`, `contracts`, `district`, `flats`, `achievements`, `tactics`, `headlook`, `utility`, `progression`
(levels, prestige, coins and the owner panel's commands) and `emotes`
(the emote pack: the converted tracks against the pack's own keyframes, the server's
attributes, the client posing a real rig, the props and the paged wheel).

```sh
lune run tools/uitest/emotes.luau
```

The emote data itself is generated: `lune run tools/emotes/convert.luau` rebuilds
`src/ReplicatedStorage/EmoteData` from `assets/emotes/EmotePack_R15R6.rbxm`, and
`lune run tools/emotes/render.luau -- out.json props` (then `node tools/mapview/shoot.mjs`)
draws the prop emotes on the game's rig to check they fit.
