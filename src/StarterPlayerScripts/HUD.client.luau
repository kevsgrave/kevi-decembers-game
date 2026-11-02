-- The main screen, laid out as in the owner's references: stacked buttons on the left, Fear at the bottom left, square icon
-- buttons on the right, and a shop timer at the bottom right. Shows server-owned values only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local PlotLayout = require(Shared:WaitForChild("PlotLayout"))
local Style = require(Shared:WaitForChild("Style"))
local UiFit = require(Shared:WaitForChild("UiFit"))

local player = Players.LocalPlayer
local popupRemote = Net.Event("Popup")
local rebirthRemote = Net.Function("Rebirth")
local fear = player:WaitForChild("leaderstats"):WaitForChild("Fear")

local gui = Instance.new("ScreenGui") gui.Name = "HUD" gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

-- on touch screens the thumbstick and jump button take the bottom corners, so Fear and the timer go top right
local touch = UserInputService.TouchEnabled

-- the left-hand stack
local sidebar = Instance.new("Frame") sidebar.Name = "Sidebar" sidebar.AnchorPoint = Vector2.new(0, 0.5) sidebar.Position = UDim2.new(0, 12, 0.45, 0)
sidebar.Size = UDim2.fromOffset(176, 340) sidebar.BackgroundTransparency = 1 sidebar.Parent = gui
UiFit.scale(sidebar)
local stack = Instance.new("UIListLayout") stack.Padding = UDim.new(0, 8) stack.SortOrder = Enum.SortOrder.LayoutOrder stack.VerticalAlignment = Enum.VerticalAlignment.Center stack.Parent = sidebar

local function sideButton(name, text, color, order)
	local b = Style.button(name, sidebar, text, color)
	b.Size = UDim2.new(1, 0, 0, 50)
	b.LayoutOrder = order
	return b
end

sideButton("Shop", "🛒 Shop", Style.GREEN, 1).Activated:Connect(function() Panels.toggle("Shop") end)
sideButton("Index", "📖 Index", Style.CYAN, 2).Activated:Connect(function() Panels.toggle("Index") end)
sideButton("Inventory", "🎒 Inventory", Style.ORANGE, 3).Activated:Connect(function() Panels.toggle("Inventory") end)
local rebirthBtn = sideButton("Rebirth", "", Style.PINK, 4)
sideButton("Settings", "⚙️ Settings", Style.GRAY, 5).Activated:Connect(function() Panels.toggle("Settings") end)
local howTo = sideButton("HowToPlay", "❓ How to play", Style.BLUE, 6)
howTo.Visible = false

-- the right-hand icon buttons, with a badge when something's waiting
local rightSide = Instance.new("Frame") rightSide.Name = "RightSide" rightSide.AnchorPoint = Vector2.new(1, 0.5) rightSide.Position = UDim2.new(1, -12, 0.45, 0)
rightSide.Size = UDim2.fromOffset(68, 144) rightSide.BackgroundTransparency = 1 rightSide.Parent = gui
UiFit.scale(rightSide)
local rightStack = Instance.new("UIListLayout") rightStack.Padding = UDim.new(0, 8) rightStack.SortOrder = Enum.SortOrder.LayoutOrder rightStack.Parent = rightSide

local function iconButton(name, icon, color, order)
	local b = Style.button(name, rightSide, icon, color)
	b.Size = UDim2.fromOffset(66, 66)
	b.LayoutOrder = order
	return b
end
local eggsButton = iconButton("Eggs", "🥚", Style.RED, 1)
eggsButton.Activated:Connect(function() Panels.toggle("Eggs") end)
iconButton("Forge", "🔥", Style.PURPLE, 2).Activated:Connect(function() Panels.toggle("Forge") end)

local badge = Instance.new("TextLabel") badge.Name = "Badge" badge.AnchorPoint = Vector2.new(0.5, 0.5) badge.Position = UDim2.new(1, -2, 1, -2) badge.Size = UDim2.fromOffset(26, 26)
badge.BackgroundColor3 = Style.GREEN badge.Font = Style.FONT badge.TextScaled = true badge.TextColor3 = Color3.new(1, 1, 1) badge.Text = "1" badge.Visible = false badge.ZIndex = 3 badge.Parent = eggsButton
Style.corner(badge, 13)
Style.outline(badge, 2)
Style.textStroke(badge, 1.5)
local function showBadge() badge.Visible = player:GetAttribute("PromiseEgg") == true end
player:GetAttributeChangedSignal("PromiseEgg"):Connect(showBadge)
showBadge()

-- Fear and the rough rate
local money = Instance.new("Frame") money.Name = "Money" money.BackgroundTransparency = 1 money.Size = UDim2.fromOffset(360, 92)
if touch then
	money.AnchorPoint = Vector2.new(1, 0) money.Position = UDim2.new(1, -12, 0, 2)
else
	money.AnchorPoint = Vector2.new(0, 1) money.Position = UDim2.new(0, 12, 1, -8)
end
money.Parent = gui
UiFit.scale(money)
local align = if touch then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
local fearLabel = Style.label("Fear", money, "", Color3.new(1, 1, 1))
fearLabel.Position = UDim2.fromOffset(0, 30) fearLabel.Size = UDim2.new(1, 0, 0, 62) fearLabel.TextXAlignment = align
Style.textStroke(fearLabel, 3)
local rateLabel = Style.label("Rate", money, "", Color3.fromRGB(170, 255, 120))
rateLabel.Size = UDim2.new(1, 0, 0, 30) rateLabel.TextXAlignment = align
-- an estimate only: Fear itself arrives when each scare finishes
local function showRate()
	local rate = player:GetAttribute("FearPerSecond") or 0
	rateLabel.Visible = rate > 0
	rateLabel.Text = "+" .. (rate < 100 and string.format("%.1f", rate) or Config.short(rate)) .. " / sec"
end
player:GetAttributeChangedSignal("FearPerSecond"):Connect(showRate)
showRate()

-- the shop timer, from the server's clock
local timer = Style.label("ShopTimer", gui, "", Color3.new(1, 1, 1))
timer.Size = UDim2.fromOffset(250, 34)
timer.TextXAlignment = Enum.TextXAlignment.Right
if touch then
	timer.AnchorPoint = Vector2.new(1, 0) timer.Position = UDim2.new(1, -12, 0, 72)
else
	timer.AnchorPoint = Vector2.new(1, 1) timer.Position = UDim2.new(1, -14, 1, -12)
end
UiFit.scale(timer)
local rotation = Config.Balance.shop.rotationSeconds
task.spawn(function()
	while true do
		local left = rotation - workspace:GetServerTimeNow() % rotation
		timer.Text = string.format("🛒 New stock in %d:%02d", math.floor(left / 60), math.floor(left % 60))
		task.wait(1)
	end
end)

-- popups
local popup = Style.label("Popup", gui, "", Color3.new(1, 1, 1))
popup.AnchorPoint = Vector2.new(0.5, 0) popup.Position = UDim2.new(0.5, 0, 0.2, 0) popup.Size = UDim2.new(0.8, 0, 0, 46)
popup.TextXAlignment = Enum.TextXAlignment.Center popup.TextTransparency = 1
local popupStroke = popup:FindFirstChildOfClass("UIStroke") popupStroke.Transparency = 1 popupStroke.Thickness = 3

local seq = 0
local function show(msg)
	seq += 1
	local mine = seq
	popup.Text = msg popup.TextTransparency = 0 popupStroke.Transparency = 0
	task.delay(2, function()
		if mine ~= seq then return end
		TweenService:Create(popup, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(popupStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
	end)
end

-- confirm dialog: a rebirth spends a lot of Fear, so it is never one tap
local dialog, _, dialogClose = Style.panel(gui, "RebirthConfirm", "🔄 Rebirth", Style.PINK, Vector2.new(480, 330))
dialog.Size = UDim2.fromOffset(480, 330)
UiFit.scale(dialog)
local body = Style.label("Body", dialog, "", Color3.new(1, 1, 1))
body.Position = UDim2.fromOffset(18, 66) body.Size = UDim2.new(1, -36, 0, 170) body.TextXAlignment = Enum.TextXAlignment.Center
local yes = Style.button("Yes", dialog, "Rebirth", Style.GREEN)
yes.AnchorPoint = Vector2.new(1, 1) yes.Position = UDim2.new(0.5, -6, 1, -14) yes.Size = UDim2.fromOffset(190, 64)
local no = Style.button("No", dialog, "Cancel", Style.GRAY)
no.AnchorPoint = Vector2.new(0, 1) no.Position = UDim2.new(0.5, 6, 1, -14) no.Size = UDim2.fromOffset(190, 64)

local function refresh()
	fearLabel.Text = "👻 " .. Config.short(fear.Value)
	local cost = player:GetAttribute("RebirthCost") or 0
	if cost < 0 then
		rebirthBtn.Text = "🔄 Max"
		rebirthBtn.BackgroundColor3 = Style.GRAY
	else
		rebirthBtn.Text = "🔄 " .. Config.short(cost)
		rebirthBtn.BackgroundColor3 = fear.Value >= cost and Style.GREEN or Style.PINK
	end
end
fear.Changed:Connect(refresh)
player:GetAttributeChangedSignal("RebirthCost"):Connect(refresh)
refresh()

local function askRebirth()
	local cost = player:GetAttribute("RebirthCost") or 0
	if cost < 0 then show("All bedrooms unlocked") return end
	local rebirths = player.leaderstats:WaitForChild("Rebirths").Value
	local rooms = Config.unlockedBedrooms(rebirths + 1)
	local newFloor = PlotLayout.floorsVisible(rooms) > PlotLayout.floorsVisible(Config.unlockedBedrooms(rebirths))
	body.Text = string.format("Rebirth for %s Fear?\nYou keep the other %s Fear and all your monsters and items. You get room %d%s and x%s Fear.", Config.short(cost), Config.short(math.max(0, fear.Value - cost)), rooms, newFloor and " and a new floor" or "", tostring(Config.rebirthMult(rebirths + 1)))
	dialog.Visible = true
	GuiService.SelectedObject = no
end
Panels.register("Rebirth", askRebirth, dialog)
rebirthBtn.Activated:Connect(function() Panels.toggle("Rebirth") end)
-- the hall of rebirth opens the same dialog; matched by name because streaming may not have loaded the part yet
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "RebirthPrompt" then Panels.open("Rebirth") end
end)
no.Activated:Connect(function() dialog.Visible = false end)
dialogClose.Activated:Connect(function() dialog.Visible = false end)

local busy = false
yes.Activated:Connect(function()
	if busy then return end
	busy = true
	dialog.Visible = false
	local ok, _, msg = pcall(rebirthRemote.InvokeServer, rebirthRemote)
	show(ok and msg or "Rebirth failed, try again")
	busy = false
end)

popupRemote.OnClientEvent:Connect(show)
