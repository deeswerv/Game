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
| Hold **Alt** | Free the mouse to click buttons (DUEL, the side menu) without leaving shift lock |
| **J** | Queue for a duel, or cancel the queue (same as clicking DUEL) |
| Hold **Tab** | Player board: levels, ranks, kills, deaths, who is dueling |
| **B / M / K / P / N** | Items, Shop, Armory, Profile, Daily reward |
| **O** | Quest journal |
| **L** | Daily contracts |
| **Y** (or click the level diamond) | Level road: what every level unlocks, and what is next |
| **H** | Achievements: claim rewards and pick the title you wear |
| **T** | Travel: jump to the Crossing, Downtown, the Flats, the Mine, the Watchpoint or the Reach (not while under fire or in a duel) |
| **E** (hold) | Open a supply drop; rob a till or an ATM downtown |
| **F1** | Settings: volumes, camera shake, field of view, crosshair colour |
| **Right mouse** | Aim; with the Longshot (or a strong scope) you look through the scope |
| **V** | Go to (or leave) the gun range |
| **Shift** or double-tap **W** | Sprint; **Ctrl** / **C** while sprinting slides |
| Hold **C** (or **Ctrl**) | Crouch: half speed, the camera comes down, and the gun's spread tightens by a quarter; let go to stand |
| **Q** | Roll the way you are moving -- **W** forward, **S** back, **A**/**D** to the side, forward if standing still -- about 10 studs, then a short cooldown |
| Hold **F** | Aim the selected throwable (an arc shows where it lands); let go to throw |
| **X** | Switch throwable: Frag (from level 3), Flashbang (level 7), Smoke |
| **Z** | Heal: the equipped heal (the Field Medkit patches 50 health over a second) |
| **G** (hold) | Emote wheel: scroll or click the tabs for five pages of emotes, 1-8 to pick |
| **U** (hold, let go) | Call in an airstrike you have earned: a red mark follows your crosshair, let go to call it |

**How you move.** Every player's body is posed by the game itself rather than Roblox's stock
animations (`ReplicatedStorage/Motion.luau`, drawn by `MotionAnimator`): a stylised walk and run
that steps the way you are actually going (strafing and backpedalling included), knees up and
arms pumping, a lean and a harder pump when sprinting, a crouch with the feet kept flat, knees
tucked in the air, a dip on landing, and a tucked somersault for the roll that stays on the
floor in every direction. Every change blends rather than snaps. Other players see all of it:
everyone's client poses everyone from what it can see, and the crouch and roll are marked on the
character by `MovementService`. The old dash on Q is gone. `lune run tools/mapview/poses.luau --
out.json run` (or `crouch`, `roll`, `rollside`, `air`...) renders the poses on the real rig;
`tools/uitest/movement.luau` checks them and the controls.

You can also queue by standing on one of the **1V1 pads** in Downtown's DUEL HALL (the lobby's
pads at the Crossing are retired).

## Utility and armour

Every life (and every duel round) starts with a fresh kit: smoke and two medkits from the
start, two frags from level 3, two flashbangs from level 7. Frags hurt anyone close, less
through walls, and you take half of your own. A flashbang whites out the screen of anyone
looking at it and blinds enemies for a few seconds (they stop seeing you and their aim goes).
Enemies cannot see through smoke. The cyan bar over your health is armour: it soaks hits
before your health does. Enemies drop armour plates (walk over them), and a duel gives both
fighters 50 armour every round.

**Gear (ZEE TACTICS).** The heal on Z, the armour you wear and the bomb in your throw slot are
gear, six grades each from Common (what everyone starts with) to Mastery, bought from the clerk
behind the counter at ZEE TACTICS in Downtown and swapped in the inventory's **GEAR** section:

| | Common | Uncommon | Rare | Epic | Legendary | Mastery |
|---|---|---|---|---|---|---|
| **Heals** | Field Medkit (+50, 1.2s, x2) | Trauma Kit (+65) | Combat Stim (+70, 0.8s, x3) | Nano Injector (+85, 0.7s) | Phoenix Serum (+100, 0.6s) | Zee Elixir (+100 and +25 armour, x4) |
| **Armor** | Padded Jacket (starts 0 / 75) | Kevlar Vest (25 / 75) | Plate Carrier (50 / 100) | Riot Rig (50 / 125) | Juggernaut Plates (75 / 150) | Titan Weave (100 / 150, bigger plates) |
| **Bombs** | Frag Grenade | Impact Grenade (goes off on landing) | Sticky Bomb (sticks to what it hits) | Cluster Bomb (four bomblets) | Incendiary (six seconds of fire) | Singularity Charge (pulls them in) |

Prices run from about $2,000 (level 3) to about $50,000 and 30 crystals (level 22+), with 8-15%
off for Friendly/Honoured Street Cred. Equipping at the counter restocks your kit (every 20
seconds); duels always use the Common of each, so a duel stays even. `tools/uitest/gear.luau`.

## Streaks and bounties

Out in the world, kills without dying build a streak: **KILLING SPREE** at 3, and at 5 you
are **WANTED** -- everyone is told, a red tag with your price floats over you through walls,
and the price climbs with every kill after (up to $4,000). Whoever takes a wanted player down
collects the bounty and XP, and the server hears about it. Duels and practice dummies do not
count.

**Killstreak rewards.** The same streak earns rewards, shown on the meter over the weapon slots
(it fades back at a streak of 0 and hides in a duel):

| Streak | Reward |
| --- | --- |
| 3 | **RADAR**: for 12 seconds every enemy within 260 studs is outlined in red through walls |
| 5 | **OVERSHIELD**: 60 points of violet shield over your health and armour until it breaks; everyone sees the shell |
| 8, then 12, 16, ... | **AIRSTRIKE**: hold **U**, aim, let go. Everyone gets a red zone and a countdown, then a jet runs in and lays six shells along it. The blasts are frag blasts, so walls help and the kills (and streak) are yours |

Dying ends the streak and loses an unused airstrike. `tools/uitest/streaks.luau`.

**Stick-ups.** Downtown's tills (behind the counters at ZEE GUNS and ZEE TACTICS) and its cash
machines (inside both shops, and outside the 24/7) can be robbed: hold **E** at one (4s for a
till, 6s for an ATM). You take a bag ($450-750 from a till, $700-1,100 from an ATM) and the
heat: the store's alarm goes off, the whole server is told where and how much, a gold tag with
the amount floats over you through walls, and three of the crew that runs the block come up the
avenue after you. Hold the bag for the heat (60s for a till, 75s for an ATM; a bar under the cash
counts it down) and it is yours, with 300 XP. Go down first and it is gone, or it goes to
whichever player put you down. A robbed target stays empty for five minutes; one bag at a time.
The squad counts toward your streak. `tools/uitest/stickups.luau`.

It plays out in front of you: the clerk jolts, a red "!" pops over their head, and they turn to
face you with both hands up, shaking, until the job is long done. The till is a real register --
keys, a receipt printer, a customer display -- and its drawer springs out with a ka-chunk and a
ching, the display shows what went, and the notes jump out, tumble, flutter down and whip into
your hands while "+$620" floats up off the counter; the drawer shuts itself a few seconds later.
A cash machine's screen goes red, reads DISPENSING, spits a stream of notes out of the slot at
you, then says OUT OF CASH. All of it is local and cosmetic: the money is in the bag before any
of it moves. Clerks and quest givers have a life the rest of the time too: they breathe and shift
their weight (a clerk waits with arms folded), look at whoever comes close, wave the first time
you walk up, and talk with their hands when you open their shop or their dialogue.
`tools/uitest/staff.luau`.

**Prompts.** Every "press E" in the game is the game's own: a key cap you could press, the action
in big type ("Rob Register", "Open Shop", "Talk"), what it is on underneath and HOLD when it must
be held. It grows and rises into place, the thing it belongs to is outlined while it is up,
holding fills the key and a bar along the bottom, and a completed press flashes and pops. A
robbery wears red; everything else the accent green. The text follows the prompt as it changes.

**MOST WANTED.** The **BOUNTIES** board on the side of the 24/7 in Downtown (next to CONTRACTS)
names a crime boss every few minutes -- *"THE VICE" Vinnie Russo*, *"BIG SAL" Moretti* and
friends -- a Capo with two of their crew, holed up somewhere in the district. The board shows
the poster, what they did, where they were last seen, their health and how long before they
skip town, plus every WANTED player and their price; a marker with the distance floats over the
target. The one who brings them in gets $1,500, XP, crystals and Street Cred; anyone who helped
gets a cut. `tools/uitest/wanted.luau`.

## Downtown

**Downtown is the first stop.** You wash up at the Crossing; the Quartermaster's first job is
*Welcome to Downtown*, and the Travel menu marks it START HERE. Everything past it -- the Flats,
Watchpoint, the Reach, and the Quartermaster's work out there -- stays locked until you beat the
Don at the top of **ZEE TOWER**.

**At night the city lights up.** As the day/night cycle runs into dusk the street lamps come on
one by one, the lights under them brighten, and windows light up across the blocks and the
skyline: warm ones mostly, the odd blue television. After midnight most of them go dark again as
people go to bed. By day nothing is touched: the city is exactly as built, with no neon.
`tools/uitest/citylights.luau`.

Open **Travel** (T) and pick **Downtown**, a cartoon low-poly city in the style of the reference
street, with no neon anywhere in daylight. Buildings are saturated orange, yellow, green, blue, coral,
purple, teal and red brick with white trim; the street faces have rows of real windows --
framed, arched with keystones, or shuttered, and bay windows on the wide ones -- over ground
floors of named shops (ZEE BEATS, PIZZA, COMICS, BOBA...) under striped awnings, with corner
quoins and heavy two-step cornices. Round trees of layered leaves, curling crook lamps, bright
purple/yellow/blue/red benches, yellow road edge lines, and a sky of big clouds with punchier
colour while you are there. The places:

- an avenue from the welcome wall to **ZEE TOWER**, and **ZEE PLAZA** with its three-tier
  fountain, planted corners and finger post;
- **ZEE GUNS** and **ZEE TACTICS**, shops you walk into: a wood-floored gun shop with rifles
  racked on the wall, pistol cases and a workbench (press E for attachments and builds), and
  a gear shop with heals on the shelves, vests on mannequins and bombs on a pegboard. A clerk
  stands behind each counter -- press E at the counter to buy;
- **ZEE GAS** and the **24/7** with the **CONTRACTS** and **BOUNTIES** boards on its wall: four
  branded pumps with their screens, grade buttons, racked nozzles and hoses, bins and squeegee
  buckets on the islands, lane arrows and oil stains on the forecourt, a car filling up, the air
  machine and a cage of gas bottles under a canopy with a lit soffit and a gold-striped fascia;
- **THE FIXER's corner** on the paving south of the courts: a purple JOBS canopy over a card
  table;
- the **DUEL HALL**, a sports hall with its own 1v1 pads, its name painted down its sides;
- **RAINBOW PARK**: a curving path, flowers and long grass, a waterfall pouring off a rock
  cliff into a pond with a rainbow over it, and the star-shaped **ZEE BEATS** stage with a
  lighting truss, speakers, benches and cafe umbrellas;
- **THE ALLEY** behind the gas station: brick backs with fire escapes, dumpsters, pallets and
  boxes to fight round, bin bags, washing strung overhead, a muscle car, a red light over the
  back door, tags on the walls and yellow bollards at the mouth;
- a basketball court, a hedged pocket park (cypresses where the path comes in, flowering
  shrubs by the benches), parked cars and a skyline all round;
- cars in five shapes, not one box in five paints: saloons with a raked windscreen and a boot,
  tall hatchbacks, square SUVs with roof rails and a spare on the back, pickups with a crate in
  the bed, and yellow taxis with a checker band and a TAXI light -- tinted glass, chunky tyres on
  silver rims, grilles, plates and lamps;
- trees in three shapes (a full dome, an upright oval, a spreading umbrella) with shrubs round
  the planters, clipped cypresses at ZEE TOWER's doors, and every ground-floor shop dressed for
  what it sells: a glazed door, a blade sign with its icon hung over the pavement, and a
  chalkboard, a menu stand, a barber's pole, a rack of stock or buckets of flowers by the door;
- the tills and cash machines are proper models (see **Stick-ups**);
- on the streets, kept deliberately sparse so the roads read and the tower stays in view from
  the far end of the avenue: one traffic light per plaza crossing (ZEE AVE / MAIN ST on the
  blades), a bench, a flower bed or a phone booth every so often along the walks, lamps with
  alternating teal and red banners, a short row of parked cars on each arm, cafe umbrellas in
  the plaza, a taco truck and an ice-cream van, rooftop billboards, balconies with flower boxes,
  set-back crowns and beacon masts on the skyline towers, and brick bridges over the tunnels
  (EAST END / WEST END, named for the compass). Mailboxes, news stands, bike racks, parking
  meters, bollards and the bunting over the road are gone: about 1,750 fewer parts, and no clutter
  to snag on in a fight.

**Finding your way.** A compass runs across the top of the screen: N is up the avenue toward
ZEE TOWER, E on your right. The landmarks -- ZEE TOWER, the plaza, ZEE GUNS, ZEE TACTICS, the
DUEL HALL, the job boards, the Fixer, Rainbow Park -- sit on it as small icons and name
themselves when you look straight at them. Your current job goes up as a gold diamond with its
distance (every Downtown job knows where it happens: a turf patch, the roof, the tower) and gets
a marker floating over the spot in the world; when it is behind you it waits at the edge of the
compass with an arrow pointing the short way round. Between jobs, whoever has a new one for
you -- the Fixer, the Quartermaster -- wears a bobbing gold **!** over their head and goes up on
the compass, so the next thing to do is always somewhere you can see. A turf war going on, a supply drop, the most
wanted player and anyone carrying a stick-up bag go up too, and come down when they are over.
Walk into a named place -- ZEE PLAZA, ZEE GUNS, THE ALLEY, RAINBOW PARK, THE COURTS, the DUEL
HALL, ZEE TOWER... -- and its name comes up big in the middle of the screen with a line under it
("THE HEART OF DOWNTOWN", "CREW TURF"), the way a new area is announced in an RPG; stepping back
out into the street does not announce the district again. The compass hides in menus, while
scoped and in a duel. `tools/uitest/wayfinding.luau`.

Climb the fire escape on the apartments for a **rooftop stash** (once a day). Supply drops land
in its streets too. `lune run tools/mapview/audit.luau -- json <export>` checks it for z-fighting
and floating props (set `AUDIT_LIMIT` to list more than 40).

**Turf wars** are fought on four patches of Downtown -- THE CAR PARK (south-east), THE COURTS
(north-east), THE ALLEY (south-west) and THE PARK (north-west). Each is marked on the ground by a
ring of dashes with a sign over it: red and "STEP IN TO START A TURF WAR" when open, orange with
the count and clock while its war is on, grey with a countdown while it cools down. Walk onto an
open patch and its crew comes out round the edge; clear them and everyone who fought for it is
paid -- anyone who landed a hit, finished one of the crew off, or stood on the patch through the
fight -- with half as much again for the MVP (the most damage). Then that patch goes quiet for three minutes (the
other three stay open, and wars on different patches run side by side). A crew wins if the
clock runs out or everybody walks away from it for 45 seconds. Downtown remembers: every crew
driven out raises the **THREAT** (I to V) -- the next crew is bigger (5 up to 10: more Gangsters
and Shooters, a second Enforcer at V), the clock longer and the payout 25% higher per level; a crew
that holds its patch lowers it. The HUD chip follows the nearest war; wars near you get a
banner, ones across town a notice.

**The Downtown chapter** (RPG). **The Fixer** stands under the purple canopy south of ZEE COURTS
(press E). They run their own job chain, separate from the Quartermaster's (one job at a time,
from either): *Rooftop Run* (get onto the apartment roof), *The Car Park*, *Alley Cats* (six crew
in the alley), *Park Life*, *Full Court Press*, *The Top Floor* (beat the Don), *Turn Up the Heat*
(two wars at threat III+) and *The Kingpin* -- then a repeatable paid job, *Street Sweep* (win
two wars). Each pays cash, XP, crystals and **Street Cred**. Finishing one puts up a **JOB
COMPLETE** banner (it queues behind a turf war's TURF DEFENDED rather than hiding under it) and
the objective card shows the job done before it slides away. A turf war won on a different patch
than the job names says so -- "THE PARK doesn't count / Wants THE CAR PARK, behind ZEE GUNS" --
instead of saying nothing. THE PARK's patch is the lawn in front of the star stage.
`tools/uitest/turfquest.luau` runs the real turf wars and quests together.

**The crews** are criminals now: Thugs with knives, Gangsters with SMGs, Shooters with rifles
and grenades, Enforcers with shotguns, and Capos running them. They call targets to each other,
split into pushers, flankers and overwatch -- and the moment you reload in the open or drop
below a third of your health, everyone with any nerve rushes you. A crew lives in THE ALLEY.

**ZEE TOWER.** Walk into the tower's lobby (level 8+) and take the elevator to **THE PENTHOUSE**
-- the real roof of the tower, 150 studs over the city: black marble and gold, an infinity pool
along the edge, a glass-roofed lounge with a grand piano, a bar and a chandelier, the Don's desk
in front of a gold Z and the vault, a helipad with his helicopter, and a crown and spire over
it all. The first one up is welcomed, then **THE DON** steps out with two bodyguards (his health
scales with the room). At 70% the family comes up the elevator and money bombs land where you
stand (red ring, then the blast); at 40% his helicopter lifts off and circles the roof, strafing
a line across it (a red strip first). Beat him and everyone up there is paid ($8,000, 4,000 XP,
25 crystals, 25 Street Cred the first time; less after) and **the world opens**. An empty roof
resets the fight; beaten, the Don is back after a minute. `tools/uitest/tower.luau`. The
world past it starts with **Hanami Valley**, below.

**Street Cred** is your standing with Downtown: +8 for every war you help win (+4 more as MVP),
the Fixer's jobs, +20 for the Kingpin, -3 when a crew holds a patch you fought for. A known name
is paid more -- **Friendly (30+) takes 10% more from every turf war, Honoured (75+) 25% more** --
and the Fixer talks to you differently. The payout toast shows the Cred and the bonus.

**The Kingpin.** Win a turf war at threat V and the one who runs the crews steps out onto that
patch: a white-suited gunfighter boss with a health bar, who calls in backup at two thirds and
one third health. You have five minutes. Everyone who hurt them shares a $5,000 / 3,000 XP /
12-crystal bounty (half again for the MVP) and Street Cred; the crews scatter (threat back to
III). Left alone, the Kingpin walks away. They rest ten minutes between appearances.
`lune run tools/uitest/turf.luau` and `tools/uitest/fixer.luau` check all of it.

**XP** is paid at 1.5x across the game (kills, quests, contracts, chests, turf wars, the stash,
supply drops) -- one rate in `GameConfig.Leveling.XP_RATE`, and every reward shows what it pays.

A plan for growing Downtown into a much larger RPG district is written up as a ready-to-use
prompt in `docs/prompts/downtown-expansion.md`.

## Hanami Valley (chapter 2)

Beat the Don and **Hanami Valley** opens on the Travel menu (🌸, LV 10-16): a low-poly valley
of cherry blossom, red gates and iron, built by `HanamiService` (`HanamiService/Valley.luau`;
everything's position lives in `ReplicatedStorage/HanamiConfig.luau`). Five areas, each with its
own name card as you walk in and its own enemy levels:

- **Hanamura**, the village you arrive in (safe): the Great Sakura, the shrine (ring its bell
  to heal -- not mid-fight), a pagoda, the teahouse (stairs to its roof), the trader's counter
  (opens the shop) and villagers to talk to;
- **Lantern Row**, the dangerous streets across the red bridge: lantern-strung shophouses,
  lanes, roof terraces with riflemen on them;
- **the Ironworks**, foundry and docks: rail, containers, a crane you can climb, the furnace
  yard where **Foreman Tetsu** works;
- **the outskirts**: **Bamboo Hollow** (the bandit camp, the waterfall and the nook behind it)
  and **the Paddies** (the farm);
- **Kurogane Keep** on its plateau, up **the Thousand Gates** stair: walls, towers, and the
  Shogun's court.

**The Kurogane clan.** Ronin (blades, rush you), Riflemen (keep their distance from high
ground), **Shieldbearers** (an iron shield stops your rounds dead until it breaks -- shoot it
apart, go over the top for the head, or flank), **Shinobi** (dash at you from range in a puff
of dust -- step aside), **Juggernauts** (big, armoured, slow), Oni (the Shogun's guard:
grenades and good rifles), with elites among them. The valley only fills while someone is in
it, refills a fallen post after a while, and empties a minute after the last player leaves.

**Elder Hoshi's story** (under the Great Sakura), one job of each kind: reach the Lantern Row
gate; clear Lantern Row; **free three captives** tied up at the bamboo camp (hold E); read
**four clues** in the Ironworks; beat **Foreman Tetsu** (mini-boss: at 60% his crew joins and
molten splashes land under you, at 30% overtime); **hold the farm** through three raid waves
(raiders at the door wear the farmhouse down); find **five iron seals** hidden on roofs, the
crane, behind the waterfall and on a hill; climb **the Thousand Gates**; and end **THE IRON
SHOGUN** in his court (level 12+): blade waves across the court, then BLOSSOM STORM (66%:
Shinobi and riflemen, petal storms under everyone) and IRON FURY (33%: three blades at a time,
faster). The first clear pays $15,000, 8,000 XP and 40 crystals, saves the valley as freed and
gives the **Shogun Slayer** title. **Captain Rei** (at the red bridge) pays bounties on
Shieldbearers, Shinobi, Juggernauts and Oni, then a repeatable Valley Patrol contract.

`lune run tools/uitest/hanami.luau` plays all of it through the real services;
`tools/uitest/shields.luau` checks the shield against the real gun code and the Shinobi's dash.

## Contracts and supply drops

- **Daily contracts**: three jobs a day (one easy, one medium, one hard), the same set on every
  server, from headshots and wallbangs to duel wins, long-range kills, Warlords and supply drops.
  Each pays cash, XP and crystals the moment it is done, and finishing all three pays a bonus.
  Progress pops up on the left; practice dummies do not count.
- **Supply drops**: every four minutes a crate parachutes down 25-70 studs from a player out in
  the world (whoever has gone longest without one), under a pillar of light, with a marker and
  distance on your screen -- the named zones are only the fallback. First to hold E on it keeps
  the cash, crystals and XP inside; about one in eight is a golden Elite drop worth more.

## Title screen

Joining opens on a title screen once per session: the camera flies over Downtown, the Flats,
a duel map and the harbour behind the PROJECT ZEE logo, with your card (level, title, money)
and what is new. **PLAY** (or Space / Enter) drops you in; the **1V1 DUEL**, **DOWNTOWN** and
**THE FLATS** shortcuts drop you straight into the queue or onto that place.

## Achievements

30 long-term goals in four groups -- Combat, Duels, World, Progress -- from First Blood to
Legend (1,000 takedowns), Champion (50 duel wins), Explorer (all six places), Warlord Slayer,
Street Defender (turf wars), Kingpin Slayer, Street Legend (Honoured Street Cred), Public
Enemy No. 1 (five MOST WANTED names), The Top Floor and Penthouse Regular (the Don) and
Completionist. They count themselves from what the server
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

**Dressed for the part.** Every enemy is the players' own rig in clothes made to measure
(`NPCService/Outfit.luau`): Thugs in hoodies with the strings and pocket, beanies, the crew's
red bandana, a crossbody bag and white sneakers; Gangsters in the red tracksuit with white
stripes down the arms and legs, a backwards cap and a gold chain; Shooters in balaclavas,
plate carriers, gloves, knee pads and a thigh holster; the Enforcer bald, goateed and in shades
with a leather jacket over a white tee; the Capo in a purple suit; the Kingpin and THE DON in
white suits with fedoras, ties, pocket squares (and, on the Don, a rose). Out of town the
Bandits wear hoods and bandoliers, Soldiers helmets with goggles, Brutes and the Warlord plate,
pauldrons and crests. A crew is a crowd, not clones: each body draws its own hoodie, jeans,
skin tone and hair from its archetype's palette, while what marks the crew (the bandana, the
tracksuit) stays the same. Nothing worn can be shot, touched or bumped into, so headshots
land exactly as before. The shop clerks and the quest givers stand on the same rig in their
own clothes (a gun-shop apron and cap, a staff polo, the Quartermaster's field jacket, the
Fixer's purple bomber and gold). `lune run tools/mapview/npcs.luau -- out.json` renders the
whole lineup; `tools/uitest/outfits.luau` checks it.

**Name tags.** An enemy's plate shows its level and name within 95 studs (a player's within
150), never through walls; an elite wears a gold star on it and a district boss a crown.
Clerks and quest givers wear the same style of tag (white name, gold role).
`tools/uitest/nameplates.luau`.

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

## Mastery Weapons

Whole Dark Matter versions of a gun, earned by mastering it (or, once a Developer Product id is
set on the variant in `WeaponConfig.Variants`, bought with Robux). Each keeps its base gun's
numbers exactly -- a look, never an advantage -- with its own shots (the gem-charge hit effect,
purple tracers and flash).

- **Carbine - Dark Matter** -- Silver mastery with the Carbine (100 kills). The imported model.
- **Warden - Dark Matter** -- Gold mastery with the Warden (250 kills). The HD rifle
  (`ARCarbineHD_DarkMatter.glb`): obsidian receivers, a curved magazine, skeletonised stock, a
  red dot on its own riser and 180 crystals, rebuilt part for part (670 parts) and wearing the
  carbine's authored muzzle flash.

The market's **Mastery** shelf lists them with how each is earned ("EARN IT") and marks the ones
you own; they sit among your guns in the inventory and the armory like any other.

The HD rifle comes from its GLB at build time, with no upload:

```sh
python3 tools/weapons/convert_glb.py ARCarbineHD_DarkMatter.glb tools/weapons/Warden_DarkMatter.json --length 4.2 --preview out/prev.json
node tools/weapons/preview.mjs out/prev.json out/compare.png three     # GLB left, rebuild right
lune run tools/weapons/export_tool.luau -- Warden_DarkMatter out/tool.json   # after a build: the Tool as assembled
```

`convert_glb.py` turns each mesh into parts in the gun's Handle space -- bevelled boxes into
Blocks, cylinders and lathed rings into Cylinders (open rings into an eight-slat band so the
optic's lens shows), profiled extrusions (receivers, grip, magazine, stock, trigger guard)
sliced into strips of Blocks and Wedges that follow the authored outline, crystal shards into a
body and a chisel tip along their own axes -- and `tools/patches/070_mastery_weapons.luau` builds
the Tool into `storeitems`. If the GLB is ever imported through Studio under the same name, the
import is kept instead. `tools/uitest/mastery.luau` checks the Tool, the reload, the variant and
earning it.

**Seeing a gun in the hands.** `tools/weapons/holdview.luau` poses the game's own rig with the
real `WeaponPose` and draws the result (`node tools/weapons/preview.mjs out/hold.json
out/hold.png hold`), and `tools/uitest/holds.luau` checks every gun: long guns carried in
front of the body with the off hand on the weapon, carrying and aiming. It caught why the
Warden - Dark Matter would not sit in the hands: the pose's reach fit picked between the
across-the-body carry and a swung-out one by the smaller slide down the barrel, the two tied
to a ten-thousandth of a stud, and it landed on the swung-out carry with the off hand half a
stud off the gun (the Longshot too). The fit now puts the hand on the gun first; every other
gun's hold is unchanged.

## Attachments

Twelve authored attachments, made for the **Dark Matter Carbine** (Mastery): a **Red Dot**,
**Holographic** and **4x Scope**; a **Compensator** and **Suppressor**; a **Vertical Grip**,
**Angled Grip** and **Bipod** under the barrel; a **Laser Sight** and **Flashlight** on the new
**side rail** (so a light or laser can run with a grip); an **Extended Mag** (+10 rounds) and a
**Skeleton Stock**. Each one is the artist's model rebuilt piece by piece where it was authored,
so fitting it is exact: the optic folds the iron sights away, a muzzle device moves the muzzle
(and the carbine's own flash) out to its end, and the extended mag is the one the reload drops
(its crystals ride on it). The crystals stay put whatever is fitted, as in the authored GLBs. Buy and fit them in the **Armory**
(K) on the gun itself -- press a padlocked chip twice to buy it; the shop no longer has an
attachment shelf. Other guns take none until attachments are made for them.

The old block-built catalogue (2x/8x scopes, brake, flash hider, drum and quick mags, heavy and
folding stocks, charms) is retired: anyone who owned one is refunded what it sold for, once, on
their next join, and a laser or light bought "under the barrel" moves to the side rail with any
builds that used it (`ShopService.MigrateAttachments`). Mastery Weapons now also count as owned
guns everywhere (the inventory, the armory, equipping), and a mastery tier actually grants one.

The models come from the GLBs through `tools/attachments/`:

```sh
lune run tools/attachments/export_weapon.luau -- Carbine_DarkMatter out/dm.json   # the gun, in Handle space
python3 tools/attachments/convert.py out/dm.json <folder of .glb> --preview out/prev
node tools/attachments/preview.mjs out/prev/Under_Bipod.json out/bipod.png         # GLB vs rebuild
```

`convert.py` fits the GLB's gun onto the in-game one (similarity transform from the parts they
share), rebuilds each attachment mesh as a Block or Cylinder, works out which stock parts it
replaces, and writes `src/ReplicatedStorage/AttachmentModels.luau`. `tools/uitest/attachments.luau`
checks the catalogue, the fitting, the migration and the shop.

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
- **VFX shelf** in the shop (it replaced Style): five **kill effects** (Shatter, Confetti,
  Thunderstrike, Void, Gem Charge) that play on anyone you eliminate, and five **tracers**
  (Crimson, Gold Rush, Plasma, Toxic, Prismatic) that change how your rounds look. Everyone sees
  them. Buy one and it goes straight on; owned ones show EQUIP / EQUIPPED. Mastery Weapons keep
  their own tracer. Hats and backs you already own are still yours to wear.
  - Kill effects hit hard: every one lands with a flash, a ball of light and a shockwave rolling
    across the ground. Thunderstrike brings a thick bolt down from 70 studs up, re-struck four
    times with forks, sparks thrown out, arcs crawling over the body and a scorch. Void opens a
    black hole with a spinning ring that collapses and blows back out.
  - Bought tracers are wide bolts of colour: a glow round the streak, a longer streak, a vapour
    line in the tracer's colour, and a flare where each round lands.
  - **Per gun** (inventory, **✨ VFX** beside EQUIP): pick which kill effect and which tracer
    THIS gun uses. *Default* follows what is equipped in the shop, *None* plays nothing on that
    gun, and any owned effect can be chosen (the rest show locked). Saved in `WeaponVFX`,
    published as the `VFX_Guns` attribute, and checked for ownership on the server.
  - `lune run tools/uitest/vfx.luau` checks all of it.
- **Dark Matter hits** play the gem-charge effect (assets/vfx/gemstoneCharge.rbxm) for everyone:
  a quick small burst on the body, and on a headshot a bigger charge on the head with a crystal
  flare. Any .rbxm dropped into assets/vfx is imported into ReplicatedStorage.VFX on build;
  `lune run tools/uitest/tracers.luau` checks all of this.

## Duel maps

Every duel is fought on one of four maps, and a pair who just played one map gets a different
one next. Two duels at once never share a map. The VS screen names the map.

| Map | Look |
| --- | --- |
| **Neon Court** | Rooftop court at night, magenta and cyan neon, lit skyline; equipment cases, stacked crates, jersey barriers and plant units for cover, lighting trusses overhead, painted court markings, team benches and lockers |
| **Dockyard** | Container quay at sunset: stacked boxes, a gantry with a hanging container, a ship and cranes across the water |
| **Rooftops** | Tar roof over the city on a clear afternoon: stair huts, water towers, a raised HVAC deck, billboard and mural |
| **Sakura Temple** | Temple courtyard at dusk: gate houses, torii, koi pond with an arched bridge, lanterns, bell tower, pagodas |

Each map is lit its own way while you are in it (time of day, haze, colour grade), and
everything goes back to the world's day/night cycle when you leave. Every map has 180-degree
rotational symmetry, so both spawns see the same thing.

The maps live in `src/ServerScriptService/ArenaService/` (one module per map, plus `Kit`).
`tools/mapview/` renders any of them to PNGs, and `lune run tools/uitest/arenas.luau` checks
every map's spawns, bounds and lighting.

### Map glitch audit

`tools/mapview/audit.luau` finds what makes a low-poly map look broken: **z-fighting** (two
faces in one plane, overlapping, in different colours -- the flicker as the camera moves),
exact duplicates, and small props floating with nothing under them. It only reports faces a
player could actually see (not buried in another part, not the underside of a slab over the
void).

```sh
lune run tools/mapview/audit.luau -- build/Game.rbxl Mine TheMap        # parts saved in the place
lune run tools/mapview/arenas.luau -- Temple out/temple.json            # a map as the server builds it
lune run tools/mapview/audit.luau -- json out/temple.json
lune run tools/mapview/arenas.luau -- world:Ascents:src/ServerScriptService/AscentService.luau out/a.json
```

Fixed with it: the Temple stage (its skirt's top was the deck's top: the whole stage
flickered), the Rooftops murals and roof edge, Downtown's kerbs, plaza walks, billboard,
doors and tower cornices, the Flats' paving joints, flags, banners and merlons, and the Mine
shaft (a flickering band round the ladder where it passes the cavern roof). The Mine is baked
into the place, so `tools/patches/060_glitch_fixes.luau` corrects the saved parts as well as
the builder. Props that hung in the air are seated: container handles, the crane beacon, the
rooftop stairs (now on stringers) and the temple fountain's spout.

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
