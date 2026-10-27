-- Fear counter, rebirth button and popup messages
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fear = player:WaitForChild("leaderstats"):WaitForChild("Fear")

local gui = Instance.new("ScreenGui") gui.Name = "HUD" gui.ResetOnSpawn = false gui.Parent = player:WaitForChild("PlayerGui")

local function text(name, size, pos, anchor)
	local t = Instance.new("TextLabel")
	t.Name = name t.Size = size t.Position = pos t.AnchorPoint = anchor t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.fromRGB(170, 120, 255)
	t.TextStrokeTransparency = 0 t.Parent = gui
	return t
end

local fearLabel = text("Fear", UDim2.fromOffset(320, 60), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))
fearLabel.TextXAlignment = Enum.TextXAlignment.Left

local popup = text("Popup", UDim2.fromOffset(500, 44), UDim2.new(0.5, 0, 0.2, 0), Vector2.new(0.5, 0))
popup.TextColor3 = Color3.new(1, 1, 1) popup.TextTransparency = 1 popup.TextStrokeTransparency = 1

local btn = Instance.new("TextButton")
btn.Name = "Rebirth" btn.Size = UDim2.fromOffset(170, 64) btn.Position = UDim2.new(0, 16, 0.5, 0) btn.AnchorPoint = Vector2.new(0, 0.5)
btn.BackgroundColor3 = Color3.fromRGB(220, 60, 90) btn.Font = Enum.Font.FredokaOne btn.TextScaled = true btn.TextColor3 = Color3.new(1, 1, 1)
btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

local function short(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(n)
end

local function refresh()
	fearLabel.Text = "👻 " .. short(fear.Value) .. " Fear"
	local cost = player:GetAttribute("RebirthCost") or 0
	if cost < 0 then
		btn.Text = "Max Rebirth"
		btn.AutoButtonColor = false
	else
		btn.Text = "Rebirth\n" .. short(cost)
		btn.BackgroundColor3 = fear.Value >= cost and Color3.fromRGB(60, 200, 90) or Color3.fromRGB(220, 60, 90)
	end
end
fear.Changed:Connect(refresh)
player:GetAttributeChangedSignal("RebirthCost"):Connect(refresh)
refresh()

btn.Activated:Connect(function() remotes.Rebirth:FireServer() end)

local seq = 0
remotes.Popup.OnClientEvent:Connect(function(msg)
	seq += 1
	local mine = seq
	popup.Text = msg popup.TextTransparency = 0 popup.TextStrokeTransparency = 0
	task.wait(1.5)
	if mine == seq then
		TweenService:Create(popup, TweenInfo.new(0.5), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	end
end)
