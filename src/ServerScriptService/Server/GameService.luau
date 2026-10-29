-- Jumpscare RNG: 8 plots in a ring around a hub. Each player gets a plot when their save loads.
-- Hub egg -> saved inventory -> place in a showcase on your plot -> timed scares -> Fear -> rebirth
-- The server owns every outcome; prompts and the rebirth remote are rate limited and distance checked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local JeffRig = require(Shared:WaitForChild("JeffRig"))
local Net = require(Shared:WaitForChild("Net"))
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.RateLimiter)
local GuestKids = require(script.Parent.GuestKids)
local RoomStyles = require(script.Parent.RoomStyles)
local PlotFrame = require(script.Parent.PlotFrame)

local GameService = {}

local plotsFolder = workspace:WaitForChild("Plots")
local hub = workspace:WaitForChild("Hub")
local template = ServerStorage:WaitForChild("PlotTemplate")

local rng = Random.new()
local popupRemote, rebirthRemote -- created in Start, from one list

local allowHatch = RateLimiter.new(3, 1.5)
local allowShowcase = RateLimiter.new(4, 2)
local allowRebirth = RateLimiter.new(2, 0.5)

local plotOwner = {} -- [plot Model] = player
local plotOf = {} -- [player] = plot Model
local lastManual = {} -- [player] = os.clock() of their last manual scare

local function bedroomsOf(player)
	local plot = plotOf[player]
	return plot and plot.Contents:FindFirstChild("Bedrooms")
end

local function owns(player, inst)
	local plot = plotOf[player]
	return plot ~= nil and inst:IsDescendantOf(plot)
end

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

-- one of the three kids, lying asleep in the bed (RoomStyles sets the pillow spot for each bed)
local function makeGuest(spot)
	if spot.Parent:FindFirstChild("Guest") then return end
	return GuestKids.build(spot.Parent, spot.CFrame, rng:NextInteger(1, #GuestKids.KINDS), spot:GetAttribute("SitPoint"))
end

-- where Jeff stands to scare: on the window side of the bed, facing the kid (worked out in plot-local space)
local function roomOrigin(bedroom)
	local P = PlotFrame.of(bedroom)
	local bed = P:PointToObjectSpace(bedroom.BedFrame.Position)
	local floor = P:PointToObjectSpace(bedroom.RoomFloor.Position)
	local side = math.sign(bed.X)
	local stand = Vector3.new(bed.X - side * (bedroom.BedFrame.Size.X / 2 + 2.2), floor.Y + bedroom.RoomFloor.Size.Y / 2 + 0.25, bed.Z)
	-- the clip's sneak walks in from his right (about 9 studs); slide 1.5 studs left so he starts inside the room and ends by the kid
	return P * CFrame.lookAt(stand, stand + Vector3.new(side, 0, 0)) * CFrame.new(-1.5, 0, 0)
end

-- Jeff's route for one scare: in through the crawl hole, across the room clear of the side-wall furniture,
-- then along the bed to his scare spot (arriving the way the Blender clip expects before it turns to the bed)
local function scarePath(bedroom, origin)
	local P = PlotFrame.of(bedroom)
	local floor = P:PointToObjectSpace(bedroom.RoomFloor.Position)
	local side = math.sign(floor.X)
	local L = -side
	local front = math.abs(P:PointToObjectSpace(bedroom.FrontLow.Position).X)
	local stand = P:PointToObjectSpace(origin.Position)
	local hole = P:PointToObjectSpace(bedroom.CrawlHole.Position)
	local laneZ = floor.Z - L * 8 -- 8 studs from the room's middle, on the hole's side
	local y = stand.Y
	return {
		P:PointToWorldSpace(Vector3.new(hole.X + side * 1.5, y, hole.Z)),
		P:PointToWorldSpace(Vector3.new(side * (front + 6), y, laneZ)),
		P:PointToWorldSpace(Vector3.new(stand.X, y, laneZ)),
		origin.Position,
	}
end

local function setScareRoute(bedroom, roomJeff, interval)
	local origin = roomOrigin(bedroom)
	local path = scarePath(bedroom, origin)
	for i, p in ipairs(path) do roomJeff:SetAttribute("P" .. i, p) end
	roomJeff:SetAttribute("RoomOrigin", origin)
	roomJeff:SetAttribute("Interval", interval)
	return JeffRig.timeline(JeffRig.pathLength(path), interval), path
end

-- Jeff on display in the case, plus a second Jeff who waits at the bedroom's crawl hole and sneaks in for each scare.
-- The room Jeff is a child of the display one, so picking the monster up removes both.
-- A rarity-coloured outline shows his tier (the case also names it).
local function makeMonster(bedroom, tier)
	local m = JeffRig.build(bedroom, bedroom.MonsterSpot.CFrame * CFrame.new(0, 0.25, 0), "JeffDisplay")
	local roomJeff = JeffRig.build(m, roomOrigin(bedroom), "JeffRoom")
	roomJeff.Name = "RoomJeff"
	local _, path = setScareRoute(bedroom, roomJeff, tier.interval)
	JeffRig.idle(roomJeff, path)
	local h = Instance.new("Highlight") h.FillTransparency = 1 h.OutlineColor = tier.color h.Parent = m
	return m
end

-- the kid's reaction at the moment Jeff pops up: it sits bolt upright, jumps and shakes with a "!", then runs off
local function playScare(bedroom)
	local guest = bedroom:FindFirstChild("Guest")
	if guest and guest.Parent then
		GuestKids.scare(guest)
		guest:Destroy()
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
	RoomStyles.apply(bedroom, tier.name) -- the room refurnishes itself: Cozy, Fancy or Gold Luxury
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
			tool.CanBeDropped = false
			JeffRig.buildMini(tool, 0.3)
			tool.ToolTip = monster.Tier .. " - place in a display case"
			tool:SetAttribute("Uid", uid)
			tool.Parent = backpack
		end
	end
end

local function refreshLocks(player)
	local d = data(player)
	local bedrooms = bedroomsOf(player)
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
	local monster = makeMonster(bedroom, tier)
	bedroom.ShowcaseGlass.PlacePrompt.ActionText = "Pick Up"
	showInfo(player, bedroom)
	-- stops when the monster is picked up, the owner leaves, or the plot is unclaimed
	local plot = plotOf[player]
	local function still() return monster.Parent ~= nil and plot ~= nil and plotOf[player] == plot and d == data(player) and d.Placed[key] == uid end
	-- one scare per timer: Jeff sneaks in, the kid reacts and Fear pays out the moment he pops up, then he sneaks back
	while still() do
		local cycleStart = os.clock()
		local roomJeff = monster:FindFirstChild("RoomJeff")
		local tl = setScareRoute(bedroom, roomJeff, tier.interval)
		roomJeff:SetAttribute("ScareCount", (roomJeff:GetAttribute("ScareCount") or 0) + 1)
		task.wait(tl.pop)
		if not still() then break end
		pay(player, rng:NextInteger(tier.min, tier.max) * bedroom:GetAttribute("Mult"))
		playScare(bedroom)
		setBedroomTier(bedroom, Config.pickBedroomTier(rng:NextNumber(0, 100)))
		showInfo(player, bedroom)
		makeGuest(bedroom.GuestSpot)
		task.wait(math.max(0.5, tier.interval - (os.clock() - cycleStart)))
	end
end

local function hatch(player)
	if not allowHatch(player) then return end
	local d = data(player)
	local egg = hub.Egg
	if not d or not near(player, egg, egg.HatchPrompt.MaxActivationDistance) then return end
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
	if not allowShowcase(player) or not owns(player, b) then return end
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
	if not owns(player, b) or not data(player) or not b:FindFirstChild("Guest") then return end
	if not near(player, b.CrawlHole, b.CrawlHole.ScarePrompt.MaxActivationDistance) then return end
	if lastManual[player] and os.clock() - lastManual[player] < Config.MANUAL_COOLDOWN then return end
	lastManual[player] = os.clock()
	pay(player, Config.MANUAL_BASE * b:GetAttribute("Mult"))
	playScare(b)
	if not data(player).Placed[tostring(b:GetAttribute("Index"))] then
		setBedroomTier(b, Config.pickBedroomTier(rng:NextNumber(0, 100)))
	end
	makeGuest(b.GuestSpot)
end

local function sendHome(player)
	local plot = plotOf[player]
	local char = player.Character
	if plot and char then char:PivotTo(plot.SpawnPoint.CFrame + Vector3.new(0, 3, 0)) end
end

-- plots are empty until a player's save loads; then the first free one is theirs: bedrooms copied in, placed monsters back.
-- (The vault's tycoon build does the same: assign on profile load, never on PlayerAdded.)
local function claim(player)
	if plotOf[player] or player.Parent ~= Players then return end
	local d = data(player)
	if not d then return end
	local plot
	for _, p in ipairs(plotsFolder:GetChildren()) do
		if p:IsA("Model") and not plotOwner[p] then plot = p break end
	end
	if not plot then
		popup(player, "All plots are taken: you are visiting. Your progress is safe.")
		return
	end
	plotOwner[plot], plotOf[player] = player, plot
	local frame = PlotFrame.of(plot)
	for _, child in ipairs(template:GetChildren()) do
		local copy = child:Clone()
		PlotFrame.place(copy, frame)
		copy.Parent = plot.Contents
	end
	local bedrooms = plot.Contents.Bedrooms
	for _, b in ipairs(bedrooms:GetChildren()) do
		setBedroomTier(b, Config.NORMAL_TIER)
		b.CrawlHole.ScarePrompt.Triggered:Connect(function(p) manualScare(p, b) end)
		b.ShowcaseGlass.PlacePrompt.Triggered:Connect(function(p) useShowcase(p, b) end)
	end
	setLabel(plot.OwnerSign, player.DisplayName .. "'s Plot")
	refreshLocks(player)
	for key, uid in d.Placed do
		local b = bedrooms:FindFirstChild("Bedroom" .. key)
		if b and b:GetAttribute("Index") <= Config.unlockedBedrooms(d.Rebirths) then task.spawn(runShowcase, player, b, uid) end
	end
	sendHome(player)
	popup(player, "This is your plot! Scare a kid through the crawl hole, then hatch an egg in the middle of the map.")
end

local function unclaim(leaving)
	local plot = plotOf[leaving]
	plotOf[leaving] = nil
	if not plot then return end
	plotOwner[plot] = nil
	plot.Contents:ClearAllChildren()
	setLabel(plot.OwnerSign, "Free plot")
	-- a visitor who had no plot gets this one
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= leaving and data(p) and not plotOf[p] then claim(p) break end
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
	refreshLocks(player)
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
	player.CharacterAdded:Connect(function()
		task.defer(syncTools, player)
		task.defer(sendHome, player)
	end)
	if profile.Unsaved then popup(player, "Studio test: progress will not be saved") end
	claim(player)
end

function GameService.Start()
	-- every remote this game uses, created by the server in one place
	popupRemote = Net.Event("Popup")
	rebirthRemote = Net.Function("Rebirth")
	rebirthRemote.OnServerInvoke = rebirth

	-- the hub egg: odds generated from Config, shown before anyone spends
	local egg = hub.Egg
	egg.HatchPrompt.Triggered:Connect(hatch)
	egg.BillboardGui.Text.Text = "Spooky Egg - " .. Config.EGG_COST .. " Fear"
	local odds = hub.EggOdds:FindFirstChildWhichIsA("SurfaceGui")
	if odds then odds.Text.Text = "Odds\n" .. Config.oddsText() end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then setLabel(plot.OwnerSign, "Free plot") end
	end
	PlayerData.OnLoaded(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		lastManual[player] = nil
		unclaim(player)
	end)
end

return GameService
