--!strict
-- One place that defines every weapon. Server and client both read this, so stats can
-- never disagree between them, and a new weapon is a table entry rather than a new
-- system.

local WeaponConfig = {}

-- Anything a weapon does not override falls back to here.
WeaponConfig.Defaults = {
	Starter = false,             -- true means every player owns it without buying
	-- How the weapon is carried. "OneHanded" puts it in the right hand and leaves the
	-- left arm relaxed; "TwoHanded" brings both arms up to it.
	--
	-- There is deliberately no grip angle here any more. The old GripPitch/GripYaw pair
	-- was measured off a character that happened to be mid-air at the time, so those
	-- numbers only ever held for that one pose. WeaponPose now solves the grip from the
	-- model's own barrel geometry at equip time, which cannot go stale.
	Hold = "TwoHanded",
	-- Where the weapon sits in the fist, in studs. Both default to 0 and are the two
	-- numbers to reach for if a gun does not look properly held.
	--   GripLateral  positive moves it toward the player's centre line, across the palm
	--   GripForward  positive slides it along its own barrel, bringing the grip under the
	--                fist rather than leaving the fist closed around the frame
	GripLateral = 0,
	GripForward = 0,
	Type = "Gun",                -- "Gun" or "Melee"; only Guns run through GunHandler
	Holster = true,              -- false for weapons that carry their own sheathe logic
	Class = "Pistol",
	Slot = "Small",              -- Small -> holstered at the hip, Large -> on the back
	Rarity = "Common",
	Description = "",

	Damage = 18,
	HeadshotMultiplier = 2,
	FireRate = 0.16,             -- seconds between shots
	Automatic = false,
	PelletsPerShot = 1,
	MagazineSize = 12,
	ReloadTime = 1.6,
	Range = 500,

	-- Reload staging. The stages are laid out as fractions of ReloadTime, so each
	-- weapon's existing ReloadTime still sets the pace and no balance changes.
	MagFed = true,                   -- false for shell/pump weapons: nothing to drop
	MagazineParts = { "Magazine" },  -- the parts that leave the gun as one magazine
	ChargePart = "Slide",            -- what the charging action racks; nil to skip it
	ChargeWhenEmpty = true,          -- rack only when the chamber actually ran dry
	MagDropLifetime = 8,             -- seconds a dropped magazine survives before cleanup

	-- Spread is in degrees and grows as you keep firing.
	SpreadMin = 0.35,
	SpreadMax = 4.5,
	SpreadPerShot = 0.65,
	SpreadRecovery = 5.0,        -- degrees bled off per second
	AdsSpreadScale = 0.3,

	-- Recoil: the camera kick, and how fast it settles.
	RecoilPitch = 1.5,
	RecoilYaw = 0.45,
	RecoilRecovery = 9,
	RecoilKickback = 0.22,       -- how far the model punches back

	AdsFov = 55,
	AdsSpeed = 12,
	AdsWalkSpeedScale = 0.6,

	FireSound = "rbxassetid://1112042117",
	ReloadSound = "",
	EmptySound = "",
	-- Reload beats. Left blank on purpose: a wrong asset id is worse than silence, so
	-- these are wired up and ready for you to paste ids into. Any left empty is skipped.
	MagOutSound = "",                -- magazine release and pull
	MagInSound = "",                 -- magazine seating into the well
	ChargeSound = "",                -- charging handle / slide / pump
	TracerColor = Color3.fromRGB(255, 214, 140),
	TracerWidth = 0.09,
	MuzzleFlashColor = Color3.fromRGB(255, 214, 140),

	-- Melee. GenericMelee = true means MeleeHandler drives it; the Greatsword and
	-- Blood Sword keep their own bespoke combat scripts and leave this false.
	-- How hard a kill throws the body, used by the ragdoll. Set per weapon so a pistol
	-- does not launch someone the way a warhammer does.
	DeathKnockback = 40,

	GenericMelee = false,
	SwingTime = 0.55,            -- seconds between swings
	MeleeRange = 9,
	MeleeArc = 110,              -- degrees of the cone in front of the player
	Knockback = 20,
	ComboCount = 3,              -- swings before the combo resets
	ComboDamageStep = 0.25,      -- each combo hit adds this fraction of base damage
	TrailColor = Color3.fromRGB(235, 235, 245),
}

-- Per-weapon overrides. Add a weapon by adding a table here whose key matches the
-- Tool's name; nothing else needs to change.
WeaponConfig.Weapons = {
	Vantage = {
		Type = "Gun",
		Class = "Pistol",
		DeathKnockback = 26,
		Hold = "OneHanded",
		Slot = "Small",
		Rarity = "Common",
		Description = "Semi-automatic sidearm. Reliable, forgiving, always there.",
		Damage = 18,
		FireRate = 0.16,
		Automatic = false,
		MagazineSize = 12,
		ReloadTime = 1.5,
		SpreadMin = 0.3,
		SpreadMax = 3.8,
		SpreadPerShot = 0.55,
		RecoilPitch = 1.4,
		RecoilYaw = 0.4,
	},

	Greatsword = {
		Starter = true,
		Type = "Melee",
		-- Moved onto the shared melee system 2026-09-18. It used to run a bespoke script kit
		-- whose server remotes validated nothing; every swing now goes through MeleeHandler,
		-- which checks that the player is holding the weapon and owns the cooldown.
		GenericMelee = true,
		Class = "Greatsword",
		DeathKnockback = 95,
		Slot = "Large",
		Rarity = "Epic",
		Description = "A heavy two-hander. Slow, enormous reach, and it sends them flying.",
		Damage = 25,
		-- Deliberately the slowest swing in the game with the longest reach: the weight is
		-- the personality, and a two-hander that swings like a dagger has none.
		SwingTime = 0.95,
		MeleeRange = 12,
		MeleeArc = 130,
		Knockback = 45,
		ComboCount = 3,
		ComboDamageStep = 0.25,
		BackstabMultiplier = 1.5,
		TrailColor = Color3.fromRGB(220, 235, 255),
		Holster = true,
	},

	Scattergun = {
		Type = "Gun",
		Class = "Shotgun",
		DeathKnockback = 100,        -- a shotgun should visibly throw them
		Slot = "Large",
		Rarity = "Rare",
		-- Pump action: no magazine leaves the weapon, and the pump is racked every reload.
		MagFed = false,
		ChargePart = "Pump",
		ChargeWhenEmpty = false,
		Description = "Eight pellets at once. Devastating up close, useless at range.",
		Damage = 11,                 -- per pellet: 88 if every pellet lands
		HeadshotMultiplier = 1.5,
		PelletsPerShot = 8,
		FireRate = 0.85,
		Automatic = false,
		MagazineSize = 5,
		ReloadTime = 2.6,
		Range = 90,                  -- deliberately short
		SpreadMin = 5.5,
		SpreadMax = 9.0,
		SpreadPerShot = 1.2,
		AdsSpreadScale = 0.65,       -- aiming helps, but it is still a shotgun
		RecoilPitch = 5.5,
		RecoilYaw = 1.2,
		RecoilKickback = 0.5,
		AdsFov = 62,
		TracerColor = Color3.fromRGB(255, 180, 120),
		TracerWidth = 0.07,
	},

	Hornet = {
		Type = "Gun",
		Class = "SMG",
		DeathKnockback = 34,
		Hold = "OneHanded",          -- compact enough to run one-handed, as in the reference
		GripLateral = 0.2,
		GripForward = 0.22,
		-- The amber floorplate is the bottom of the same magazine, so it leaves with it.
		MagazineParts = { "Magazine", "MagBase" },
		Slot = "Small",
		Rarity = "Uncommon",
		Description = "Fully automatic. Low damage per shot, but it never stops.",
		Damage = 8,
		FireRate = 0.075,
		Automatic = true,
		MagazineSize = 30,
		ReloadTime = 1.9,
		Range = 300,
		SpreadMin = 1.1,
		SpreadMax = 7.0,
		SpreadPerShot = 0.42,
		SpreadRecovery = 6.5,
		RecoilPitch = 0.75,
		RecoilYaw = 0.5,
		RecoilRecovery = 11,
		AdsFov = 60,
		TracerColor = Color3.fromRGB(180, 240, 255),
		TracerWidth = 0.06,
	},

	Redwood = {
		Type = "Gun",
		Class = "Rifle",
		DeathKnockback = 58,
		Hold = "TwoHanded",
		Slot = "Large",
		Rarity = "Epic",
		Description = "Wood-furniture battle rifle. Heavy rounds, and it does not care about range.",
		-- 16 x 8.3 shots a second is about 133 damage a second, a little above the Hornet's
		-- 107 and the Vantage's 112, which is where an Epic rifle should sit.
		Damage = 16,
		HeadshotMultiplier = 2,
		FireRate = 0.12,
		Automatic = true,
		MagazineSize = 30,
		ReloadTime = 2.5,
		Range = 400,
		SpreadMin = 0.65,
		SpreadMax = 5.2,
		SpreadPerShot = 0.48,
		SpreadRecovery = 5.5,
		RecoilPitch = 2.0,
		RecoilYaw = 0.65,
		RecoilRecovery = 8,
		RecoilKickback = 0.34,
		AdsFov = 52,
		TracerColor = Color3.fromRGB(255, 196, 120),
		TracerWidth = 0.08,
		-- The curved magazine is three parts, and all three leave together on a reload.
		MagazineParts = { "Magazine", "MagMid", "MagFloor" },
		ChargePart = "ChargingHandle",
		ChargeWhenEmpty = true,
		GripLateral = 0.2,
		GripForward = 0.1,
	},

	-- The imported CompactCarbine. Stats are set here so the weapon is ready the moment
	-- the model is brought in; WeaponImporter builds the Tool, and everything else --
	-- market, inventory, attachments, camos, builds -- picks it up from this entry.
	Carbine = {
		Type = "Gun",
		Class = "Rifle",
		Hold = "TwoHanded",
		Slot = "Large",
		Rarity = "Legendary",
		Description = "Short-barrelled carbine. Accurate, controllable, and quietly expensive.",
		Damage = 28,
		FireRate = 0.105,
		Automatic = true,
		MagazineSize = 30,
		ReloadTime = 2.0,
		Range = 420,
		SpreadMin = 0.55,
		SpreadMax = 5.4,
		SpreadPerShot = 0.4,
		SpreadRecovery = 7.5,
		RecoilPitch = 1.25,
		RecoilYaw = 0.5,
		RecoilRecovery = 11,
		AdsFov = 56,
		TracerColor = Color3.fromRGB(255, 214, 160),
		Knockback = 32,
	},

	-- ---------------------------------------------------------------- imported --
	--
	-- These three come from the authored .glb models in "Gun Models". Their stats are set
	-- here so each weapon is ready the moment its model is brought in; WeaponImporter
	-- builds the Tool and everything downstream -- market, inventory, attachments, camos,
	-- builds -- reads this entry. Their magazine parts are tagged by the importer rather
	-- than listed here, which is why there is no MagazineParts line on any of them.

	-- Full-size AR with a mounted optic. The most complete weapon in the set: the one
	-- everything else is balanced against.
	Warden = {
		Type = "Gun",
		Class = "Rifle",
		Hold = "TwoHanded",
		Slot = "Large",
		Rarity = "Legendary",
		Description = "Full-length rifle, optic already mounted. Nothing about it is a compromise.",
		-- 24 x 10.5 shots a second is 252 damage a second on paper, but the low magazine
		-- turnover and the 2.2s reload put its sustained figure just under the Carbine's.
		Damage = 24,
		HeadshotMultiplier = 2,
		FireRate = 0.095,
		Automatic = true,
		MagazineSize = 30,
		ReloadTime = 2.2,
		Range = 450,
		SpreadMin = 0.45,
		SpreadMax = 4.8,
		SpreadPerShot = 0.36,
		SpreadRecovery = 8.0,
		-- The first weapon moved onto the structured block. A long rifle with an optic: it
		-- climbs hard but predictably, wanders little, and aiming brakes it more than most.
		Recoil = {
			Vertical = 1.15,
			Horizontal = 0.42,
			Kick = 0.95,
			Recovery = 12,
			AdsMultiplier = 0.5,
			Climb = 0.7,
			ClimbShots = 7,
			Jitter = 0.12,
			Wave = 1.7,
		},
		-- Kept so anything still reading the flat fields sees the same weapon.
		RecoilPitch = 1.15,
		RecoilYaw = 0.42,
		RecoilRecovery = 12,
		AdsFov = 50,             -- it has the optic, so it earns the tightest zoom
		ChargePart = "ChargingHandle",
		ChargeWhenEmpty = true,
		TracerColor = Color3.fromRGB(255, 214, 160),
		DeathKnockback = 60,
		Knockback = 34,
	},

	-- The bolt-action sniper, and the reason a scope overlay exists. One body shot does not
	-- quite kill a full-health player; one to the head always does. Slow to cycle, slow to
	-- reload, useless from the hip -- and pinpoint through the glass. No falloff: a sniper
	-- that loses damage with distance is a shotgun with a longer barrel.
	Longshot = {
		Type = "Gun",
		Class = "Sniper",
		Hold = "TwoHanded",
		Slot = "Large",
		Rarity = "Legendary",
		Scoped = true,
		Description = "Bolt-action sniper. Five rounds, a real scope, and one shot to the head.",
		Damage = 90,
		HeadshotMultiplier = 2.4,
		FireRate = 1.25,
		Automatic = false,
		MagazineSize = 5,
		ReloadTime = 2.8,
		Range = 1000,
		FalloffStart = 1000,
		FalloffEnd = 1001,
		FalloffMin = 1,
		SpreadMin = 3.5,             -- from the hip it is a guess
		SpreadMax = 7,
		SpreadPerShot = 3,
		SpreadRecovery = 4,
		AdsSpreadScale = 0.01,       -- through the scope it goes where the reticle is
		Recoil = {
			Vertical = 4.2,
			Horizontal = 0.8,
			Kick = 1.6,
			Recovery = 6,
			AdsMultiplier = 0.45,
			Climb = 0,
			ClimbShots = 1,
			Jitter = 0.1,
			Wave = 0.9,
		},
		RecoilPitch = 4.2,
		RecoilYaw = 0.8,
		RecoilRecovery = 6,
		RecoilKickback = 0.5,
		AdsFov = 20,
		AdsSpeed = 9,
		AdsWalkSpeedScale = 0.45,
		ChargePart = "Bolt",
		ChargeWhenEmpty = false,
		TracerColor = Color3.fromRGB(255, 220, 120),
		TracerWidth = 0.14,
		MuzzleFlashColor = Color3.fromRGB(255, 200, 120),
		DeathKnockback = 95,
		Knockback = 50,
	},

	-- Walnut-furniture pump gun. The forend is both the off hand's grip and the part the
	-- reload racks, which is why ChargePart points at it.
	Blackwood = {
		Type = "Gun",
		Class = "Shotgun",
		Hold = "TwoHanded",
		Slot = "Large",
		Rarity = "Epic",
		Description = "Walnut and blued steel. Seven pellets a shell and a very short argument.",
		MagFed = false,          -- shells, not a magazine: nothing leaves the weapon
		ChargePart = "LowerHandguard",
		ChargeWhenEmpty = false, -- a pump gun is racked every shot, not only when empty
		Damage = 13,             -- per pellet: 91 if the whole pattern lands
		HeadshotMultiplier = 1.5,
		PelletsPerShot = 7,
		FireRate = 0.9,
		Automatic = false,
		MagazineSize = 6,
		ReloadTime = 3.0,
		Range = 100,
		SpreadMin = 4.8,
		SpreadMax = 8.5,
		SpreadPerShot = 1.1,
		AdsSpreadScale = 0.6,
		RecoilPitch = 6.0,
		RecoilYaw = 1.3,
		RecoilKickback = 0.55,
		AdsFov = 64,
		TracerColor = Color3.fromRGB(255, 186, 130),
		TracerWidth = 0.07,
		DeathKnockback = 110,
		Knockback = 48,
	},

	-- Railed service pistol. Heavier than the Vantage, cheaper to miss with than the Talon.
	Sentinel = {
		Type = "Gun",
		Class = "Pistol",
		Hold = "OneHanded",
		Slot = "Small",
		Rarity = "Rare",
		Description = "Railed service pistol. Fifteen rounds and no bad habits.",
		Damage = 27,
		HeadshotMultiplier = 2,
		FireRate = 0.19,
		Automatic = false,
		MagazineSize = 15,
		ReloadTime = 1.8,
		Range = 360,
		SpreadMin = 0.35,
		SpreadMax = 4.4,
		SpreadPerShot = 0.85,
		SpreadRecovery = 5.5,
		RecoilPitch = 2.4,
		RecoilYaw = 0.7,
		RecoilKickback = 0.3,
		AdsFov = 60,
		ChargePart = "Slide",
		ChargeWhenEmpty = true,
		TracerColor = Color3.fromRGB(255, 226, 160),
		TracerWidth = 0.08,
		DeathKnockback = 40,
		Knockback = 26,
	},

	-- Compact AK pistol. The most detailed model in the set, so it earns its rarity.
	Kestrel = {
		Type = "Gun",
		Class = "Rifle",
		Hold = "TwoHanded",
		Slot = "Small",
		Rarity = "Epic",
		Description = "Cut-down rifle. Rifle punch in something you can swing round a corner.",
		Damage = 26,
		FireRate = 0.11,
		Automatic = true,
		MagazineSize = 20,
		ReloadTime = 2.0,
		Range = 320,
		SpreadMin = 1.2,
		SpreadMax = 7.5,
		SpreadPerShot = 0.6,
		SpreadRecovery = 6.0,
		RecoilPitch = 1.7,
		RecoilYaw = 0.7,
		RecoilRecovery = 9,
		AdsFov = 58,
		TracerColor = Color3.fromRGB(255, 190, 120),
		Knockback = 34,
	},

	-- Heavy sidearm. Hits like a rifle, holds seven rounds, punishes a miss.
	Talon = {
		Type = "Gun",
		Class = "Pistol",
		Hold = "OneHanded",
		Slot = "Small",
		Rarity = "Rare",
		Description = "Hand cannon. Seven rounds, and every one of them means it.",
		Damage = 46,
		FireRate = 0.42,
		Automatic = false,
		MagazineSize = 7,
		ReloadTime = 2.1,
		Range = 340,
		SpreadMin = 0.4,
		SpreadMax = 5.5,
		SpreadPerShot = 1.6,
		SpreadRecovery = 4.5,
		RecoilPitch = 4.2,
		RecoilYaw = 1.1,
		RecoilKickback = 0.45,
		AdsFov = 62,
		TracerColor = Color3.fromRGB(255, 236, 170),
		TracerWidth = 0.1,
		Knockback = 55,
	},

	-- Machine pistol. Empties itself in about two seconds and is a menace up close.
	Wasp = {
		Type = "Gun",
		Class = "SMG",
		Hold = "OneHanded",
		Slot = "Small",
		Rarity = "Uncommon",
		Description = "Machine pistol. No range, no manners, empties in two seconds.",
		Damage = 10,
		FireRate = 0.055,
		Automatic = true,
		MagazineSize = 32,
		ReloadTime = 1.6,
		Range = 190,
		SpreadMin = 1.8,
		SpreadMax = 9.0,
		SpreadPerShot = 0.5,
		SpreadRecovery = 8.0,
		RecoilPitch = 0.6,
		RecoilYaw = 0.6,
		RecoilRecovery = 12,
		AdsFov = 64,
		TracerColor = Color3.fromRGB(200, 255, 210),
		TracerWidth = 0.05,
		Knockback = 18,
	},

	Sparrow = {
		Type = "Gun",
		Class = "SMG",
		Hold = "TwoHanded",
		Slot = "Small",
		Rarity = "Rare",
		Description = "Compact submachine gun. Fast, close, and unfussy about range.",
		Damage = 13,
		FireRate = 0.085,
		Automatic = true,
		MagazineSize = 25,
		ReloadTime = 1.7,
		Range = 260,
		SpreadMin = 0.9,
		SpreadMax = 6.2,
		SpreadPerShot = 0.38,
		SpreadRecovery = 7.0,
		RecoilPitch = 0.9,
		RecoilYaw = 0.45,
		RecoilRecovery = 10,
		AdsFov = 60,
		TracerColor = Color3.fromRGB(150, 210, 255),
		TracerWidth = 0.06,
		Knockback = 26,
	},

	Fang = {
		Type = "Melee",
		GenericMelee = true,
		Class = "Dagger",
		Slot = "Small",
		Rarity = "Uncommon",
		Description = "Quick, short, and merciless from behind. Backstabs hit triple.",
		Damage = 14,
		SwingTime = 0.28,
		MeleeRange = 6.5,
		MeleeArc = 80,
		Knockback = 8,
		DeathKnockback = 30,
		ComboCount = 4,
		ComboDamageStep = 0.18,
		BackstabMultiplier = 3,      -- from behind
		TrailColor = Color3.fromRGB(150, 255, 200),
	},

	Ironjaw = {
		Type = "Melee",
		GenericMelee = true,
		Class = "Warhammer",
		Slot = "Large",
		Rarity = "Epic",
		Description = "Slow as a landslide and about as forgiving. Sends them flying.",
		Damage = 42,
		SwingTime = 1.25,
		MeleeRange = 11,
		MeleeArc = 150,
		Knockback = 70,
		DeathKnockback = 135,        -- it is a warhammer; sending them flying is the point
		ComboCount = 2,
		ComboDamageStep = 0.4,
		TrailColor = Color3.fromRGB(255, 170, 90),
	},

	BloodSword = {
		Type = "Melee",
		GenericMelee = true,
		Class = "Katana",
		Slot = "Large",
		Rarity = "Legendary",
		Description = "A blade that drinks what it cuts. Fast, and it heals what it takes.",
		Damage = 22,
		-- Fast and close, where the Greatsword is slow and long. Lifesteal is what the
		-- retired ability kit was for; as a stat it survives the kit and cannot be exploited.
		SwingTime = 0.5,
		MeleeRange = 8.5,
		MeleeArc = 100,
		Knockback = 18,
		ComboCount = 4,
		ComboDamageStep = 0.2,
		BackstabMultiplier = 2,
		Lifesteal = 0.25,
		TrailColor = Color3.fromRGB(255, 90, 110),
		DeathKnockback = 70,
		Holster = true,
	},
}

local cache = {}

-- Merged view of a weapon's stats. Returns nil for anything that is not a weapon,
-- which is how the controller decides whether to take over a Tool at all.
function WeaponConfig.Get(name: string)
	if cache[name] then
		return cache[name]
	end
	local entry = WeaponConfig.Weapons[name]
	if not entry then
		return nil
	end
	local merged = {}
	for k, v in pairs(WeaponConfig.Defaults) do
		merged[k] = v
	end
	for k, v in pairs(entry) do
		merged[k] = v
	end
	merged.Name = name
	cache[name] = merged
	return merged
end

function WeaponConfig.IsWeapon(name: string): boolean
	return WeaponConfig.Weapons[name] ~= nil
end

-- Is there actually a model to equip?
--
-- A weapon can be fully configured -- stats, price, rarity, the lot -- while its model is
-- still waiting to be imported, because Roblox meshes have to go through an account and
-- there is no API for it. Such a weapon must not be offered for sale: it would take the
-- player's coins and hand them nothing they could hold.
--
-- The market and the inventory both check this, so a weapon appears of its own accord the
-- moment its model lands in storeitems, with nothing to remember to switch on.
function WeaponConfig.HasModel(name: string): boolean
	local store = game:GetService("ReplicatedStorage"):FindFirstChild("storeitems")
	return store ~= nil and store:FindFirstChild(name) ~= nil
end

-- --------------------------------------------------------------- attachments --
--
-- The stats an attachment is allowed to touch, and which direction is an improvement.
-- The workshop reads this to decide whether a change is drawn as a gain or a loss, so
-- there is exactly one place that knows a lower reload time is a good thing.
WeaponConfig.TunableStats = {
	{ key = "Damage", label = "Damage", ceiling = 50, higherIsBetter = true, decimals = 0 },
	{ key = "FireRate", label = "Fire Rate", ceiling = 0.5, higherIsBetter = false, decimals = 3 },
	{ key = "MagazineSize", label = "Magazine", ceiling = 60, higherIsBetter = true, decimals = 0 },
	{ key = "Range", label = "Range", ceiling = 500, higherIsBetter = true, decimals = 0 },
	{ key = "ReloadTime", label = "Reload", ceiling = 3.5, higherIsBetter = false, decimals = 2 },
	{ key = "SpreadMin", label = "Accuracy", ceiling = 6, higherIsBetter = false, decimals = 2 },
	{ key = "RecoilPitch", label = "Recoil", ceiling = 6, higherIsBetter = false, decimals = 2 },
	{ key = "AdsSpeed", label = "Aim Speed", ceiling = 16, higherIsBetter = true, decimals = 1 },
}

local tunableSet = {}
for _, row in ipairs(WeaponConfig.TunableStats) do
	tunableSet[row.key] = row
end

function WeaponConfig.IsTunable(key: string): boolean
	return tunableSet[key] ~= nil
end

-- A weapon's stats with a loadout of attachments folded in.
--
-- Returns a COPY. WeaponConfig.Get hands back a cached table that everything shares, so
-- writing the modified numbers into it would quietly re-balance the weapon for every
-- player on the server.
function WeaponConfig.WithAttachments(cfg, loadout)
	if not cfg then
		return nil
	end
	local AttachmentConfig = require(script.Parent.AttachmentConfig)
	local mods = AttachmentConfig.Modifiers(loadout)
	if next(mods) == nil then
		return cfg
	end

	local merged = table.clone(cfg)
	for key, effect in pairs(mods) do
		local base = merged[key]
		if type(base) == "number" and tunableSet[key] then
			local value = base * effect.mul + effect.add
			-- A magazine is a whole number of rounds, and no stat may go to zero or below.
			if key == "MagazineSize" then
				value = math.max(1, math.floor(value + 0.5))
			else
				value = math.max(value, 0.001)
			end
			merged[key] = value
		end
	end
	return merged
end

-- The stats a LIVE weapon is actually running on.
--
-- The server stamps the equipped build's numbers onto the Tool as attributes when it
-- dresses it, so this is what makes the workshop's bars and the bullets agree: both read
-- the same numbers off the same object, rather than the UI modelling what it thinks the
-- attachments do while the server fires the unmodified weapon.
--
-- Only the server writes these attributes, so a client cannot buff its own gun by setting
-- one -- the server never reads the client's copy.
function WeaponConfig.For(tool: Instance?)
	if not tool then
		return nil
	end
	local cfg = WeaponConfig.Get(tool.Name)
	if not cfg then
		return nil
	end
	local overrides = nil
	for _, row in ipairs(WeaponConfig.TunableStats) do
		local value = tool:GetAttribute("Stat_" .. row.key)
		if type(value) == "number" then
			overrides = overrides or table.clone(cfg)
			overrides[row.key] = value
		end
	end
	return overrides or cfg
end

-- ------------------------------------------------------------------- noise --
--
-- How far a shot is heard. Enemies do not get told who fired -- they get told something
-- happened over there -- so a firefight pulls the next patrol in to look, which is what
-- makes a fight spread instead of staying politely in one room.
--
-- A suppressor genuinely halves it. That is the attachment actually doing what it says
-- rather than being another "+5%", and it is why a marksman build can work a flank quietly.
local NOISE_BY_CLASS = {
	Sniper = 170,
	Shotgun = 150,
	Rifle = 130,
	Marksman = 140,
	LMG = 150,
	SMG = 105,
	Pistol = 90,
	Revolver = 110,
}
local NOISE_DEFAULT = 120
local SUPPRESSED = 0.45

function WeaponConfig.NoiseRadius(cfg, tool: Instance?): number
	if not cfg or cfg.Type ~= "Gun" then
		return 0
	end
	local radius = cfg.NoiseRadius or NOISE_BY_CLASS[cfg.Class] or NOISE_DEFAULT
	-- WeaponBuildService stamps what is fitted, by slot, when it dresses the weapon. Read
	-- from there rather than guessed from part names inside the built model.
	if tool then
		local muzzle = tool:GetAttribute("Att_Muzzle")
		if muzzle == "Suppressor" then
			return radius * SUPPRESSED
		end
	end
	return radius
end

WeaponConfig.RarityColors = {
	Common = Color3.fromRGB(170, 176, 186),
	Uncommon = Color3.fromRGB(104, 198, 122),
	Rare = Color3.fromRGB(88, 156, 245),
	Epic = Color3.fromRGB(176, 112, 240),
	Legendary = Color3.fromRGB(245, 176, 66),
	-- Above Legendary. Currently only camos reach it; no weapon does, deliberately.
	Mythic = Color3.fromRGB(248, 92, 116),
}

-- Rarest last. The market and the workshop sort by this rather than by price, so a
-- cheap Mythic still shows where a Mythic belongs.
WeaponConfig.RarityOrder = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6,
}

-- ------------------------------------------------------------------ recoil --

-- Recoil described as a block, so a weapon is tuned by editing data rather than code, and so
-- the shape of it is legible: how hard it climbs, how much it wanders, how fast it settles,
-- and how much aiming tames it.
--
-- Legacy flat fields are still honoured. A weapon with no Recoil block behaves exactly as it
-- did before, so this can be adopted one weapon at a time instead of in one risky sweep.
local RECOIL_FALLBACK = {
	Vertical = 1.0,        -- degrees of climb per shot
	Horizontal = 0.4,      -- peak sideways wander per shot
	Kick = 0.9,            -- the one-shot camera jolt, which always returns to zero
	Recovery = 12,         -- how fast the aim offset settles back
	AdsMultiplier = 0.6,   -- aiming braces the weapon

	-- Climb makes the first shots of a burst rise faster than the last, which is what gives
	-- a weapon a recognisable "shape" instead of a straight line.
	Climb = 0.6,
	ClimbShots = 6,

	-- A LEARNABLE pattern, not noise. Horizontal follows a repeating wave keyed to the shot
	-- index, so the same gun wanders the same way every magazine and muscle memory works.
	-- Jitter is the only random part, and it is small enough that the pattern still reads.
	Jitter = 0.15,
	Wave = 1.7,
}

-- Character by CLASS, the way WeaponAudio assigns sound. This is where most of the feel
-- lives, and doing it per class rather than per weapon means every gun gets a distinct recoil
-- signature without thirteen near-identical data blocks to keep in step.
--
-- Only the fields the legacy flat values do NOT cover are set here -- how the climb is shaped,
-- how wide the wander is, how much aiming helps. Vertical, Horizontal and Recovery still come
-- from each weapon's own numbers, so nothing is retuned behind anyone's back.
local RECOIL_BY_CLASS = {
	-- Steady and very learnable: the climb is the whole story.
	Rifle    = { Climb = 0.7, ClimbShots = 7, Jitter = 0.12, Wave = 1.7, AdsMultiplier = 0.55 },
	Carbine  = { Climb = 0.6, ClimbShots = 6, Jitter = 0.14, Wave = 1.9, AdsMultiplier = 0.55 },

	-- Light and fast, so it wanders rather than climbs. Harder to hold, cheap to correct.
	SMG      = { Climb = 0.35, ClimbShots = 10, Jitter = 0.3, Wave = 2.6, AdsMultiplier = 0.7 },

	-- One big shove and a long settle; there is no burst to learn.
	Shotgun  = { Climb = 0.0, ClimbShots = 1, Jitter = 0.2, Wave = 1.1, AdsMultiplier = 0.75 },
	Sniper   = { Climb = 0.0, ClimbShots = 1, Jitter = 0.1, Wave = 0.9, AdsMultiplier = 0.4 },
	Marksman = { Climb = 0.2, ClimbShots = 3, Jitter = 0.12, Wave = 1.3, AdsMultiplier = 0.45 },

	-- Heavy, slow to settle, and it walks sideways the longer it is held.
	LMG      = { Climb = 0.9, ClimbShots = 12, Jitter = 0.22, Wave = 2.1, AdsMultiplier = 0.65 },

	-- Sidearms: sharp per shot, but nothing accumulates.
	Pistol   = { Climb = 0.15, ClimbShots = 4, Jitter = 0.18, Wave = 2.2, AdsMultiplier = 0.6 },
	Revolver = { Climb = 0.0, ClimbShots = 1, Jitter = 0.14, Wave = 1.5, AdsMultiplier = 0.55 },
}

--- Resolve a weapon's recoil into plain numbers.
---
--- Precedence, most specific first: the weapon's own Recoil block, then its legacy flat
--- fields, then its class character, then the generic fallback.
function WeaponConfig.Recoil(cfg)
	local block = (type(cfg) == "table" and type(cfg.Recoil) == "table") and cfg.Recoil or nil
	local byClass = (type(cfg) == "table" and cfg.Class) and RECOIL_BY_CLASS[cfg.Class] or nil
	local out = {}
	for key, fallback in pairs(RECOIL_FALLBACK) do
		local value = block and block[key]
		if type(value) ~= "number" then
			value = byClass and byClass[key]
		end
		out[key] = type(value) == "number" and value or fallback
	end

	-- Legacy flat fields win over the generic fallback but lose to an explicit block, so a
	-- weapon mid-migration is never silently retuned.
	if not block or type(block.Vertical) ~= "number" then
		out.Vertical = tonumber(cfg and cfg.RecoilPitch) or out.Vertical
	end
	if not block or type(block.Horizontal) ~= "number" then
		out.Horizontal = tonumber(cfg and cfg.RecoilYaw) or out.Horizontal
	end
	if not block or type(block.Recovery) ~= "number" then
		out.Recovery = tonumber(cfg and cfg.RecoilRecovery) or out.Recovery
	end
	if not block or type(block.Kick) ~= "number" then
		out.Kick = out.Vertical * 0.8
	end

	return out
end

--- The aim offset one shot adds, given which shot of the burst it is.
---
--- Deterministic apart from Jitter: shot 4 of a Warden burst pulls the same way every time.
function WeaponConfig.RecoilStep(recoil, shotIndex: number, aiming: boolean): (number, number)
	local scale = aiming and recoil.AdsMultiplier or 1

	local climbFraction = math.min(shotIndex, recoil.ClimbShots) / math.max(recoil.ClimbShots, 1)
	local vertical = recoil.Vertical * (1 + recoil.Climb * climbFraction) * scale

	local wave = math.sin(shotIndex * recoil.Wave)
	local jitter = 1 + (math.random() - 0.5) * 2 * recoil.Jitter
	local horizontal = recoil.Horizontal * wave * jitter * scale

	return vertical, horizontal
end

function WeaponConfig.RarityRank(rarity: string?): number
	return WeaponConfig.RarityOrder[rarity or ""] or 0
end

-- ------------------------------------------------------------- categories --

-- Which shelf of the inventory a weapon lives on, keyed by its Class. A weapon can
-- override this with a `Category` field, but it should rarely need to: giving a new gun
-- a Class it already recognises is enough to file it correctly.
WeaponConfig.ClassCategory = {
	Pistol = "Pistols",
	Revolver = "Pistols",
	SMG = "Automatic",
	LMG = "Automatic",
	Rifle = "Rifles",
	Carbine = "Rifles",
	Shotgun = "Shotguns",
	Sniper = "Marksman",
	Marksman = "Marksman",
	Dagger = "Melee",
	Katana = "Melee",
	Warhammer = "Melee",
	Greatsword = "Melee",
}

-- Tab order in the inventory. "All" first, then everything else; a category with nothing
-- in it is simply not drawn, so this can list types the game has not built yet.
WeaponConfig.CategoryOrder = {
	"All", "Rifles", "Automatic", "Pistols", "Shotguns", "Marksman", "Melee", "Other",
}

function WeaponConfig.CategoryOf(cfg): string
	if not cfg then
		return "Other"
	end
	if cfg.Category then
		return cfg.Category                     -- explicit override wins
	end
	local byClass = WeaponConfig.ClassCategory[cfg.Class]
	if byClass then
		return byClass
	end
	return cfg.Type == "Melee" and "Melee" or "Other"
end

-- ------------------------------------------------------------------ stars --

WeaponConfig.RarityStars = {
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
	-- Mythic also shows five: adding a sixth slot would put an empty star on every other
	-- card in the game to distinguish a tier nothing currently occupies. It is told apart
	-- by its colour instead.
	Legendary = 5,
	Mythic = 5,
}

WeaponConfig.MaxStars = 5

-- How many filled stars a weapon shows. Driven by its Rarity, with an optional numeric
-- `Stars` override on the weapon for anything that does not fit the five named tiers.
-- The UI reads this rather than knowing any weapon by name.
function WeaponConfig.StarsFor(cfg): number
	if not cfg then
		return 0
	end
	if type(cfg.Stars) == "number" then
		return math.clamp(cfg.Stars, 0, WeaponConfig.MaxStars)
	end
	return WeaponConfig.RarityStars[cfg.Rarity] or 1
end

-- ------------------------------------------------------------- variants --
--
-- Mastery Weapons. A variant is a WHOLE weapon rather than paint over a shared model --
-- which is the difference between this and the camo system it replaces. It names a `base`
-- weapon and inherits that weapon's stats, so a variant is cosmetic by default and cannot
-- quietly become pay-to-win; give it its own stat block only on purpose.
--
-- `robux` sells it through Roblox's own prompt. `earn` says how it is won instead. A
-- variant may have both, one, or neither -- neither means it is not obtainable yet, which
-- is a legitimate state for one being built.
--
-- Shape:
--   { id = "Carbine_DarkMatter", base = "Carbine", name = "Carbine - Dark Matter",
--     desc = "...", rarity = "Mythic", robux = 499,
--     earn = { mastery = "Ronin", weapon = "Carbine" },
--     model = "CompactCarbine_DarkMatter" }   -- a Tool under ReplicatedStorage.storeitems
--
-- A variant only appears in the market once its Tool actually exists in storeitems, so an
-- entry can be written before the model is imported without putting a dead card on a shelf.
WeaponConfig.Variants = {
	{
		id = "Carbine_DarkMatter",
		base = "Carbine",
		name = "Carbine - Dark Matter",
		desc = "Obsidian and grown crystal. The veins wake up when it fires.",
		rarity = "Mythic",
		robux = 2000,
		-- Earned as well as sold. Silver is 100 kills with the Carbine -- a few hours, not a
		-- grind, which is what "earned early" asks for. One word to move it up a tier.
		earn = { mastery = "Silver", weapon = "Carbine" },
		-- Its own imported model, not a repaint of the Carbine's.
		--
		-- I first built this as a recolour of the base gun plus box-approximated crystals,
		-- because that needed no upload. It looked nothing like the authored model -- the
		-- shards are faceted, not boxes, and the VFX was substituted rather than imported.
		-- The export was brought in through Roblox's 3D importer instead, which is what the
		-- rest of the weapons already do. 298 parts: 134 of gun, 140 crystals, 6 veins,
		-- 14 shimmer motes and 4 muzzle-flash pieces, all as authored.
		model = "Carbine_DarkMatter",
		-- Straight off the authored materials in the VFX export, converted from glTF's linear
		-- space to sRGB: the petals of DarkMatterVFX/MuzzleFlash, and the emissive of
		-- DM_CrystalBright for the tracer. So the shot matches the gun rather than approximating it.
		visual = {
			MuzzleFlashColor = Color3.fromRGB(176, 123, 255),
			TracerColor = Color3.fromRGB(106, 43, 255),
			TracerWidth = 0.1,
		},
	},
}

-- Every variant gets a real Weapons entry, CLONED from its base at load and then overlaid
-- with whatever it changes. Cloning rather than hand-writing the stats is the guard: a
-- variant cannot drift from the gun it is a variant of, so buying one can never buy an
-- advantage. Only the keys under `visual` differ, and those are all cosmetic.
for _, variant in ipairs(WeaponConfig.Variants) do
	local base = WeaponConfig.Weapons[variant.base]
	if base then
		local entry = table.clone(base)
		entry.DisplayName = variant.name
		entry.Rarity = variant.rarity or base.Rarity
		for key, value in pairs(variant.visual or {}) do
			entry[key] = value
		end
		WeaponConfig.Weapons[variant.id] = entry
	else
		warn(("[WeaponConfig] variant %s names a base weapon that does not exist: %s")
			:format(variant.id, tostring(variant.base)))
	end
end

local variantById = {}
for _, variant in ipairs(WeaponConfig.Variants) do
	variantById[variant.id] = variant
end

--- The variant a weapon name refers to, or nil for an ordinary weapon.
function WeaponConfig.VariantOf(name: string?)
	return (name ~= nil) and variantById[name] or nil
end

return WeaponConfig
