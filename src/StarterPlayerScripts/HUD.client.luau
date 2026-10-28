-- Fear counter, rebirth button with a confirm step, and popup messages. Shows server-owned values only.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local popupRemote = Net.Event("Popup")
local rebirthRemote = Net.Function("Rebirth")
local fear = player:WaitForChild("leaderstats"):WaitForChild("Fear")

local DARK = Color3.fromRGB(20, 10, 40)
local LIME = Color3.fromRGB(60, 200, 90)
local CRIMSON = Color3.fromRGB(220, 60, 90)
local SILVER = Color3.fromRGB(150, 150, 165)

local gui = Instance.new("ScreenGui") gui.Name = "HUD" gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function stroke(obj, thickness, border)
	local s = Instance.new("UIStroke") s.Thickness = thickness s.Color = DARK
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = obj
	return s
end

local function text(name, size, pos, anchor, parent)
	local t = Instance.new("TextLabel")
	t.Name = name t.Size = size t.Position = pos t.AnchorPoint = anchor t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.fromRGB(90, 255, 90)
	t.Parent = parent or gui
	stroke(t, 4)
	return t
end

local function button(name, label, color, size, pos, anchor, parent)
	local b = Instance.new("TextButton")
	b.Name = name b.Size = size b.Position = pos b.AnchorPoint = anchor
	b.BackgroundColor3 = color b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1) b.Text = label
	b.Parent = parent or gui
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 16)
	stroke(b, 4, true)
	stroke(b, 3)
	local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10) pad.PaddingTop = UDim.new(0, 8) pad.PaddingBottom = UDim.new(0, 8) pad.Parent = b
	return b
end

local fearLabel = text("Fear", UDim2.fromOffset(380, 80), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))
fearLabel.TextXAlignment = Enum.TextXAlignment.Left

local popup = text("Popup", UDim2.fromOffset(500, 44), UDim2.new(0.5, 0, 0.2, 0), Vector2.new(0.5, 0))
popup.TextColor3 = Color3.new(1, 1, 1) popup.TextTransparency = 1
local popupStroke = popup.UIStroke popupStroke.Transparency = 1

local rebirthBtn = button("Rebirth", "", CRIMSON, UDim2.fromOffset(150, 110), UDim2.new(0, 16, 0.5, 0), Vector2.new(0, 0.5))

-- confirm dialog: a rebirth resets Fear, so it is never one tap
local dialog = Instance.new("Frame") dialog.Name = "RebirthConfirm" dialog.Visible = false
dialog.Size = UDim2.fromOffset(420, 240) dialog.Position = UDim2.fromScale(0.5, 0.5) dialog.AnchorPoint = Vector2.new(0.5, 0.5)
dialog.BackgroundColor3 = Color3.fromRGB(60, 40, 110) dialog.Parent = gui
Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 18)
stroke(dialog, 4, true)
local sizeCap = Instance.new("UISizeConstraint") sizeCap.MaxSize = Vector2.new(420, 240) sizeCap.Parent = dialog
local body = text("Body", UDim2.new(1, -32, 0, 130), UDim2.new(0.5, 0, 0, 16), Vector2.new(0.5, 0), dialog)
body.TextColor3 = Color3.new(1, 1, 1)
local yes = button("Yes", "Rebirth", LIME, UDim2.fromOffset(170, 64), UDim2.new(0.5, -8, 1, -16), Vector2.new(1, 1), dialog)
local no = button("No", "Cancel", SILVER, UDim2.fromOffset(170, 64), UDim2.new(0.5, 8, 1, -16), Vector2.new(0, 1), dialog)

local seq = 0
local function show(msg)
	seq += 1
	local mine = seq
	popup.Text = msg popup.TextTransparency = 0 popupStroke.Transparency = 0
	task.delay(1.5, function()
		if mine ~= seq then return end
		TweenService:Create(popup, TweenInfo.new(0.2), {TextTransparency = 1}):Play()
		TweenService:Create(popupStroke, TweenInfo.new(0.2), {Transparency = 1}):Play()
	end)
end

local function refresh()
	fearLabel.Text = "👻 " .. Config.short(fear.Value) .. " Fear"
	local cost = player:GetAttribute("RebirthCost") or 0
	if cost < 0 then
		rebirthBtn.Text = "Max Rebirth"
		rebirthBtn.BackgroundColor3 = SILVER
	else
		rebirthBtn.Text = "Rebirth\n" .. Config.short(cost)
		rebirthBtn.BackgroundColor3 = fear.Value >= cost and LIME or CRIMSON
	end
end
fear.Changed:Connect(refresh)
player:GetAttributeChangedSignal("RebirthCost"):Connect(refresh)
refresh()

rebirthBtn.Activated:Connect(function()
	local cost = player:GetAttribute("RebirthCost") or 0
	if cost < 0 then show("All bedrooms unlocked") return end
	local rebirths = player.leaderstats:WaitForChild("Rebirths").Value
	body.Text = string.format("Rebirth for %s Fear?\nYour Fear goes back to 0. You keep your monsters, unlock a bedroom and earn x%s Fear.", Config.short(cost), tostring(Config.rebirthMult(rebirths + 1)))
	dialog.Visible = true
	GuiService.SelectedObject = no
end)
no.Activated:Connect(function() dialog.Visible = false end)

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
