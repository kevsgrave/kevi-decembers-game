-- Jumpscare RNG: claim plot, egg -> saved inventory -> place in showcase -> timed scares -> Fear -> rebirth
-- The server owns every outcome; prompts and the rebirth remote are rate limited and distance checked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local JeffRig = require(Shared:WaitForChild("JeffRig"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.RateLimiter)

local GameService = {}

local plot = workspace:WaitForChild("Plot")
local contents = plot:WaitForChild("Contents")
local claimPad = plot:WaitForChild("ClaimPad")
local template = ServerStorage:WaitForChild("PlotTemplate")

local GUEST_COLORS = {
	Color3.fromRGB(150, 110, 80), Color3.fromRGB(255, 200, 150), Color3.fromRGB(230, 120, 60),
	Color3.fromRGB(245, 245, 245), Color3.fromRGB(120, 200, 110), Color3.fromRGB(160, 160, 170),
}

local rng = Random.new()
local popupRemote, rebirthRemote -- created in Start, from one list

local allowHatch = RateLimiter.new(3, 1.5)
local allowShowcase = RateLimiter.new(4, 2)
local allowRebirth = RateLimiter.new(2, 0.5)

local owner
local bedrooms -- the claimed plot's Bedrooms folder
local lastManual = {} -- [player] = os.clock() of their last manual scare

local function data(player)
	local profile = PlayerData.Get(player)
	return profile and profile.Data
end

-- the server re-checks prompt range itself (prompt distance is client-side)
local function near(player, part, maxDistance)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - part.Position).Magnitude <= maxDistance + 4
end

local function popup(player, msg) popupRemote:FireClient(player, msg) end

local function setFear(player, d, value)
	d.Fear = math.clamp(math.floor(value), 0, Config.MAX_FEAR)
	local ls = player:FindFirstChild("leaderstats")
	if ls then ls.Fear.Value = d.Fear end
end

local function publishRebirth(player, d)
	player.leaderstats.Rebirths.Value = d.Rebirths
	local maxed = Config.unlockedBedrooms(d.Rebirths) >= Config.BEDROOM_COUNT
	player:SetAttribute("RebirthCost", maxed and -1 or Config.rebirthCost(d.Rebirths))
	player:SetAttribute("Multiplier", Config.rebirthMult(d.Rebirths))
end

local function setLabel(part, text, color)
	local t = part:FindFirstChildWhichIsA("SurfaceGui").Text
	t.Text = text
	if color then t.TextColor3 = color end
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint") w.Part0 = a w.Part1 = b w.Parent = a
end

local function part(model, name, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color p.Anchored = false p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end

-- shortcut: part-built stand-ins; swap for the art/guests meshes once uploaded
local function makeGuest(spot)
	if spot.Parent:FindFirstChild("Guest") then return end
	local m = Instance.new("Model") m.Name = "Guest"
	local c = GUEST_COLORS[rng:NextInteger(1, #GUEST_COLORS)]
	local cf = spot.CFrame
	local head = part(m, "Head", Vector3.new(2.4, 2.4, 2.4), cf, c, Enum.PartType.Ball)
	head.Anchored = true
	for _, x in ipairs({-0.8, 0.8}) do
		weld(head, part(m, "Ear", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(x, 1.1, 0), c, Enum.PartType.Ball))
		weld(head, part(m, "Eye", Vector3.new(0.35, 0.35, 0.35), cf * CFrame.new(x * 0.5, 0.2, -1.1), Color3.new(0, 0, 0), Enum.PartType.Ball))
	end
	weld(head, part(m, "Body", Vector3.new(2, 1.6, 1.4), cf * CFrame.new(0, -1.7, 0.3), Color3.fromRGB(120, 170, 255)))
	m.PrimaryPart = head
	m.Parent = spot.Parent
	return m
end

-- Jeff built from the Blender model; a rarity-coloured outline shows his tier (the case also names it)
local function makeMonster(spot, tier)
	local m = JeffRig.build(spot.Parent, spot.CFrame * CFrame.new(0, 0.25, 0))
	local h = Instance.new("Highlight") h.FillTransparency = 1 h.OutlineColor = tier.color h.Parent = m
	return m
end

-- mild scare: clients play Jeff's Blender scare, then the kid jumps with a "!" bubble
local function playScare(bedroom, monster)
	local guest = bedroom:FindFirstChild("Guest")
	if monster then
		monster:SetAttribute("ScareCount", (monster:GetAttribute("ScareCount") or 0) + 1)
		task.wait(JeffRig.PEAK)
	end
	if guest and guest.Parent then
		local head = guest.PrimaryPart
		local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromOffset(60, 60) bb.StudsOffset = Vector3.new(0, 2.5, 0) bb.Parent = head
		local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
		t.TextScaled = true t.Text = "!" t.TextColor3 = Color3.fromRGB(255, 230, 60) t.TextStrokeTransparency = 0 t.Parent = bb
		TweenService:Create(head, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {CFrame = head.CFrame * CFrame.new(0, 2, 0)}):Play()
		task.wait(0.8)
		-- kid runs off, room resets with a new kid
		guest:Destroy()
		task.wait(0.4)
	end
end

local function pay(player, amount)
	local d = data(player)
	if not d then return end
	amount = math.floor(amount * Config.rebirthMult(d.Rebirths))
	setFear(player, d, d.Fear + amount)
	popup(player, "+" .. Config.short(amount) .. " Fear")
end

local function setBedroomTier(bedroom, tier)
	bedroom:SetAttribute("Tier", tier.name)
	bedroom:SetAttribute("Mult", tier.mult)
	setLabel(bedroom.TierSign, tier.name .. " x" .. tier.mult, tier.color)
end

-- display case readout: monster name and rarity, then expected Fear per scare under it
local function showInfo(player, bedroom)
	local info = bedroom.ShowcaseLid.Info
	local d = data(player)
	local uid = d and d.Placed[tostring(bedroom:GetAttribute("Index"))]
	local monster = uid and d.Monsters[uid]
	local tier = monster and Config.TIER_BY_NAME[monster.Tier]
	if not tier then
		info.MonsterName.Text = "Empty"
		info.MonsterName.TextColor3 = Color3.new(1, 1, 1)
		info.Cash.Text = "Hatch an egg!"
		return
	end
	local avg = (tier.min + tier.max) / 2 * bedroom:GetAttribute("Mult") * Config.rebirthMult(d.Rebirths)
	info.MonsterName.Text = tier.name .. " " .. monster.Kind
	info.MonsterName.TextColor3 = tier.color
	info.Cash.Text = "👻 " .. Config.short(avg) .. " / scare"
end

-- inventory lives in the save; Tools in the Backpack are only the "holding" view of unplaced monsters
local function syncTools(player)
	local d = data(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not d or not backpack then return end
	local placed = {}
	for _, uid in d.Placed do placed[uid] = true end
	local have = {}
	for _, holder in ipairs({backpack, player.Character}) do
		for _, tool in ipairs(holder and holder:GetChildren() or {}) do
			local uid = tool:IsA("Tool") and tool:GetAttribute("Uid")
			if uid then
				if d.Monsters[uid] == nil or placed[uid] or have[uid] then tool:Destroy() else have[uid] = true end
			end
		end
	end
	for uid, monster in d.Monsters do
		if not placed[uid] and not have[uid] then
			local tool = Instance.new("Tool")
			tool.Name = monster.Kind
			tool.RequiresHandle = false
			tool.CanBeDropped = false
			tool.ToolTip = monster.Tier .. " - place in a display case"
			tool:SetAttribute("Uid", uid)
			tool.Parent = backpack
		end
	end
end

local function refreshLocks(player)
	local d = data(player)
	if not d or not bedrooms then return end
	local unlocked = Config.unlockedBedrooms(d.Rebirths)
	for _, b in ipairs(bedrooms:GetChildren()) do
		local open = b:GetAttribute("Index") <= unlocked
		b.Lock.Transparency = open and 1 or 0.1
		b.Lock.CanCollide = not open
		b.Lock.SurfaceGui.Enabled = not open
		b.ShowcaseLid.Info.Enabled = open
		b.CrawlHole.ScarePrompt.Enabled = open
		b.ShowcaseGlass.PlacePrompt.Enabled = open
		if open then
			makeGuest(b.GuestSpot)
			showInfo(player, b)
		end
	end
end

local function runShowcase(player, bedroom, uid)
	local key = tostring(bedroom:GetAttribute("Index"))
	local d = data(player)
	local tier = d and Config.TIER_BY_NAME[d.Monsters[uid].Tier]
	if not tier then return end
	local old = bedroom:FindFirstChild("Monster") if old then old:Destroy() end
	local monster = makeMonster(bedroom.MonsterSpot, tier)
	bedroom.ShowcaseGlass.PlacePrompt.ActionText = "Pick Up"
	showInfo(player, bedroom)
	-- stops when the monster is picked up, the owner leaves, or the plot is unclaimed
	local function still() return monster.Parent ~= nil and owner == player and d == data(player) and d.Placed[key] == uid end
	while still() do
		task.wait(tier.interval)
		if not still() then break end
		pay(player, rng:NextInteger(tier.min, tier.max) * bedroom:GetAttribute("Mult"))
		playScare(bedroom, monster)
		setBedroomTier(bedroom, Config.pickBedroomTier(rng:NextNumber(0, 100)))
		showInfo(player, bedroom)
		makeGuest(bedroom.GuestSpot)
	end
end

local function hatch(player)
	if not allowHatch(player) or player ~= owner then return end
	local d = data(player)
	if not d or not near(player, contents.Egg, contents.Egg.HatchPrompt.MaxActivationDistance) then return end
	local count = 0
	for _ in d.Monsters do count += 1 end
	if count >= Config.INVENTORY_CAP then
		popup(player, "Your inventory is full (" .. Config.INVENTORY_CAP .. ")")
		return
	end
	if d.Fear < Config.EGG_COST then
		popup(player, "Need " .. Config.EGG_COST .. " Fear")
		return
	end
	-- no yields from the checks above to here, so a double request cannot spend once and hatch twice
	local tier = Config.pickMonsterTier(rng:NextNumber(0, 100))
	local uid = "m" .. d.NextUid
	d.NextUid += 1
	d.Monsters[uid] = {Kind = Config.MONSTER_KIND, Tier = tier.name}
	setFear(player, d, d.Fear - Config.EGG_COST)
	syncTools(player)
	popup(player, "You hatched a " .. tier.name .. " " .. Config.MONSTER_KIND .. "! Place him in a display case.")
end

-- display case prompt: place the held (or first unplaced) monster, or pick the current one back up
local function useShowcase(player, b)
	if not allowShowcase(player) or player ~= owner then return end
	local d = data(player)
	local index = b:GetAttribute("Index")
	if not d or index > Config.unlockedBedrooms(d.Rebirths) or not near(player, b.ShowcaseGlass, b.ShowcaseGlass.PlacePrompt.MaxActivationDistance) then return end
	local key = tostring(index)
	local prompt = b.ShowcaseGlass.PlacePrompt
	if d.Placed[key] then
		d.Placed[key] = nil
		local m = b:FindFirstChild("Monster") if m then m:Destroy() end
		prompt.ActionText = "Place Monster"
		syncTools(player)
		showInfo(player, b)
		return
	end
	local placed = {}
	for _, uid in d.Placed do placed[uid] = true end
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local uid = held and held:GetAttribute("Uid")
	if not (uid and d.Monsters[uid] and not placed[uid]) then
		uid = nil
		for id in d.Monsters do
			if not placed[id] then uid = id break end
		end
	end
	if not uid then
		popup(player, "Hatch an egg first!")
		return
	end
	d.Placed[key] = uid
	syncTools(player)
	task.spawn(runShowcase, player, b, uid)
end

local function manualScare(player, b)
	if player ~= owner or not data(player) or not b:FindFirstChild("Guest") then return end
	if not near(player, b.CrawlHole, b.CrawlHole.ScarePrompt.MaxActivationDistance) then return end
	if lastManual[player] and os.clock() - lastManual[player] < Config.MANUAL_COOLDOWN then return end
	lastManual[player] = os.clock()
	pay(player, Config.MANUAL_BASE * b:GetAttribute("Mult"))
	playScare(b, nil)
	if not data(player).Placed[tostring(b:GetAttribute("Index"))] then
		setBedroomTier(b, Config.pickBedroomTier(rng:NextNumber(0, 100)))
	end
	makeGuest(b.GuestSpot)
end

-- the plot is empty until a player's save loads, then it is theirs automatically: bedrooms and egg copied in, placed monsters back
local function claim(player)
	if owner or player.Parent ~= Players then return end
	local d = data(player)
	if not d then return end
	owner = player
	for _, child in ipairs(template:GetChildren()) do child:Clone().Parent = contents end
	bedrooms = contents.Bedrooms
	local egg = contents.Egg
	egg.HatchPrompt.Triggered:Connect(hatch)
	egg.BillboardGui.Text.Text = "Spooky Egg - " .. Config.EGG_COST .. " Fear"
	-- odds generated from Config, shown before anyone spends
	local odds = Instance.new("BillboardGui") odds.Name = "Odds" odds.Size = UDim2.fromScale(6, 6) odds.StudsOffsetWorldSpace = Vector3.new(6, 2, 0) odds.MaxDistance = 60 odds.Parent = contents.EggPedestal
	local ot = Instance.new("TextLabel") ot.Size = UDim2.fromScale(1, 1) ot.BackgroundTransparency = 1 ot.Font = Enum.Font.FredokaOne ot.TextScaled = true
	ot.TextColor3 = Color3.new(1, 1, 1) ot.Text = "Odds\n" .. Config.oddsText() ot.Parent = odds
	local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = Color3.fromRGB(20, 10, 40) s.Parent = ot
	for _, b in ipairs(bedrooms:GetChildren()) do
		setBedroomTier(b, Config.NORMAL_TIER)
		b.CrawlHole.ScarePrompt.Triggered:Connect(function(p) manualScare(p, b) end)
		b.ShowcaseGlass.PlacePrompt.Triggered:Connect(function(p) useShowcase(p, b) end)
	end
	claimPad.Sign.Text.Text = player.DisplayName .. "'s Plot"
	refreshLocks(player)
	for key, uid in d.Placed do
		local b = bedrooms:FindFirstChild("Bedroom" .. key)
		if b and b:GetAttribute("Index") <= Config.unlockedBedrooms(d.Rebirths) then task.spawn(runShowcase, player, b, uid) end
	end
	popup(player, "This is your plot! Hatch the Spooky Egg.")
end

-- shortcut: one plot on the map, so it passes to the next loaded player; per-player plots come with multiplayer
local function unclaim(leaving)
	owner = nil
	bedrooms = nil
	contents:ClearAllChildren()
	claimPad.Sign.Text.Text = ""
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= leaving and data(p) then claim(p) break end
	end
end

-- RemoteFunction: returns (ok, message) for the confirm dialog; takes no arguments
local function rebirth(player, ...)
	if not allowRebirth(player) then return false, "Slow down!" end
	if select("#", ...) > 0 then return false, "Bad request" end
	local d = data(player)
	if not d then return false, "Still loading" end
	if Config.unlockedBedrooms(d.Rebirths) >= Config.BEDROOM_COUNT then return false, "All bedrooms unlocked" end
	local cost = Config.rebirthCost(d.Rebirths)
	if d.Fear < cost then return false, "Need " .. Config.short(cost) .. " Fear" end
	-- check and reset with no yield between, so parallel requests cannot rebirth twice for one price
	d.Rebirths += 1
	setFear(player, d, 0)
	publishRebirth(player, d)
	if player == owner then refreshLocks(player) end
	task.spawn(PlayerData.SaveNowAsync, player)
	return true, "Rebirth! New bedroom unlocked, x" .. Config.rebirthMult(d.Rebirths) .. " Fear"
end

local function onLoaded(profile)
	local player, d = profile.Player, profile.Data
	local ls = Instance.new("Folder") ls.Name = "leaderstats"
	local fear = Instance.new("IntValue") fear.Name = "Fear" fear.Value = d.Fear fear.Parent = ls -- numeric stat first
	local rb = Instance.new("IntValue") rb.Name = "Rebirths" rb.Parent = ls
	ls.Parent = player
	publishRebirth(player, d)
	syncTools(player)
	player.CharacterAdded:Connect(function() task.defer(syncTools, player) end)
	if profile.Unsaved then popup(player, "Studio test: progress will not be saved") end
	claim(player)
end

function GameService.Start()
	-- every remote this game uses, created by the server in one place
	popupRemote = Net.Event("Popup")
	rebirthRemote = Net.Function("Rebirth")
	rebirthRemote.OnServerInvoke = rebirth

	-- no manual claiming: the pad is only the owner's name sign
	local oldPrompt = claimPad:FindFirstChild("ClaimPrompt") if oldPrompt then oldPrompt:Destroy() end
	claimPad.Transparency = 1
	claimPad.CanCollide = false
	claimPad.CanTouch = false
	claimPad.Sign.Text.Text = ""
	PlayerData.OnLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		lastManual[player] = nil
		if owner == player then unclaim(player) end
	end)
end

return GameService
