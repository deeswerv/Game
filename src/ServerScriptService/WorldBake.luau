--!strict
-- Hand-editable world pieces.
--
-- Everything the build services make used to be generated fresh on every server start, so
-- none of it existed in Edit mode: you could not select a tower, drag a sign or delete one
-- prop, and anything you did change was wiped the next time the game ran.
--
-- Baking stops that. The folder gets a "Baked" attribute, the service sees it and leaves the
-- geometry exactly as it finds it, and the models become ordinary anchored parts you move in
-- Studio like anything built by hand. Services that attach behaviour -- travel prompts,
-- mining prompts -- re-attach it to the parts that are already there, so a portal you drag
-- somewhere else is still a working portal.
--
-- To bake, or to re-bake after changing builder code, run this in the Studio command bar
-- while in EDIT mode, then save the place:
--
--     require(game.ServerScriptService.WorldBake).Bake()
--
-- To throw your edits away and get the generated version back, untick "Baked" on the folder
-- (or delete the folder) and run the game once.

local WorldBake = {}

WorldBake.ATTRIBUTE = "Baked"

-- Folder in workspace -> the module that owns it, in build order. MineService has to come
-- before CrystalService: the seams are placed from the mine's own rooms.
WorldBake.Order = {
	{ folder = "MapExpansion",  module = "MapExpansion" },
	{ folder = "Ascents",       module = "AscentService" },
	{ folder = "Mine",          module = "MineService" },
	{ folder = "Crystals",      module = "CrystalService" },
	{ folder = "BiomeDressing", module = "BiomeService" },
	{ folder = "Arenas",        module = "ArenaService" },
	{ folder = "Map2Cover",     module = "CoverService" },
	{ folder = "TravelGates",   module = "TravelService" },
	{ folder = "Landmarks",     module = "LandmarkService" },
}

function WorldBake.IsBaked(folderName: string): boolean
	local f = workspace:FindFirstChild(folderName)
	return f ~= nil and f:GetAttribute(WorldBake.ATTRIBUTE) == true
end

--- True when the caller should leave its folder alone. Prints, so a world that did not
--- rebuild reads as a decision in the console rather than a mystery.
function WorldBake.Skip(folderName: string, label: string): boolean
	if not WorldBake.IsBaked(folderName) then
		return false
	end
	print(("[%s] baked copy kept -- move it in Studio; untick Baked to regenerate"):format(label))
	return true
end

function WorldBake.Mark(folderName: string)
	local f = workspace:FindFirstChild(folderName)
	if f then
		f:SetAttribute(WorldBake.ATTRIBUTE, true)
	end
end

--- Build every piece into the CURRENT datamodel and mark it hand-editable. Only useful in
--- Edit mode: run it in Play and the result dies with the session.
function WorldBake.Bake(): string
	local lines = {}
	for _, entry in ipairs(WorldBake.Order) do
		local existing = workspace:FindFirstChild(entry.folder)
		if existing then
			existing:SetAttribute(WorldBake.ATTRIBUTE, nil)   -- so Build does not skip itself
		end
		local module = game.ServerScriptService:FindFirstChild(entry.module)
		local ok, err = pcall(function()
			require(module).Build()
		end)
		if ok then
			WorldBake.Mark(entry.folder)
			local f = workspace:FindFirstChild(entry.folder)
			lines[#lines + 1] = ("%-14s %d parts"):format(entry.folder, f and #f:GetDescendants() or 0)
		else
			lines[#lines + 1] = ("%-14s FAILED: %s"):format(entry.folder, tostring(err))
		end
	end
	return table.concat(lines, "\n")
end

return WorldBake
