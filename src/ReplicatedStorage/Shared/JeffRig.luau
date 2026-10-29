-- Builds Jeff from the baked Blender data (JeffAnim) and poses him at any point of his scare
local data = require(script.Parent.JeffAnim)

local JeffRig = {}

-- the Blender clip sneaks in and turns to the bed (frames 1-78), then scares (79-150); a showcase only plays the scare
JeffRig.SCARE_FIRST = 40 -- sampled frame for Blender frame 79
JeffRig.SCARE_LAST = #data.frames
JeffRig.FPS = data.fps
JeffRig.POP = 53 -- sampled frame where he pops up at the kid

local boneIndex = {}
for i, name in ipairs(data.bones) do boneIndex[name] = i end

-- keep him standing on his spot: cancel the root's travel from the sneak and centre his lean
local anchor = data.frames[JeffRig.SCARE_FIRST][boneIndex.Root]
local ax, az = anchor[1] + 1, anchor[3]
-- in Blender he scares toward +X (the bed); turn that to face out of the showcase (-Z)
local FACE = CFrame.Angles(0, math.rad(90), 0)

local parts = {}
for _, p in ipairs(data.parts) do
	local name, bone, size, pos, q, col, shape = table.unpack(p)
	local rot = CFrame.new(0, 0, 0, q[1], q[2], q[3], q[4])
	-- how much each bone-axis scale stretches each of this part's own axes
	local axes = {rot.RightVector, rot.UpVector, -rot.LookVector}
	parts[name] = {bone = boneIndex[bone], size = Vector3.new(size[1], size[2], size[3]), pos = Vector3.new(pos[1], pos[2], pos[3]), rot = rot, axes = axes}
	parts[name].def = {color = Color3.fromRGB(col[1], col[2], col[3]), shape = shape}
end

local function boneAt(f, i)
	local fa = math.floor(f)
	local fb = math.min(fa + 1, #data.frames)
	local a, b = data.frames[fa][i], data.frames[fb][i]
	local t = f - fa
	local ca = CFrame.new(a[1] - ax, a[2], a[3] - az, a[4], a[5], a[6], a[7])
	local cb = CFrame.new(b[1] - ax, b[2], b[3] - az, b[4], b[5], b[6], b[7])
	local sa, sb = Vector3.new(a[8], a[9], a[10]), Vector3.new(b[8], b[9], b[10])
	return ca:Lerp(cb, t), sa:Lerp(sb, t)
end

-- In a bedroom he plays the whole clip (sneak in, turn, pop up). A monster whose scare timer is shorter
-- than the clip starts partway through the sneak so one scare ends before the next begins.
function JeffRig.startFrame(interval)
	return math.clamp(JeffRig.SCARE_LAST - math.floor((interval - 0.6) * JeffRig.FPS), 1, JeffRig.SCARE_FIRST)
end
function JeffRig.popTime(interval) -- seconds from the start of the clip to the pop, for timing the kid's jump
	return (JeffRig.POP - JeffRig.startFrame(interval)) / JeffRig.FPS
end

-- pose every part of `model` at sampled frame f (may be fractional), relative to `origin` (default: its spot)
function JeffRig.pose(model, f, origin)
	origin = origin or model:GetAttribute("Origin")
	local bones = {}
	for name, info in pairs(parts) do
		local part = model:FindFirstChild(name)
		if part then
			local b = bones[info.bone]
			if not b then
				b = {boneAt(f, info.bone)}
				bones[info.bone] = b
			end
			local cf, s = b[1], b[2]
			local stretch = Vector3.new(
				math.abs(info.axes[1].X) * s.X + math.abs(info.axes[1].Y) * s.Y + math.abs(info.axes[1].Z) * s.Z,
				math.abs(info.axes[2].X) * s.X + math.abs(info.axes[2].Y) * s.Y + math.abs(info.axes[2].Z) * s.Z,
				math.abs(info.axes[3].X) * s.X + math.abs(info.axes[3].Y) * s.Y + math.abs(info.axes[3].Z) * s.Z)
			part.Size = info.size * stretch
			part.CFrame = origin * FACE * cf * CFrame.new(info.pos * s) * info.rot
		end
	end
end

function JeffRig.build(parent, origin)
	local model = Instance.new("Model")
	model.Name = "Monster"
	model:SetAttribute("Rig", "Jeff")
	model:SetAttribute("Origin", origin)
	for name, info in pairs(parts) do
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = info.def.color
		p.Shape = Enum.PartType[info.def.shape]
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
	end
	JeffRig.pose(model, JeffRig.SCARE_FIRST)
	model.Parent = parent
	return model
end

-- a small Jeff welded to a Tool's Handle, standing upright on the player's hand
function JeffRig.buildMini(tool, scale)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 0.4, 0.4)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	local model = JeffRig.build(tool, CFrame.new())
	model.Name = "Mini"
	model:SetAttribute("Rig", "JeffMini") -- the scare animator ignores it
	model.WorldPivot = CFrame.new()
	model:ScaleTo(scale)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("WeldConstraint") w.Part0 = handle w.Part1 = p w.Parent = p
		end
	end
	return model
end

-- self-check: a slow monster plays the full clip, a fast one still finishes inside its timer, and the pop is after the start
assert(JeffRig.startFrame(15) == 1, "slow monsters play the whole clip")
assert((JeffRig.SCARE_LAST - JeffRig.startFrame(3.5)) / JeffRig.FPS < 3.5, "fast monsters finish before their next scare")
assert(JeffRig.popTime(3.5) > 0 and JeffRig.popTime(15) > JeffRig.popTime(3.5), "pop timing")

return JeffRig
