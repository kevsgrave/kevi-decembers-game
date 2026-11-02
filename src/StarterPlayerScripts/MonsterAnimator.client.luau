-- Plays each bedroom scare on this client when the server bumps a room Jeff's ScareCount:
-- he sneaks from the crawl hole to the bed, turns and pops up at the kid, then sneaks back and waits at the hole.
-- The display-case Jeff stays still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local JeffRig = require(Shared:WaitForChild("JeffRig"))
local Config = require(Shared:WaitForChild("Config"))

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

local function play(model)
	if playing[model] then return end
	playing[model] = true
	local path = pathOf(model)
	local back = {}
	for i = #path, 1, -1 do table.insert(back, path[i]) end
	local origin = model:GetAttribute("RoomOrigin")
	local tl = JeffRig.timeline(JeffRig.pathLength(path), model:GetAttribute("Interval") or 15)
	local start = os.clock()
	while model.Parent do
		local t = os.clock() - start
		if t >= tl.total then break end
		if t < tl.walkTime then
			JeffRig.walk(model, path, t, tl)
		elseif t < tl.walkTime + tl.turnTime then
			JeffRig.pose(model, JeffRig.WALK_LAST + (t - tl.walkTime) * tl.turnFps, origin)
		else
			JeffRig.walk(model, back, t - tl.walkTime - tl.turnTime, tl)
		end
		RunService.RenderStepped:Wait()
	end
	if model.Parent then JeffRig.idle(model, path) end
	playing[model] = nil
end

local function watch(model)
	if not model:IsA("Model") or model:GetAttribute("Rig") ~= "JeffRoom" then return end
	model:GetAttributeChangedSignal("ScareCount"):Connect(function() task.spawn(play, model) end)
	if model:GetAttribute("P1") then JeffRig.idle(model, pathOf(model)) end
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
