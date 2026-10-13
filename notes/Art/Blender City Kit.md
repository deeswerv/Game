---
tags: [art, blender]
---
# Blender city kit

Every 3D model the cities use, modelled in Blender **in code** by `tools/models/build_kit.py`.
The script writes the meshes into the game (`ReplicatedStorage/MeshKitGeometry`), and every
player's device builds them with EditableMesh and draws them over the part-built props, hiding
those on its own screen only. The parts stay solid underneath, so cover and collisions never
change. A device that cannot make meshes just sees the parts. Back to [[Home]].

> [!warning] If the meshes do not show in a live server
> Game Settings → Security → **Allow Mesh / Image APIs** → on.

## The street (Downtown)
![[assets/models/previews/sheet.png]]

## The plaza (Downtown)
![[assets/models/previews/sheet2.png]]

## Vehicles
![[assets/models/previews/sheet3.png]]

## Every model
| Model | Where | Preview |
|---|---|---|
| Sedan, Hatch, SUV, Pickup, MuscleCar | Downtown cars (the taxi is the Sedan) | ![[Pickup.png\|160]] |
| StreetLamp, PostLamp | Downtown's crook lamps, the plaza's post lamps | ![[StreetLamp.png\|160]] |
| Tree, TreeTall, Cypress, Shrub | Downtown's planting | ![[Tree.png\|160]] |
| Bench, Bin, Hydrant, Dumpster, PhoneBooth, TrafficLight | Downtown street furniture | ![[Hydrant.png\|160]] |
| CafeTable, Awning, Fountain, FoodTruck | The plaza, the shops, the taco truck and ice-cream van | ![[Fountain.png\|160]] |
| BusShelter | Downtown's avenue | ![[BusShelter.png\|160]] |
| WaterTower, RoofUnit | Downtown's roofs | ![[WaterTower.png\|160]] |
| Sakura, Pine, StoneLantern, Torii, Vending | Hanami's trees, lanterns, gates, drinks machines | ![[Sakura.png\|160]] |
| AvenueLamp, AvenueLamp2 | Hanami's avenues | ![[AvenueLamp2.png\|160]] |
| Kei, JSedan, Van, KeiTruck | Hanami's cars (taxis are the JSedan) | ![[KeiTruck.png\|160]] |
| Bus | Hanami's city buses | ![[Bus.png\|160]] |
| TrainCar, TrainCab | The train at Hanami Station | ![[TrainCab.png\|160]] |
| UtilityPole, UtilityPoleT | Hanami's side streets (T has a transformer) | ![[UtilityPoleT.png\|160]] |
| Bike | Hanami's bike rows | ![[Bike.png\|160]] |
| Pigeon | Both cities' flocks | ![[Pigeon.png\|160]] |

## Adding a model
1. Write a function for it in `tools/models/build_kit.py` (Roblox coordinates via `rb`/`rbox`), call it from `build()`.
2. Run `python tools/models/build_kit.py` (Blender's `bpy`); `KIT_ONLY=Name` renders just that preview.
3. In the builder for the prop, wrap the part-built version with `MeshKit.Prop(b, "Name", paints)`.
4. `lune run tools/build.luau`, then the `meshkit`, `citymeshes` and `hanami` suites.

## Ideas
- [ ] The ZEE BANK armoured truck · [ ] the ice-cream van's cone · [ ] Hanami lantern strings and noren
- [ ] Mailboxes and news stands if Downtown ever wants more street clutter back
