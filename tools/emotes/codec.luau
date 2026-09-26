--!nocheck
-- The track codec shared by the keyframe converters (tools/emotes/convert.luau and
-- tools/anims/locomotion.luau). What it writes, ReplicatedStorage.EmotePlayer reads:
--
--   per key, 15 bytes, little-endian:
--     u16  time in milliseconds
--     i16  x3  rotation quaternion x, y, z  (* 32767; w >= 0 is recovered)
--     i16  x3  position in thousandths of a stud
--     u8       easing: style * 4 + direction

local Codec = {}

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

Codec.clamped = 0
local function encode(keys): string
	local parts = table.create(#keys)
	for _, k in ipairs(keys) do
		local _, x, y, z = quaternion(k.cf)
		local p = k.cf.Position
		local function q(v: number, scale: number): number
			local n = math.floor(v * scale + 0.5)
			if n > 32767 or n < -32767 then
				Codec.clamped += 1
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


Codec.quaternion = quaternion
Codec.close = close
Codec.base64 = base64
Codec.simplify = simplify
Codec.encode = encode
Codec.lua = lua

return Codec
