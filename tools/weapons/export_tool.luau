--!nocheck
-- Export a built weapon Tool from build/Game.rbxl for tools/weapons/preview.mjs to draw, so a
-- rebuilt weapon can be looked at exactly as the build assembled it.
--
--   lune run tools/weapons/export_tool.luau -- Warden_DarkMatter out/tool.json
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
local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local tool = game:GetService("ReplicatedStorage").storeitems:FindFirstChild(args[1])
assert(tool, "no such tool: " .. tostring(args[1]))
local handle = tool.Handle
local parts = {}
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("BasePart") and d ~= handle and d.Transparency < 0.98 then
		local rel = handle.CFrame:ToObjectSpace(d.CFrame)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = rel:GetComponents()
		local shape = "Block"
		if d:IsA("WedgePart") then
			shape = "Wedge"
		elseif d:IsA("Part") then
			shape = d.Shape.Name
		end
		table.insert(parts, {
			name = d.Name, shape = shape, size = { d.Size.X, d.Size.Y, d.Size.Z }, centre = { x, y, z },
			axes = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } },
			colour = { d.Color.R, d.Color.G, d.Color.B }, material = d.Material.Name, transparency = d.Transparency,
		})
	end
end
fs.writeFile(args[2], serde.encode("json", { parts = parts }))
print(("exported %d parts of %s"):format(#parts, args[1]))
