--!strict
-- Crystal nodes: the reason to look at the world rather than run the path between fights.
--
-- Coins come from killing; crystals come from exploring. Keeping them separate means the
-- things they buy can differ in KIND rather than just in price.
--
-- Every position below was found by sampling the zone, casting for real walkable ground
-- (skipping non-collidable hits, which is how you avoid planting a crystal on a tree
-- canopy), and rejecting anything with something solid in the 5x5x5 box above it.

local CrystalConfig = {}

CrystalConfig.RESPAWN_MIN = 100
CrystalConfig.RESPAWN_MAX = 190
CrystalConfig.HARVEST_SECONDS = 1.2     -- hold time on the prompt

-- Richer the further from safety, same direction the enemy levels run.
CrystalConfig.Zones = {
	-- All crystals now sit in one worked seam inside the mine, so there is one entry.
	-- The old per-island entries are kept because nothing costs anything to leave here and
	-- a node placed outside later should still find its colour rather than erroring.
	Mine    = { yield = { 2, 5 }, colour = Color3.fromRGB(168, 140, 255) },
	Harbour = { yield = { 1, 2 }, colour = Color3.fromRGB(120, 215, 255) },
	Flats   = { yield = { 2, 4 }, colour = Color3.fromRGB(150, 130, 255) },
	Reach   = { yield = { 3, 6 }, colour = Color3.fromRGB(255, 150, 210) },
}

-- Nodes are no longer scattered across the islands. They live in the mine, laid out in two
-- worked rows plus a cluster at the far wall -- a seam somebody dug, not litter dropped
-- wherever an algorithm found flat ground. The positions come from MineService.NodePositions
-- at build time, so the mine's layout and the crystals can never drift apart.
CrystalConfig.Nodes = {}

-- What crystals buy, spoken for through the Quartermaster rather than a new screen.
CrystalConfig.CRAFT_COST = 12

return CrystalConfig
