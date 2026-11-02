-- The manual scare's screen: a fade while crawling in, then a timing bar. It only shows things and sends the tap;
-- the server times the tap itself, decides the bonus and pays.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local cueRemote = Net.Event("ManualCue")
local tapRemote = Net.Event("ManualTap")
local M = Config.Balance.manual

local gui = Instance.new("ScreenGui") gui.Name = "ManualScare" gui.ResetOnSpawn = false gui.IgnoreGuiInset = true gui.DisplayOrder = 5
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local fade = Instance.new("Frame") fade.Name = "Fade" fade.Size = UDim2.fromScale(1, 1) fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 1 fade.Visible = false fade.Parent = gui
local fadeText = Instance.new("TextLabel") fadeText.AnchorPoint = Vector2.new(0.5, 0.5) fadeText.Position = UDim2.fromScale(0.5, 0.5) fadeText.Size = UDim2.fromScale(0.7, 0.1)
fadeText.BackgroundTransparency = 1 fadeText.Font = Enum.Font.FredokaOne fadeText.TextScaled = true fadeText.TextColor3 = Color3.new(1, 1, 1) fadeText.Text = "Crawling in..." fadeText.Parent = fade

local panel = Instance.new("Frame") panel.Name = "Cue" panel.Visible = false panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -110) panel.Size = UDim2.fromScale(0.8, 0.22) panel.BackgroundColor3 = Color3.fromRGB(60, 40, 110) panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(560, 170) cap.Parent = panel

local bar = Instance.new("Frame") bar.Name = "Bar" bar.Position = UDim2.fromScale(0.05, 0.12) bar.Size = UDim2.fromScale(0.9, 0.28)
bar.BackgroundColor3 = Color3.fromRGB(35, 25, 65) bar.ClipsDescendants = true bar.Parent = panel
local function zone(width, color)
	local z = Instance.new("Frame") z.AnchorPoint = Vector2.new(0.5, 0) z.Position = UDim2.fromScale(M.perfectAt, 0)
	z.Size = UDim2.fromScale(width, 1) z.BackgroundColor3 = color z.BorderSizePixel = 0 z.Parent = bar
end
zone(M.goodWidth, Color3.fromRGB(255, 200, 40))
zone(M.perfectWidth, Color3.fromRGB(60, 220, 100))
local marker = Instance.new("Frame") marker.Name = "Marker" marker.AnchorPoint = Vector2.new(0.5, 0) marker.Size = UDim2.new(0, 6, 1, 0)
marker.BackgroundColor3 = Color3.new(1, 1, 1) marker.BorderSizePixel = 0 marker.ZIndex = 2 marker.Parent = bar

local tapButton = Instance.new("TextButton") tapButton.Name = "Tap" tapButton.AnchorPoint = Vector2.new(0.5, 1) tapButton.Position = UDim2.fromScale(0.5, 0.94) tapButton.Size = UDim2.fromScale(0.6, 0.44)
tapButton.BackgroundColor3 = Color3.fromRGB(220, 60, 90) tapButton.Font = Enum.Font.FredokaOne tapButton.TextScaled = true tapButton.TextColor3 = Color3.new(1, 1, 1) tapButton.Text = "BOO!" tapButton.Parent = panel
Instance.new("UICorner", tapButton).CornerRadius = UDim.new(0, 12)

local result = Instance.new("TextLabel") result.Name = "Result" result.AnchorPoint = Vector2.new(0.5, 0.5) result.Position = UDim2.fromScale(0.5, 0.3) result.Size = UDim2.fromScale(0.7, 0.1)
result.BackgroundTransparency = 1 result.Font = Enum.Font.FredokaOne result.TextScaled = true result.TextColor3 = Color3.fromRGB(255, 230, 80) result.TextStrokeTransparency = 0 result.Visible = false result.Parent = gui

local sent = false
local cueTween

local function tap()
	if panel.Visible and not sent then
		sent = true
		if cueTween then cueTween:Pause() end -- the marker stops where you tapped
		tapRemote:FireServer()
	end
end
tapButton.Activated:Connect(tap)
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then tap() end
end)

local function setFade(on, seconds)
	fade.Visible = true
	fadeText.Visible = on
	local tween = TweenService:Create(fade, TweenInfo.new(seconds), {BackgroundTransparency = on and 0.15 or 1})
	tween:Play()
	if not on then
		task.delay(seconds, function()
			if fade.BackgroundTransparency >= 0.99 then fade.Visible = false end
		end)
	end
end

cueRemote.OnClientEvent:Connect(function(state)
	if state.phase == "crawl" then
		setFade(true, state.seconds * 0.6)
	elseif state.phase == "cue" then
		setFade(false, 0.2)
		sent = false
		marker.Position = UDim2.fromScale(0, 0)
		panel.Visible = true
		cueTween = TweenService:Create(marker, TweenInfo.new(state.seconds, Enum.EasingStyle.Linear), {Position = UDim2.fromScale(1, 0)})
		cueTween:Play()
	elseif state.phase == "done" then
		panel.Visible = false
		setFade(false, 0.2)
		if state.word then
			result.Text = state.word .. " +" .. Config.short(state.amount) .. " Fear"
			result.Visible = true
			task.delay(1.6, function() result.Visible = false end)
		end
	end
end)
