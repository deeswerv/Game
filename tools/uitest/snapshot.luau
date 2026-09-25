--!nocheck
-- Serialise what is on screen (the PlayerGui) to JSON for tools/uitest/render.html.
--
-- Only what the renderer understands is written: GuiObjects with their geometry, colours and
-- text, and the UI modifiers (corners, strokes, gradients, padding, layouts, scales, size
-- constraints) that shape them.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

return function(World, outPath: string)
	local R = World.R

	local function udim2(u)
		return { u.X.Scale, u.X.Offset, u.Y.Scale, u.Y.Offset }
	end
	local function v2(v)
		return { v.X, v.Y }
	end
	local function c3(c)
		return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
	end
	local function enumName(e)
		return e and e.Name or nil
	end
	local function colorSeq(seq)
		local out = {}
		for _, k in ipairs(seq.Keypoints) do
			table.insert(out, { k.Time, c3(k.Value) })
		end
		return out
	end
	local function numberSeq(seq)
		local out = {}
		for _, k in ipairs(seq.Keypoints) do
			table.insert(out, { k.Time, k.Value })
		end
		return out
	end
	local function fontOf(inst)
		local ok, face = pcall(function()
			return inst.FontFace
		end)
		if ok and face then
			return { family = tostring(face.Family), weight = enumName(face.Weight), style = enumName(face.Style) }
		end
		return nil
	end

	local function node(inst)
		local cls = inst.ClassName
		local n = { class = cls, name = inst.Name }

		if inst:IsA("LayerCollector") then
			n.enabled = inst.Enabled
			if inst:IsA("ScreenGui") then
				n.displayOrder = inst.DisplayOrder
			end
		elseif inst:IsA("GuiObject") then
			n.visible = inst.Visible
			n.size = udim2(inst.Size)
			n.position = udim2(inst.Position)
			n.anchor = v2(inst.AnchorPoint)
			n.rotation = inst.Rotation
			n.z = inst.ZIndex
			n.order = inst.LayoutOrder
			n.bg = c3(inst.BackgroundColor3)
			n.bgT = inst.BackgroundTransparency
			n.clips = inst.ClipsDescendants
			n.auto = enumName(inst.AutomaticSize)
			if inst:IsA("CanvasGroup") then
				n.groupT = inst.GroupTransparency
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
				n.text = inst.Text
				n.textColor = c3(inst.TextColor3)
				n.textT = inst.TextTransparency
				n.textSize = inst.TextSize
				n.textScaled = inst.TextScaled
				n.wrapped = inst.TextWrapped
				n.rich = inst.RichText
				n.xAlign = enumName(inst.TextXAlignment)
				n.yAlign = enumName(inst.TextYAlignment)
				n.font = fontOf(inst)
				n.strokeT = inst.TextStrokeTransparency
				n.strokeColor = c3(inst.TextStrokeColor3)
			end
			if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
				n.image = inst.Image
				n.imageColor = c3(inst.ImageColor3)
				n.imageT = inst.ImageTransparency
			end
			if inst:IsA("ScrollingFrame") then
				n.canvas = udim2(inst.CanvasSize)
			end
		elseif cls == "UICorner" then
			local r = inst.CornerRadius
			n.radius = { r.Scale, r.Offset }
		elseif cls == "UIStroke" then
			n.color = c3(inst.Color)
			n.thickness = inst.Thickness
			n.transparency = inst.Transparency
			n.mode = enumName(inst.ApplyStrokeMode)
			n.enabled = inst.Enabled
		elseif cls == "UIGradient" then
			n.color = colorSeq(inst.Color)
			n.transparency = numberSeq(inst.Transparency)
			n.rotation = inst.Rotation
			n.enabled = inst.Enabled
		elseif cls == "UIPadding" then
			n.pad = {
				inst.PaddingTop.Offset, inst.PaddingRight.Offset, inst.PaddingBottom.Offset, inst.PaddingLeft.Offset,
			}
		elseif cls == "UIListLayout" then
			n.dir = enumName(inst.FillDirection)
			n.gap = inst.Padding.Offset
			n.h = enumName(inst.HorizontalAlignment)
			n.v = enumName(inst.VerticalAlignment)
			n.sort = enumName(inst.SortOrder)
			n.wraps = inst.Wraps
		elseif cls == "UIGridLayout" then
			n.cell = udim2(inst.CellSize)
			n.cellPad = udim2(inst.CellPadding)
			n.dir = enumName(inst.FillDirection)
			n.h = enumName(inst.HorizontalAlignment)
			n.v = enumName(inst.VerticalAlignment)
			n.sort = enumName(inst.SortOrder)
		elseif cls == "UIScale" then
			n.scale = inst.Scale
		elseif cls == "UISizeConstraint" then
			n.min = v2(inst.MinSize)
			n.max = { math.min(inst.MaxSize.X, 1e5), math.min(inst.MaxSize.Y, 1e5) }
		elseif cls == "UIAspectRatioConstraint" then
			n.ratio = inst.AspectRatio
		else
			return nil
		end

		local children = {}
		for _, child in ipairs(inst:GetChildren()) do
			local c = node(child)
			if c then
				table.insert(children, c)
			end
		end
		if #children > 0 then
			n.children = children
		end
		return n
	end

	local screens = {}
	for _, child in ipairs(World.playerGui:GetChildren()) do
		if child:IsA("LayerCollector") and child.Enabled then
			local n = node(child)
			if n then
				table.insert(screens, n)
			end
		end
	end
	table.sort(screens, function(a, b)
		return (a.displayOrder or 0) < (b.displayOrder or 0)
	end)
	fs.writeFile(outPath, serde.encode("json", { viewport = { 1280, 720 }, screens = screens }))
	return #screens
end
