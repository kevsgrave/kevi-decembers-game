-- Plays Jeff's Blender scare on this client whenever the server bumps a monster's ScareCount:
-- he leaves the display case, sneaks up to the bed inside the bedroom, pops up, then goes back to the case
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local JeffRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("JeffRig"))

local playing = {}

local function play(model)
	if playing[model] then return end
	playing[model] = true
	local room = model:GetAttribute("RoomOrigin")
	local first = JeffRig.startFrame(model:GetAttribute("Interval") or 15)
	local start = os.clock()
	local length = (JeffRig.SCARE_LAST - first) / JeffRig.FPS
	while model.Parent do
		local t = os.clock() - start
		if t >= length then break end
		JeffRig.pose(model, first + t * JeffRig.FPS, room)
		RunService.RenderStepped:Wait()
	end
	if model.Parent then JeffRig.pose(model, JeffRig.SCARE_FIRST) end
	playing[model] = nil
end

local function watch(model)
	if not model:IsA("Model") or model:GetAttribute("Rig") ~= "Jeff" then return end
	model:GetAttributeChangedSignal("ScareCount"):Connect(function() task.spawn(play, model) end)
end

workspace.DescendantAdded:Connect(watch)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
