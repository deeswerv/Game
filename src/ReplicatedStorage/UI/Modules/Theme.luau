--!strict
-- Theme: the single source of truth for how the interface looks.
--
-- Every colour, size, gap and corner in the new UI comes from this file. That is the point of
-- it -- the old interface drifted because each screen picked its own greys and its own
-- padding, so nothing looked related. Change a value here and the change lands everywhere.
--
-- The values were read off the reference shots rather than invented: a near-black panel on a
-- dark scrim, one hairline stroke, white type at two weights, muted grey for anything
-- secondary, and exactly one saturated accent doing the work of "this is the thing to press".
-- Colour is rationed on purpose. The moment three accents compete the screen stops having a
-- hierarchy, which is the single biggest difference between the references and a default
-- Roblox GUI.

local Theme = {}

-- ----------------------------------------------------------------- palette --

Theme.Colour = {
	Scrim       = Color3.fromRGB(8, 10, 14),      -- full-screen dim behind a menu
	Sunken      = Color3.fromRGB(18, 20, 26),     -- inset wells, list backgrounds
	Panel       = Color3.fromRGB(23, 26, 33),     -- the default surface
	PanelRaised = Color3.fromRGB(31, 35, 44),     -- cards sitting on a panel
	Hover       = Color3.fromRGB(39, 44, 55),
	Stroke      = Color3.fromRGB(46, 52, 65),     -- 1px hairline; never thicker
	StrokeSoft  = Color3.fromRGB(34, 38, 48),     -- divider inside a panel

	Text        = Color3.fromRGB(255, 255, 255),
	TextDim     = Color3.fromRGB(167, 174, 188),  -- labels, subtitles, units
	TextMuted   = Color3.fromRGB(110, 118, 134),  -- disabled, placeholder, locked

	-- One accent. The primary action and nothing else.
	Accent      = Color3.fromRGB(55, 214, 122),
	AccentDim   = Color3.fromRGB(38, 158, 89),
	AccentText  = Color3.fromRGB(8, 10, 14),      -- type that sits ON the accent

	Info        = Color3.fromRGB(78, 168, 255),   -- selection, neutral highlight
	Warning     = Color3.fromRGB(245, 196, 81),   -- level badge, soft gate
	Danger      = Color3.fromRGB(229, 72, 77),    -- destructive, low health
	Currency    = Color3.fromRGB(93, 214, 128),   -- cash figures only
}

-- Rarity is a small swatch, a border and a word -- never a card flooded with colour. Six
-- steps, each separable at chip size.
Theme.Rarity = {
	Common    = { colour = Color3.fromRGB(154, 163, 178), order = 1 },
	Uncommon  = { colour = Color3.fromRGB(76, 195, 138),  order = 2 },
	Rare      = { colour = Color3.fromRGB(78, 168, 255),  order = 3 },
	Epic      = { colour = Color3.fromRGB(168, 85, 247),  order = 4 },
	Legendary = { colour = Color3.fromRGB(245, 165, 36),  order = 5 },
	Mythic    = { colour = Color3.fromRGB(255, 77, 109),  order = 6 },
}

Theme.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

function Theme.RarityColour(name: string?): Color3
	local entry = name and Theme.Rarity[name]
	return entry and entry.colour or Theme.Colour.TextMuted
end

-- -------------------------------------------------------------- typography --

-- Two weights and nothing else. Heavy for anything read at a glance -- a number, a title, a
-- button -- and medium for everything supporting it.
Theme.Font = {
	Display = Enum.Font.GothamBlack,
	Bold    = Enum.Font.GothamBold,
	Medium  = Enum.Font.GothamMedium,
}

-- A scale, not a free-for-all. Anything needing a size picks the nearest step.
Theme.Text = {
	Micro = 11, Small = 13, Body = 15, Large = 18, Title = 24, Huge = 34, Hero = 46,
}

-- ------------------------------------------------------------------ metrics --

-- One 4px rhythm. Every gap and pad comes from here, which is most of what makes a layout
-- read as deliberate rather than assembled.
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24, XXL = 32 }

-- Corners stay tight. The references round just enough to soften an edge; larger starts to
-- read as a mobile simulator.
Theme.Radius = { Chip = 4, Small = 6, Card = 10, Panel = 14, Pill = 999 }

Theme.Stroke = { Hair = 1, Emphasis = 2 }

-- Shared sizes, so a card in the market matches a card in the inventory.
Theme.Size = {
	SlotTile = Vector2.new(132, 132),
	RailWidth = 84,
	RowHeight = 44,
	ButtonHeight = 40,
	ButtonHeightS = 30,
	IconButton = 44,
	HeaderHeight = 56,
}

-- ---------------------------------------------------------------- animation --

-- Fast, flat, never bouncy. A press should feel acknowledged, not launched.
Theme.Tween = {
	Hover = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Press = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Open  = TweenInfo.new(0.20, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Close = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	Value = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
}

-- How far a menu travels as it opens. Small on purpose: a long slide reads as slow even when
-- it is fast.
Theme.Motion = { Rise = 18, HoverLift = 2, PressSink = 1 }

-- Named so two screens can never argue about who sits on top.
Theme.Layer = { HUD = 1, Menu = 10, Overlay = 20, Toast = 30, Tooltip = 40 }

-- --------------------------------------------------------------- responsive --

-- The design is authored at this size and scaled rather than re-laid-out per device. It is
-- the cheapest way to be correct on every aspect ratio and keeps one set of numbers.
Theme.DesignResolution = Vector2.new(1280, 720)
Theme.ScaleRange = NumberRange.new(0.70, 1.15)
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

-- Kept clear of the Roblox topbar and the mobile notch, read from here rather than each
-- corner guessing its own inset.
Theme.Inset = { Top = 48, Side = 20, Bottom = 20 }

return Theme
