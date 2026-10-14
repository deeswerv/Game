---
tags: [testing]
---
# Playtest checklist

Every change is checked by the automated suites (`tools/uitest/`), but those run in an emulator,
not in Roblox. These are the things only a real Studio session or live server can confirm. Copy
the list into a new [[Devlog/2026-10-08|devlog]] entry each time you test a build, tick what works,
and put anything broken in [[Bugs & Feedback]]. Back to [[Home]].

## Before you start
- [ ] The BUILD stamp (title screen bottom-right, or F4) matches the newest commit
- [ ] Output window has no red errors in the first minute

## The First Day (as a brand-new player)
- [ ] On first join the job "Welcome to Downtown" is already up, with a compass marker
- [ ] Each step goes up by itself a few seconds after the last: Alley → ZEE TACTICS → a till → the Fixer
- [ ] Nothing is confusing or blocked; note how long it takes: ____ minutes

## The Blender kit ([[Blender City Kit]])
- [ ] Downtown's cars, lamps, trees and benches look smooth (meshes), not boxy (parts)
- [ ] If they look boxy in a live server: Game Settings → Security → **Allow Mesh / Image APIs**
- [ ] Rooftop water towers and air units on Downtown's roofs
- [ ] Bus shelters on the avenue: curved roof, glass, bench, round stop sign
- [ ] Hanami Station: the train at the platform has noses at both ends
- [ ] Hanami side streets: utility poles with cross-arms and wires; bikes in rows by the station
- [ ] Walking into a car, lamp post or tree still blocks you; shooting one still stops the round

## City life ([[City Life & Effects]])
- [ ] Shoot a parked car: amber hazards flash, an alarm whoops, it stops after ~7 seconds
- [ ] People walk Downtown's pavements and Hanami's Scramble, and run when shooting starts
- [ ] Pigeons scatter when you walk up or shoot
- [ ] F4 → Weather → Rain: streaks, splashes, wet streets, lightning and thunder
- [ ] Night: lamps and windows come on

## Performance
- [ ] F1 → GRAPHICS → PERFORMANCE feels smooth on a low-end device or phone emulator
- [ ] No big hitch when travelling (T) to Hanami City

## Saving (only in a published place)
- [ ] Owner panel shows **● SAVING TO THE PROFILE** (needs Publish + Studio API access on)
