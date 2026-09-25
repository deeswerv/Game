--!strict
-- Somewhere to fight over, in Map 2: the stone courtyard between its four pillars.
--
-- It used to be grey blocks and rusty containers dropped on the slab. It is now a designed
-- battleground in the map's own low-poly style -- the raiders' camp, the guard post, a ruined
-- gatehouse in the middle, a walled flank and a terrace -- built by CoverService.Flats, which
-- says what each part is for.
--
-- Every solid piece a person could crouch behind is tagged "Cover", which is what
-- NPCService's cover search prefers; none of it is AI-only furniture.

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBake = require(ServerScriptService.WorldBake)

local CoverService = {}

CoverService.FOLDER = "Map2Cover"
CoverService.TAG = "Cover"

-- The courtyard slab between the pillars: its centre, with y at the top of the slab.
CoverService.CENTRE = Vector3.new(-573, 1.5, 88)

local Flats = require(script.Flats)
CoverService.Flats = Flats

local function folder(): Folder
	local existing = workspace:FindFirstChild(CoverService.FOLDER)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = CoverService.FOLDER
	f.Parent = workspace
	return f
end

-- The ground the battleground owns: the courtyard slab between the pillars, in the world.
CoverService.Footprint = { minX = -624, maxX = -521, minZ = 36, maxZ = 140 }

local function inFootprint(p: Vector3): boolean
	local fp = CoverService.Footprint
	return p.X >= fp.minX and p.X <= fp.maxX and p.Z >= fp.minZ and p.Z <= fp.maxZ
end

--- Whether a built piece counts as cover: solid, and its top (measured in the world, so a
--- stack of logs lying on their sides counts by its top log) at least crouching height.
function CoverService.IsCover(part: BasePart): boolean
	if not part.CanCollide or part.Transparency >= 1 then
		return false
	end
	local cf, size = part.CFrame, part.Size
	local height = math.abs(cf.XVector.Y) * size.X + math.abs(cf.YVector.Y) * size.Y + math.abs(cf.ZVector.Y) * size.Z
	return height >= 0.9 and cf.Position.Y + height / 2 >= CoverService.CENTRE.Y + 1.8
end

function CoverService.Build()
	local f = folder()
	Flats.Build(f, CoverService.CENTRE)
	-- The biome dressing was scattered (and baked) when this was an empty slab. Inside the
	-- pillars the battleground owns the ground now, so a dead tree does not grow through the
	-- guards' wall. Everywhere else it is left exactly as baked.
	local dressing = workspace:FindFirstChild("BiomeDressing")
	if dressing then
		local doomed = {}
		for _, model in ipairs(dressing:GetDescendants()) do
			local part = model:IsA("Model") and model:FindFirstChildWhichIsA("BasePart")
			if part and inFootprint(part.Position) then
				table.insert(doomed, model)
			end
		end
		for _, model in ipairs(doomed) do
			model:Destroy()
		end
	end
	-- Everything a person could crouch behind is cover, for the AI's search as much as for
	-- players.
	local tagged = 0
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") and CoverService.IsCover(d) then
			CollectionService:AddTag(d, CoverService.TAG)
			tagged += 1
		end
	end
	print(("[Cover] the Flats battleground: %d parts, %d of them cover"):format(#f:GetDescendants(), tagged))
	return tagged
end

if not WorldBake.Skip(CoverService.FOLDER, "Cover") then
	local existing = workspace:FindFirstChild(CoverService.FOLDER)
	if existing then
		existing:Destroy()
	end
	CoverService.Build()
end

return CoverService
