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

local player = Players.LocalPlayer
local stepRemote = Net.Event("TutorialStep")
local doneRemote = Net.Event("TutorialDone")
local camera = workspace.CurrentCamera

local GOLD = Color3.fromRGB(255, 220, 70)

local gui = Instance.new("ScreenGui") gui.Name = "TutorialGuide" gui.ResetOnSpawn = false gui.DisplayOrder = 3
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local caption = Instance.new("Frame") caption.Name = "Caption" caption.AnchorPoint = Vector2.new(0.5, 0)
-- touch screens have Fear in the top corner, so the caption sits under it
local touchOffset = if game:GetService("UserInputService").TouchEnabled then 66 else 0
caption.Position = UDim2.new(0.5, 0, 0, 8 + touchOffset) caption.Size = UDim2.fromScale(0.9, 0.16) caption.BackgroundColor3 = Color3.fromRGB(35, 22, 70) caption.Visible = false caption.Parent = gui
Instance.new("UICorner", caption).CornerRadius = UDim.new(0, 14)
local border = Instance.new("UIStroke") border.Color = GOLD border.Thickness = 3 border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border border.Parent = caption
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(640, 110) cap.Parent = caption

local function label(name, position, size, color)
	local t = Instance.new("TextLabel") t.Name = name t.Position = position t.Size = size t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = color t.Parent = caption
	return t
end
local stepText = label("Step", UDim2.fromScale(0.03, 0.05), UDim2.fromScale(0.94, 0.26), GOLD)
local bodyText = label("Body", UDim2.fromScale(0.03, 0.31), UDim2.fromScale(0.94, 0.62), Color3.new(1, 1, 1))

local finishButton = Instance.new("TextButton") finishButton.Name = "Finish" finishButton.AnchorPoint = Vector2.new(0.5, 0)
finishButton.Position = UDim2.new(0.5, 0, 0, 126 + touchOffset) finishButton.Size = UDim2.fromOffset(190, 52) finishButton.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
finishButton.Font = Enum.Font.FredokaOne finishButton.TextScaled = true finishButton.TextColor3 = Color3.new(1, 1, 1) finishButton.Text = "Finish" finishButton.Visible = false finishButton.Parent = gui
Instance.new("UICorner", finishButton).CornerRadius = UDim.new(0, 12)
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
	local panel = player.PlayerGui:FindFirstChild("InventoryPanel")
	local open = panel and panel:FindFirstChild("Open")
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
local replayButton = Instance.new("TextButton") replayButton.Name = "HowToPlay" replayButton.AnchorPoint = Vector2.new(0, 0.5)
replayButton.Position = UDim2.new(0, 16, 0.63, 0) replayButton.Size = UDim2.fromOffset(150, 44) replayButton.BackgroundColor3 = Color3.fromRGB(60, 40, 110)
replayButton.Font = Enum.Font.FredokaOne replayButton.TextScaled = true replayButton.TextColor3 = Color3.new(1, 1, 1) replayButton.Text = "How to play" replayButton.Visible = false replayButton.Parent = gui
Instance.new("UICorner", replayButton).CornerRadius = UDim.new(0, 10)
UiFit.scale(replayButton)
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
