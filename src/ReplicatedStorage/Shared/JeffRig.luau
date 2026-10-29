-- Builds Jeff from the baked Blender data (JeffAnim) and poses him at any point of his scare
local data = require(script.Parent.JeffAnim)

local JeffRig = {}

-- the Blender clip sneaks in and turns to the bed (frames 1-78), then scares (79-150); a showcase only plays the scare
JeffRig.SCARE_FIRST = 40 -- sampled frame for Blender frame 79
JeffRig.SCARE_LAST = #data.frames
JeffRig.FPS = data.fps

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

local function boneAt(f, i, ox, oz)
	local fa = math.floor(f)
	local fb = math.min(fa + 1, #data.frames)
	local a, b = data.frames[fa][i], data.frames[fb][i]
	local t = f - fa
	local ca = CFrame.new(a[1] - ox, a[2], a[3] - oz, a[4], a[5], a[6], a[7])
	local cb = CFrame.new(b[1] - ox, b[2], b[3] - oz, b[4], b[5], b[6], b[7])
	local sa, sb = Vector3.new(a[8], a[9], a[10]), Vector3.new(b[8], b[9], b[10])
	return ca:Lerp(cb, t), sa:Lerp(sb, t)
end

-- pose every part of `model` at sampled frame f (may be fractional), relative to `origin` (default: its spot).
-- inPlace cancels the root's travel for that frame, so the sneak's steps can be walked along any path.
function JeffRig.pose(model, f, origin, inPlace)
	origin = origin or model:GetAttribute("Origin")
	local ox, oz = ax, az
	if inPlace then
		local fa = math.floor(f)
		local a, b = data.frames[fa][boneIndex.Root], data.frames[math.min(fa + 1, #data.frames)][boneIndex.Root]
		ox, oz = a[1] + (b[1] - a[1]) * (f - fa), a[3] + (b[3] - a[3]) * (f - fa)
	end
	local bones = {}
	for name, info in pairs(parts) do
		local part = model:FindFirstChild(name)
		if part then
			local b = bones[info.bone]
			if not b then
				b = {boneAt(f, info.bone, ox, oz)}
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

-- One scare in a bedroom: Jeff sneaks from the crawl hole along a path to the bed (the clip's sneak steps, in place),
-- turns and pops up at the kid (the clip's own ending), then sneaks back to the hole. Slower monsters take their time;
-- a fast tier speeds the whole thing up so it always fits inside its scare timer.
JeffRig.WALK_LAST = 31 -- sampled frames 1-31 are the sneak; 31-75 turn to the bed and pop
JeffRig.POP = 53 -- sampled frame where he pops up at the kid
local BASE_WALK_SPEED = 2.5 -- studs per second, slower than the clip's own sneak
local CLIP_WALK_SPEED = 4.6 -- studs per second the Blender sneak covers
local BASE_TURN_FPS = 10.5 -- the turn and pop at 70% speed

function JeffRig.pathLength(path)
	local len = 0
	for i = 2, #path do len += (path[i] - path[i - 1]).Magnitude end
	return len
end

function JeffRig.timeline(pathLen, interval)
	local turnFrames = JeffRig.SCARE_LAST - JeffRig.WALK_LAST
	local baseTotal = 2 * pathLen / BASE_WALK_SPEED + turnFrames / BASE_TURN_FPS
	local k = math.min(1, interval * 0.9 / baseTotal)
	local walkSpeed, turnFps = BASE_WALK_SPEED / k, BASE_TURN_FPS / k
	local walkTime, turnTime = pathLen / walkSpeed, turnFrames / turnFps
	return {
		walkSpeed = walkSpeed,
		stepFps = JeffRig.FPS * walkSpeed / CLIP_WALK_SPEED,
		turnFps = turnFps,
		walkTime = walkTime,
		turnTime = turnTime,
		pop = walkTime + (JeffRig.POP - JeffRig.WALK_LAST) / turnFps,
		total = 2 * walkTime + turnTime,
	}
end

-- the point `dist` studs along the path, and the direction of travel there
local function along(path, dist)
	for i = 2, #path do
		local seg = path[i] - path[i - 1]
		if dist <= seg.Magnitude or i == #path then
			return path[i - 1] + seg.Unit * math.min(dist, seg.Magnitude), seg.Unit
		end
		dist -= seg.Magnitude
	end
	return path[1], Vector3.zAxis
end

-- walking pose `t` seconds into a walk along `path` (pass the path reversed to walk back)
function JeffRig.walk(model, path, t, tl)
	local pos, dir = along(path, t * tl.walkSpeed)
	-- the in-place sneak faces the origin's -X, so turn the origin until -X points along the path
	local origin = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, -math.pi / 2, 0)
	JeffRig.pose(model, 1 + (t * tl.stepFps) % (JeffRig.WALK_LAST - 1), origin, true)
end

-- standing at the hole, ready to sneak in
function JeffRig.idle(model, path)
	local dir = (path[2] - path[1]).Unit
	JeffRig.pose(model, 1, CFrame.lookAt(path[1], path[1] + dir) * CFrame.Angles(0, -math.pi / 2, 0), true)
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

-- self-check: a slow monster gets the full slow scare, a fast one still fits inside its timer
do
	local slow, fast = JeffRig.timeline(20, 15), JeffRig.timeline(20, 3.5)
	assert(slow.total <= 15 and fast.total <= 3.5 and slow.pop < slow.total and fast.pop > 0, "scare timeline")
	assert(slow.walkSpeed <= fast.walkSpeed, "fast tiers move faster")
end

return JeffRig
