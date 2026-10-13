---
tags: [system, animation]
---
# Movement & animation

Every body (players and enemies) is the locked **Roblox Boy** rig, posed by the game itself
(`ReplicatedStorage/Motion.luau`, drawn by `MotionAnimator`). Back to [[Home]].

- Walk, run and sprint cycles blended by speed; strafes turn the hips; backpedal plays in reverse
- Sprint: Shift or double-tap W; slide with Ctrl/C while sprinting
- **Crouch**: hold C (half speed, tighter spread)
- **Roll**: Q, about 18 studs in the direction you move
- Jumps tuck the knees; landings dip; a gun drops into a carry when you sprint
- **Emotes**: hold G for the wheel (32 emotes across five pages)
- **Head look**: heads turn where their player looks, and everyone sees it

Checks without Studio: `tools/uitest/movement.luau`; render clips with `tools/mapview/motionclip.luau`.
