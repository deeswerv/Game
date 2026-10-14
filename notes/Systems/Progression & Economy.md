---
tags: [system, rpg]
---
# Progression & economy

Back to [[Home]] · related: [[Combat & Guns]], [[Crime & Heat]].

## Levels
- Max level 50, then **prestige**. XP is paid at 1.5x everywhere (`GameConfig.Leveling.XP_RATE`).
- The **level road** (Y) shows what every level unlocks.
- Guns unlock by level and price: Fang $4,500 (6), Hornet $7,500 (8), Redwood $20,000 (16), Carbine $38,000 (25), Warden $50,000 (30).

## The First Day (new players)
Started automatically on a first join, each step chaining into the next (see `autoNext` in
`QuestConfig`): get Downtown → two crew in THE ALLEY → the ZEE TACTICS counter → rob a till → find
the Fixer. Pays $1,750, 1,050 XP and 2 crystals in all.

## Quest givers
- **The Quartermaster**: the first job, *Welcome to Downtown*, and work out in the world
- **The Fixer** ([[Downtown]]): Rooftop Run → The Car Park → Alley Cats → Park Life → Full Court Press → The Top Floor → Turn Up the Heat → The Kingpin → repeatable Street Sweep
- **Elder Hoshi** and **Captain Rei** ([[Hanami City]])

## Bosses
| Boss | Where | First-clear reward |
|---|---|---|
| The Kingpin | A Downtown turf patch | $5,000, 3,000 XP, 12 crystals (shared) |
| THE DON | ZEE TOWER penthouse | $8,000, 4,000 XP, 25 crystals, 25 Street Cred; opens the world |
| Foreman Tetsu (mini-boss) | Hanami Steelworks | story step |
| THE IRON SHOGUN | Kurogane Castle | $15,000, 8,000 XP, 40 crystals, Shogun Slayer title |

## Daily things
- **Daily contracts** (L): three a day, the same on every server, plus a bonus for all three
- **Supply drops** every four minutes near a player; one in eight is golden
- **Daily reward** (N), the **rooftop stash** (once a day)
- **Achievements** (H): 30 goals with cash, XP, crystals and titles

## Gear (ZEE TACTICS)
Heals, armour and bombs in six grades (Common → Mastery), about $3,000 to $78,000 + 30 crystals.
Restock mid-life from the inventory's GEAR strip. Duels always use Common.

## Prices
Priced against what playing pays (`tools/uitest/economy.luau`): a gun costs three to four
levels' income at the level it unlocks.
