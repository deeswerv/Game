--!strict
-- Rebuilds the playable place from place/base.rbxl + src/.
--   1. Copies every script in tools/map.json from src/ back into the place. A mapped file
--      that has been deleted from src/ retires its script.
--   2. Creates a script for every NEW .luau file under src/, at the instance path its folders
--      spell out (Name.luau = ModuleScript, .client.luau = LocalScript, .server.luau = Script,
--      init.*.luau = the folder itself).
--   3. Runs each tools/patches/*.luau (sorted) for structural changes (removed instances,
--      lighting, props...).
--   4. Compiles every script in the result to catch syntax errors.
--   5. Writes build/Game.rbxl and a sourcemap.json of the result for luau-lsp.
-- Usage: lune run tools/build.luau
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local process = require("@lune/process")

local game = roblox.deserializePlace(fs.readFile("place/base.rbxl"))
local mapping = serde.decode("json", fs.readFile("tools/map.json"))

-- Which file each script instance's source lives in, for the sourcemap.
local fileOf: { [any]: string } = {}

local function resolve(path: { number }): any
	local inst: any = game
	for _, i in path do
		inst = inst:GetChildren()[i]
		assert(inst, "bad index path")
	end
	return inst
end

-- 1. Resolve every mapped instance before changing anything so index paths stay valid.
local mapped: { [string]: boolean } = {}
local targets = {}
for _, entry in mapping do
	local inst = resolve(entry.path)
	assert(inst.ClassName == entry.class, `class mismatch for {entry.file}`)
	table.insert(targets, { inst = inst, entry = entry })
	mapped[entry.file] = true
end
local synced = 0
for _, t in targets do
	if fs.isFile(t.entry.file) then
		local src = fs.readFile(t.entry.file)
		if t.inst.Source ~= src then
			t.inst.Source = src
			synced += 1
		end
		fileOf[t.inst] = t.entry.file
	else
		print(`retired script {t.inst:GetFullName()}`)
		t.inst.Parent = nil
	end
end
print(`synced {synced} changed scripts`)

-- Helpers shared with patches.
local ctx = {}
ctx.game = game
ctx.roblox = roblox
ctx.fs = fs

function ctx.find(path: string): any
	local inst: any = game
	for part in string.gmatch(path, "[^/]+") do
		local nextInst = inst:FindFirstChild(part)
		if not nextInst and inst == game then
			local ok, svc = pcall(function()
				return game:GetService(part)
			end)
			if ok then
				nextInst = svc
			end
		end
		if not nextInst then
			return nil
		end
		inst = nextInst
	end
	return inst
end

function ctx.get(path: string): any
	local inst = ctx.find(path)
	assert(inst, `missing instance {path}`)
	return inst
end

function ctx.new(className: string, parent: any, props: { [string]: any }?): any
	local inst = roblox.Instance.new(className)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	inst.Parent = parent
	return inst
end

--- Creates (or replaces the source of) a script whose source lives in src/.
function ctx.script(parent: any, name: string, className: string, file: string): any
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName ~= className then
		existing.Parent = nil
		existing = nil
	end
	local inst = existing or ctx.new(className, parent, { Name = name })
	inst.Source = fs.readFile(file)
	fileOf[inst] = file
	return inst
end

function ctx.remove(path: string)
	local inst = ctx.find(path)
	if inst then
		print(`removed {inst:GetFullName()}`)
		inst.Parent = nil
	else
		print(`(already absent) {path}`)
	end
end

-- 2. New files.
local function walk(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			walk(full, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, full)
		end
	end
end
local files = {}
walk("src", files)
local fresh = {}
for _, file in files do
	if not mapped[file] then
		table.insert(fresh, file)
	end
end
-- Parents before children: a shorter path can only be an ancestor.
table.sort(fresh, function(a, b)
	local da = select(2, string.gsub(a, "/", ""))
	local db = select(2, string.gsub(b, "/", ""))
	if da ~= db then
		return da < db
	end
	return a < b
end)
for _, file in fresh do
	local rel = string.sub(file, 5) -- strip "src/"
	local parts = string.split(rel, "/")
	local base = table.remove(parts) :: string
	local className = "ModuleScript"
	local stem = string.sub(base, 1, -6)
	if string.sub(stem, -7) == ".server" then
		className, stem = "Script", string.sub(stem, 1, -8)
	elseif string.sub(stem, -7) == ".client" then
		className, stem = "LocalScript", string.sub(stem, 1, -8)
	end
	local name = stem
	if stem == "init" then
		name = table.remove(parts) :: string
	end
	local parent = ctx.find(table.concat(parts, "/"))
	if not parent and #parts > 1 then
		-- A new plain folder of modules (no init.luau): make the Folder it lives in.
		local above = ctx.find(table.concat(parts, "/", 1, #parts - 1))
		if above then
			parent = ctx.new("Folder", above, { Name = parts[#parts] })
			print(`created Folder {parent:GetFullName()}`)
		end
	end
	assert(parent, `no instance for folder of new file {file}`)
	ctx.script(parent, name, className, file)
	print(`created {className} {parent:GetFullName()}.{name}`)
end

-- 3. Patches.
local patchFiles = fs.readDir("tools/patches")
table.sort(patchFiles)
for _, f in patchFiles do
	if string.sub(f, -5) == ".luau" then
		print(`patch {f}`)
		local chunk = luau.load(fs.readFile("tools/patches/" .. f), { debugName = f })
		local apply = chunk()
		apply(ctx)
	end
end

-- 4. Compile check everything that ends up in the place.
local failures = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		local ok, err = pcall(luau.compile, d.Source)
		if not ok then
			failures += 1
			print(`COMPILE ERROR {d:GetFullName()}: {err}`)
		end
	end
end
if failures > 0 then
	print(`{failures} scripts failed to compile; not writing build`)
	process.exit(1)
end

-- 5. Output.
if not fs.isDir("build") then
	fs.writeDir("build")
end
-- Stamp the build, so a place opened in Studio can say which build it is (the owner panel and
-- the title screen show it, and the server prints it). "Nothing changed" is very often an
-- older copy of the file; the stamp settles that at a glance.
do
	local stamp = os.date("!%Y-%m-%d %H:%M UTC")
	game:GetService("ReplicatedStorage"):SetAttribute("BuildStamp", stamp)
	print(`build stamp {stamp}`)
end
fs.writeFile("build/Game.rbxl", roblox.serializePlace(game))
print("wrote build/Game.rbxl")

local SKIP = { Pose = true, Keyframe = true, KeyframeMarker = true }
local function node(inst: any): any
	local n: any = { name = inst.Name, className = inst.ClassName }
	if fileOf[inst] then
		n.filePaths = { fileOf[inst] }
	end
	local children = {}
	for _, child in inst:GetChildren() do
		if not SKIP[child.ClassName] then
			table.insert(children, node(child))
		end
	end
	if #children > 0 then
		n.children = children
	end
	return n
end
local root: any = { name = "Game", className = "DataModel", children = {} }
for _, svc in game:GetChildren() do
	table.insert(root.children, node(svc))
end
fs.writeFile("sourcemap.json", serde.encode("json", root, false))
