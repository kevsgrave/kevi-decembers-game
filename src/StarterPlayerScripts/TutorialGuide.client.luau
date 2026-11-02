-- Shows the tutorial: a caption, an arrow that always stays on screen, a beam on the ground and a highlight on the target.
-- It only shows what the server says. Every step moves on when the server sees the real action happen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Tutorial = require(Shared:WaitForChild("Tutorial"))

local player = Players.LocalPlayer
local stepRemote = Net.Event("TutorialStep")
local doneRemote = Net.Event("TutorialDone")
local camera = workspace.CurrentCamera

local GOLD = Color3.fromRGB(255, 220, 70)
local EDGE = 70 -- pixels the arrow keeps from the screen edge

local gui = Instance.new("ScreenGui") gui.Name = "TutorialGuide" gui.ResetOnSpawn = false gui.DisplayOrder = 3
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local caption = Instance.new("Frame") caption.Name = "Caption" caption.AnchorPoint = Vector2.new(0.5, 0)
caption.Position = UDim2.new(0.5, 0, 0, 8) caption.Size = UDim2.fromScale(0.9, 0.16) caption.BackgroundColor3 = Color3.fromRGB(35, 22, 70) caption.Visible = false caption.Parent = gui
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
finishButton.Position = UDim2.new(0.5, 0, 0, 126) finishButton.Size = UDim2.fromOffset(190, 52) finishButton.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
finishButton.Font = Enum.Font.FredokaOne finishButton.TextScaled = true finishButton.TextColor3 = Color3.new(1, 1, 1) finishButton.Text = "Finish" finishButton.Visible = false finishButton.Parent = gui
Instance.new("UICorner", finishButton).CornerRadius = UDim.new(0, 12)

local arrow = Instance.new("TextLabel") arrow.Name = "Arrow" arrow.AnchorPoint = Vector2.new(0.5, 0.5) arrow.Size = UDim2.fromOffset(72, 72)
arrow.BackgroundTransparency = 1 arrow.Font = Enum.Font.GothamBlack arrow.TextScaled = true arrow.Text = "➤" arrow.TextColor3 = GOLD arrow.TextStrokeTransparency = 0 arrow.Visible = false arrow.Parent = gui

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

local function placeArrow(position, angle)
	local size = camera.ViewportSize
	-- never offscreen, on any screen size
	arrow.Position = UDim2.fromOffset(math.clamp(position.X, EDGE, math.max(EDGE, size.X - EDGE)), math.clamp(position.Y, EDGE, math.max(EDGE, size.Y - EDGE)))
	arrow.Rotation = angle
	arrow.Visible = true
end

RunService.RenderStepped:Connect(function()
	if not state then return end
	if state.ui then
		local target = interfaceTarget(state.ui)
		if target then placeArrow(target, if state.ui == "hotbar" then 90 else 180) else arrow.Visible = false end
		return
	end
	if not state.position then
		arrow.Visible = false
		return
	end
	local screen, onScreen = camera:WorldToViewportPoint(state.position)
	if onScreen and screen.Z > 0 then
		local bob = math.sin(os.clock() * 5) * 8
		placeArrow(Vector2.new(screen.X, screen.Y - 60 + bob), 90)
	else
		-- behind or off to the side: point from the screen's centre toward it
		local middle = camera.ViewportSize / 2
		local toward = Vector2.new(screen.X, screen.Y) - middle
		if screen.Z < 0 then toward = -toward end
		if toward.Magnitude < 1 then toward = Vector2.new(0, 1) end
		local unit = toward.Unit
		local reach = math.min(middle.X - EDGE, middle.Y - EDGE)
		placeArrow(middle + unit * reach, math.deg(math.atan2(unit.Y, unit.X)))
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local rootAttachment = root and root:FindFirstChild("RootAttachment")
	beam.Attachment0 = rootAttachment
	beam.Enabled = rootAttachment ~= nil
end)

-- after the tutorial, the steps can be read again. This only shows text and never talks to the server, so no reward can repeat.
local replayButton = Instance.new("TextButton") replayButton.Name = "HowToPlay" replayButton.AnchorPoint = Vector2.new(0, 0.5)
replayButton.Position = UDim2.new(0, 16, 0.5, 156) replayButton.Size = UDim2.fromOffset(150, 44) replayButton.BackgroundColor3 = Color3.fromRGB(60, 40, 110)
replayButton.Font = Enum.Font.FredokaOne replayButton.TextScaled = true replayButton.TextColor3 = Color3.new(1, 1, 1) replayButton.Text = "How to play" replayButton.Visible = false replayButton.Parent = gui
Instance.new("UICorner", replayButton).CornerRadius = UDim.new(0, 10)
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
		arrow.Visible = false
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
	if next.id == "done" then arrow.Visible = false state.position = nil end
end)

finishButton.Activated:Connect(function()
	if replayIndex then
		replayIndex += 1
		showReplay()
	else
		doneRemote:FireServer()
	end
end)
