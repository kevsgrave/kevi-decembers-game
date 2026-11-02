-- Settings: reduced scares and volumes. The server saves them and sends them back as player attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UiFit = require(Shared:WaitForChild("UiFit"))

local player = Players.LocalPlayer
local settingRemote = Net.Event("SetSetting")
local volumeRemote = Net.Event("SetVolume")

local PANEL = Color3.fromRGB(60, 40, 110)
local ROW = Color3.fromRGB(85, 60, 145)
local LIME = Color3.fromRGB(60, 200, 90)
local SILVER = Color3.fromRGB(150, 150, 165)

local gui = Instance.new("ScreenGui") gui.Name = "SettingsPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 4
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r) end
local function label(parent, text, position, size)
	local t = Instance.new("TextLabel") t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left t.Text = text t.Position = position t.Size = size t.Parent = parent
	return t
end
local function button(parent, text, color, position, size)
	local b = Instance.new("TextButton") b.BackgroundColor3 = color b.Font = Enum.Font.FredokaOne b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text b.Position = position b.Size = size b.Parent = parent
	corner(b, 10)
	return b
end

local openButton = button(gui, "Settings", PANEL, UDim2.new(0, 16, 0.72, 0), UDim2.fromOffset(150, 44))
openButton.AnchorPoint = Vector2.new(0, 0.5)
UiFit.scale(openButton)

local panel = Instance.new("Frame") panel.Visible = false panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(440, 320) panel.BackgroundColor3 = PANEL panel.Parent = gui
corner(panel, 18)
UiFit.scale(panel)
label(panel, "Settings", UDim2.fromOffset(16, 10), UDim2.new(1, -90, 0, 36))
local closeButton = button(panel, "X", SILVER, UDim2.new(1, -54, 0, 8), UDim2.fromOffset(44, 44))
closeButton.Activated:Connect(function() panel.Visible = false end)

local function rowFrame(y)
	local f = Instance.new("Frame") f.Position = UDim2.fromOffset(12, y) f.Size = UDim2.new(1, -24, 0, 76) f.BackgroundColor3 = ROW f.Parent = panel
	corner(f, 12)
	return f
end

-- reduced scares: softer reactions, no pop-up lunge, a gentler sound
local reducedRow = rowFrame(60)
label(reducedRow, "Reduced scares", UDim2.fromOffset(12, 8), UDim2.new(1, -120, 0, 30))
label(reducedRow, "Softer scares, no sudden moves", UDim2.fromOffset(12, 42), UDim2.new(1, -120, 0, 24))
local reducedButton = button(reducedRow, "", SILVER, UDim2.new(1, -100, 0.5, -24), UDim2.fromOffset(90, 48))
reducedButton.Activated:Connect(function()
	settingRemote:FireServer("ReducedScares", player:GetAttribute("ReducedScares") ~= true)
end)

local function volumeRow(y, title, attribute)
	local f = rowFrame(y)
	label(f, title, UDim2.fromOffset(12, 22), UDim2.new(0.4, 0, 0, 32))
	local value = label(f, "", UDim2.new(0.6, -6, 0, 22), UDim2.fromOffset(70, 32))
	value.TextXAlignment = Enum.TextXAlignment.Center
	local function step(by)
		local now = player:GetAttribute(attribute)
		now = if type(now) == "number" then now else 1
		volumeRemote:FireServer(attribute, math.clamp(math.round((now + by) * 4) / 4, 0, 1))
	end
	button(f, "-", SILVER, UDim2.new(0.6, -64, 0.5, -24), UDim2.fromOffset(48, 48)).Activated:Connect(function() step(-0.25) end)
	button(f, "+", LIME, UDim2.new(0.6, 76, 0.5, -24), UDim2.fromOffset(48, 48)).Activated:Connect(function() step(0.25) end)
	return function()
		local now = player:GetAttribute(attribute)
		now = if type(now) == "number" then now else 1
		value.Text = math.round(now * 100) .. "%"
	end
end
local showMusic = volumeRow(144, "Music", "MusicVolume")
local showEffects = volumeRow(228, "Effects", "SfxVolume")

local function refresh()
	local reduced = player:GetAttribute("ReducedScares") == true
	reducedButton.Text = if reduced then "On" else "Off"
	reducedButton.BackgroundColor3 = if reduced then LIME else SILVER
	showMusic()
	showEffects()
	Sounds.startMusic()
end
for _, attribute in {"ReducedScares", "MusicVolume", "SfxVolume"} do
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end
refresh()

openButton.Activated:Connect(function() panel.Visible = not panel.Visible end)
