---
tags: [system, ai]
---
# Enemies & AI

Back to [[Home]] · related: [[Combat & Guns]].

## Who
- **Downtown crews**: Thugs (knives), Gangsters (SMGs), Shooters (rifles and grenades), Enforcers (shotguns), Capos; the Kingpin and THE DON
- **Out in the world**: Bandits, Soldiers, Brutes, the Warlord, Guards, Marksmen
- **Hanami's Kurogane clan**: Ronin, Riflemen, Shieldbearers (shoot the shield apart or flank), Shinobi (dash), Juggernauts, Oni

## How they fight
- Callouts and "?" / "!" over their heads; they split into pushers, flankers and overwatch
- Grenades on a real arc when you camp; they clear out of yours and dive
- Suppression throws their aim; hurt ones bandage out of sight
- They crouch behind cover and pop up to shoot; they strafe between bursts
- Higher levels react faster and aim sooner (`NPCConfig.Levelled`)
- They run on the players' own gait and body within 150 studs

## Looks
Every enemy wears clothes made to measure on the players' rig (`NPCService/Outfit.luau`); a crew
is a crowd, not clones. Name plates show level and name; elites a gold star, bosses a crown.

## Limits
Camps refill after 50 s to 3 min, never near a player; at most 24 enemies alive on a server.
