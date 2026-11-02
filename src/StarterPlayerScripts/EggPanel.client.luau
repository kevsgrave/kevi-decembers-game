-- The egg shrine's panel: every egg with its price and odds before you spend, then a short skippable reveal.
-- The result is decided on the server before the reveal starts, so skipping can't change it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local hatchRemote = Net.Function("HatchEgg")

local DARK = Color3.fromRGB(20, 10, 40)
local PANEL = Color3.fromRGB(60, 40, 110)
local ROW = Color3.fromRGB(85, 60, 145)
local LIME = Color3.fromRGB(60, 200, 90)
local SILVER = Color3.fromRGB(150, 150, 165)

local gui = Instance.new("ScreenGui") gui.Name = "EggPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 2
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r) end
local function label(name, parent, text, color)
	local t = Instance.new("TextLabel") t.Name = name t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1) t.Text = text t.TextXAlignment = Enum.TextXAlignment.Left t.Parent = parent
	return t
end
local function button(name, parent, text, color)
	local b = Instance.new("TextButton") b.Name = name b.BackgroundColor3 = color b.Font = Enum.Font.FredokaOne b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1) b.Text = text b.Parent = parent
	corner(b, 10)
	return b
end

local panel = Instance.new("Frame") panel.Name = "Panel" panel.Visible = false panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.55) panel.Size = UDim2.fromScale(0.92, 0.76) panel.BackgroundColor3 = PANEL panel.Parent = gui
corner(panel, 18)
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(640, 540) cap.Parent = panel
local title = label("Title", panel, "Egg Shrine", Color3.new(1, 1, 1))
title.Position = UDim2.fromOffset(16, 10) title.Size = UDim2.new(1, -90, 0, 34)
local closeButton = button("Close", panel, "X", SILVER)
closeButton.AnchorPoint = Vector2.new(1, 0) closeButton.Position = UDim2.new(1, -10, 0, 8) closeButton.Size = UDim2.fromOffset(44, 44)
local list = Instance.new("ScrollingFrame") list.Name = "List" list.Position = UDim2.fromOffset(12, 58) list.Size = UDim2.new(1, -24, 1, -70)
list.BackgroundTransparency = 1 list.BorderSizePixel = 0 list.ScrollBarThickness = 8 list.CanvasSize = UDim2.new() list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.Parent = panel
local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 6) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = list

-- the reveal
local reveal = Instance.new("TextButton") reveal.Name = "Reveal" reveal.Size = UDim2.fromScale(1, 1) reveal.BackgroundColor3 = DARK reveal.BackgroundTransparency = 0.2
reveal.AutoButtonColor = false reveal.Text = "" reveal.Visible = false reveal.ZIndex = 5 reveal.Parent = gui
local function revealLabel(name, y, height, text)
	local t = Instance.new("TextLabel") t.Name = name t.AnchorPoint = Vector2.new(0.5, 0.5) t.Position = UDim2.fromScale(0.5, y) t.Size = UDim2.fromScale(0.8, height)
	t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.new(1, 1, 1) t.Text = text t.ZIndex = 6 t.Parent = reveal
	return t
end
local eggIcon = revealLabel("Egg", 0.42, 0.3, "🥚")
local nameText = revealLabel("Name", 0.42, 0.14, "")
local rarityText = revealLabel("Rarity", 0.54, 0.09, "")
local infoText = revealLabel("Info", 0.64, 0.07, "")
local tapText = revealLabel("Tap", 0.8, 0.05, "Tap to skip")

local revealRun = 0

local function showResult(r)
	local tier = Config.TIER_BY_NAME[r.tier]
	eggIcon.Visible = false
	nameText.Text = r.kind
	rarityText.Text = r.tier
	rarityText.TextColor3 = tier and tier.color or Color3.new(1, 1, 1)
	infoText.Text = "👻 " .. Config.short(r.baseFear) .. " / scare, every " .. (tier and tier.interval or "?") .. "s. Added to your inventory"
	tapText.Text = "Tap to close"
end

local shown = nil
local function startReveal(r)
	revealRun += 1
	local run = revealRun
	shown = r
	eggIcon.Visible = true
	nameText.Text, rarityText.Text, infoText.Text = "", "", ""
	tapText.Text = "Tap to skip"
	reveal.Visible = true
	for i = 1, 16 do
		if run ~= revealRun then return end
		eggIcon.Rotation = ((i % 2 == 0) and 1 or -1) * math.min(i * 2, 22)
		task.wait(0.1)
	end
	if run == revealRun and shown then
		showResult(shown)
		shown = nil
	end
end

reveal.Activated:Connect(function()
	if shown then
		showResult(shown)
		shown = nil
		revealRun += 1
	else
		reveal.Visible = false
	end
end)

local busy = false
local requestCount = 0

local function hatch(eggId, feedback)
	if busy then return end -- no second request until the first answers
	busy = true
	requestCount += 1
	feedback.Text = "..."
	local ok, success, result = pcall(hatchRemote.InvokeServer, hatchRemote, eggId, player.UserId .. "-" .. requestCount)
	busy = false
	if ok and success then
		panel.Visible = false
		task.spawn(startReveal, result)
	else
		feedback.Text = (ok and success == false and result) or "Try again"
	end
end

local function oddsLine(egg)
	local parts = {}
	for _, r in ipairs(Config.Balance.rarities) do
		local chance = egg.odds[r.id]
		if chance and chance > 0 then table.insert(parts, r.id .. " " .. tostring(chance) .. "%") end
	end
	return table.concat(parts, ", ")
end

local function addRow(egg, position, free)
	local f = Instance.new("Frame") f.Name = egg.id f.LayoutOrder = position f.Size = UDim2.new(1, -12, 0, 96) f.BackgroundColor3 = ROW f.Parent = list
	corner(f, 12)
	local top = label("Name", f, egg.name .. (free and " - FREE" or " - " .. Config.short(egg.price) .. " Fear"), Color3.fromRGB(255, 225, 110))
	top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -130, 0, 30)
	local odds = label("Odds", f, oddsLine(egg))
	odds.Position = UDim2.fromOffset(12, 38) odds.Size = UDim2.new(1, -130, 0, 48)
	odds.TextWrapped = true
	local hatchButton = button("Hatch", f, "Hatch", LIME)
	hatchButton.AnchorPoint = Vector2.new(1, 0.5) hatchButton.Position = UDim2.new(1, -8, 0.5, 0) hatchButton.Size = UDim2.fromOffset(104, 60)
	hatchButton.Activated:Connect(function()
		hatch(egg.id, hatchButton)
		if hatchButton.Parent and hatchButton.Text == "..." then hatchButton.Text = "Hatch" end
	end)
end

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local position = 0
	for _, egg in ipairs(Config.Balance.eggs) do
		local promise = egg.source == "tutorial" and player:GetAttribute("PromiseEgg") == true
		if promise or (egg.source == "fear" and egg.live) then
			position += 1
			addRow(egg, if promise then 0 else position, promise)
		end
	end
end

local function open()
	render()
	panel.Visible = true
end

closeButton.Activated:Connect(function() panel.Visible = false end)
player:GetAttributeChangedSignal("PromiseEgg"):Connect(function()
	if panel.Visible then render() end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "HatchPrompt" then open() end
end)
