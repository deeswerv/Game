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

local Codec = require("./codec")
local simplify, encode, lua = Codec.simplify, Codec.encode, Codec.lua

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
	keptKeys / totalKeys * 100, totalBytes / 1024, Codec.clamped > 0 and (", %d values clamped"):format(Codec.clamped) or ""))
