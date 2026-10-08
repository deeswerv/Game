--!strict
-- The city kit, drawn by this client from the meshes' own data -- nothing to import or upload.
--
-- Downtown's cars, lamps, trees, benches, bins and hydrants are built from parts, each in a
-- Model tagged "KitProp" that says which of the kit's models it is, where that stands and how
-- to paint it (MeshKit.Group). This builds each kit model once, with EditableMesh, from
-- MeshKitGeometry (written by tools/models/build_kit.py in Blender), and draws it over every
-- tagged prop as it streams in: the part-built pieces are hidden on this screen only
-- (LocalTransparencyModifier), and stay exactly where they were for everything else -- they
-- are still what you collide with and what a bullet hits.
--
-- Where a device cannot make meshes (the API is unavailable or over its budget), nothing
-- changes: the part-built props are what it sees.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshKitClient = require(ReplicatedStorage:WaitForChild("MeshKitClient"))
local Data = MeshKitClient.Data

local TAG = "KitProp"

-- --------------------------------------------------------------------------- the props --

local function hideIn(prop: Instance, d: Instance, drawn: Instance)
	if d:IsA("BasePart") and not d:IsDescendantOf(drawn) then
		if d:GetAttribute("KitKeep") then
			local raise = d:GetAttribute("KitRaise")
			if type(raise) == "number" and not d:GetAttribute("KitRaised") then
				d:SetAttribute("KitRaised", true)
				d.CFrame += Vector3.new(0, raise, 0)
			end
		else
			d.LocalTransparencyModifier = 1
		end
	end
end

local function draw(prop: Instance)
	if not prop:IsA("Model") or prop:GetAttribute("KitDrawn") then
		return
	end
	local model = prop:GetAttribute("KitModel")
	local frame = prop:GetAttribute("KitFrame")
	if type(model) ~= "string" or typeof(frame) ~= "CFrame" then
		return
	end
	local pieces = MeshKitClient.Pieces(model)
	if not pieces or not prop.Parent or prop:GetAttribute("KitDrawn") then
		return
	end
	local scale = tonumber(prop:GetAttribute("KitScale")) or 1
	local drawn = Instance.new("Folder")
	drawn.Name = "KitMeshes"
	for role, template in pairs(pieces) do
		local spec = Data[model][role]
		local p = template:Clone()
		p.Name = (prop:GetAttribute("KitName_" .. role) :: string?) or role
		p.Size = spec.size * scale
		p.CFrame = (frame :: CFrame) * CFrame.new(spec.offset * scale)
		local colour = prop:GetAttribute("KitColour_" .. role)
		if typeof(colour) == "Color3" then
			p.Color = colour
		end
		local material = prop:GetAttribute("KitMaterial_" .. role)
		if type(material) == "string" then
			local ok, value = pcall(function()
				return (Enum.Material :: any)[material]
			end)
			if ok and value then
				p.Material = value
			end
		end
		p.Reflectance = tonumber(prop:GetAttribute("KitShine_" .. role)) or 0
		p.Transparency = tonumber(prop:GetAttribute("KitClear_" .. role)) or 0
		p.CastShadow = prop:GetAttribute("KitShadow_" .. role) == true
		p.Parent = drawn
	end
	prop:SetAttribute("KitDrawn", true)
	for _, d in ipairs(prop:GetDescendants()) do
		hideIn(prop, d, drawn)
	end
	-- Pieces of a big prop can stream in after it.
	prop.DescendantAdded:Connect(function(d)
		hideIn(prop, d, drawn)
	end)
	drawn.Parent = prop
end

CollectionService:GetInstanceAddedSignal(TAG):Connect(function(prop)
	task.spawn(draw, prop)
end)
for _, prop in ipairs(CollectionService:GetTagged(TAG)) do
	task.spawn(draw, prop)
end
