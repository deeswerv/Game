--!strict
-- The city kit's meshes on this client, built from their own data with EditableMesh -- nothing
-- to import or upload. MeshKitGeometry (written by tools/models/build_kit.py in Blender) holds
-- every piece; Pieces(model) builds that model's once and hands back MeshPart templates to
-- clone, sized and placed by MeshKitData. Used by CityMeshes (the street props) and CityLife
-- (the pigeons). Where a device cannot make meshes, Pieces returns nil and callers draw parts.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("MeshKitData")) :: any
local Geometry = require(ReplicatedStorage:WaitForChild("MeshKitGeometry")) :: any

local MeshKitClient = {}

MeshKitClient.Data = Data

-- ----------------------------------------------------------------------------- base64 --

local DIGITS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE: { [number]: number } = {}
for i = 1, #DIGITS do
	VALUE[string.byte(DIGITS, i)] = i - 1
end

--- Bytes from base64 text, skipping anything that is not a digit (line breaks, padding).
local function decode(text: string): buffer
	local out = buffer.create(#text * 3 // 4 + 3)
	local n, acc, bits = 0, 0, 0
	for i = 1, #text do
		local v = VALUE[string.byte(text, i)]
		if v then
			acc = acc * 64 + v
			bits += 6
			if bits >= 8 then
				bits -= 8
				local byte = acc // 2 ^ bits
				buffer.writeu8(out, n, byte)
				n += 1
				acc -= byte * 2 ^ bits
			end
		end
	end
	return out
end

-- ------------------------------------------------------------------------- the meshes --

local function contentOf(mesh: any): any
	local ok, content = pcall(function()
		return (Content :: any).fromObject(mesh)
	end)
	return if ok and content then content else mesh
end

--- One piece of one model as a MeshPart, from its data; `withNormals` false makes the device
--- work its own normals out (for an API that will not take ours).
local function piece(model: string, role: string, withNormals: boolean): MeshPart
	local g = Geometry[model][role]
	local half = Data[model][role].size / 2
	local buf = decode(g.data)
	local V, T = g.verts, g.tris
	local mesh = (AssetService :: any):CreateEditableMesh()
	local vids = table.create(V)
	for i = 0, V - 1 do
		local at = i * 6
		vids[i + 1] = mesh:AddVertex(Vector3.new(buffer.readi16(buf, at) / 32767 * half.X,
			buffer.readi16(buf, at + 2) / 32767 * half.Y, buffer.readi16(buf, at + 4) / 32767 * half.Z))
	end
	local nids = {}
	if withNormals then
		nids = table.create(V)
		local base = V * 6
		for i = 0, V - 1 do
			local at = base + i * 3
			local n = Vector3.new(buffer.readi8(buf, at), buffer.readi8(buf, at + 1), buffer.readi8(buf, at + 2))
			nids[i + 1] = mesh:AddNormal(if n.Magnitude > 0 then n.Unit else Vector3.yAxis)
		end
	end
	local base = V * 9
	for t = 0, T - 1 do
		local at = base + t * 6
		local a, b, c = buffer.readu16(buf, at) + 1, buffer.readu16(buf, at + 2) + 1, buffer.readu16(buf, at + 4) + 1
		local face = mesh:AddTriangle(vids[a], vids[b], vids[c])
		if withNormals then
			mesh:SetFaceNormals(face, { nids[a], nids[b], nids[c] })
		end
	end
	local part = (AssetService :: any):CreateMeshPartAsync(contentOf(mesh),
		{ CollisionFidelity = Enum.CollisionFidelity.Box }) :: MeshPart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

type Pieces = { [string]: MeshPart }

-- Each model's pieces once built (FAILED: this device cannot), and who is waiting on a build.
local FAILED: Pieces = {}
local built: { [string]: Pieces } = {}
local building: { [string]: { thread } } = {}
local warned = false

local function build(model: string): Pieces
	local spec, geo = Data[model], Geometry[model]
	if not spec or not geo then
		return FAILED
	end
	local function attempt(withNormals: boolean): Pieces
		local parts: Pieces = {}
		for role in pairs(spec) do
			parts[role] = piece(model, role, withNormals)
		end
		return parts
	end
	local ok, result = pcall(attempt, true)
	if ok then
		return result
	end
	local ok2, result2 = pcall(attempt, false)
	if ok2 then
		return result2
	end
	if not warned then
		warned = true
		warn(("[CityMeshes] no meshes on this device (%s); the part-built props stay"):format(tostring(result)))
	end
	return FAILED
end

--- `model`'s pieces, building them the first time (others asking meanwhile wait for that).
local function piecesOf(model: string): Pieces
	local done = built[model]
	if done ~= nil then
		return done
	end
	local queue = building[model]
	if queue then
		table.insert(queue, coroutine.running())
		return coroutine.yield()
	end
	building[model] = {}
	local result = build(model)
	built[model] = result
	local waiting = building[model]
	building[model] = nil
	for _, thread in ipairs(waiting) do
		task.spawn(thread, result)
	end
	return result
end


--- `model`'s pieces as MeshPart templates (by role), or nil where this device cannot make
--- meshes. Yields the first time a model is asked for.
function MeshKitClient.Pieces(model: string): { [string]: MeshPart }?
	local pieces = piecesOf(model)
	return if pieces == FAILED then nil else pieces
end

--- Forget every model built (or failed), so the next ask builds afresh.
function MeshKitClient.Reset()
	table.clear(built)
	warned = false
end

return MeshKitClient
