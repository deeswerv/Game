# Project Zee

## Play the upgraded build

1. Download **`build/Game.rbxl`** from this branch (click the file on GitHub, then the download button).
2. In Roblox Studio: **File → Open from File…** and pick `Game.rbxl`.
3. Press **Play**.

To put it live, publish from that file with **File → Publish to Roblox As…** and choose your
existing experience. Keep a copy of your current place first; `place/base.rbxl` is the original
as uploaded.

## Controls

| Key | Does |
| --- | --- |
| Hold **Alt** | Free the mouse to click buttons (PLAY, the side menu) without leaving shift lock |
| **J** | Queue for a duel, or cancel the queue (same as clicking PLAY) |
| Hold **Tab** | Player board: levels, ranks, kills, deaths, who is dueling |
| **B / M / K / P / N** | Items, Shop, Armory, Profile, Daily reward |
| **O** | Quest journal |
| **L** | Daily contracts |
| **Y** (or click the level diamond) | Level road: what every level unlocks, and what is next |
| **E** (hold) | Open a supply drop |
| **F1** | Settings: volumes, camera shake, field of view, crosshair colour |
| **Right mouse** | Aim; with the Longshot (or a strong scope) you look through the scope |
| **V** | Go to (or leave) the gun range |
| **Shift** or double-tap **W** | Sprint; **Ctrl** / **C** while sprinting slides |

You can also queue by standing on one of the glowing **1V1 pads** near the spawn.

## Streaks and bounties

Out in the world, kills without dying build a streak: **KILLING SPREE** at 3, and at 5 you
are **WANTED** -- everyone is told, a red tag with your price floats over you through walls,
and the price climbs with every kill after (up to $4,000). Whoever takes a wanted player down
collects the bounty and XP, and the server hears about it. Duels and practice dummies do not
count.

## Downtown

Take the **pink gate** at the spawn crossing to **Downtown**, a city district built block by
block: an avenue from the gate to **ZEE TOWER**, **ZEE PLAZA** with its fountain and screen
tower, **ZEE GUNS** and the **ARMORY** (walk up and press E to shop or customise), **ZEE GAS**
and the **24/7** with the **CONTRACTS** board, the **DUEL HALL** with its own 1v1 pads, a
basketball court, a pocket park, parked cars, street lamps and a skyline all round. Climb the
fire escape on the apartments for a **rooftop stash** (once a day). Supply drops land in its
streets too.

## Contracts and supply drops

- **Daily contracts**: three jobs a day (one easy, one medium, one hard), the same set on every
  server, from headshots and wallbangs to duel wins, long-range kills, Warlords and supply drops.
  Each pays cash, XP and crystals the moment it is done, and finishing all three pays a bonus.
  Progress pops up on the left; practice dummies do not count.
- **Supply drops**: every four minutes a crate parachutes into one of the open zones under a
  pillar of light, with a marker and distance on your screen. First to hold E on it keeps the
  cash, crystals and XP inside; about one in eight is a golden Elite drop worth double.

## Gun handling

- **Moving and jumping** open your cone; aiming steadies part of that (a scoped sniper on the
  move still throws rounds wide). The crosshair shows exactly the cone the server fires.
- **First-shot accuracy**: a weapon rested for a moment fires its first round tighter. Tap for
  precision, spray for volume. Snipers only get it scoped.
- **Tactical reloads**: reloading with a round still chambered takes 75% of the time.
- **Wallbangs**: rifles and snipers put rounds through thin cover (glass, planks, crates) for
  reduced damage; hitting someone that way calls WALLBANG. Concrete stops everything.
- The armory card shows Mobility, Penetration and both reload times for each weapon.

## Duel maps

Every duel is fought on one of four maps, and a pair who just played one map gets a different
one next. Two duels at once never share a map. The VS screen names the map.

| Map | Look |
| --- | --- |
| **Neon Court** | Rooftop court at night, magenta and cyan neon, lit skyline |
| **Dockyard** | Container quay at sunset: stacked boxes, a gantry with a hanging container, a ship and cranes across the water |
| **Rooftops** | Tar roof over the city on a clear afternoon: stair huts, water towers, a raised HVAC deck, billboard and mural |
| **Sakura Temple** | Temple courtyard at dusk: gate houses, torii, koi pond with an arched bridge, lanterns, bell tower, pagodas |

Each map is lit its own way while you are in it (time of day, haze, colour grade), and
everything goes back to the world's day/night cycle when you leave. Every map has 180-degree
rotational symmetry, so both spawns see the same thing.

The maps live in `src/ServerScriptService/ArenaService/` (one module per map, plus `Kit`).
`tools/mapview/` renders any of them to PNGs, and `lune run tools/uitest/arenas.luau` checks
every map's spawns, bounds and lighting.

The **"+"** beside your cash opens the Shop.

## Testing without Studio

`tools/uitest/` runs the whole interface under Lune and renders every screen -- see its
README. Run it after any UI change: it catches the kind of error that stops a menu script
half way through (which is what once hid the inventory, shop and side menu).

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
