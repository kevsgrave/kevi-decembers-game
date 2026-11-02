-- Shows the tutorial: a caption, an arrow that always stays on screen, a beam on the ground and a highlight on the target.
-- It only shows what the server says. Every step moves on when the server sees the real action happen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tutorial = require(Shared:WaitForChild("Tutorial"))
local GuideArrow = require(Shared:WaitForChild("GuideArrow"))
local UiFit = require(Shared:WaitForChild("UiFit"))
local Style = require(Shared:WaitForChild("Style"))

local player = Players.LocalPlayer
local stepRemote = Net.Event("TutorialStep")
local doneRemote = Net.Event("TutorialDone")
local camera = workspace.CurrentCamera

local GOLD = Color3.fromRGB(255, 220, 70)

local gui = Instance.new("ScreenGui") gui.Name = "TutorialGuide" gui.ResetOnSpawn = false gui.DisplayOrder = 3
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

-- the quest pill at the top of the screen, as in the references
local caption = Instance.new("Frame") caption.Name = "Caption" caption.AnchorPoint = Vector2.new(0.5, 0)
-- touch screens have Fear in the top corner, so the caption sits under it
local touchOffset = if game:GetService("UserInputService").TouchEnabled then 110 else 0
caption.Position = UDim2.new(0.5, 0, 0, 8 + touchOffset) caption.Size = UDim2.fromScale(0.74, 0.15) caption.BackgroundColor3 = Style.CYAN:Lerp(Color3.new(0, 0, 0), 0.45) caption.Visible = false caption.Parent = gui
Style.corner(caption, 22)
Style.outline(caption, 3, Style.INK)
Style.studs(caption, 0.9)
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(620, 96) cap.Parent = caption

local function label(name, position, size, color)
	local t = Style.label(name, caption, "", color)
	t.Position = position t.Size = size t.TextXAlignment = Enum.TextXAlignment.Center
	return t
end
local stepText = label("Step", UDim2.fromScale(0.05, 0.08), UDim2.fromScale(0.9, 0.28), Style.GOLD)
local bodyText = label("Body", UDim2.fromScale(0.05, 0.37), UDim2.fromScale(0.9, 0.56), Color3.new(1, 1, 1))

local finishButton = Style.button("Finish", gui, "Finish", Style.GREEN)
finishButton.AnchorPoint = Vector2.new(0.5, 0)
finishButton.Position = UDim2.new(0.5, 0, 0, 112 + touchOffset) finishButton.Size = UDim2.fromOffset(190, 52) finishButton.Visible = false
UiFit.scale(finishButton)

local arrow = GuideArrow.new(gui, GOLD)

-- the beam's far end, local to this client
local anchor = Instance.new("Part") anchor.Name = "TutorialAnchor" anchor.Anchored = true anchor.CanCollide = false anchor.CanQuery = false anchor.CanTouch = false anchor.Transparency = 1 anchor.Size = Vector3.one
local anchorAttachment = Instance.new("Attachment") anchorAttachment.Parent = anchor
local beam = Instance.new("Beam") beam.Color = ColorSequence.new(GOLD) beam.Width0 = 0.7 beam.Width1 = 0.7 beam.FaceCamera = true beam.LightEmission = 1 beam.Segments = 2 beam.Attachment1 = anchorAttachment beam.Enabled = false beam.Parent = anchor
local highlight = Instance.new("Highlight") highlight.FillTransparency = 0.6 highlight.FillColor = GOLD highlight.OutlineColor = GOLD highlight.Enabled = false highlight.Parent = gui

local state = nil

-- a screen-space target for steps that point at the interface rather than the world
local function interfaceTarget(name)
	if name == "hotbar" then
		return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y - 110)
	end
	local hud = player.PlayerGui:FindFirstChild("HUD")
	local open = hud and hud:FindFirstChild("Sidebar") and hud.Sidebar:FindFirstChild("Inventory")
	if open then return open.AbsolutePosition + open.AbsoluteSize / 2 + Vector2.new(open.AbsoluteSize.X / 2 + 40, 0) end
	return nil
end

RunService.RenderStepped:Connect(function()
	if not state then return end
	if state.ui then
		local target = interfaceTarget(state.ui)
		if target then arrow:pointAtScreen(target, if state.ui == "hotbar" then 90 else 180) else arrow:hide() end
		return
	end
	if not state.position then
		arrow:hide()
		return
	end
	arrow:pointAt(state.position)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local rootAttachment = root and root:FindFirstChild("RootAttachment")
	beam.Attachment0 = rootAttachment
	beam.Enabled = rootAttachment ~= nil
end)

-- after the tutorial, the steps can be read again. This only shows text and never talks to the server, so no reward can repeat.
local replayButton = player.PlayerGui:WaitForChild("HUD"):WaitForChild("Sidebar"):WaitForChild("HowToPlay")
local replayIndex = nil

local function showReplay()
	if replayIndex > Tutorial.COUNT - 1 then -- the last step's text is only a sign-off
		replayIndex = nil
		caption.Visible = false
		finishButton.Visible = false
		return
	end
	stepText.Text = "How to play: step " .. replayIndex .. " of " .. (Tutorial.COUNT - 1)
	bodyText.Text = Tutorial.STEPS[replayIndex].text
	finishButton.Text = "Next"
	caption.Visible = true
	finishButton.Visible = true
end

replayButton.Activated:Connect(function()
	replayIndex = 1
	showReplay()
end)

stepRemote.OnClientEvent:Connect(function(next)
	replayIndex = nil
	finishButton.Text = "Finish"
	replayButton.Visible = next.id == "none"
	if next.id == "none" then
		state = nil
		caption.Visible = false
		arrow:hide()
		finishButton.Visible = false
		beam.Enabled = false
		highlight.Enabled = false
		anchor.Parent = nil
		return
	end
	state = next
	stepText.Text = "Tutorial: step " .. next.index .. " of " .. next.total
	bodyText.Text = next.text
	caption.Visible = true
	finishButton.Visible = next.id == "done"
	beam.Enabled = false
	if next.position then
		anchor.Position = next.position
		anchor.Parent = workspace
	else
		anchor.Parent = nil
	end
	highlight.Adornee = next.target
	highlight.Enabled = next.target ~= nil
	if next.id == "done" then arrow:hide() state.position = nil end
end)

finishButton.Activated:Connect(function()
	if replayIndex then
		replayIndex += 1
		showReplay()
	else
		doneRemote:FireServer()
	end
end)
