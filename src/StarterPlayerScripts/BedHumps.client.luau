-- Swaps every bed for its lumpy-quilt version on this client (see Shared/BedHump), so sleeping kids lie under the real blanket
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BedHump = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BedHump"))

local function watch(bed)
	if not bed:IsA("Model") or not bed:GetAttribute("BedKind") then return end
	task.spawn(function()
		local mesh, deadline = nil, os.clock() + 10
		repeat -- the bed's parts may replicate a moment after the model itself
			mesh = bed:FindFirstChildWhichIsA("MeshPart", true)
			if not mesh then task.wait(0.2) end
		until mesh or os.clock() > deadline or not bed.Parent
		if not mesh or bed:FindFirstChild("QuiltWithKid", true) then return end
		local lumpy = BedHump.make(mesh, bed:GetAttribute("BedKind"))
		if lumpy and bed.Parent then
			lumpy.Parent = mesh.Parent
			mesh.LocalTransparencyModifier = 1 -- the plain bed stays for the server; this client shows the lumpy one
		end
	end)
end

workspace.DescendantAdded:Connect(watch)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end
