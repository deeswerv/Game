--!strict
-- Exports every script in place/base.rbxl into src/ as .luau files and writes
-- tools/map.json (script -> file) plus sourcemap.json for luau-lsp.
-- Usage: lune run tools/export.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local game = roblox.deserializePlace(fs.readFile("place/base.rbxl"))

local SKIP_SOURCEMAP = { Pose = true, Keyframe = true, KeyframeMarker = true }

local function sanitize(name: string): string
	local s = string.gsub(name, "[/\\:%*%?\"<>|]", "_")
	s = string.gsub(s, "^%s+", "")
	s = string.gsub(s, "%s+$", "")
	if s == "" or s == "." or s == ".." then s = "_" end
	return s
end

local function suffixFor(inst: any): string
	if inst.ClassName == "Script" then return ".server.luau" end
	if inst.ClassName == "LocalScript" then return ".client.luau" end
	return ".luau"
end

local function containsScripts(inst: any): boolean
	for _, d in inst:GetDescendants() do
		if d:IsA("LuaSourceContainer") then return true end
	end
	return false
end

local mapping = {}

-- Returns the sourcemap node for inst. dir is the directory this instance's
-- files live in; indexPath is the list of child indices from the DataModel.
local function visit(inst: any, dir: string, indexPath: { number }): any
	local node: any = { name = inst.Name, className = inst.ClassName }
	local isScript = inst:IsA("LuaSourceContainer")
	local hasScriptKids = containsScripts(inst)
	local childDir = dir

	if isScript then
		local file
		if hasScriptKids then
			fs.writeDir(dir)
			file = dir .. "/init" .. suffixFor(inst)
		else
			file = dir .. suffixFor(inst)
		end
		fs.writeFile(file, inst.Source)
		node.filePaths = { file }
		table.insert(mapping, { file = file, path = table.clone(indexPath), class = inst.ClassName })
	elseif hasScriptKids then
		fs.writeDir(dir)
	end

	local used: { [string]: number } = {}
	local children = {}
	for i, child in inst:GetChildren() do
		if not SKIP_SOURCEMAP[child.ClassName] then
			local base = sanitize(child.Name)
			local key = string.lower(base)
			used[key] = (used[key] or 0) + 1
			if used[key] > 1 then base = base .. "~" .. used[key] end
			local p = table.clone(indexPath)
			table.insert(p, i)
			table.insert(children, visit(child, childDir .. "/" .. base, p))
		end
	end
	if #children > 0 then node.children = children end
	return node
end

if fs.isDir("src") then fs.removeDir("src") end
fs.writeDir("src")
local root: any = { name = "Game", className = "DataModel", children = {} }
for i, svc in game:GetChildren() do
	table.insert(root.children, visit(svc, "src/" .. sanitize(svc.Name), { i }))
end
fs.writeFile("sourcemap.json", serde.encode("json", root, false))
fs.writeFile("tools/map.json", serde.encode("json", mapping, true))
print(`exported {#mapping} scripts`)
