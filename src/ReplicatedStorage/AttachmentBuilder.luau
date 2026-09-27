--!strict
-- Puts attachments onto a weapon.
--
-- Every attachment is modelled for the weapon it fits (AttachmentModels, generated from the
-- artist's GLBs): its pieces are laid out in the weapon's Handle space exactly where the
-- artist put them, so fitting one is placing parts, not working out where they might go.
-- A weapon takes a slot only when a model exists for it -- there is no guessing a mount
-- point off the geometry any more, and so no floating sight on a gun it was never made for.
--
-- Fitting an attachment can also change the weapon itself, and all of it is undone by
-- Clear:
--   hides   the stock parts it replaces go invisible -- the irons fold away under an optic,
--           the standard magazine under the extended one, the brake under a suppressor.
--   shift   a muzzle device moves the Muzzle marker (where rounds, flash and tracers start)
--           and the weapon's authored flash out to the front of the device.
--   magazine an extended mag's pieces are the magazine the reload takes out, in place of
--           the standard one's.
--
-- Used on the server to fit out the real weapons, and on the client to draw the armory
-- preview, so both see exactly the same thing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local AttachmentModels = require(ReplicatedStorage.AttachmentModels)

local AttachmentBuilder = {}

local FOLDER_NAME = "Attachments"
-- On an attachment's own parts, so Clear can find the ones that cannot live in the folder.
local ADDED = "AttachmentPart"
-- On a stock part an attachment covers: its own Transparency, to put back.
local HIDDEN = "AttHidden"
-- On a stock magazine part: it was tagged MagPart before an extended mag took over.
local MAG_OFF = "AttMagOff"
-- On a part a muzzle device moved: how far, along the Handle's Z, to move it back.
local SHIFTED = "AttShift"

-- The models fitted to this weapon, by slot, or nil. Keyed by the weapon's name, which the
-- live Tool, the storeitems template and every preview copy all share.
local function modelsFor(tool: Instance)
	return AttachmentModels.Weapons[tool.Name]
end

--- Can this weapon take this kind of attachment at all?
---
--- Only where a model has been fitted to it. The armory hides slots that fail this, so a
--- player is never offered a choice that would do nothing.
function AttachmentBuilder.Supports(tool: Instance, slot: string): boolean
	return AttachmentModels.HasSlot(tool.Name, slot)
end

--- Does this weapon take any attachment? The armory says so rather than showing an empty
--- editor for a gun nothing has been made for.
function AttachmentBuilder.SupportsAny(tool: Instance): boolean
	for _, slot in ipairs(AttachmentConfig.Slots) do
		if AttachmentBuilder.Supports(tool, slot) then
			return true
		end
	end
	return false
end

--- Where a slot's attachment sits, in Handle space: the centre of its fitted pieces for the
--- first option that has a model. Kept for anything that wants to frame a slot (the old
--- per-geometry mount finder is gone).
function AttachmentBuilder.MountCFrame(tool: Instance, slot: string): CFrame?
	local models = modelsFor(tool)
	local bySlot = models and models[slot]
	if not bySlot then
		return nil
	end
	for _, option in ipairs(AttachmentConfig.Options[slot] or {}) do
		local fitted = bySlot[option.id]
		if fitted and #fitted.parts > 0 then
			local sum = Vector3.zero
			for _, piece in ipairs(fitted.parts) do
				sum += piece.cf.Position
			end
			return CFrame.new(sum / #fitted.parts)
		end
	end
	return nil
end

-- Move a part along the Handle's Z by `dz` studs, keeping it welded.
--
-- A WeldConstraint captures the offset between its parts when it is enabled, so the weld is
-- switched off, the part moved and the weld switched back on. Moving it with the weld live
-- would drag the whole assembly -- the player's arm included -- rather than the one part.
local function slide(handle: BasePart, part: BasePart, dz: number)
	local welds = {}
	for _, d in ipairs(part:GetChildren()) do
		if d:IsA("WeldConstraint") and d.Enabled then
			d.Enabled = false
			table.insert(welds, d)
		end
	end
	local rel = handle.CFrame:ToObjectSpace(part.CFrame)
	part.CFrame = handle.CFrame * (CFrame.new(0, 0, dz) * rel)
	for _, weld in ipairs(welds) do
		weld.Enabled = true
	end
end

-- The parts a muzzle device carries forward with it: the marker every shot starts from and
-- the weapon's own authored flash.
local function muzzleParts(tool: Instance): { BasePart }
	local out = {}
	local marker = tool:FindFirstChild("Muzzle")
	if marker and marker:IsA("BasePart") then
		table.insert(out, marker)
	end
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("DMRole") == "MuzzleFlash" then
			table.insert(out, d)
		end
	end
	return out
end

--- Remove everything this module added, and put back everything it changed.
function AttachmentBuilder.Clear(tool: Instance)
	local folder = tool:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
	local handle = tool:FindFirstChild("Handle")
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute(ADDED) == true then
				d:Destroy()
			else
				local was = d:GetAttribute(HIDDEN)
				if type(was) == "number" then
					d.Transparency = was
					d:SetAttribute(HIDDEN, nil)
				end
				if d:GetAttribute(MAG_OFF) == true then
					d:SetAttribute("MagPart", true)
					d:SetAttribute(MAG_OFF, nil)
				end
				local dz = d:GetAttribute(SHIFTED)
				if type(dz) == "number" then
					if handle and handle:IsA("BasePart") then
						slide(handle, d, -dz)
					end
					d:SetAttribute(SHIFTED, nil)
				end
			end
		end
	end
end

-- One piece of a fitted attachment, as a real part welded to the Handle.
local function build(handle: BasePart, piece: AttachmentModels.Piece, slot: string, id: string): BasePart
	local part = Instance.new("Part")
	part.Name = piece.name
	if piece.shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
	elseif piece.shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	end
	part.Size = piece.size
	part.CFrame = handle.CFrame * piece.cf
	part.Color = piece.colour
	part.Material = piece.material
	part.Reflectance = piece.reflectance
	part.Transparency = piece.transparency
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part:SetAttribute(ADDED, true)
	part:SetAttribute("AttachmentSlot", slot)
	part:SetAttribute("AttachmentId", id)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

--- Fit a whole loadout: { Sight = "RedDot", Muzzle = "Suppressor", ... }.
--- Anything unknown, or not modelled for this weapon, is skipped rather than erroring, so a
--- stale save cannot break a weapon. Returns how many parts were added.
function AttachmentBuilder.Apply(tool: Instance, loadout: { [string]: string }?): number
	AttachmentBuilder.Clear(tool)
	if not loadout then
		return 0
	end
	local handle = tool:FindFirstChild("Handle")
	local models = modelsFor(tool)
	if not handle or not handle:IsA("BasePart") or not models then
		return 0
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local added = 0
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local id = loadout[slot]
		local fitted = id and AttachmentConfig.Find(slot, id) and models[slot] and models[slot][id]
		if fitted then
			-- The stock parts it replaces. Hidden by name: a repeated name (the magazine's
			-- two MagMid halves) is only ever listed when every part of that name goes.
			local hides = {}
			for _, name in ipairs(fitted.hides) do
				hides[name] = true
			end
			for _, d in ipairs(tool:GetDescendants()) do
				if d:IsA("BasePart") and hides[d.Name] and d ~= handle
					and d:GetAttribute(ADDED) ~= true and d:GetAttribute(HIDDEN) == nil then
					d:SetAttribute(HIDDEN, d.Transparency)
					d.Transparency = 1
					if d:GetAttribute("MagPart") == true then
						d:SetAttribute("MagPart", nil)
						d:SetAttribute(MAG_OFF, true)
					end
				end
			end

			for _, piece in ipairs(fitted.parts) do
				local part = build(handle, piece, slot, id)
				if slot == "Magazine" then
					-- The reload collects the magazine from the Tool's own children by this
					-- tag, so the extended mag's pieces sit there rather than in the folder.
					part:SetAttribute("MagPart", true)
					part.Parent = tool
				else
					part.Parent = folder
				end
				added += 1
			end

			local dz = fitted.shift
			if slot == "Muzzle" and type(dz) == "number" and dz ~= 0 then
				for _, part in ipairs(muzzleParts(tool)) do
					slide(handle, part, dz)
					part:SetAttribute(SHIFTED, dz)
				end
			end
		end
	end

	if #folder:GetChildren() > 0 then
		folder.Parent = tool
	else
		folder:Destroy()
	end
	return added
end

return AttachmentBuilder
