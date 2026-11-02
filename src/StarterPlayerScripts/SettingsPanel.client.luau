-- Settings: reduced scares and volumes. The server saves them and sends them back as player attributes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local Style = require(Shared:WaitForChild("Style"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local UiFit = require(Shared:WaitForChild("UiFit"))

local player = Players.LocalPlayer
local settingRemote = Net.Event("SetSetting")
local volumeRemote = Net.Event("SetVolume")

local LIME, SILVER = Style.GREEN, Style.GRAY

local gui = Instance.new("ScreenGui") gui.Name = "SettingsPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 4
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function label(parent, text, position, size)
	local t = Style.label("Text", parent, text)
	t.Position = position t.Size = size
	return t
end
local function button(parent, text, color, position, size)
	local b = Style.button("Button", parent, text, color)
	b.Position = position b.Size = size
	return b
end

local panel, _, closeButton = Style.panel(gui, "Panel", "⚙️ Settings", Style.GRAY, Vector2.new(440, 330))
panel.Size = UDim2.fromOffset(440, 330)
UiFit.scale(panel)
closeButton.Activated:Connect(function() panel.Visible = false end)

local function rowFrame(y)
	local f = Style.card("Row", panel, 0, 76)
	f.Position = UDim2.fromOffset(12, y)
	f.Size = UDim2.new(1, -24, 0, 76)
	return f
end

-- reduced scares: softer reactions, no pop-up lunge, a gentler sound
local reducedRow = rowFrame(64)
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
local showMusic = volumeRow(148, "Music", "MusicVolume")
local showEffects = volumeRow(232, "Effects", "SfxVolume")

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

Panels.register("Settings", function() panel.Visible = true end, panel)
