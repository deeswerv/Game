--!strict
-- Builds a weapon out of Roblox parts, from geometry recorded off the authored model.
--
-- Roblox meshes have to be uploaded through a human's account, which made every new
-- weapon wait on a manual import. It turns out that is avoidable for these models: every
-- shape in them is a BOX -- checked, not assumed; all their vertices lie on their own
-- bounding-box faces -- so each one can be rebuilt as a Part with the right size, place
-- and rotation. No upload, no moderation, nothing for anyone to do by hand.
--
-- What is lost is the bevelled edge on each box. At these sizes -- the median part is a
-- seventh of a stud across -- that is not visible.
--
-- The data lives in ReplicatedStorage.WeaponParts, one module per weapon, each row being
-- { name, material, sizeX, sizeY, sizeZ, posX, posY, posZ [, 9 rotation terms] } in the
-- source file's own metres.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local WeaponFinish = require(ReplicatedStorage.WeaponFinish)
local WeaponImporter = require(script.Parent.WeaponImporter)

local WeaponBuilder = {}

-- Turn the rows into a Model laid out exactly as the source file has it.
--
-- Pre-scaled on the way in. The source is in metres, where the median part is 0.026
-- across -- under Roblox's 0.05 minimum part size, so building at source scale and
-- scaling afterwards would flatten most of the detail into slabs before anything could
-- rescue it.
function WeaponBuilder.Stage(rows, targetLength: number): (Model, number)
	local lo, hi = math.huge, -math.huge
	for _, r in ipairs(rows) do
		lo = math.min(lo, r[6])
		hi = math.max(hi, r[6])
	end
	local span = hi - lo
	local scale = (span > 1e-6) and (targetLength / span) or 1

	local model = Instance.new("Model")
	for _, r in ipairs(rows) do
		local p = Instance.new("Part")
		p.Name = r[1]
		p.Size = Vector3.new(r[3], r[4], r[5]) * scale
		local pos = Vector3.new(r[6], r[7], r[8]) * scale
		if #r >= 17 then
			p.CFrame = CFrame.new(pos.X, pos.Y, pos.Z,
				r[9], r[10], r[11], r[12], r[13], r[14], r[15], r[16], r[17])
		else
			p.CFrame = CFrame.new(pos)
		end
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		-- Recorded from the file rather than guessed from the colour, so the camo system
		-- knows what every part is made of before it is even painted.
		p:SetAttribute("Finish", r[2])
		p.Parent = model
	end

	-- One pass to give every part its factory colour, material and reflectance.
	WeaponFinish.Restore(model)
	return model, scale
end

-- Build one weapon and publish it as a Tool, exactly as an imported model would be.
--
-- Everything downstream of the staging model is the existing import path, so a built
-- weapon and an imported one are the same kind of thing: same conventions, same magazine
-- tagging, same authored mount points, same welds and sounds.
function WeaponBuilder.Build(weaponName: string, opts)
	opts = opts or {}
	local parts = ReplicatedStorage:FindFirstChild("WeaponParts")
	local module = parts and parts:FindFirstChild(weaponName)
	if not module or not module:IsA("ModuleScript") then
		return weaponName .. ": no part data in ReplicatedStorage.WeaponParts"
	end

	local ok, rows = pcall(require, module)
	if not ok or type(rows) ~= "table" or #rows == 0 then
		return weaponName .. ": part data would not load (" .. tostring(rows) .. ")"
	end

	local length = tonumber(opts.length) or 3.6
	local model = WeaponBuilder.Stage(rows, length)
	model.Name = weaponName .. "_staging"
	model.Parent = ServerStorage

	local result = WeaponImporter.Convert(model, weaponName, opts)
	model:Destroy()
	return string.format("%s: built %d parts from data\n         %s", weaponName, #rows, tostring(result))
end

-- Build everything that has data and is not already in storeitems.
function WeaponBuilder.BuildAll(force: boolean?)
	local lines = {}
	for _, entry in ipairs(WeaponImporter.Set) do
		local existing = ReplicatedStorage.storeitems:FindFirstChild(entry.as)
		local parts = ReplicatedStorage:FindFirstChild("WeaponParts")
		local hasData = parts and parts:FindFirstChild(entry.as) ~= nil
		if not hasData then
			-- Nothing recorded for it; it is either already in, or still needs a real import.
		elseif existing and not force then
			table.insert(lines, string.format("%-10s already in storeitems, left alone", entry.as))
		else
			table.insert(lines, WeaponBuilder.Build(entry.as, {
				length = entry.length, grip = entry.grip,
			}))
		end
	end
	return table.concat(lines, "\n")
end

return WeaponBuilder
