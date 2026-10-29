-- Loops Jeff's Blender scare (sneak to the bed, pop up at the kid) on every room Jeff, on this client.
-- The display-case Jeff stays still.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local JeffRig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("JeffRig"))

local CLIP = (JeffRig.SCARE_LAST - 1) / JeffRig.FPS -- seconds for the whole Blender clip
local roomJeffs = {} -- [model] = os.clock() it appeared, so each room starts its loop from the beginning

local function watch(model)
	if model:IsA("Model") and model:GetAttribute("Rig") == "JeffRoom" then roomJeffs[model] = os.clock() end
end
workspace.DescendantAdded:Connect(watch)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for model, born in pairs(roomJeffs) do
		if model.Parent then
			JeffRig.pose(model, 1 + ((now - born) % CLIP) * JeffRig.FPS)
		else
			roomJeffs[model] = nil
		end
	end
end)
