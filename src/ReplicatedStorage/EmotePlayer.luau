--!strict
-- Keyframe emotes, decoded and sampled.
--
-- The emote pack's animations are plain KeyframeSequences, which a live game will only play
-- once they are published as animation assets. So they are not played as animations at all:
-- tools/emotes/convert.luau packs each one into a data module (ReplicatedStorage.EmoteData),
-- and this turns that back into one track per joint and says where every joint is at any
-- moment. The client (EmoteAnimator) writes those poses onto the characters doing the emote.
--
-- Each key is 15 bytes, base64'd in the data module:
--   u16 time (ms), i16 x3 rotation quaternion xyz (/32767, w >= 0 implied),
--   i16 x3 position (/1000 studs), u8 easing (style * 4 + direction).
--
-- The pose of a joint is what Roblox calls its Transform: the joint's rest C0 times this is
-- where the part goes. Tracks interpolate the way the animator does -- per joint, between the
-- keys either side, with the earlier key's easing.

local EmotePlayer = {}

export type Track = { times: { number }, poses: { CFrame }, easing: { number } }
export type Part = { length: number, joints: { [string]: Track } }
export type Clip = { length: number, loop: boolean, joints: { [string]: Track }, intro: Part? }

--- Characters EmoteAnimator is posing right now. Anything else that writes joints (the head
--- look) leaves these alone.
EmotePlayer.Posing = setmetatable({}, { __mode = "k" }) :: any

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DECODE: { [number]: number } = {}
for i = 1, #ALPHABET do
	DECODE[string.byte(ALPHABET, i)] = i - 1
end

local KEY_BYTES = 15

local function unbase64(s: string): string
	local out = table.create(#s // 4)
	for i = 1, #s, 4 do
		local a, b, c, d = string.byte(s, i, i + 3)
		local n = DECODE[a] * 262144 + DECODE[b] * 4096 + (DECODE[c :: number] or 0) * 64 + (DECODE[d :: number] or 0)
		table.insert(out, string.char(n // 65536, n // 256 % 256, n % 256))
	end
	return table.concat(out)
end

--- One joint's track from its encoded string.
function EmotePlayer.DecodeTrack(encoded: string): Track
	local bytes = unbase64(encoded)
	local count = #bytes // KEY_BYTES
	local times, poses, easing = table.create(count), table.create(count), table.create(count)
	for i = 0, count - 1 do
		local t, qx, qy, qz, px, py, pz, ease = string.unpack("<Hhhhhhhb", bytes, 1 + i * KEY_BYTES)
		local x, y, z = qx / 32767, qy / 32767, qz / 32767
		local w = math.sqrt(math.max(0, 1 - x * x - y * y - z * z))
		times[i + 1] = t / 1000
		poses[i + 1] = CFrame.new(px / 1000, py / 1000, pz / 1000, x, y, z, w)
		easing[i + 1] = ease
	end
	return { times = times, poses = poses, easing = easing }
end

local function decodeJoints(raw: { [string]: string }): { [string]: Track }
	local joints = {}
	for name, encoded in pairs(raw) do
		joints[name] = EmotePlayer.DecodeTrack(encoded)
	end
	return joints
end

--- A clip from a data module's table (see tools/emotes/convert.luau).
function EmotePlayer.FromData(data: any): Clip
	local clip: Clip = {
		length = data.length,
		loop = data.loop == true,
		joints = decodeJoints(data.joints),
		intro = nil,
	}
	if type(data.intro) == "table" then
		clip.intro = { length = data.intro.length, joints = decodeJoints(data.intro.joints) }
	end
	return clip
end

local cache: { [string]: Clip } = {}

--- The clip for an emote id, decoded once and kept.
function EmotePlayer.Load(id: string): Clip?
	local hit = cache[id]
	if hit then
		return hit
	end
	local folder = script.Parent:FindFirstChild("EmoteData")
	local module = folder and folder:FindFirstChild(id)
	if not module or not module:IsA("ModuleScript") then
		return nil
	end
	local ok, data = pcall(require, module)
	if not ok or type(data) ~= "table" then
		return nil
	end
	local clip = EmotePlayer.FromData(data)
	cache[id] = clip
	return clip
end

-- ---------------------------------------------------------------- easing --

local function ease(style: number, direction: number, a: number): number
	if style == 1 then                     -- Constant: hold until the next key
		return 0
	elseif style == 0 then                 -- Linear
		return a
	end
	local function eIn(x: number): number
		if style == 3 or style == 5 then   -- Cubic
			return x * x * x
		elseif style == 2 then             -- Elastic
			if x == 0 or x == 1 then
				return x
			end
			return -(2 ^ (10 * x - 10)) * math.sin((x * 10 - 10.75) * (2 * math.pi) / 3)
		elseif style == 4 then             -- Bounce
			local y = 1 - x
			local out
			if y < 1 / 2.75 then
				out = 7.5625 * y * y
			elseif y < 2 / 2.75 then
				y -= 1.5 / 2.75
				out = 7.5625 * y * y + 0.75
			elseif y < 2.5 / 2.75 then
				y -= 2.25 / 2.75
				out = 7.5625 * y * y + 0.9375
			else
				y -= 2.625 / 2.75
				out = 7.5625 * y * y + 0.984375
			end
			return 1 - out
		end
		return x
	end
	if direction == 0 then
		return eIn(a)
	elseif direction == 1 then
		return 1 - eIn(1 - a)
	end
	return a < 0.5 and eIn(a * 2) / 2 or 1 - eIn((1 - a) * 2) / 2
end

--- Where a joint is at time `t` along its track.
function EmotePlayer.Sample(track: Track, t: number): CFrame
	local times = track.times
	local n = #times
	if n == 1 or t <= times[1] then
		return track.poses[1]
	elseif t >= times[n] then
		return track.poses[n]
	end
	-- The last key at or before t.
	local lo, hi = 1, n
	while hi - lo > 1 do
		local mid = (lo + hi) // 2
		if times[mid] <= t then
			lo = mid
		else
			hi = mid
		end
	end
	local span = times[hi] - times[lo]
	local a = span > 0 and (t - times[lo]) / span or 1
	local code = track.easing[lo]
	return track.poses[lo]:Lerp(track.poses[hi], ease(code // 4, code % 4, a))
end

--- Every joint's pose `elapsed` seconds into the emote: the intro first (if it has one), then
--- the main part, looping or holding its last frame. Writes into `out` and returns it.
function EmotePlayer.PoseAt(clip: Clip, elapsed: number, out: { [string]: CFrame }?): { [string]: CFrame }
	local result = out or {}
	local joints = clip.joints
	local t = elapsed
	local intro = clip.intro
	if intro then
		if elapsed < intro.length then
			joints = intro.joints
		else
			t = elapsed - intro.length
		end
	end
	if joints == clip.joints then
		if clip.loop and clip.length > 0 then
			t = t % clip.length
		else
			t = math.min(t, clip.length)
		end
	end
	for name, track in pairs(joints) do
		result[name] = EmotePlayer.Sample(track, t)
	end
	return result
end

--- How long a play-once emote runs, intro included. Looping ones run until stopped.
function EmotePlayer.Duration(clip: Clip): number
	return clip.length + (clip.intro and clip.intro.length or 0)
end

return EmotePlayer
