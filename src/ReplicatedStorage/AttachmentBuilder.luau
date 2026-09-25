--!strict
-- Puts attachments onto a weapon.
--
-- Mount points are worked out from the weapon's own parts rather than authored per gun:
-- the sight sits on top of whatever passes for a receiver, the muzzle device goes on the
-- front face of the muzzle, and so on. That means a weapon supports the whole catalogue
-- as soon as it has the usual pieces, and a new weapon needs nothing added here.
--
-- Used on the server to fit out the real weapon templates, and on the client to draw the
-- customisation preview, so both see exactly the same thing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)

local AttachmentBuilder = {}

local FOLDER_NAME = "Attachments"

-- The weapon's own axes, in Handle space. Every model in this game is built with the bore
-- along the handle's -Z, which is what the pose solver relies on too.
local function weaponAxes(tool: Instance)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return nil
	end
	local barrel = (tool:FindFirstChild("Barrel") or tool:FindFirstChild("BarrelTop")) :: BasePart?
	local muzzle = tool:FindFirstChild("Muzzle") :: BasePart?
	local bore = Vector3.new(0, 0, -1)
	if barrel and muzzle and (muzzle.Position - barrel.Position).Magnitude > 0.05 then
		bore = handle.CFrame:VectorToObjectSpace((muzzle.Position - barrel.Position).Unit)
	end
	return handle, bore.Unit
end

-- How far a part reaches from its own centre along one of the Handle's axes.
--
-- Part.Size is in the part's own frame, and the converted models are full of rotated
-- unions, so half a size component is not half an extent along the weapon. Projecting all
-- three of the part's axes onto the one we care about gives the true reach. Using the
-- largest size component instead -- which is what the first attempt did -- overshot the
-- barrel by half a stud and left muzzle devices hanging in front of the gun.
local function extentAlong(handle: BasePart, part: BasePart, axis: Vector3): number
	local rel = handle.CFrame:ToObjectSpace(part.CFrame)
	local size = part.Size
	return 0.5 * (math.abs(rel.XVector:Dot(axis)) * size.X
		+ math.abs(rel.YVector:Dot(axis)) * size.Y
		+ math.abs(rel.ZVector:Dot(axis)) * size.Z)
end

-- How far an attachment part reaches along the bore from the mount point.
--
-- A "Cylinder" part is built lying along the weapon in Apply -- its size is swapped and it
-- is turned ninety degrees -- so its length down the bore is the Y of the authored size,
-- not the Z. Getting this wrong makes a suppressor look half as long as it is.
local function partSpanZ(s): (number, number)
	local half = (s.shape == "Cylinder" and s.size.Y or s.size.Z) * 0.5
	return s.offset.Z - half, s.offset.Z + half
end

-- Where a slot's attachment should sit, as a CFrame in Handle space.
--
-- `option` is optional but worth passing: it lets a top-mounted attachment be raised only
-- over what it actually covers, rather than over the tallest thing anywhere on the gun.
function AttachmentBuilder.MountCFrame(tool: Instance, slot: string, option): CFrame?
	local spec = AttachmentConfig.Mounts[slot]
	if not spec then
		return nil
	end
	local handle, bore = weaponAxes(tool)
	if not handle then
		return nil
	end

	-- An authored mount point always wins. These come from the weapon's own source file --
	-- the artist marked where the sight, grip and stock bolt on -- so there is nothing to
	-- derive and nothing to get wrong. WeaponMounts stamps them onto the Handle at import.
	local authored = handle:FindFirstChild("Mount_" .. slot)
	if authored and authored:IsA("Attachment") then
		return CFrame.new(authored.Position)
	end

	-- The muzzle is a special case. The Muzzle part is a flash-spawn marker deliberately
	-- sitting ahead of the barrel so shots do not start inside the gun -- on the converted
	-- models that is nearly half a stud out. Hanging a suppressor off it left the device
	-- floating in front of the weapon. A muzzle device instead goes where the barrel
	-- visually ends, while staying on the bore line the marker defines.
	if slot == "Muzzle" then
		local muzzle = tool:FindFirstChild("Muzzle") :: BasePart?
		if not muzzle then
			return nil
		end
		local bore = handle.CFrame:PointToObjectSpace(muzzle.Position)
		local existing = tool:FindFirstChild(FOLDER_NAME)
		local frontZ = math.huge
		for _, p in ipairs(tool:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1
				and not (existing and p:IsDescendantOf(existing)) then
				local z = handle.CFrame:PointToObjectSpace(p.Position).Z
					- extentAlong(handle, p, Vector3.zAxis)
				if z < frontZ then
					frontZ = z
				end
			end
		end
		if frontZ == math.huge then
			frontZ = bore.Z
		end
		-- Butted up against the barrel end, on the bore line.
		return CFrame.new(Vector3.new(bore.X, bore.Y, frontZ + 0.02))
	end

	local host: BasePart? = nil
	for _, name in ipairs(spec.hosts) do
		local found = tool:FindFirstChild(name)
		if found and found:IsA("BasePart") then
			host = found
			break
		end
	end
	if not host then
		return nil
	end

	local centre = handle.CFrame:PointToObjectSpace(host.Position)
	local point = centre

	-- Sit on the named face of the host, so an attachment rests on the surface rather than
	-- inside the part. Extents are measured along the weapon's axes, not the part's own.
	if spec.face == "Top" then
		-- An optic has to clear the weapon's own irons where it OVERLAPS them, or a scope
		-- ends up sunk into the front sight block.
		--
		-- It must not clear them everywhere, though, which is what this used to do: taking
		-- the tallest point anywhere on the weapon lifted a red dot the full height of a
		-- rear sight blade half the gun away from it, and left the sight visibly hovering
		-- over the rail with daylight underneath. Only obstacles the attachment actually
		-- sits over count.
		local top = centre.Y + extentAlong(handle, host, Vector3.yAxis)

		local lo, hi = -math.huge, math.huge
		if option and option.parts and #option.parts > 0 then
			lo, hi = math.huge, -math.huge
			for _, s in ipairs(option.parts) do
				local a, b = partSpanZ(s)
				lo = math.min(lo, centre.Z + a)
				hi = math.max(hi, centre.Z + b)
			end
		end

		local existing = tool:FindFirstChild(FOLDER_NAME)
		for _, p in ipairs(tool:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1
				and not (existing and p:IsDescendantOf(existing)) then
				local rel = handle.CFrame:PointToObjectSpace(p.Position)
				local halfZ = extentAlong(handle, p, Vector3.zAxis)
				if rel.Z + halfZ > lo and rel.Z - halfZ < hi then
					local y = rel.Y + extentAlong(handle, p, Vector3.yAxis)
					if y > top then
						top = y
					end
				end
			end
		end
		point = Vector3.new(centre.X, top, centre.Z)
	elseif spec.face == "Bottom" then
		point -= Vector3.new(0, extentAlong(handle, host, Vector3.yAxis), 0)
	elseif spec.face == "Front" then
		point -= Vector3.new(0, 0, extentAlong(handle, host, Vector3.zAxis))
	elseif spec.face == "Rear" then
		point += Vector3.new(0, 0, extentAlong(handle, host, Vector3.zAxis))
	elseif spec.face == "Side" then
		point += Vector3.new(extentAlong(handle, host, Vector3.xAxis),
			-extentAlong(handle, host, Vector3.yAxis) * 0.3, 0)
	end

	return CFrame.new(point)
end

-- Can this weapon take this kind of attachment at all?
--
-- Decided by whether the weapon has anywhere to put it, rather than by a compatibility
-- list per weapon: a pump shotgun has no detachable magazine and a pistol has no stock,
-- and both facts are already true of their models. The workshop hides slots that fail
-- this, so a player is never offered a choice that would do nothing.
function AttachmentBuilder.Supports(tool: Instance, slot: string): boolean
	return AttachmentBuilder.MountCFrame(tool, slot) ~= nil
end

-- Remove anything this module previously added.
function AttachmentBuilder.Clear(tool: Instance)
	local folder = tool:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

-- Fit a whole loadout: { Sight = "RedDot", Muzzle = "Suppressor", ... }.
-- Anything unknown is skipped rather than erroring, so a stale save cannot break a weapon.
function AttachmentBuilder.Apply(tool: Instance, loadout: { [string]: string }?)
	AttachmentBuilder.Clear(tool)
	if not loadout then
		return
	end
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local added = 0
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local id = loadout[slot]
		local option = id and AttachmentConfig.Find(slot, id)
		if option and #option.parts > 0 then
			local mount = AttachmentBuilder.MountCFrame(tool, slot, option)
			if mount then
				for _, spec in ipairs(option.parts) do
					local part = Instance.new("Part")
					part.Name = slot .. "_" .. option.id
					part.Size = spec.size
					part.Color = spec.colour
					part.Material = spec.material or Enum.Material.SmoothPlastic
					part.Transparency = spec.transparency or 0
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Massless = true
					part.CastShadow = false
					part.TopSurface = Enum.SurfaceType.Smooth
					part.BottomSurface = Enum.SurfaceType.Smooth

					if spec.shape == "Cylinder" then
						-- A Roblox cylinder runs along X, but these are described running
						-- down the barrel, so it is turned and its size swapped to match.
						part.Shape = Enum.PartType.Cylinder
						part.Size = Vector3.new(spec.size.Y, spec.size.X, spec.size.Z)
					elseif spec.shape == "Ball" then
						part.Shape = Enum.PartType.Ball
					end

					local offset = mount * CFrame.new(spec.offset)
					if spec.shape == "Cylinder" then
						offset = offset * CFrame.Angles(0, math.rad(90), 0)
					end
					part.CFrame = handle.CFrame * offset
					part.Parent = folder

					local weld = Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = part
					weld.Parent = part
					added += 1
				end
			end
		end
	end

	if added > 0 then
		folder.Parent = tool
	else
		folder:Destroy()
	end
	return added
end

return AttachmentBuilder
