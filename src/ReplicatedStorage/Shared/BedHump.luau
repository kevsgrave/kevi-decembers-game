-- Reshapes a bed's own quilt mesh so it has a sleeping-kid lump, using EditableMesh.
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
BedHump.HEIGHT = 1.4 -- studs the quilt rises over the kid
BedHump.SPREAD = Vector2.new(1.05, 1.2) -- studs across / along the bed
BedHump.BACK = 1.0 -- lump centre, studs from the shoulders toward the feet

local cache = {} -- [meshId] = Content

local function build(meshPart, cfg)
	local em = AssetService:CreateEditableMeshAsync(Content.fromUri(meshPart.MeshId))
	local scale = meshPart.Size / meshPart.MeshSize
	local zc, sx, sz, amp = cfg.fold - BedHump.BACK, BedHump.SPREAD.X, BedHump.SPREAD.Y, BedHump.HEIGHT
	local function weight(p) local wx, wz = p.X * scale.X / sx, (p.Z * scale.Z - zc) / sz return math.exp(-wx * wx - wz * wz) end
	local function lowEnough(p) return p.Y * scale.Y + meshPart.Size.Y / 2 < cfg.mattressTop + 1.2 end -- quilt, not headboard or canopy
	local function facingUp(vs)
		local a, b, c = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
		local n = (b - a):Cross(c - a)
		return n.Magnitude > 0 and math.abs(n.Unit.Y) > 0.5
	end
	local hasUV = pcall(function() return em:GetFaceUVs(em:GetFaces()[1]) end)

	-- 1) split the quilt's top faces over the lump so it can bend smoothly (three rounds, under the triangle limit)
	for _ = 1, 3 do
		local midV, midUV = {}, {}
		local function mid(a, b, store, get, add)
			local k = (a < b) and (a .. "_" .. b) or (b .. "_" .. a)
			if not store[k] then store[k] = add((get(a) + get(b)) / 2) end
			return store[k]
		end
		local getP, addP = function(v) return em:GetPosition(v) end, function(p) return em:AddVertex(p) end
		local getU, addU = function(u) return em:GetUV(u) end, function(u) return em:AddUV(u) end
		local todo = {}
		for _, f in ipairs(em:GetFaces()) do
			local vs = em:GetFaceVertices(f)
			local c = (em:GetPosition(vs[1]) + em:GetPosition(vs[2]) + em:GetPosition(vs[3])) / 3
			if weight(c) > 0.05 and lowEnough(c) and facingUp(vs) then table.insert(todo, f) end
		end
		if #em:GetFaces() + #todo * 3 > 19000 then break end
		for _, f in ipairs(todo) do
			local vs = em:GetFaceVertices(f)
			local us = hasUV and em:GetFaceUVs(f) or nil
			local m12, m23, m31 = mid(vs[1], vs[2], midV, getP, addP), mid(vs[2], vs[3], midV, getP, addP), mid(vs[3], vs[1], midV, getP, addP)
			local tris = {{vs[1], m12, m31}, {m12, vs[2], m23}, {m31, m23, vs[3]}, {m12, m23, m31}}
			local uvt
			if us then
				local u12, u23, u31 = mid(us[1], us[2], midUV, getU, addU), mid(us[2], us[3], midUV, getU, addU), mid(us[3], us[1], midUV, getU, addU)
				uvt = {{us[1], u12, u31}, {u12, us[2], u23}, {u31, u23, us[3]}, {u12, u23, u31}}
			end
			em:RemoveFace(f)
			for i, t in ipairs(tris) do
				local nf = em:AddTriangle(t[1], t[2], t[3])
				if uvt then em:SetFaceUVs(nf, uvt[i]) end
			end
		end
	end

	-- 2) raise the quilt's top surface; vertices shared with side faces stay put so no seams open
	local frozen = {}
	for _, f in ipairs(em:GetFaces()) do
		local vs = em:GetFaceVertices(f)
		if not facingUp(vs) then for _, v in ipairs(vs) do frozen[v] = true end end
	end
	local CELL = 0.25
	local top = {}
	local verts = em:GetVertices()
	local function key(p) return math.floor(p.X * scale.X / CELL) .. ":" .. math.floor(p.Z * scale.Z / CELL) end
	for _, v in ipairs(verts) do local p = em:GetPosition(v) local k = key(p) top[k] = math.max(top[k] or -math.huge, p.Y) end
	for _, v in ipairs(verts) do
		local p = em:GetPosition(v)
		if not frozen[v] and p.Y > (top[key(p)] or p.Y) - 0.3 / scale.Y and lowEnough(p) then
			local w = weight(p)
			if w > 0.06 then em:SetPosition(v, p + Vector3.new(0, amp * (w - 0.06) / 0.94 / scale.Y, 0)) end
		end
	end

	-- 3) smooth automatic normals over the reshaped area
	local autoN = {}
	for _, f in ipairs(em:GetFaces()) do
		local vs = em:GetFaceVertices(f)
		local c = (em:GetPosition(vs[1]) + em:GetPosition(vs[2]) + em:GetPosition(vs[3])) / 3
		if weight(c) > 0.02 and lowEnough(c) and facingUp(vs) then
			local ns = {}
			for i, v in ipairs(vs) do
				if not autoN[v] then autoN[v] = em:AddNormal() end
				ns[i] = autoN[v]
			end
			pcall(em.SetFaceNormals, em, f, ns)
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
