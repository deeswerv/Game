---
tags: [system, graphics]
---
# City life & effects

What makes the cities feel lived in. Back to [[Home]] · maps: [[Downtown]], [[Hanami City]].

| Feature | What it does | Script / test |
|---|---|---|
| Pedestrians | A dozen in Downtown, sixteen on Hanami's Scramble; they run from gunfire | `Pedestrians.client`, `DistrictService/Crowd`, `staff.luau`, `hanami.luau` |
| Pigeons | Flocks that potter about and scatter when you come close or shoot | `CityLife.client`, `citylife.luau` |
| Steam & smoke | Manholes steam, chimney pots smoke | `CityLife.client` |
| Petals & fireflies | Petals fall from every cherry tree; fireflies over the parks at night | `CityLife.client` |
| Rain | Streaks, splashes, wet streets, cooler grade, lightning and thunder (F4 → Weather → Rain) | `Rain.client`, `rain.luau` |
| Night lights | Lamps and windows come on at dusk, most go dark after midnight | `CityLights.client`, `citylights.luau` |
| Car alarms | Shoot a parked car: amber hazards, a glow, a two-tone alarm for 7 s | `CarAlarms.client`, `caralarms.luau` |
| Giant screens | Hanami's screens rotate their adverts | `CityScreens.client` |

**GRAPHICS** (F1): ULTRA, BALANCED or PERFORMANCE. PERFORMANCE thins flocks, turns steam, smoke,
petals and fireflies off, draws less rain and hides small trim, never a landmark.

Lighting is Future, with lamps and signs really lighting the street at night
(`tools/patches/090_graphics.luau`).
