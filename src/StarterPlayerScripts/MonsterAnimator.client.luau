-- Plays each bedroom scare on this client when the server bumps a room Jeff's ScareCount:
-- he sneaks from the crawl hole to the bed, turns and pops up at the kid, then sneaks back and waits at the hole.
-- The display-case Jeff stays still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local JeffRig = require(Shared:WaitForChild("JeffRig"))
local Config = require(Shared:WaitForChild("Config"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- nobody can see a scare this far away, so it isn't animated
local ANIMATE_DISTANCE = 220

local function pathOf(model)
	local path = {}
	for i = 1, 8 do
		local p = model:GetAttribute("P" .. i)
		if not p then break end
		table.insert(path, p)
	end
	return path
end

local playing = {}

local function tooFar(position)
	return (workspace.CurrentCamera.CFrame.Position - position).Magnitude > ANIMATE_DISTANCE
end

-- placeholders glide along the same route as Jeff and pop by growing for a moment; reduced scares skips the pop
local function playPlaceholder(model, path, tl)
	local back = {}
	for i = #path, 1, -1 do table.insert(back, path[i]) end
	local gentle = player:GetAttribute("ReducedScares") == true
	local base = model:GetScale()
	local function walk(route, t)
		local pos, dir = JeffRig.along(route, t * tl.walkSpeed)
		model:PivotTo(CFrame.lookAt(pos, pos + dir))
	end
	local start = os.clock()
	local popped, shrunk = false, false
	while model.Parent do
		local t = os.clock() - start
		if t >= tl.total then break end
		if t < tl.walkTime then
			walk(path, t)
		elseif t < tl.walkTime + tl.turnTime then
			if t >= tl.pop and not popped then
				popped = true
				if not gentle then model:ScaleTo(base * 1.35) end
				Sounds.play(if gentle then "scareSoft" else "scare", model:FindFirstChildWhichIsA("BasePart"))
			end
			if popped and not shrunk and t >= tl.pop + 0.35 then
				shrunk = true
				model:ScaleTo(base)
			end
		else
			walk(back, t - tl.walkTime - tl.turnTime)
		end
		RunService.RenderStepped:Wait()
	end
	if model.Parent then
		model:ScaleTo(base)
		model:PivotTo(CFrame.new(path[1]))
	end
end

local function play(model)
	if playing[model] then return end
	local path = pathOf(model)
	if #path == 0 or tooFar(path[1]) then return end
	playing[model] = true
	if model:GetAttribute("Rig") == "PlaceholderRoom" then
		playPlaceholder(model, path, JeffRig.timeline(JeffRig.pathLength(path), model:GetAttribute("Interval") or 15))
		playing[model] = nil
		return
	end
	local back = {}
	for i = #path, 1, -1 do table.insert(back, path[i]) end
	local origin = model:GetAttribute("RoomOrigin")
	local tl = JeffRig.timeline(JeffRig.pathLength(path), model:GetAttribute("Interval") or 15)
	local gentle = player:GetAttribute("ReducedScares") == true
	local sounded = false
	local start = os.clock()
	while model.Parent do
		local t = os.clock() - start
		if t >= tl.total then break end
		if t < tl.walkTime then
			JeffRig.walk(model, path, t, tl)
		elseif t < tl.walkTime + tl.turnTime then
			if t >= tl.pop and not sounded then
				sounded = true
				Sounds.play(if gentle then "scareSoft" else "scare", model:FindFirstChildWhichIsA("BasePart"))
			end
			-- reduced scares holds the sneak's last pose instead of the sudden lunge
			JeffRig.pose(model, if gentle then JeffRig.WALK_LAST else JeffRig.WALK_LAST + (t - tl.walkTime) * tl.turnFps, origin)
		else
			JeffRig.walk(model, back, t - tl.walkTime - tl.turnTime, tl)
		end
		RunService.RenderStepped:Wait()
	end
	if model.Parent then JeffRig.idle(model, path) end
	playing[model] = nil
end

local function watch(model)
	if not model:IsA("Model") then return end
	local rig = model:GetAttribute("Rig")
	if rig ~= "JeffRoom" and rig ~= "PlaceholderRoom" then return end
	model:GetAttributeChangedSignal("ScareCount"):Connect(function() task.spawn(play, model) end)
	if rig == "JeffRoom" and model:GetAttribute("P1") then JeffRig.idle(model, pathOf(model)) end
end

-- text that floats up over a room's window and fades: the payout, and a better room when one rolls
local function float(bedroom, message, color, height)
	local anchor = bedroom:FindFirstChild("Window")
	if not anchor then return end
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(12, 2.2) bb.StudsOffset = Vector3.new(0, height, 0) bb.MaxDistance = 90 bb.AlwaysOnTop = true bb.Parent = anchor
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
	t.Text = message t.TextColor3 = color t.TextStrokeTransparency = 0 t.Parent = bb
	TweenService:Create(bb, TweenInfo.new(1.4), {StudsOffset = Vector3.new(0, height + 3, 0)}):Play()
	TweenService:Create(t, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(1.5, function() bb:Destroy() end)
end

local function watchRoom(bedroom)
	if not bedroom:IsA("Model") or not string.match(bedroom.Name, "^Bedroom%d+$") then return end
	bedroom:GetAttributeChangedSignal("PayoutSeq"):Connect(function()
		float(bedroom, "+" .. Config.short(bedroom:GetAttribute("PayoutAmount") or 0) .. " Fear", Color3.fromRGB(120, 255, 130), 1)
		Sounds.play("payout", bedroom:FindFirstChild("Window"))
	end)
	bedroom:GetAttributeChangedSignal("Tier"):Connect(function()
		local name = bedroom:GetAttribute("Tier")
		if name and name ~= "Normal" then
			float(bedroom, name .. " room! x" .. tostring(bedroom:GetAttribute("Mult")), Color3.fromRGB(255, 220, 90), 4)
		end
	end)
end

local function watchAny(d)
	watch(d)
	watchRoom(d)
end
workspace.DescendantAdded:Connect(watchAny)
for _, d in ipairs(workspace:GetDescendants()) do watchAny(d) end
