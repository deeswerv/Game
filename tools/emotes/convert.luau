--!nocheck
-- Turn the emote pack (assets/emotes/EmotePack_R15R6.rbxm) into compact data modules the game
-- can play without the animations ever being uploaded.
--
--   lune run tools/emotes/convert.luau
--
-- Why not ship the KeyframeSequences as they are: a KeyframeSequence only plays in a live
-- game once it has been published as an animation asset, and the pack is 147,000 Pose
-- instances -- far too many to replicate to every client on join. So each R15 sequence is
-- boiled down here to one track per joint (the key times, the joint's pose at each, and the
-- easing), redundant keys dropped (anything a straight line between its neighbours already
-- reproduces to within 0.004 studs and 0.3 degrees), and packed as base64:
--
--   per key, 15 bytes, little-endian:
--     u16  time in milliseconds
--     i16  x3  rotation quaternion x, y, z  (* 32767; w >= 0 is recovered)
--     i16  x3  position in thousandths of a stud
--     u8       easing: style * 4 + direction
--
-- ReplicatedStorage.EmotePlayer decodes it. One module per emote under
-- src/ReplicatedStorage/EmoteData/, plus Index.luau with every emote's length and looping,
-- which the server needs to know when a play-once emote has finished.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local SOURCE = "assets/emotes/EmotePack_R15R6.rbxm"
local OUT = "src/ReplicatedStorage/EmoteData"

-- id, folder in the pack, main sequence suffix, intro sequence suffix (played once first).
local EMOTES = {
	{ "TakeTheL", "Take the L", "Idle" },
	{ "KazotskyKick", "Kazotsky Kick", "Idle" },
	{ "BoogieDown", "Boogie Down", "Idle" },
	{ "OrangeJustice", "Orange Justice", "Idle" },
	{ "ThumbsUp", "Thumbs Up", "Idle" },
	{ "GamblerDance", "Gambler Dance", "Idle" },
	{ "HonoredOne", "The Honored One", "Idle" },
	{ "CompanyDance", "Company Dance", "Idle" },
	{ "ToiletSit", "Toilet Sit", "Idle", "Sit" },
	{ "Threaten", "Threaten", "Idle" },
	{ "ShadowEmerge", "Shadow Emerge", "Idle" },
	{ "Sunbath", "Sunbath", "Idle" },
	{ "IceCreamCart", "Ice Cream Cart", "Idle" },
	{ "Surfer", "Surfer", "Idle" },
	{ "CoconutLaunch", "Coconut Launch", "Idle" },
	{ "CouchNap", "Couch Nap", "Idle" },
	{ "ReapersRide", "Reaper's Ride", "Idle" },
	{ "TrickOrTreat", "Trick or Treat", "Idle" },
	{ "ZombieDance", "Zombie Dance", "Idle" },
	{ "HeadJuggle", "Head Juggle", "Idle" },
	{ "ParrotWiggle", "Parrot Wiggle", "Idle" },
	{ "Breakdance", "Breakdance", "Idle" },
	{ "TPose", "T-Pose", "Idle" },
	{ "StarEmote", "The Star Emote", "Idle" },
	{ "ShadowStep", "Shadow Step", "Idle" },
	{ "NekoDance", "Neko Dance", "Idle" },
	{ "BlossomBreak", "Blossom Break", "Idle" },
	{ "FloatingMeditation", "Floating Meditation", "Idle" },
	{ "DapUp", "Dap Up", "Idle" },
	{ "Beatbox", "Beatbox", "Idle" },
	{ "DramaticBow", "Dramatic Bow", "Idle" },
	{ "CandyDance", "Candy Dance", "Idle" },
}

-- The joints an R15 character has, by the part they move. Anything else in a sequence is a
-- tool grip or a prop's own rig, which a player character does not have.
local JOINTS = {
	LowerTorso = true, UpperTorso = true, Head = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

local STYLES = { Linear = 0, Constant = 1, Elastic = 2, Cubic = 3, Bounce = 4, CubicV2 = 5 }
local DIRECTIONS = { In = 0, Out = 1, InOut = 2 }

local POS_TOL = 0.004
local ROT_TOL = math.rad(0.3)

-- ------------------------------------------------------------------ maths --

local function quaternion(cf)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local trace = r00 + r11 + r22
	local w, x, y, z
	if trace > 0 then
		local s = math.sqrt(trace + 1) * 2
		w = 0.25 * s
		x = (r21 - r12) / s
		y = (r02 - r20) / s
		z = (r10 - r01) / s
	elseif r00 > r11 and r00 > r22 then
		local s = math.sqrt(1 + r00 - r11 - r22) * 2
		w = (r21 - r12) / s
		x = 0.25 * s
		y = (r01 + r10) / s
		z = (r02 + r20) / s
	elseif r11 > r22 then
		local s = math.sqrt(1 + r11 - r00 - r22) * 2
		w = (r02 - r20) / s
		x = (r01 + r10) / s
		y = 0.25 * s
		z = (r12 + r21) / s
	else
		local s = math.sqrt(1 + r22 - r00 - r11) * 2
		w = (r10 - r01) / s
		x = (r02 + r20) / s
		y = (r12 + r21) / s
		z = 0.25 * s
	end
	local len = math.sqrt(w * w + x * x + y * y + z * z)
	w, x, y, z = w / len, x / len, y / len, z / len
	if w < 0 then
		w, x, y, z = -w, -x, -y, -z
	end
	return w, x, y, z
end

local function angleBetween(a, b): number
	local aw, ax, ay, az = quaternion(a)
	local bw, bx, by, bz = quaternion(b)
	local dot = math.abs(aw * bw + ax * bx + ay * by + az * bz)
	return 2 * math.acos(math.min(1, dot))
end

local function close(a, b): boolean
	return (a.Position - b.Position).Magnitude <= POS_TOL and angleBetween(a, b) <= ROT_TOL
end

-- ----------------------------------------------------------------- base64 --

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(data: string): string
	local out = table.create(math.ceil(#data / 3) * 4)
	for i = 1, #data, 3 do
		local a, b, c = string.byte(data, i, i + 2)
		b = b or 0
		c = c or 0
		local n = a * 65536 + b * 256 + c
		local chunk = #data - i + 1
		table.insert(out, ALPHABET:sub(n // 262144 + 1, n // 262144 + 1))
		table.insert(out, ALPHABET:sub(n // 4096 % 64 + 1, n // 4096 % 64 + 1))
		table.insert(out, chunk > 1 and ALPHABET:sub(n // 64 % 64 + 1, n // 64 % 64 + 1) or "=")
		table.insert(out, chunk > 2 and ALPHABET:sub(n % 64 + 1, n % 64 + 1) or "=")
	end
	return table.concat(out)
end

-- ----------------------------------------------------------------- tracks --

--- One sequence as tracks: joint -> sorted list of { t, cf, style, direction }.
local function tracksOf(kfs)
	local tracks = {}
	local keyframes = {}
	for _, kf in ipairs(kfs:GetChildren()) do
		if kf:IsA("Keyframe") then
			table.insert(keyframes, kf)
		end
	end
	table.sort(keyframes, function(a, b)
		return a.Time < b.Time
	end)
	local length = 0
	for _, kf in ipairs(keyframes) do
		length = math.max(length, kf.Time)
		for _, pose in ipairs(kf:GetDescendants()) do
			if pose:IsA("Pose") and JOINTS[pose.Name] and pose.Weight > 0 then
				local list = tracks[pose.Name]
				if not list then
					list = {}
					tracks[pose.Name] = list
				end
				table.insert(list, {
					t = kf.Time,
					cf = pose.CFrame,
					style = STYLES[pose.EasingStyle.Name] or 0,
					direction = DIRECTIONS[pose.EasingDirection.Name] or 0,
				})
			end
		end
	end
	return tracks, length, #keyframes
end

--- Drop keys a straight line between their neighbours already reproduces.
local function simplify(keys)
	if #keys <= 2 then
		return keys
	end
	local kept = { keys[1] }
	local anchor = 1
	local i = 2
	while i < #keys do
		-- Can the segment anchor -> i+1 stand in for everything between?
		local a, b = keys[anchor], keys[i + 1]
		local ok = a.style == 0 and keys[i].style == 0
		if ok then
			for j = anchor + 1, i do
				local k = keys[j]
				local alpha = (b.t - a.t) > 0 and (k.t - a.t) / (b.t - a.t) or 0
				if not close(a.cf:Lerp(b.cf, alpha), k.cf) then
					ok = false
					break
				end
			end
		end
		if not ok then
			table.insert(kept, keys[i])
			anchor = i
		end
		i += 1
	end
	table.insert(kept, keys[#keys])
	-- A track that never moves off one pose needs one key.
	local static = true
	for _, k in ipairs(kept) do
		if not close(k.cf, kept[1].cf) then
			static = false
			break
		end
	end
	if static then
		return { kept[1] }
	end
	return kept
end

local clamped = 0
local function encode(keys): string
	local parts = table.create(#keys)
	for _, k in ipairs(keys) do
		local _, x, y, z = quaternion(k.cf)
		local p = k.cf.Position
		local function q(v: number, scale: number): number
			local n = math.floor(v * scale + 0.5)
			if n > 32767 or n < -32767 then
				clamped += 1
				n = math.clamp(n, -32767, 32767)
			end
			return n
		end
		table.insert(parts, string.pack("<Hhhhhhhb", math.clamp(math.floor(k.t * 1000 + 0.5), 0, 65535),
			q(x, 32767), q(y, 32767), q(z, 32767), q(p.X, 1000), q(p.Y, 1000), q(p.Z, 1000),
			k.style * 4 + k.direction))
	end
	return base64(table.concat(parts))
end

local function lua(s: string): string
	return string.format("%q", s)
end

-- ------------------------------------------------------------------ write --

local model = roblox.deserializeModel(fs.readFile(SOURCE))
local pack = model[1]
if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end

local index = {}
local totalBytes, totalKeys, keptKeys = 0, 0, 0
for _, spec in ipairs(EMOTES) do
	local id, folderName, main, intro = spec[1], spec[2], spec[3], spec[4]
	local folder = pack:FindFirstChild(folderName)
	local r15 = folder and folder:FindFirstChild("R15")
	assert(r15, "no R15 folder for " .. folderName)
	local function sequence(suffix: string)
		for _, k in ipairs(r15:GetChildren()) do
			if k:IsA("KeyframeSequence") and k.Name == folderName .. " R15 " .. suffix .. "_KeyframeSequence" then
				return k
			end
		end
		error("no " .. suffix .. " sequence in " .. folderName)
	end
	local function block(kfs, indent: string): (string, number, boolean)
		local tracks, length, count = tracksOf(kfs)
		local lines = {}
		local names = {}
		for name in pairs(tracks) do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local keys = tracks[name]
			totalKeys += #keys
			local simple = simplify(keys)
			keptKeys += #simple
			local data = encode(simple)
			totalBytes += #data
			table.insert(lines, indent .. "\t" .. name .. " = " .. lua(data) .. ",")
		end
		return table.concat(lines, "\n"), length, kfs.Loop
	end
	local mainBody, length, loop = block(sequence(main), "\t")
	local out = {
		"-- Generated by tools/emotes/convert.luau from " .. SOURCE .. " (\"" .. folderName .. "\"). Do not edit;",
		"-- re-run the converter. Decoded by ReplicatedStorage.EmotePlayer.",
		"return {",
		("\tlength = %.3f,"):format(length),
		("\tloop = %s,"):format(tostring(loop == true)),
		"\tjoints = {",
		mainBody,
		"\t},",
	}
	local introLength = 0
	if intro then
		local introBody, il = block(sequence(intro), "\t\t")
		introLength = il
		table.insert(out, "\tintro = {")
		table.insert(out, ("\t\tlength = %.3f,"):format(il))
		table.insert(out, "\t\tjoints = {")
		table.insert(out, introBody)
		table.insert(out, "\t\t},")
		table.insert(out, "\t},")
	end
	table.insert(out, "}")
	fs.writeFile(OUT .. "/" .. id .. ".luau", table.concat(out, "\n") .. "\n")
	table.insert(index, ("\t%s = { length = %.3f, loop = %s, intro = %.3f },"):format(id, length, tostring(loop == true),
		introLength))
end

fs.writeFile(OUT .. "/Index.luau", table.concat({
	"-- Generated by tools/emotes/convert.luau. Do not edit; re-run the converter.",
	"-- Every keyframe emote's main length, whether it loops, and its intro's length (0 = none).",
	"return {",
	table.concat(index, "\n"),
	"}",
	"",
}, "\n"))

print(("%d emotes: %d keys -> %d kept (%.0f%%), %.0f KB of track data%s"):format(#EMOTES, totalKeys, keptKeys,
	keptKeys / totalKeys * 100, totalBytes / 1024, clamped > 0 and (", %d values clamped"):format(clamped) or ""))
