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
