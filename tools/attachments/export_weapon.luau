--!nocheck
-- Writes one weapon template's parts, in its Handle's space, to JSON -- the other half of
-- what tools/attachments/convert.py needs to fit a GLB's attachment onto the real model.
--
--   lune run tools/attachments/export_weapon.luau -- Carbine_DarkMatter out.json
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local weapon, out = args[1], args[2]
local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local tool = game:GetService("ReplicatedStorage").storeitems:FindFirstChild(weapon)
assert(tool, "no such weapon template: " .. tostring(weapon))
local handle = tool:FindFirstChild("Handle")
local parts = {}
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("BasePart") and d ~= handle then
		local rel = handle.CFrame:ToObjectSpace(d.CFrame)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
		table.insert(parts, {
			name = d.Name,
			class = d.ClassName,
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			size = { d.Size.X, d.Size.Y, d.Size.Z },
			group = d:GetAttribute("DMGroup"),
			colour = { d.Color.R, d.Color.G, d.Color.B },
			material = d.Material.Name,
			transparency = d.Transparency,
			reflectance = d.Reflectance,
			magPart = d:GetAttribute("MagPart"),
		})
	end
end
fs.writeFile(out, serde.encode("json", { weapon = weapon, parts = parts }, true))
print(("wrote %d parts of %s"):format(#parts, weapon))
