# Project Zee

## Play the upgraded build

1. Download **`build/Game.rbxl`** from this branch (click the file on GitHub, then the download button).
2. In Roblox Studio: **File → Open from File…** and pick `Game.rbxl`.
3. Press **Play**.

To put it live, publish from that file with **File → Publish to Roblox As…** and choose your
existing experience. Keep a copy of your current place first; `place/base.rbxl` is the original
as uploaded.

### Is this the latest build?

The title screen (bottom-right corner) and the owner panel (F4, top-right) both show a
**BUILD** date and time, and the server prints it first thing in the Output window. If it does
not match the newest commit on this branch, you are playing an older copy of the file:
download `build/Game.rbxl` again.

### Saving while testing in Studio

A place opened with **Open from File** has never been published, so Roblox gives it no
DataStores at all: levels, coins, prestige and unlocks work during the test but are gone when
you press Stop, whatever the game does. To test saving:

1. **File → Publish to Roblox As…** your experience (keep a copy of your current place first).
2. **Game Settings → Security → Enable Studio Access to API Services** → on.
3. Play again. The owner panel's strip shows **● SAVING TO THE PROFILE** in green when it is
   really saving, and the Output window says `[Data] saving to DataStores`. If it says
   **NOT SAVING**, one of the two steps above is missing.

The live game always saves.

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
| **H** | Achievements: claim rewards and pick the title you wear |
| **T** | Travel: jump to the Crossing, Downtown, the Flats, the Mine, the Watchpoint or the Reach (not while under fire or in a duel) |
| **E** (hold) | Open a supply drop |
| **F1** | Settings: volumes, camera shake, field of view, crosshair colour |
| **Right mouse** | Aim; with the Longshot (or a strong scope) you look through the scope |
| **V** | Go to (or leave) the gun range |
| **Shift** or double-tap **W** | Sprint; **Ctrl** / **C** while sprinting slides |
| Hold **F** | Aim the selected throwable (an arc shows where it lands); let go to throw |
| **X** | Switch throwable: Frag (from level 3), Flashbang (level 7), Smoke |
| **Z** | Medkit: patch up 50 health over a second |
| **G** (hold) | Emote wheel: scroll or click the tabs for five pages of emotes, 1-8 to pick |

You can also queue by standing on one of the glowing **1V1 pads** near the spawn.

## Utility and armour

Every life (and every duel round) starts with a fresh kit: smoke and two medkits from the
start, two frags from level 3, two flashbangs from level 7. Frags hurt anyone close, less
through walls, and you take half of your own. A flashbang whites out the screen of anyone
looking at it and blinds enemies for a few seconds (they stop seeing you and their aim goes).
Enemies cannot see through smoke. The cyan bar over your health is armour: it soaks hits
before your health does. Enemies drop armour plates (walk over them), and a duel gives both
fighters 50 armour every round.

## Streaks and bounties

Out in the world, kills without dying build a streak: **KILLING SPREE** at 3, and at 5 you
are **WANTED** -- everyone is told, a red tag with your price floats over you through walls,
and the price climbs with every kill after (up to $4,000). Whoever takes a wanted player down
collects the bounty and XP, and the server hears about it. Duels and practice dummies do not
count.

## Downtown

Open **Travel** (T) and pick **Downtown**, a painted low-poly city district built block by
block, with no neon anywhere: an avenue from the welcome wall to **ZEE TOWER**, **ZEE PLAZA**
with its three-tier fountain, planted corners and finger post, **ZEE GUNS** and the **ARMORY**
(walk up and press E to shop or customise), **ZEE GAS** and the **24/7** with the
**CONTRACTS** board, the **DUEL HALL** (a blue-and-orange sports hall with its own 1v1 pads),
a basketball court, a hedged pocket park, blossom trees, lanterns with flower baskets, parked
cars and a skyline all round. Climb the fire escape on the apartments for a **rooftop stash**
(once a day). Supply drops land in its streets too.

**Turf war**: every few minutes while players are downtown, a crew (three Bandits, a Soldier
and a Brute lieutenant) rolls in from one of the district's edges. Drive them out within four
minutes and everyone who landed a hit is paid, with a bonus for the MVP.

## Contracts and supply drops

- **Daily contracts**: three jobs a day (one easy, one medium, one hard), the same set on every
  server, from headshots and wallbangs to duel wins, long-range kills, Warlords and supply drops.
  Each pays cash, XP and crystals the moment it is done, and finishing all three pays a bonus.
  Progress pops up on the left; practice dummies do not count.
- **Supply drops**: every four minutes a crate parachutes into one of the open zones under a
  pillar of light, with a marker and distance on your screen. First to hold E on it keeps the
  cash, crystals and XP inside; about one in eight is a golden Elite drop worth double.

## Title screen

Joining opens on a title screen once per session: the camera flies over Downtown, the Flats,
a duel map and the harbour behind the PROJECT ZEE logo, with your card (level, title, money)
and what is new. **PLAY** (or Space / Enter) drops you in; the **1V1 DUEL**, **DOWNTOWN** and
**THE FLATS** shortcuts drop you straight into the queue or onto that place.

## Achievements

25 long-term goals in four groups -- Combat, Duels, World, Progress -- from First Blood to
Legend (1,000 takedowns), Champion (50 duel wins), Explorer (all six places), Warlord Slayer,
Street Defender (turf wars) and Completionist. They count themselves from what the server
already decides; an unlock pops a banner and a badge on the Awards tile, and the reward
(cash, XP, crystals, often a **title**) is claimed in the panel (H), where you also choose
the title you wear. `lune run tools/uitest/achievements.luau` checks the list and the counting.

## The Flats battleground

The stone courtyard between Map 2's four pillars is where the raiders and the town guard
fight it out, and it is built for it now rather than scattered with blocks:

- **Raider camp** (west): a palisade of sharpened logs with a gate at the back (the Warlord
  waits outside it), tents, a campfire, supply piles and log barricades.
- **Guard post** (east): a crenellated stone wall with a gap, a watchtower you can climb by
  its ramp, and a pavilion.
- **The gatehouse** (centre): a ruined gateway across the line of fire. The doorway is the
  short, exposed way through; round the broken walls is the long way.
- **The walls** (north): overgrown low walls and a fallen tree, the fast flank.
- **The terrace** (south): the high ground over the open middle, climbed from the far side.

Six raiders hold the camp (down from eight). `lune run tools/uitest/flats.luau` checks every
post has room, the ways through are open and the high ground can be reached.

## Enemies

Enemies fight like a squad, not a row of turrets:

- **They talk.** A "?" pops over one that heard something and is coming to look, a "!" when
  it has seen you, and speech bubbles as the fight goes: *Contact!*, *Reloading!*,
  *Flanking!*, *Man down!*, *Lost visual.* Soldiers, Bandits, Guards and Brutes each have
  their own voice.
- **Grenades.** Duck behind a wall, or camp one spot, and a Soldier or Elite lobs a grenade
  at you ("Frag out!"). It flies on a real arc, lands, blinks and beeps faster and faster,
  and a red marker plus a **GRENADE -- MOVE!** warning shows while you are in the blast.
  Damage falls off with distance and a wall between you takes most of it.
- **Suppression.** Rounds cracking past an enemy's head throw its aim off and send it
  looking for cover.
- **Patching up.** Hurt and out of your sight, a Soldier, Elite, Marksman or Guard stops to
  bandage itself (a green bar over its head). Hit it again and the bandage is cancelled:
  that is your moment to push.
- **Strafing.** Holding its ground in a gunfight, an enemy sidesteps between bursts.
- **Fewer, slower respawns.** Camps refill after 50 seconds to 3 minutes rather than 12, never
  within 45 studs of a player, and at most 24 enemies are alive on a server.

## Gun handling

- **Moving and jumping** open your cone; aiming steadies part of that (a scoped sniper on the
  move still throws rounds wide). The crosshair shows exactly the cone the server fires.
- **First-shot accuracy**: a weapon rested for a moment fires its first round tighter. Tap for
  precision, spray for volume. Snipers only get it scoped.
- **Tactical reloads**: reloading with a round still chambered takes 75% of the time.
- **Wallbangs**: rifles and snipers put rounds through thin cover (glass, planks, crates) for
  reduced damage; hitting someone that way calls WALLBANG. Concrete stops everything.
- The armory card shows Mobility, Penetration and both reload times for each weapon.
- **Tracers leave the barrel you see.** Rounds are fired from the muzzle as your screen draws
  it (the server checks it is close to you and not through a wall), and every client draws
  every tracer from the gun as it sees it. A tracer is a hot streak that flies at its class's
  speed -- pistols visibly travel, a sniper's round cracks across and leaves a vapour line --
  and the impact lands when the round does. A fitted suppressor fires from the end of the can.
- **Dark Matter headshots** play the gem-charge effect (assets/vfx/gemstoneCharge.rbxm) on the
  head that was hit, for everyone. Any .rbxm dropped into assets/vfx is imported into
  ReplicatedStorage.VFX on build; `lune run tools/uitest/tracers.luau` checks all of this.

## Movement animations

Characters move with the uploaded clips (assets/animations: Idle, Run, WalkLeft, WalkRight,
WalkBackward). They were authored on R6; `lune run tools/anims/locomotion.luau` carries them to
this game's R15 body -- rotations re-expressed per joint, the torso re-rooted, and knees solved
so each foot lands where the R6 foot did (and never through the floor). The game plays them
itself (LocomotionAnimator), so nothing needs publishing:

- Direction picks the clip -- forward runs, back backpedals, sideways strafes, diagonals mix --
  and each plays at the speed your feet are covering ground. Standing still breathes the arms.
- With a gun out the torso stays upright and square to your aim; the hips still turn into a
  strafe and the legs keep running. Jumps, falls, seats and emotes hand the body back.
- Everyone sees everyone move this way, from their velocity; no network traffic.
- `lune run tools/anims/render.luau -- out.json` renders every clip; `tools/uitest/locomotion.luau`
  checks the carry-over, the mix and the hand-offs.

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
README. `tactics.luau` checks the enemy grenades, patching up, suppression and callouts. Run it after any UI change: it catches the kind of error that stops a menu script
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
