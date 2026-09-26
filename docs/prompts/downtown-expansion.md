# Prompt: expand and upgrade Downtown into a full RPG district

Paste everything below the line into a new Claude Code session on this repository (branch
`claude/roblox-gameplay-improvements-itfwjz`, or a new branch off it). It is written to be read
cold: it says what exists, what to build, the rules to build it by, and how to prove it works.

---

## Goal

Turn **Downtown** from a single four-block city centre into a **large, detailed, living RPG
district** of PROJECT ZEE (a Roblox shooter with RPG progression, styled on Rivals / Hood
Rivals: low-poly, painted, chunky, readable). Make it:

1. **Bigger** -- grow it from about 400 × 400 studs to about 720 × 720, adding new *quarters*
   around the existing core, each with its own look, level band, enemies and things to do.
2. **More advanced and more beautiful** -- a real facade kit, street detail, interiors for key
   buildings, lighting that sells day and night, and zero visual glitches.
3. **A place to play the RPG** -- gang territory, quests, activities, vendors, fast travel and
   turf control that make players *stay* downtown and level there, not just pass through.

Work in phases (below). Build, test, render and commit after every phase. Never break a system
that already works.

## What exists today (read these files first)

- `src/ServerScriptService/DistrictService/Downtown.luau` (~1,330 lines) -- the pure geometry
  builder, `Downtown.Build(parent, centre)`, using `ServerScriptService.ArenaService.Kit`.
  Local coordinates: +Z north, y = 0 road, 0.5 kerb. `HalfWidth = HalfLength = 200`.
  Layout: an avenue south→north (arrival forecourt at z ≈ -172 → ZEE TOWER at the north end),
  a cross street east-west, **ZEE PLAZA** at the crossing (tiled paving, 3-tier fountain, finger
  post), four blocks: **SE** ZEE GUNS + ARMORY storefronts, **SW** ZEE GAS + 24/7 store with the
  CONTRACTS board, **NW** DUEL HALL (1v1 pads), **NE** basketball court + apartments whose fire
  escape climbs to the ROOFTOP STASH. A ring of tall, non-enterable buildings and a skyline
  (about 200-240 out) hides the edge. ~6,000 parts, 40 lights, 34 signs. **No Neon anywhere**
  (a test enforces it): the look is painted low-poly -- soft facades with cream trim, faceted
  trees, striped awnings, lettering on painted boards.
- `src/ServerScriptService/DistrictService.luau` -- places Downtown in the sky at
  `CENTRE = Vector3.new(-155, 1000, 1500)` and wires prompts from `Downtown.Panels`
  (`GunShop → Market`, `Armory → Workshop`, `ContractBoard → Contracts`), the Duel Hall pads
  (`DuelPads`), and the once-a-day ROOFTOP STASH (coins, crystals, XP).
- `src/ServerScriptService/TurfWarService.luau` -- four walk-in patches (`Zones`: THE CAR PARK,
  THE COURTS, THE ALLEY, THE PARK, local offsets + radius). Stepping onto an open patch spawns
  its crew; a finished war puts that patch on a 180 s cooldown; wars on different patches run
  side by side. It has a district-wide **THREAT level I-V**: each defence raises it (bigger crew:
  5 → 10 NPCs, longer clock, payout +25% per level), a loss lowers it. Ground rings and signs
  live in `workspace.TurfZones`. `CENTRE` is duplicated in the file. HUD: `UI/Modules/WorldEvents.luau`.
- `src/ReplicatedStorage/NPCConfig.luau` -- archetypes `Grunt` (Bandit), `Soldier`, `Brute`,
  `Marksman`, `Elite`, `Guard` (Town Guard), `Warlord`; zone table with
  `{ id = "Downtown", minX = -355, maxX = 45, minZ = 1300, maxZ = 1700, level = { 4, 7 } }`
  (only turf crews stand there today). Elite modifiers: Armoured, Veteran, Quick, Deadeye.
- `src/ServerScriptService/NPCService/` -- `NPCService.Spawn(archetype, position, { respawn,
  ignoreCap })`, levelled by zone; `AI/` has perception, cover, navigation.
- `src/ReplicatedStorage/QuestConfig.luau` + `QuestService.luau` -- objective kinds `Kill`,
  `KillPlayer`, `KillElite`, `KillInZone` (by zone id), `Reach` (zone or radius).
- `ReputationService` (tiers Hated → Honoured; shop prices follow town standing),
  `ContractService` (daily contracts; `Note(player, "turf")`, `"stash"` ...), `BountyService`,
  `SupplyDropService` (DOWNTOWN drop centre and radius 150, `maxRise = 3`), `TravelService`
  (Downtown arrival `Vector3.new(-155, 1000.5, 1330)`), `LevelSystem` (XP is paid at
  `GameConfig.Leveling.XP_RATE = 1.5`; display with `GameConfig.ShownXP`), `ShopService` +
  `UI/Modules/Market.luau` (shelves: Guns, Mastery, Attachments, **VFX**, Cash -- hats/backs are
  no longer sold in the shop), `VFXService` / `VFXConfig` (kill effects, tracers).
- `WorldBake.luau` -- Downtown is **not baked** (built fresh at server start from code), so
  changes to the builder are what players see.
- Tools: `tools/mapview/arenas.luau -- src/ServerScriptService/DistrictService/Downtown.luau out.json`
  exports the district; `node tools/mapview/shoot.mjs out.json prefix` renders it (cameras come
  from `Downtown.Preview`); `tools/mapview/audit.luau -- json out.json` finds z-fighting,
  duplicates and floating props; `tools/uitest/district.luau` is the district's test suite
  (part count, no neon, pads, walkable avenue, prompts, fire-escape headroom).
- Build: `lune run tools/build.luau` → `build/Game.rbxl`. Every suite in `tools/uitest/` must pass.

## Hard rules

1. **Keep everything that works working.** The shop, armory and contracts prompts, the Duel
   Hall pads, the stash, supply drops, turf wars, travel arrival, the district test, and every
   other suite. If a test's expectation must change because the design changed, change it on
   purpose and say why in the commit.
2. **One source of truth for the district's size.** Today `CENTRE`/`HALF` are copied into
   TurfWarService, NPCConfig's zone, SupplyDropService, TravelService and the tests. Put the
   bounds on the builder (`Downtown.HalfWidth/HalfLength`, a new `Downtown.Quarters` table) and
   make every other file read them (or a small shared `ReplicatedStorage.DistrictLayout` module
   if the client needs them). Do not leave magic numbers behind.
3. **No visual glitches.** Run the audit on the exported district after every phase. New work
   adds **zero** visible z-fights and **zero** floating props. Use the house layering:
   road 0, paving slab 0.50, tile 0.52, walk strip 0.54, kerb 0.56, decals at least 0.02 above
   what they sit on; details stand **a few hundredths proud** of the face they are fixed to,
   never flush; windows are inset behind their frames, never coplanar with the wall; a cap
   that overhangs stops just under the top it covers (see `tools/patches/060_glitch_fixes.luau`
   and the Downtown kerb/billboard fixes for examples).
4. **Collision is deliberate.** `b:part` collides and stops bullets; `b:decor` is seen, never
   touched (no collision, no raycasts, no shadow). Detail is decor. Anything a player could walk
   into or shoot through must look like what it is. Keep fights readable: cover every 20-30
   studs on combat streets, long sightlines broken, no invisible walls except the district
   bounds.
5. **Art direction** (match what is there): painted low-poly toy town. Soft facade palette
   with cream trim, chunky shapes, bevel-less boxes and wedges, faceted trees, striped awnings,
   painted signs (the `painted()`/`board()` helpers). **No Neon material** -- if a quarter
   needs glow (the Night Market's lanterns), use warm SmoothPlastic plus PointLights, or change
   the district test on purpose and keep glow to that quarter.
6. **Performance budget.** The whole district at most ~16,000 parts and ~120 lights (Shadows
   off except a handful of hero spots). Reuse builder functions; no per-frame scripts on props;
   decor CanQuery off. StreamingEnabled is on: group each quarter under its own Model so it
   streams as a unit; nothing gameplay-critical may depend on a far quarter being streamed in.
7. **Code style:** read like the surrounding code -- comment the *why*, same naming, `--!strict`,
   helpers per prop. Split the builder: `DistrictService/Downtown.luau` keeps the core and
   calls one module per quarter (`DistrictService/Quarters/<Name>.luau`), each exporting
   `Build(b, bounds)` plus its own `Panels`, `Spawns`, `Preview` cameras and `Zone` table.

## The expansion: layout

Keep the existing core ("MIDTOWN": plaza, ZEE TOWER, the four blocks) exactly where it is and
grow outward to `HalfWidth = HalfLength = 360`. Open the ring of tall buildings where the avenue
and the cross street continue, add a **ring road** at about ±230, and fill the band from ±240 to
±340 with quarters. Beyond ±340, a skyline ring (the existing `skyline` approach) so there is
still no visible edge.

Must build (phases 2-3):

| Quarter | Where | Levels | Character |
| --- | --- | --- | --- |
| **NIGHT MARKET** | east | 6-9 | A lantern-strung street under a painted gate arch, food stalls with striped canopies, a noodle bar, an arcade front, strings of paper lanterns (warm lights), crates and delivery bikes. The **VFX BAZAAR** stall here opens the shop on its VFX shelf. Back alleys belong to the **Jade Syndicate**. |
| **RIVERSIDE DOCKS** | north-east | 8-12 | A canal cuts the corner (water plane with a stone embankment, steps down, moored boats), two bridges (one a lifting drawbridge), brick warehouses with loading doors, a fish market hall, stacked containers and a small crane. **Dock Rats** gang turf. |
| **THE PROJECTS** | south-west | 12-16 | Tower blocks round a courtyard, fenced basketball cages, graffiti walls, burnt-out car, washing lines, a boarded-up corner shop. **Redline Crew** HQ: an enterable **hideout** (two floors, stair core, a boss room). |
| **RAIL YARD + ZEE CENTRAL** | south-east | 9-13 | An elevated rail viaduct on piers crossing the quarter, **Zee Central** station (platforms, canopy, ticket hall -- the subway fast-travel hub), freight wagons as cover, signal gantries, a turntable. |

Should build (phase 4, if the budget allows):

| Quarter | Where | Levels | Character |
| --- | --- | --- | --- |
| **FINANCIAL DISTRICT** | north, behind ZEE TOWER | 10-14 | Glass-and-stone towers with an enterable lobby, a sky bridge, **BANK OF ZEE** (columned front, vault -- the heist event). |
| **OLD TOWN** | south, either side of the forecourt | 4-6 | Brick rowhouses with stoops, a clock tower, a small park with a pond and bandstand. The **TAILOR** sells hats and backs (the cosmetics that left the shop). A calm, low-level welcome for arrivals. |
| **ARTS DISTRICT** | west | 7-10 | A theatre with a marquee board (painted, unlit letters), galleries, a rooftop garden, the **FIXER**'s office (quest giver). |
| **SPORTS QUARTER** | north-west, behind the DUEL HALL | 5-8 | A stadium exterior, a training yard with dummies (reuse the range targets), a sports shop. |

Each quarter needs: a clear entrance from the ring road, one **landmark** visible from the plaza,
two or three **combat pockets** (cover, flanks, height) for patrols and turf wars, at least one
**vertical route** (stairs, fire escape, ladder) onto rooftops, and a **Preview** camera set.

## The expansion: look and detail

- **Facade kit** (new helpers in the builder): window bays with frames, sills and lintels,
  glass inset 0.1 behind the frame; shopfronts with stall risers, transoms and awnings (scalloped
  edge from small wedges); balconies with railings; fire escapes; AC units, drainpipes, vents,
  rooftop water towers (exists), antennas, rooftop billboards; cornices and string courses that
  step proud of the wall (never flush). Vary heights per building; every block gets a mix.
- **Streets:** lane arrows, stop lines, parking bays, manholes and drains, bus stops with
  timetable boards, traffic lights (a slow client-side colour cycle is fine), street name signs
  at every junction, bike racks, newspaper boxes, planters, trees in pits with grates. Rule of
  thumb: one prop every 12-16 studs of pavement, a lamp every ~24.
- **Interiors** only where there is gameplay: the hideout, Zee Central's ticket hall, the bank
  lobby and vault, the VFX Bazaar, the Tailor. Interiors are lit by warm PointLights and have a
  floor, walls, ceiling, and furniture -- never a black box.
- **Day and night:** lamps and lit windows come on at night (the existing lamp helper has a
  light); the Night Market is at its best after dark.
- **Life:** ambient civilians (non-combat, pathing along pavements, scattering from gunfire;
  cheap -- a handful per streamed quarter), birds on roofs, steam from vents, flags that move.

## The expansion: gameplay and RPG

1. **Zones and levels.** Add each quarter as its own zone in `NPCConfig` (bounds from the
   builder, level bands above), so NPCs level by where they stand and `KillInZone` quests can
   target a quarter. Midtown stays a safe hub (no patrols; turf crews only).
2. **Gangs.** Three gang factions -- **Redline Crew** (red, the Projects), **Jade Syndicate**
   (green/gold, Night Market alleys), **Dock Rats** (navy, the Docks) -- as NPC factions with
   their own palette (tint the existing archetypes, a hat or bandana each), patrol routes along
   their streets, and a respawn cap per quarter. Standing with each gang goes through
   `ReputationService`: fighting a gang lowers standing with it and raises it with the town.
3. **Turf control per quarter.** Extend `TurfWarService`: each gang quarter has a holder
   (`gang` or `players`). A turf war targets a quarter (weighted towards gang-held ones) and
   starts from that quarter's entry points; winning flips it to **players** for 20 minutes --
   a painted banner goes up, patrols thin out, that quarter's vendors give a discount -- and
   the gang retakes it when the timer ends or a war is lost there. Keep the district-wide
   THREAT level on top. Publish control state (attributes on ReplicatedStorage) and show it on a
   district map in the HUD (see 8).
4. **Activities.**
   - **Bank Heist** (Financial District, world event, co-op): crack the vault on a timer while
     guard waves arrive, carry loot bags to a van, big payout; announced like supply drops.
   - **Gang Hideout** (the Projects): clear two floors and the **Redline Boss** (reuse
     `BossService` phases); daily first-clear bonus.
   - **Rooftop Runs:** three timed parkour routes across rooftops (checkpoints, a couple of
     ziplines), best times on a board in the plaza.
   - **Zee Tags:** 30 hidden graffiti tags to find across the district, tracked in the Journal,
     a title for all 30.
   - **Bounty targets:** a named gang lieutenant roams a quarter with a HUD marker (build on
     `BountyService`).
   - **Courier jobs** from vendors: carry a package across the district before a timer runs out
     (enemies drawn to the carrier).
5. **Quests.** A Downtown story chain of 8-10 quests from the **FIXER** that walks a player
   through every quarter (existing kinds plus new ones added to `QuestService` tracking:
   `WinTurf`, `HoldQuarter`, `FindTags`, `FinishRun`, `ClearHideout`). Rewards in coins, XP,
   crystals, a VFX item and a title at the end. Show XP with `GameConfig.ShownXP`.
6. **Economy.** VFX Bazaar (opens Market on the VFX shelf), the Tailor (sells
   `CosmeticConfig` hats/backs -- purchasing already exists server-side as `PurchaseCosmetic`),
   a pawn shop is optional. Prices follow town standing as the shop does.
7. **Fast travel.** A subway: Zee Central plus a station in three quarters, each a prompt that
   opens a small station map and moves you (server-validated, like `TravelService`).
8. **HUD.** A compass strip and a district map (on a key that is free -- M is already the shop;
   check the Controls section of the README): quarters coloured by
   holder, turf war / bounty / heist / drop markers, station icons, your position.
9. **Wire-up checklist** -- every one of these must read the new bounds, not a copy:
   `TurfWarService` (CENTRE, Zones → one or more patches per quarter), `NPCConfig` zones,
   `SupplyDropService` DOWNTOWN (centre, radius, `maxRise`), `TravelService` arrival,
   `DistrictService.CENTRE` (keep it), `Downtown.DropRadius`, `Downtown.Preview`,
   `tools/uitest/district.luau`, `tools/uitest/fixtures.luau` (Travel entry text).

## Phases and acceptance

1. **Foundation.** Split the builder into core + `Quarters/`, introduce the shared bounds,
   grow the ground and the ring road, open the avenue/cross street, move the skyline ring out.
   *Accept:* district suite passes unchanged in spirit; audit clean; renders of the ring road
   and each empty quarter plot; nothing references the old ±200 bounds.
2. **Night Market + Riverside Docks** (geometry, detail, landmarks, VFX Bazaar, gang patrols,
   zones). *Accept:* renders from 6+ cameras per quarter, audit clean, walkable from the plaza
   to both (add path checks to the district suite), patrols spawn only in their quarters.
3. **The Projects (with the hideout) + Rail Yard / Zee Central** (subway hub). *Accept:* hideout
   clear works end to end in a test; station prompt present; audit clean; part budget on track.
4. **Should-have quarters** as budget allows, then **turf control per quarter**, activities,
   the FIXER quest chain, subway, HUD map. *Accept:* new tests for turf control flips and
   timers, quest objective kinds, subway validation; gallery shots of the map and the quest
   journal.
5. **Polish:** a lighting pass for day and night, a performance pass (part and light counts in
   the district suite, per-quarter), a final audit, and README sections for Downtown.

After **every** phase: `lune run tools/build.luau`, the strict type check, **all** suites in
`tools/uitest/`, export + audit + render Downtown, commit with a clear message (ending with the
repository's attribution lines), push, and report honestly what was built, what was verified
and how, what was not, and the renders.
