-- The look of every screen, from the owner's references (docs/references/style): chunky bright buttons with a thick dark
-- outline and a stud texture, bold white text with a black stroke, and dark studded panels under a bright header bar.
local Style = {}

local STUDS = "rbxassetid://6372755229" -- also used on the map; see docs/phase8/ASSETS.md

Style.GREEN = Color3.fromRGB(100, 215, 50)
Style.CYAN = Color3.fromRGB(30, 200, 240)
Style.ORANGE = Color3.fromRGB(255, 150, 40)
Style.RED = Color3.fromRGB(225, 40, 50)
Style.PINK = Color3.fromRGB(235, 70, 170)
Style.PURPLE = Color3.fromRGB(150, 80, 235)
Style.BLUE = Color3.fromRGB(60, 120, 245)
Style.GRAY = Color3.fromRGB(125, 125, 140)
Style.GOLD = Color3.fromRGB(255, 225, 60)
Style.PANEL = Color3.fromRGB(46, 46, 58)
Style.CARD = Color3.fromRGB(70, 70, 86)
Style.INK = Color3.fromRGB(14, 12, 24)
Style.FONT = Enum.Font.FredokaOne

function Style.corner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 6)
	c.Parent = obj
	return c
end

function Style.outline(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 3
	s.Color = color or Style.INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

-- the stud texture, laid over a frame
function Style.studs(obj, transparency)
	local t = Instance.new("ImageLabel")
	t.Name = "Studs"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Image = STUDS
	t.ImageColor3 = Color3.new(0, 0, 0)
	t.ImageTransparency = transparency or 0.88
	t.ScaleType = Enum.ScaleType.Tile
	t.TileSize = UDim2.fromOffset(28, 28)
	t.ZIndex = obj.ZIndex
	t.Active = false
	t.Interactable = false
	Style.corner(t, 6)
	t.Parent = obj
	return t
end

-- white heavy text with a black stroke, on anything
function Style.textStroke(t, thickness)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = Style.INK
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = t
	return s
end

function Style.label(name, parent, text, color)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Style.FONT
	t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.Text = text
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextWrapped = true
	t.Parent = parent
	Style.textStroke(t, 2)
	return t
end

function Style.button(name, parent, text, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.BackgroundColor3 = color
	b.Font = Style.FONT
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Style.corner(b, 6)
	Style.outline(b, 3, color:Lerp(Style.INK, 0.72))
	Style.studs(b, 0.86)
	Style.textStroke(b, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 4), UDim.new(0, 4)
	pad.Parent = b
	return b
end

-- a dark card for a row in a list
function Style.card(name, parent, order, height, edge)
	local f = Instance.new("Frame")
	f.Name = name
	f.LayoutOrder = order or 0
	f.Size = UDim2.new(1, -12, 0, height)
	f.BackgroundColor3 = Style.CARD
	f.Parent = parent
	Style.corner(f, 6)
	Style.outline(f, 2, edge or Style.INK)
	Style.studs(f, 0.92)
	return f
end

-- a panel with a bright studded header, title and red X. Content starts 62 pixels down.
-- Returns the panel, its title label and the close button.
function Style.panel(gui, name, title, headerColor, maxSize)
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.Visible = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromScale(0.94, 0.84)
	panel.BackgroundColor3 = Style.PANEL
	panel.Parent = gui
	Style.corner(panel, 8)
	Style.outline(panel, 4, Style.INK)
	Style.studs(panel, 0.9)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = maxSize or Vector2.new(660, 580)
	cap.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 54)
	header.BackgroundColor3 = headerColor
	header.Parent = panel
	Style.corner(header, 8)
	Style.outline(header, 3, headerColor:Lerp(Style.INK, 0.72))
	Style.studs(header, 0.84)

	local titleLabel = Style.label("Title", header, title)
	titleLabel.Position = UDim2.fromOffset(14, 7)
	titleLabel.Size = UDim2.new(1, -86, 0, 40)
	Style.textStroke(titleLabel, 3)

	local close = Style.button("Close", header, "X", Style.RED)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -7, 0, 6)
	close.Size = UDim2.fromOffset(44, 42)
	return panel, titleLabel, close
end

-- a scrolling list that fills a panel from `top` pixels down
function Style.list(panel, top)
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Position = UDim2.fromOffset(12, top)
	list.Size = UDim2.new(1, -24, 1, -(top + 10))
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

return Style
