--!strict
-- Theme: the single source of truth for how the interface looks.
--
-- Every colour, size, gap and corner in the UI comes from this file, so a change here lands
-- everywhere -- including the older UIKit panels (prompts, quests, chests, emote wheel),
-- which map their palette from these values.
--
-- The look is read off the reference shots (profile card, inventory, shop, armory, HUD):
--
--   * Chunky and bold. Source Sans Bold for words, a rounded heavy face (Fredoka One) for
--     the numbers the player actually reads -- cash, level, ammo, stats.
--   * Every piece of text carries a dark outline. That is what lets type float over the
--     world with no box behind it, and it is the single most recognisable trait of the
--     references compared with a default Roblox GUI.
--   * Dark charcoal glass panels over a blurred world, rounded generously.
--   * Colour means something: bright green is money and the primary action, gold is level
--     and rank, red is danger and closing, cyan is armour. Cards are flooded with their
--     rarity colour as a gradient, the way the reference weapon cards are green.

local Theme = {}

-- ----------------------------------------------------------------- palette --

Theme.Colour = {
	Scrim       = Color3.fromRGB(6, 8, 12),       -- full-screen dim behind a menu
	Sunken      = Color3.fromRGB(14, 15, 19),     -- inset wells, list backgrounds
	Panel       = Color3.fromRGB(24, 25, 31),     -- the default surface (charcoal glass)
	PanelRaised = Color3.fromRGB(38, 40, 48),     -- cards and tiles sitting on a panel
	Hover       = Color3.fromRGB(56, 59, 70),
	Stroke      = Color3.fromRGB(78, 82, 96),     -- card border
	StrokeSoft  = Color3.fromRGB(44, 47, 56),     -- divider inside a panel
	Outline     = Color3.fromRGB(8, 8, 12),       -- the dark edge around text and chunky frames

	Text        = Color3.fromRGB(255, 255, 255),
	TextDim     = Color3.fromRGB(186, 190, 200),  -- labels, subtitles, units
	TextMuted   = Color3.fromRGB(122, 127, 140),  -- disabled, placeholder, locked

	-- The primary action: the DUEL button and the "+" beside the cash in the references.
	Accent      = Color3.fromRGB(46, 204, 84),
	AccentDim   = Color3.fromRGB(24, 128, 50),
	AccentText  = Color3.fromRGB(255, 255, 255),  -- white on green, outlined, as referenced

	Info        = Color3.fromRGB(64, 170, 255),   -- selection, neutral highlight
	Warning     = Color3.fromRGB(255, 190, 32),   -- level diamond, soft gate
	Danger      = Color3.fromRGB(232, 52, 60),    -- destructive, close, low health
	Currency    = Color3.fromRGB(64, 236, 64),    -- cash figures only
	CurrencyEdge = Color3.fromRGB(10, 70, 16),    -- the dark green outline on cash figures

	Health      = Color3.fromRGB(36, 214, 36),
	Armour      = Color3.fromRGB(52, 214, 240),
	Level       = Color3.fromRGB(255, 196, 30),
	LevelEdge   = Color3.fromRGB(196, 110, 8),
	Kill        = Color3.fromRGB(236, 30, 36),    -- victim names, kill counts
	Xp          = Color3.fromRGB(214, 84, 255),
}

-- Rarity floods a card as a gradient (as the reference weapon cards are flooded green), and
-- tints its border, chip and name. Six steps, each separable at chip size.
Theme.Rarity = {
	Common    = { colour = Color3.fromRGB(150, 158, 172), order = 1 },
	Uncommon  = { colour = Color3.fromRGB(46, 200, 84),   order = 2 },
	Rare      = { colour = Color3.fromRGB(46, 150, 255),  order = 3 },
	Epic      = { colour = Color3.fromRGB(176, 76, 255),  order = 4 },
	Legendary = { colour = Color3.fromRGB(255, 170, 20),  order = 5 },
	Mythic    = { colour = Color3.fromRGB(255, 56, 96),   order = 6 },
}

Theme.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

function Theme.RarityColour(name: string?): Color3
	local entry = name and Theme.Rarity[name]
	return entry and entry.colour or Theme.Colour.TextMuted
end

-- -------------------------------------------------------------- typography --

-- Enum fonts, because every older panel sets `.Font` directly and keeps working unchanged.
Theme.Font = {
	Display = Enum.Font.FredokaOne,        -- numbers and headlines
	Bold    = Enum.Font.SourceSansBold,    -- words
	Medium  = Enum.Font.SourceSansSemibold,
}

-- FontFaces for the few places an Enum font cannot reach: a condensed face for the ammo
-- count and the player's name, and a heavy italic for the elimination call.
Theme.Face = {
	Condensed = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold),
	Heavy = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy),
	HeavyItalic = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy,
		Enum.FontStyle.Italic),
	Display = Font.fromEnum(Enum.Font.FredokaOne),
}

-- A scale, not a free-for-all. Source Sans sets smaller than Gotham at the same size, so
-- these run a step larger than a Gotham UI would.
Theme.Text = {
	Micro = 12, Small = 14, Body = 16, Large = 19, Title = 26, Huge = 36, Hero = 50,
}

-- ------------------------------------------------------------------ metrics --

Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32 }

-- Generous, chunky rounding, as in every reference panel and card.
Theme.Radius = { Chip = 6, Small = 8, Card = 12, Panel = 18, Pill = 999 }

Theme.Stroke = { Hair = 1.5, Emphasis = 3 }

-- Text outline thickness by size. A 12px label with a 2px edge turns to mush; a 36px number
-- with a 1px edge vanishes against the sky.
function Theme.OutlineFor(size: number): number
	if size >= 34 then
		return 3
	elseif size >= 24 then
		return 2.2
	elseif size >= 16 then
		return 1.6
	end
	return 1.1
end

-- Shared sizes, so a card in the market matches a card in the inventory.
Theme.Size = {
	SlotTile = Vector2.new(132, 132),
	RailWidth = 96,
	RowHeight = 44,
	ButtonHeight = 42,
	ButtonHeightS = 32,
	IconButton = 44,
	HeaderHeight = 72,
}

-- ---------------------------------------------------------------- animation --

-- Snappy with a little overshoot on the things that should feel physical (buttons, cards,
-- pop-ins); flat on values, which must never wobble past the number they are showing.
Theme.Tween = {
	Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Open  = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Value = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
	Pop   = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

Theme.Motion = { Rise = 26, HoverLift = 3, PressSink = 2 }

-- Named so two screens can never argue about who sits on top.
Theme.Layer = { HUD = 1, Menu = 10, Overlay = 20, Toast = 30, Tooltip = 40 }

-- --------------------------------------------------------------- responsive --

-- The design is authored at this size and scaled rather than re-laid-out per device.
Theme.DesignResolution = Vector2.new(1280, 720)
Theme.ScaleRange = NumberRange.new(0.62, 1.2)
Theme.MobileWidth = 700

--- Scale for a viewport, clamped so text never becomes unreadable on a phone or comically
--- large on a 4K monitor.
function Theme.ScaleFor(viewport: Vector2): number
	local raw = math.min(viewport.X / Theme.DesignResolution.X, viewport.Y / Theme.DesignResolution.Y)
	return math.clamp(raw, Theme.ScaleRange.Min, Theme.ScaleRange.Max)
end

function Theme.IsCompact(viewport: Vector2): boolean
	return viewport.X < Theme.MobileWidth
end

-- Kept clear of the Roblox topbar and the mobile notch.
Theme.Inset = { Top = 52, Side = 20, Bottom = 18 }

-- ----------------------------------------------------------------- helpers --

--- A darker or lighter version of a colour, for gradient ends and borders.
function Theme.Shade(colour: Color3, amount: number): Color3
	if amount >= 0 then
		return colour:Lerp(Color3.new(1, 1, 1), amount)
	end
	return colour:Lerp(Color3.new(0, 0, 0), -amount)
end

return Theme
