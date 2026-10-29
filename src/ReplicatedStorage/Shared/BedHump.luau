-- Reshapes a bed's own quilt mesh so it has a sleeping-kid lump, using EditableMesh (moving existing points only).
-- Studio cannot publish edited meshes yet, so every client builds the lumpy version itself (once per bed type)
-- and swaps it in over the plain bed. The patchwork/duvet texture is the bed's own, so the hump is the real blanket.
local AssetService = game:GetService("AssetService")

local BedHump = {}

-- per bed model: fold = where the kid's shoulders go (studs from the bed's centre toward the headboard),
-- mattressTop = height of the sleeping surface above the floor (studs). The lump sits from the shoulders down.
BedHump.BEDS = {
	CozyBed = {fold = 0.5, mattressTop = 3.4},
	FancyBed = {fold = 1.0, mattressTop = 3.7},
	LuxuryBed = {fold = 1.5, mattressTop = 3.6},
}
BedHump.HEIGHT = 1.7 -- studs the quilt rises over the kid
BedHump.SPREAD = Vector2.new(1.1, 1.4) -- studs across / along the bed
BedHump.BACK = 1.6 -- lump centre, studs from the shoulders toward the feet (keeps the turned-down edge flat)

local cache = {} -- [meshId] = Content

local function build(meshPart, cfg)
	local em = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId))
	local scale = meshPart.Size / meshPart.MeshSize
	local zc, sx, sz, amp = cfg.fold - BedHump.BACK, BedHump.SPREAD.X, BedHump.SPREAD.Y, BedHump.HEIGHT
	local function weight(p) local wx, wz = p.X * scale.X / sx, (p.Z * scale.Z - zc) / sz return math.exp(-wx * wx - wz * wz) end
	local function lowEnough(p) return p.Y * scale.Y + meshPart.Size.Y / 2 < cfg.mattressTop + 1.2 end -- quilt, not headboard or canopy

	-- raise only the topmost layer of the quilt (live games may move a mesh's points but never add any,
	-- so this needs a bed mesh that is already dense across the quilt)
	local CELL = 0.15
	local top = {}
	local verts = em:GetVertices()
	local function key(p) return math.floor(p.X * scale.X / CELL) .. ":" .. math.floor(p.Z * scale.Z / CELL) end
	for _, v in ipairs(verts) do local p = em:GetPosition(v) local k = key(p) top[k] = math.max(top[k] or -math.huge, p.Y) end
	for _, v in ipairs(verts) do
		local p = em:GetPosition(v)
		if p.Y > (top[key(p)] or p.Y) - 0.08 / scale.Y and lowEnough(p) then
			local w = weight(p)
			if w > 0.06 then em:SetPosition(v, p + Vector3.new(0, amp * (w - 0.06) / 0.94 / scale.Y, 0)) end
		end
	end

	-- let the engine recompute the existing normals over the reshaped area (no new elements)
	for _, f in ipairs(em:GetFaces()) do
		local vs = em:GetFaceVertices(f)
		local c = (em:GetPosition(vs[1]) + em:GetPosition(vs[2]) + em:GetPosition(vs[3])) / 3
		if weight(c) > 0.02 and lowEnough(c) then
			for _, n in ipairs(em:GetFaceNormals(f)) do pcall(em.ResetNormal, em, n) end
		end
	end
	return Content.fromObject(em)
end

-- returns a new MeshPart with the lump, sized and placed exactly over `meshPart`, or nil if it could not be built
function BedHump.make(meshPart, bedKind)
	local cfg = BedHump.BEDS[bedKind]
	if not cfg then return nil end
	if not cache[meshPart.MeshId] then
		local ok, content = pcall(build, meshPart, cfg)
		if not ok then warn("[BedHump] " .. tostring(content)) return nil end
		cache[meshPart.MeshId] = content
	end
	local ok, part = pcall(AssetService.CreateMeshPartAsync, AssetService, cache[meshPart.MeshId])
	if not ok then warn("[BedHump] " .. tostring(part)) return nil end
	part.Name = "QuiltWithKid"
	part.TextureID = meshPart.TextureID
	part.Size = meshPart.Size
	part.CFrame = meshPart.CFrame
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	return part
end

return BedHump
