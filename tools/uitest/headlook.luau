--!nocheck
-- The head look (HeadLook + HeadLookService), checked without Studio:
--
--   * your head turns the way your camera looks -- left is left, up is up -- with the chest
--     taking part of the turn, and it eases there rather than snapping;
--   * the angles go to the server, rounded, and not every frame;
--   * the server clamps what it is sent to what a neck can do, refuses junk and floods,
--     and publishes it on the character;
--   * with a gun out the chest is left to the weapon pose; during an emote nothing is
--     touched; looking behind you fades the turn out; the setting at 0% turns it off.
--
--   lune run tools/uitest/headlook.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local Rig = require("./rig")
local R = World.R
local CFrame, Vector3, Vector2 = roblox.CFrame, roblox.Vector3, roblox.Vector2

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local function angle(a, b): number
	local _, theta = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.deg(math.abs(theta))
end

local sent = {}
R.ClassMethods.RemoteEvent.FireServer = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("HeadLookService"), sss)
local HeadLookService = World.require(sss.HeadLookService)
local EmotePlayer = World.require(rs.EmotePlayer)

local player = World.player
local rig, rests = Rig.character(World, place)
local neck, waist = Rig.motor(rig, "Head"), Rig.motor(rig, "UpperTorso")
local camera = World.workspace.CurrentCamera

-- The character stands at the origin facing -Z; its left is -X.
local head = Vector3.new(0, 4.5, 0)
-- Built by hand: Lune's CFrame.lookAt does not agree with the engine's.
local function lookAlong(direction)
	local forward = direction.Unit
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(forward)
	camera.CFrame = CFrame.fromMatrix(head - forward * 10, right, up)
end

-- Where the head faces, in the character's frame: the neck's turn from rest, composed with
-- the chest's, applied to "straight ahead".
local function headFacing()
	local chest = rests.UpperTorso:Inverse() * waist.C0
	local turn = rests.Head:Inverse() * neck.C0
	return (chest.Rotation * turn.Rotation):VectorToWorldSpace(Vector3.new(0, 0, -1))
end

World.run(World.service("StarterPlayer").StarterPlayerScripts.HeadLook)
World.advance(0.1)

print("your own head")
lookAlong(Vector3.new(-1, 0, -1))          -- 45 degrees to the left
World.advance(0.08)
local early = headFacing()
World.advance(1.2)
local facing = headFacing()
check(facing.X < -0.4, ("looking left turns the head left (facing %.2f, %.2f, %.2f)"):format(facing.X, facing.Y, facing.Z))
check(math.abs(math.deg(math.atan2(-facing.X, -facing.Z)) - 45) < 3, "by the whole 45 degrees, chest and neck together")
check(early.X > facing.X + 0.05, "easing there, not snapping")
check(angle(waist.C0, rests.UpperTorso) > 10 and angle(waist.C0, rests.UpperTorso) < 25,
	("the chest takes part of it (%.1f degrees)"):format(angle(waist.C0, rests.UpperTorso)))

lookAlong(Vector3.new(0, 0.6, -1))         -- up, straight ahead
World.advance(1.2)
facing = headFacing()
check(facing.Y > 0.3 and math.abs(facing.X) < 0.05, ("looking up tips the head up (%.2f)"):format(facing.Y))

lookAlong(Vector3.new(0.2, 0, 1))          -- almost straight behind
World.advance(1.2)
facing = headFacing()
check(math.abs(facing.X) < 0.1 and facing.Z < -0.95, "looking behind fades the turn out instead of wrenching the neck")

print("sent to the server")
table.clear(sent)
lookAlong(Vector3.new(-1, 0.3, -1))
World.advance(1.0)
local looks = {}
for _, s in ipairs(sent) do
	if s.name == "LookUpdate" then
		table.insert(looks, s.args)
	end
end
local last = looks[#looks]
check(#looks >= 1 and #looks <= 11, ("sent %d times in a second of turning, not every frame"):format(#looks))
check(last and last[1] == math.floor(last[1]) and last[1] > 30 and last[2] > 5,
	("the last is the look, in whole degrees (%s, %s)"):format(last and tostring(last[1]) or "?", last and tostring(last[2]) or "?"))
table.clear(sent)
World.advance(1.0)
check(#sent == 0, "a still camera sends nothing")

print("the server")
World.advance(0.2)
check(HeadLookService.Set(player, 30.4, -10.6) == true and rig:GetAttribute("HeadLook") == Vector2.new(30, -11),
	"a look is published on the character, rounded")
check(HeadLookService.Set(player, 20, 0) == false, "a second one straight after is dropped")
World.advance(0.15)
HeadLookService.Set(player, 400, -90)
check(rig:GetAttribute("HeadLook") == Vector2.new(75, -45), "past what a neck can do is clamped")
World.advance(0.15)
check(HeadLookService.Set(player, 0 / 0, 0) == false and HeadLookService.Set(player, "left", 0) == false,
	"NaN and junk are refused")

print("standing aside")
lookAlong(Vector3.new(-1, 0, -1))
rig:SetAttribute("PoseRightC0", CFrame.new())
waist.C0 = rests.UpperTorso * CFrame.Angles(0, 0.3, 0)
local held = waist.C0
World.advance(0.6)
check(angle(waist.C0, held) < 0.01, "with a gun out, the chest is left to the weapon pose")
check(angle(neck.C0, rests.Head) > 30, "and the neck takes the whole turn")
rig:SetAttribute("PoseRightC0", nil)

EmotePlayer.Posing[rig] = true
neck.C0 = rests.Head * CFrame.Angles(1, 0, 0)
local emoting = neck.C0
World.advance(0.4)
check(angle(neck.C0, emoting) < 0.01, "during an emote, the joints are the emote's")
EmotePlayer.Posing[rig] = nil
neck.C0 = rests.Head
World.advance(0.08)
check(angle(neck.C0, rests.Head) < 20, "and after it, the head eases back in from rest")

player:SetAttribute("HeadLookSetting", 0)
World.advance(1.2)
check(angle(neck.C0, rests.Head) < 0.5 and angle(waist.C0, rests.UpperTorso) < 0.5, "the setting at 0% turns it off")

print(failures == 0 and "\27[32mall head look checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
