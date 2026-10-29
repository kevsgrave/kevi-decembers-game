-- Plays each bedroom scare on this client when the server bumps a room Jeff's ScareCount:
-- he sneaks from the crawl hole to the bed, turns and pops up at the kid, then sneaks back and waits at the hole.
-- The display-case Jeff stays still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local JeffRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("JeffRig"))

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

workspace.DescendantAdded:Connect(watch)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
