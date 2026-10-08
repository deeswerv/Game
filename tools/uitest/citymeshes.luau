--!nocheck
-- The city kit drawn by each client (CityMeshes) over Downtown's part-built props, with no
-- import: checked against a stand-in AssetService that records the EditableMesh calls.
--
--   * every kit-able prop is a "KitProp" Model saying which model, where and how painted;
--   * on a device that cannot make meshes nothing changes -- the part-built props are seen;
--   * where it can, every prop gets the kit's pieces, the manifest's size, in the right place
--     (cars nose first toward -Z), painted as asked, and the meshes face outward;
--   * the part-built pieces are hidden on that screen only and stay solid for everything else;
--     a taxi's light is kept and lifted onto the kit's roof; the GRAPHICS setting never shows
--     a hidden piece again.
--
--   lune run tools/uitest/citymeshes.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local World = require("./world")
local R = World.R

local Vector3 = roblox.Vector3

task.delay(240, function()
	print("\27[31mtimed out\27[0m")
	process.exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local rs = World.service("ReplicatedStorage")
local Data = World.require(rs:FindFirstChild("MeshKitData"))
local Downtown = World.require(sss.DistrictService.Downtown)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, Vector3.new(-155, 1000, 1500))

local props = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("KitModel") then
		table.insert(props, d)
	end
end
local kinds = {}
for _, p in ipairs(props) do
	kinds[p:GetAttribute("KitModel")] = (kinds[p:GetAttribute("KitModel")] or 0) + 1
end
check(#props > 100 and kinds.Sedan and kinds.Hatch and kinds.SUV and kinds.StreetLamp and (kinds.Tree or kinds.TreeTall)
	and kinds.Bench and kinds.Bin and kinds.Hydrant, ("%d props marked for the kit"):format(#props))

-- The stand-in: EditableMesh records what it is given; a MeshPart comes back sized to it.
local made, volumeSign, normalsSet = 0, 0, 0
local failing = true
R.ClassMethods.AssetService = {
	CreateEditableMesh = function()
		if failing then
			error("EditableMesh is not enabled")
		end
		local mesh = { verts = {}, tris = {} }
		function mesh.AddVertex(self, p)
			table.insert(self.verts, p)
			return #self.verts
		end
		function mesh.AddNormal(_, n)
			return n
		end
		function mesh.AddTriangle(self, a, b, c)
			table.insert(self.tris, { a, b, c })
			return #self.tris
		end
		function mesh.SetFaceNormals()
			normalsSet += 1
		end
		return mesh
	end,
	CreateMeshPartAsync = function(_, mesh)
		made += 1
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, v in ipairs(mesh.verts) do
			lo, hi = lo:Min(v), hi:Max(v)
		end
		local vol = 0
		for _, t in ipairs(mesh.tris) do
			local a, b, c = mesh.verts[t[1]], mesh.verts[t[2]], mesh.verts[t[3]]
			vol += a:Dot(b:Cross(c))
		end
		volumeSign += if vol > 0 then 1 else -1
		local part = R.new("MeshPart")
		part.Size = hi - lo
		return part
	end,
}

local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local function ltm(p)
	return p.LocalTransparencyModifier or 0
end

print("a device that cannot make meshes")
World.run(sps:FindFirstChild("CityMeshes"))
World.advance(0.5)
local hidden = 0
for _, p in ipairs(props) do
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") and ltm(d) == 1 then
			hidden += 1
		end
	end
end
check(hidden == 0 and props[1]:FindFirstChild("KitMeshes") == nil, "sees the part-built props, untouched")

print("a device that can")
failing = false
World.run(sps:FindFirstChild("CityMeshes"))
World.advance(1)
local models = 0
for _ in pairs(Data) do
	models += 1
end
check(made > 0 and volumeSign == made, ("%d meshes made, every one facing outward"):format(made))
check(normalsSet > 1000, "with the modelled normals")
local drawn, wrong = 0, nil
for _, p in ipairs(props) do
	local meshes = p:FindFirstChild("KitMeshes")
	local spec = Data[p:GetAttribute("KitModel")]
	local n = 0
	if meshes then
		for _, m in ipairs(meshes:GetChildren()) do
			n += 1
		end
	end
	local want = 0
	for _ in pairs(spec) do
		want += 1
	end
	if meshes and n == want then
		drawn += 1
	elseif not wrong then
		wrong = p:GetFullName()
	end
end
check(drawn == #props, ("every prop drawn from the kit (%d of %d) %s"):format(drawn, #props, wrong or ""))

-- Hidden here, solid everywhere.
local shown, solid, total = 0, 0, 0
for _, p in ipairs(props) do
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsDescendantOf(p:FindFirstChild("KitMeshes")) then
			total += 1
			if ltm(d) ~= 1 and not d:GetAttribute("KitKeep") then
				shown += 1
			end
			if d.CanCollide then
				solid += 1
			end
		end
	end
end
check(shown == 0, ("every part-built piece hidden on this screen (%d of %d still shown)"):format(shown, total))
check(solid > #props, "and still solid for everything else")

-- Cars nose first; the shell over the body; the right size and paint.
local good, cars, why = 0, 0, ""
for _, p in ipairs(props) do
	local kind = p:GetAttribute("KitModel")
	if kind == "Sedan" or kind == "Hatch" or kind == "SUV" then
		cars += 1
		local body = p:FindFirstChild("Body")
		local meshes = p:FindFirstChild("KitMeshes")
		local shell = meshes and meshes:FindFirstChild("Paintwork")
		local lamp = meshes and meshes:FindFirstChild("Headlight")
		if body and shell and lamp then
			local rel = body.CFrame:PointToObjectSpace(shell.Position)
			local nose = body.CFrame:PointToObjectSpace(lamp.Position)
			if math.abs(rel.X) < 0.2 and math.abs(rel.Z) < 0.3 and nose.Z < -3 and (shell.Size - Data[kind].Body.size).Magnitude < 0.01
				and shell.Color == p:GetAttribute("KitColour_Body") then
				good += 1
			else
				why = ("%s rel (%.2f, %.2f) nose %.2f"):format(p:GetFullName(), rel.X, rel.Z, nose.Z)
			end
		end
	end
end
check(cars > 6 and good == cars, ("every car's shell on its body, nose forward, its paint (%d of %d) %s"):format(good, cars, why))

local globes = 0
for _, p in ipairs(props) do
	if p:GetAttribute("KitModel") == "StreetLamp" then
		local meshes = p:FindFirstChild("KitMeshes")
		if meshes and meshes:FindFirstChild("LanternGlass") then
			globes += 1
		end
	end
end
check(globes == kinds.StreetLamp, "every lamp's globe is LanternGlass (it lights at night)")

local taxiLight = nil
for _, d in ipairs(folder:GetDescendants()) do
	if d.Name == "TaxiLight" then
		taxiLight = d
	end
end
check(taxiLight and ltm(taxiLight) == 0 and taxiLight:GetAttribute("KitRaised") == true, "a taxi keeps its light, lifted onto the roof")

print("the GRAPHICS setting")
World.run(sps:FindFirstChild("GraphicsQuality"))
World.player:SetAttribute("GraphicsQuality", 1)
World.advance(0.2)
World.player:SetAttribute("GraphicsQuality", 3)
World.advance(0.2)
local back = 0
for _, p in ipairs(props) do
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("BasePart") and not d:IsDescendantOf(p:FindFirstChild("KitMeshes")) and ltm(d) ~= 1
			and not d:GetAttribute("KitKeep") then
			back += 1
		end
	end
end
check(back == 0, ("never shows a hidden piece again (%d shown)"):format(back))

print(if failures == 0 then "\27[32mall citymeshes checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
