-- The egg shrine's panel: every egg with its price and odds before you spend, then a short skippable reveal.
-- The result is decided on the server before the reveal starts, so skipping can't change it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local Style = require(Shared:WaitForChild("Style"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local player = Players.LocalPlayer
local hatchRemote = Net.Function("HatchEgg")

local LIME = Style.GREEN
local label, button = Style.label, Style.button

local gui = Instance.new("ScreenGui") gui.Name = "EggPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 2
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel, _, closeButton = Style.panel(gui, "Panel", "🥚 Eggs", Style.RED)
local list = Style.list(panel, 62)

-- the reveal
local reveal = Instance.new("TextButton") reveal.Name = "Reveal" reveal.Size = UDim2.fromScale(1, 1) reveal.BackgroundColor3 = Style.INK reveal.BackgroundTransparency = 0.25
reveal.AutoButtonColor = false reveal.Text = "" reveal.Visible = false reveal.ZIndex = 5 reveal.Parent = gui
local function revealLabel(name, y, height, text)
	local t = Instance.new("TextLabel") t.Name = name t.AnchorPoint = Vector2.new(0.5, 0.5) t.Position = UDim2.fromScale(0.5, y) t.Size = UDim2.fromScale(0.8, height)
	t.BackgroundTransparency = 1 t.Font = Style.FONT t.TextScaled = true t.TextColor3 = Color3.new(1, 1, 1) t.Text = text t.ZIndex = 6 t.Parent = reveal
	Style.textStroke(t, 3)
	return t
end
local eggIcon = revealLabel("Egg", 0.42, 0.3, "🥚")
local nameText = revealLabel("Name", 0.42, 0.14, "")
local rarityText = revealLabel("Rarity", 0.54, 0.09, "")
local infoText = revealLabel("Info", 0.64, 0.07, "")
local tapText = revealLabel("Tap", 0.8, 0.05, "Tap to skip")

local revealRun = 0

local function showResult(r)
	Sounds.play("hatch")
	local tier = Config.TIER_BY_NAME[r.tier]
	eggIcon.Visible = false
	nameText.Text = r.kind
	rarityText.Text = r.tier .. (if r.mutation then " - " .. r.mutation .. "!" else "")
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

-- eggs hatched from the inventory come back here for the same reveal
Net.Event("HatchReveal").OnClientEvent:Connect(function(result)
	task.spawn(startReveal, result)
end)

local function oddsLine(egg)
	local parts = {}
	for _, r in ipairs(Config.Balance.rarities) do
		local chance = egg.odds[r.id]
		if chance and chance > 0 then table.insert(parts, r.id .. " " .. tostring(chance) .. "%") end
	end
	return table.concat(parts, ", ")
end

-- standard Fear eggs can mutate; the chances are the same for each and shown with the odds
local function mutationLine()
	local parts = {}
	for _, m in ipairs(Config.Balance.mutations) do table.insert(parts, m.id .. " " .. tostring(m.rollChance) .. "%") end
	return "Mutation chance: " .. table.concat(parts, ", ")
end

local function addRow(egg, position, free)
	local f = Style.card(egg.id, list, position, if free then 96 else 124, if free then Style.GOLD else nil)
	local top = label("Name", f, egg.name .. (free and " - FREE" or " - " .. Config.short(egg.price) .. " Fear"), Color3.fromRGB(255, 225, 110))
	top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -130, 0, 30)
	local odds = label("Odds", f, oddsLine(egg))
	odds.Position = UDim2.fromOffset(12, 38) odds.Size = UDim2.new(1, -130, 0, 48)
	odds.TextWrapped = true
	if not free then
		local mutations = label("Mutations", f, mutationLine(), Color3.fromRGB(215, 205, 240))
		mutations.Position = UDim2.fromOffset(12, 88) mutations.Size = UDim2.new(1, -130, 0, 30) mutations.TextWrapped = true
	end
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
Panels.register("Eggs", open, panel)
player:GetAttributeChangedSignal("PromiseEgg"):Connect(function()
	if panel.Visible then render() end
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "HatchPrompt" then Panels.open("Eggs") end
end)
