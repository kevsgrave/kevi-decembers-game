-- Follows an active tracker: an arrow, the distance and the time left, then a glowing mound with a Dig prompt.
-- The mound exists only on this player's screen. Digging asks the server, which checks the player is really there.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local GuideArrow = require(Shared:WaitForChild("GuideArrow"))
local Net = require(Shared:WaitForChild("Net"))
local Style = require(Shared:WaitForChild("Style"))

local player = Players.LocalPlayer
local stateRemote = Net.Event("TrackerState")
local digRemote = Net.Function("Dig")
local TEAL = Color3.fromRGB(120, 255, 220)

local gui = Instance.new("ScreenGui") gui.Name = "TrackerGuide" gui.ResetOnSpawn = false gui.DisplayOrder = 1
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local arrow = GuideArrow.new(gui, TEAL)
local readout = Style.label("Readout", gui, "", TEAL)
readout.AnchorPoint = Vector2.new(0.5, 1) readout.Position = UDim2.new(0.5, 0, 1, -150) readout.Size = UDim2.fromScale(0.7, 0.06)
readout.TextXAlignment = Enum.TextXAlignment.Center readout.Visible = false

local state = nil
local mound = nil

local function removeMound()
	if mound then mound:Destroy() end
	mound = nil
end

local function makeMound(position)
	local p = Instance.new("Part") p.Name = "BuriedEggMound" p.Shape = Enum.PartType.Ball p.Size = Vector3.new(5, 5, 5) p.Anchored = true p.CanCollide = false
	p.CanQuery = false p.Color = Color3.fromRGB(110, 80, 55) p.Material = Enum.Material.Ground p.Position = position - Vector3.new(0, 1.2, 0)
	local light = Instance.new("PointLight") light.Color = TEAL light.Range = 16 light.Brightness = 2 light.Shadows = false light.Parent = p
	local sparkle = Instance.new("Sparkles") sparkle.SparkleColor = TEAL sparkle.Parent = p
	-- clods of dirt around it, and a floating sign you can spot from a way off
	for k = 1, 6 do
		local a = k * math.pi / 3
		local clod = Instance.new("Part") clod.Name = "Clod" clod.Size = Vector3.new(1.6, 1, 1.6) clod.Anchored = true clod.CanCollide = false clod.CanQuery = false clod.CanTouch = false
		clod.Color = Color3.fromRGB(150, 105, 70) clod.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 3.6, -0.3, math.sin(a) * 3.6)) * CFrame.Angles(0, a, 0.3) clod.Parent = p
	end
	local sign = Instance.new("BillboardGui") sign.Size = UDim2.fromScale(12, 2.6) sign.StudsOffset = Vector3.new(0, 6, 0) sign.LightInfluence = 0 sign.Parent = p
	local signText = Style.label("Text", sign, "Dig here!", Color3.new(1, 1, 1))
	signText.Size = UDim2.fromScale(1, 1) signText.TextXAlignment = Enum.TextXAlignment.Center
	local gradient = Instance.new("UIGradient") gradient.Rotation = 90 gradient.Color = ColorSequence.new(TEAL, Style.GOLD) gradient.Parent = signText
	local prompt = Instance.new("ProximityPrompt") prompt.ActionText = "Dig" prompt.ObjectText = "Buried Moon Egg" prompt.HoldDuration = Config.Balance.trackers.digHoldSeconds
	prompt.MaxActivationDistance = Config.Balance.trackers.digDistance prompt.RequiresLineOfSight = false prompt.Parent = p
	prompt.Triggered:Connect(function()
		if state then pcall(digRemote.InvokeServer, digRemote, state.uid) end
	end)
	p.Parent = workspace
	return p
end

RunService.RenderStepped:Connect(function()
	if not state then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	arrow:pointAt(state.position)
	local distance = (root.Position - state.position).Magnitude
	local left = math.max(0, state.expiresAt - workspace:GetServerTimeNow())
	readout.Text = string.format("Buried egg: %d studs away, %d:%02d left", distance, math.floor(left / 60), math.floor(left % 60))
	player:SetAttribute("TrackerText", string.format("Buried egg: %d studs", distance)) -- only this client sees it; the Dig Camp shows it
	if distance < 60 and not mound then mound = makeMound(state.position) end
end)

stateRemote.OnClientEvent:Connect(function(next)
	removeMound()
	state = next and next.position and next or nil
	readout.Visible = state ~= nil
	if not state then
		arrow:hide()
		player:SetAttribute("TrackerText", nil)
	end
end)
