-- Jumpscare RNG: 8 plots in a ring around a hub. Each player gets a plot when their save loads.
-- Hub egg -> saved inventory -> place in a showcase on your plot -> timed scares -> Fear -> rebirth
-- The server owns every outcome; prompts and the rebirth remote are rate limited and distance checked.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local JeffRig = require(Shared:WaitForChild("JeffRig"))
local Payout = require(Shared:WaitForChild("Payout"))
local Net = require(Shared:WaitForChild("Net"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataTemplate = require(script.Parent.DataTemplate)
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.RateLimiter)
local GuestKids = require(script.Parent.GuestKids)
local RoomStyles = require(script.Parent.RoomStyles)
local PlotFrame = require(script.Parent.PlotFrame)
local PlotClaims = require(script.Parent.PlotClaims)
local Inventory = require(script.Parent.Inventory)
local ScareScheduler = require(script.Parent.ScareScheduler)

local GameService = {}

local plotsFolder = workspace:WaitForChild("Plots")
local hub = workspace:WaitForChild("Hub")
local template = ServerStorage:WaitForChild("PlotTemplate")

local rng = Random.new()
local popupRemote, rebirthRemote, inventoryRemote, cueRemote -- created in Start, from one list

local allowHatch = RateLimiter.new(Config.LIMITS.hatch.capacity, Config.LIMITS.hatch.refillPerSecond)
local allowShowcase = RateLimiter.new(Config.LIMITS.showcase.capacity, Config.LIMITS.showcase.refillPerSecond)
local allowRebirth = RateLimiter.new(Config.LIMITS.rebirth.capacity, Config.LIMITS.rebirth.refillPerSecond)
local allowInventory = RateLimiter.new(Config.LIMITS.inventory.capacity, Config.LIMITS.inventory.refillPerSecond)
local allowManual = RateLimiter.new(Config.LIMITS.manual.capacity, Config.LIMITS.manual.refillPerSecond)

local claims = PlotClaims.new()
local plotOf = claims.plotOf -- [player] = plot Model
local lastManual = {} -- [player] = os.clock() of their last manual scare
local manualSessions = {} -- [player] = the manual scare in progress
local working = {} -- [bedroom] = {player, uid} for a monster doing automatic scares
local reacting = {} -- [bedroom] = true while its guest is reacting, so nothing else can scare it

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

-- visitors may tour any plot, but only the owner can use it
local function ownedOrWarn(player, inst)
	if owns(player, inst) then return true end
	popup(player, "This isn't your plot. You can look around, but only its owner can use it.")
	return false
end

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

-- every Fear payout goes through here; the amount is already final
local function pay(player, amount)
	local d = data(player)
	if not d then return false end
	setFear(player, d, d.Fear + amount)
	d.TotalFearEarned = math.min(d.TotalFearEarned + amount, Config.MAX_FEAR)
	return true
end

-- clients show the floating payout from these; visitors see them too
local function announcePayout(bedroom, amount)
	bedroom:SetAttribute("PayoutAmount", amount)
	bedroom:SetAttribute("PayoutSeq", (bedroom:GetAttribute("PayoutSeq") or 0) + 1)
end

local function setBedroomTier(bedroom, tier)
	bedroom:SetAttribute("Tier", tier.name)
	bedroom:SetAttribute("Mult", tier.mult)
	setLabel(bedroom.TierSign, tier.name .. " x" .. tier.mult, tier.color)
	RoomStyles.apply(bedroom, tier.name) -- the room refurnishes itself: Cozy, Fancy or Gold Luxury
end

-- this room's current payout, the same way it's paid
local function roomPayout(d, bedroom, monster)
	local accessory = Payout.accessoryOf(d, tostring(bedroom:GetAttribute("Index")))
	return Payout.scare(monster, bedroom:GetAttribute("Mult") or 1, d.Rebirths, accessory)
end

-- the HUD's Fear per second: an estimate from the rooms as they stand; Fear itself only comes from finished scares
local function updateRate(player, d)
	local bedrooms = bedroomsOf(player)
	local rate = 0
	if bedrooms then
		for slot, uid in d.Placed do
			local b = bedrooms:FindFirstChild("Bedroom" .. slot)
			local monster = d.Monsters[uid]
			local tier = monster and Config.TIER_BY_NAME[monster.Tier]
			if b and tier then rate += roomPayout(d, b, monster).total / tier.interval end
		end
	end
	player:SetAttribute("FearPerSecond", rate)
end

-- display case readout: name and rarity word, what it pays and how often, then how that number is made up
local function showInfo(player, bedroom)
	local info = bedroom.ShowcaseLid.Info
	local d = data(player)
	if not d then return end
	local uid = d.Placed[tostring(bedroom:GetAttribute("Index"))]
	local monster = uid and d.Monsters[uid]
	local tier = monster and Config.TIER_BY_NAME[monster.Tier]
	if not tier then
		info.MonsterName.Text = "Empty"
		info.MonsterName.TextColor3 = Color3.new(1, 1, 1)
		info.Cash.Text = "Hold a monster and press E"
		info.Factors.Text = ""
	else
		local b = roomPayout(d, bedroom, monster)
		info.MonsterName.Text = monster.Kind .. " - " .. tier.name
		info.MonsterName.TextColor3 = tier.color
		info.Cash.Text = "👻 " .. Config.short(b.total) .. " / scare, every " .. tier.interval .. "s"
		info.Factors.Text = Payout.describe(b, bedroom:GetAttribute("Tier") or "Room", monster.Size, monster.Mutation)
	end
	updateRate(player, d)
end

-- the case's third line, added to each claimed copy so the template stays as it is
local function addFactorsLine(bedroom)
	local info = bedroom.ShowcaseLid.Info
	info.Size = UDim2.fromScale(9, 4.8)
	info.MonsterName.Size = UDim2.fromScale(1, 0.375)
	info.Cash.Position = UDim2.fromScale(0, 0.375)
	info.Cash.Size = UDim2.fromScale(1, 0.375)
	local factors = info.Cash:Clone()
	factors.Name = "Factors"
	factors.Text = ""
	factors.Position = UDim2.fromScale(0, 0.75)
	factors.Size = UDim2.fromScale(1, 0.25)
	factors.TextColor3 = Color3.fromRGB(235, 235, 245)
	factors.Parent = info
end

-- inventory lives in the save; Tools in the Backpack are only the hotbar's view of it, rebuilt from the saved list
local function syncTools(player)
	local d = data(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not d or not backpack then return end
	local wanted = {}
	for _, uid in d.Hotbar do wanted[uid] = true end
	local have = {}
	for _, holder in ipairs({backpack, player.Character}) do
		for _, tool in ipairs(holder and holder:GetChildren() or {}) do
			local uid = tool:IsA("Tool") and tool:GetAttribute("Uid")
			if uid then
				if not wanted[uid] or have[uid] then tool:Destroy() else have[uid] = tool end
			end
		end
	end
	for _, uid in d.Hotbar do
		if not have[uid] then
			local monster = d.Monsters[uid]
			local tool = Instance.new("Tool")
			tool.Name = monster.Tier .. " " .. monster.Kind
			tool.CanBeDropped = false
			JeffRig.buildMini(tool, 0.3)
			tool.ToolTip = "👻 " .. Config.short(monster.BaseFear) .. " / scare. Press E at your display case"
			tool:SetAttribute("Uid", uid)
			tool.Parent = backpack
			have[uid] = tool
		end
	end
	return have
end

-- everything that changes the inventory ends here: the hotbar view and the client's panel both follow the save
local function inventoryChanged(player)
	syncTools(player)
	local d = data(player)
	if d then inventoryRemote:FireClient(player, Inventory.snapshot(d)) end
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
		if not open then
			local more = b:GetAttribute("Index") - unlocked
			b.Lock.SurfaceGui.Text.Text = "🔒 Rebirth " .. more .. " more time" .. (more == 1 and "" or "s") .. " to unlock"
		end
		b.ShowcaseLid.Info.Enabled = open
		b.CrawlHole.ScarePrompt.Enabled = open
		b.ShowcaseGlass.PlacePrompt.Enabled = open
		if open then
			makeGuest(b.GuestSpot)
			showInfo(player, b)
		end
	end
end

-- a scare has landed: the kid reacts, the room rerolls and a fresh kid gets into bed
local function resetRoom(player, bedroom)
	reacting[bedroom] = true
	playScare(bedroom)
	reacting[bedroom] = nil
	if not bedroom.Parent then return end -- the plot was released while the kid reacted
	setBedroomTier(bedroom, Config.pickBedroomTier(rng:NextNumber(0, 100)))
	showInfo(player, bedroom)
	makeGuest(bedroom.GuestSpot)
end

-- one scheduler for every room's automatic scares, driven by one loop in Start
local scheduler = ScareScheduler.new({
	-- Jeff sets off from the crawl hole; returns when he reaches the kid
	begin = function(bedroom)
		local work = working[bedroom]
		local monster = bedroom:FindFirstChild("Monster")
		local roomJeff = monster and monster:FindFirstChild("RoomJeff")
		if not work or not roomJeff then return 0 end
		local tl = setScareRoute(bedroom, roomJeff, Config.TIER_BY_NAME[work.tier].interval)
		roomJeff:SetAttribute("ScareCount", (roomJeff:GetAttribute("ScareCount") or 0) + 1)
		bedroom:SetAttribute("State", "Scaring")
		return tl.pop
	end,
	-- pays once if everything is still true at the moment of the scare
	pay = function(bedroom)
		local work = working[bedroom]
		local d = work and data(work.player)
		local slot = tostring(bedroom:GetAttribute("Index"))
		if not d or d.Placed[slot] ~= work.uid or plotOf[work.player] == nil or reacting[bedroom] or not bedroom:FindFirstChild("Guest") then return false end
		local amount = roomPayout(d, bedroom, d.Monsters[work.uid]).total
		if not pay(work.player, amount) then return false end
		announcePayout(bedroom, amount)
		return true
	end,
	reset = function(bedroom)
		bedroom:SetAttribute("State", "Resetting")
		task.spawn(resetRoom, working[bedroom].player, bedroom)
	end,
})

local function stopRoom(bedroom)
	scheduler:remove(bedroom)
	working[bedroom] = nil
	bedroom:SetAttribute("State", "Sleeping")
end

-- Jeff goes on show in the case and starts work on the next tick
local function startRoom(player, bedroom, uid)
	local d = data(player)
	local record = d and d.Monsters[uid]
	local tier = record and Config.TIER_BY_NAME[record.Tier]
	if not tier then return end
	local old = bedroom:FindFirstChild("Monster") if old then old:Destroy() end
	makeMonster(bedroom, tier)
	bedroom.ShowcaseGlass.PlacePrompt.ActionText = "Pick Up"
	working[bedroom] = {player = player, uid = uid, tier = record.Tier}
	scheduler:add(bedroom, tier.interval, os.clock())
	showInfo(player, bedroom)
end

local function hatch(player)
	if not allowHatch(player) then return end
	local d = data(player)
	local egg = hub.Egg
	if not d or not near(player, egg, egg.HatchPrompt.MaxActivationDistance) then return end
	if Inventory.isFull(d) then
		popup(player, "Your inventory is full (" .. Config.INVENTORY_CAP .. ")")
		return
	end
	if d.Fear < Config.EGG_COST then
		popup(player, "Need " .. Config.EGG_COST .. " Fear")
		return
	end
	-- no yields from the checks above to here, so a double request cannot spend once and hatch twice
	local tier = Config.pickMonsterTier(rng:NextNumber(0, 100))
	Inventory.add(d, DataTemplate.newMonster(Config.MONSTER_KIND, tier.name, rng:NextInteger(tier.min, tier.max), "egg"))
	setFear(player, d, d.Fear - Config.EGG_COST)
	inventoryChanged(player)
	popup(player, "You hatched a " .. tier.name .. " " .. Config.MONSTER_KIND .. "! Hold it and press E at a display case.")
end

-- display case prompt: place the monster you're holding, or pick the current one back up
local PLACE_MESSAGES = {
	locked = "Rebirth to unlock this room",
	occupied = "This case already has a monster",
	missing = "Hold a monster first: pick one from your hotbar or inventory",
	deployed = "That monster is already in another room",
}

local function useShowcase(player, b)
	if not allowShowcase(player) or not ownedOrWarn(player, b) then return end
	local d = data(player)
	if not d or not near(player, b.ShowcaseGlass, b.ShowcaseGlass.PlacePrompt.MaxActivationDistance) then return end
	local index = b:GetAttribute("Index")
	local prompt = b.ShowcaseGlass.PlacePrompt
	if manualSessions[player] and manualSessions[player].bedroom == b then return end
	if d.Placed[tostring(index)] then
		Inventory.pickUp(d, index)
		stopRoom(b)
		local m = b:FindFirstChild("Monster") if m then m:Destroy() end
		prompt.ActionText = "Place Monster"
		inventoryChanged(player)
		showInfo(player, b)
		return
	end
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local uid = held and held:GetAttribute("Uid")
	local placed, why = Inventory.place(d, index, uid, Config.unlockedBedrooms(d.Rebirths))
	if not placed then
		popup(player, PLACE_MESSAGES[why])
		return
	end
	inventoryChanged(player)
	startRoom(player, b, uid)
end

-- put a monster from the inventory panel on the hotbar and in the player's hand
local function holdMonster(player, ...)
	if not allowInventory(player) or not Remotes.checkArgs("HoldMonster", ...) then return end
	local d = data(player)
	local uid = ...
	if not d or not Inventory.putOnHotbar(d, uid) then return end
	inventoryChanged(player)
	local tools = syncTools(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if tools and tools[uid] and humanoid and humanoid.Health > 0 then humanoid:EquipTool(tools[uid]) end
end

local function favoriteMonster(player, ...)
	if not allowInventory(player) or not Remotes.checkArgs("FavoriteMonster", ...) then return end
	local d = data(player)
	local uid, on = ...
	if d and Inventory.setFavorite(d, uid, on) then inventoryChanged(player) end
end

local function getInventory(player, ...)
	if not allowInventory(player) or not Remotes.checkArgs("GetInventory", ...) then return nil end
	local d = data(player)
	return d and Inventory.snapshot(d)
end

-- Manual scare: a short scripted crawl through the hole, a timing bar, the kid reacts, then back out to the aisle.
-- The character is anchored and moved by the server. The server times the tap itself; the client only says it tapped.
local function holeSpots(b)
	local P = PlotFrame.of(b)
	local hole = P:PointToObjectSpace(b.CrawlHole.Position)
	local floorY = P:PointToObjectSpace(b.RoomFloor.Position).Y + b.RoomFloor.Size.Y / 2
	local side = math.sign(hole.X)
	local inside = Vector3.new(hole.X + side * 3, floorY + 3, hole.Z)
	local outside = Vector3.new(hole.X - side * 4, floorY + 3, hole.Z)
	local bed = P:PointToObjectSpace(b.BedFrame.Position)
	return P * CFrame.lookAt(inside, Vector3.new(bed.X, inside.Y, bed.Z)), P * CFrame.lookAt(outside, Vector3.new(0, outside.Y, outside.Z))
end

local function runManual(player, b, session)
	local M = Config.Balance.manual
	local char, plot = player.Character, plotOf[player]
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local function alive()
		return manualSessions[player] == session and player.Parent == Players and player.Character == char and humanoid.Health > 0 and plotOf[player] == plot and b.Parent ~= nil
	end
	local inside, outside = holeSpots(b)
	root.Anchored = true
	cueRemote:FireClient(player, {phase = "crawl", seconds = M.crawlSeconds})
	task.wait(M.crawlSeconds)
	if alive() then
		char:PivotTo(inside)
		session.phase = "cue"
		session.cueStart = os.clock()
		cueRemote:FireClient(player, {phase = "cue", seconds = M.cueSeconds})
		while alive() and not session.tapAt and os.clock() - session.cueStart < M.cueSeconds do task.wait(0.03) end
		session.phase = "paying"
	end
	if alive() then
		local d = data(player)
		-- exactly one payout per session; leaving or dying before this point pays nothing
		local fraction = session.tapAt and math.clamp((session.tapAt - session.cueStart) / M.cueSeconds, 0, 1)
		local bonus, word = Payout.timing(fraction)
		local amount = Payout.manual(d.Rebirths, bonus)
		if pay(player, amount) then
			announcePayout(b, amount)
			cueRemote:FireClient(player, {phase = "done", word = word, amount = amount})
			playScare(b)
		end
	elseif player.Parent == Players then
		cueRemote:FireClient(player, {phase = "done"})
	end
	if b.Parent then
		if not b:FindFirstChild("Guest") then
			setBedroomTier(b, Config.pickBedroomTier(rng:NextNumber(0, 100)))
			showInfo(player, b)
			makeGuest(b.GuestSpot)
		end
	end
	if player.Character == char and char.Parent then
		if b.Parent and humanoid.Health > 0 then char:PivotTo(outside) end
		root.Anchored = false
	end
	reacting[b] = nil
	if manualSessions[player] == session then manualSessions[player] = nil end
end

local function manualScare(player, b)
	if not allowManual(player) or not ownedOrWarn(player, b) then return end
	local d = data(player)
	if not d or manualSessions[player] or not near(player, b.CrawlHole, b.CrawlHole.ScarePrompt.MaxActivationDistance) then return end
	if b:GetAttribute("Index") > Config.unlockedBedrooms(d.Rebirths) then return end
	if d.Placed[tostring(b:GetAttribute("Index"))] then
		popup(player, "A monster is working in this room. Scare a kid in an empty one!")
		return
	end
	if reacting[b] or not b:FindFirstChild("Guest") then
		popup(player, "This room is settling down, give it a moment")
		return
	end
	local waited = lastManual[player] and os.clock() - lastManual[player]
	if waited and waited < Config.MANUAL_COOLDOWN then
		popup(player, "Catch your breath: " .. math.ceil(Config.MANUAL_COOLDOWN - waited) .. "s")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then return end
	-- no yields from the checks above to here, so two prompts can't start two scares
	lastManual[player] = os.clock()
	local session = {bedroom = b, phase = "crawl"}
	manualSessions[player] = session
	reacting[b] = true
	-- runManual clears reacting when it finishes, however it ends
	task.spawn(runManual, player, b, session)
end

-- the client says it tapped; only the server's clock decides when, allowing for the player's connection
local function manualTap(player, ...)
	if not allowManual(player) or not Remotes.checkArgs("ManualTap", ...) then return end
	local session = manualSessions[player]
	if session and session.phase == "cue" and not session.tapAt then
		session.tapAt = os.clock() - math.min(player:GetNetworkPing(), 0.3)
	end
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
		if p:IsA("Model") and not claims.ownerOf[p] then plot = p break end
	end
	if not plot then
		popup(player, "All plots are taken: you are visiting. Your progress is safe.")
		return
	end
	claims:claim(plot, player)
	local frame = PlotFrame.of(plot)
	for _, child in ipairs(template:GetChildren()) do
		local copy = child:Clone()
		PlotFrame.place(copy, frame)
		copy.Parent = plot.Contents
	end
	local bedrooms = plot.Contents.Bedrooms
	for _, b in ipairs(bedrooms:GetChildren()) do
		addFactorsLine(b)
		setBedroomTier(b, Config.NORMAL_TIER)
		b.CrawlHole.ScarePrompt.ActionText = "Crawl In"
		b.CrawlHole.ScarePrompt.Triggered:Connect(function(p) manualScare(p, b) end)
		b.ShowcaseGlass.PlacePrompt.Triggered:Connect(function(p) useShowcase(p, b) end)
	end
	setLabel(plot.OwnerSign, player.DisplayName .. "'s Plot")
	refreshLocks(player)
	for key, uid in d.Placed do
		local b = bedrooms:FindFirstChild("Bedroom" .. key)
		if b and b:GetAttribute("Index") <= Config.unlockedBedrooms(d.Rebirths) then startRoom(player, b, uid) end
	end
	sendHome(player)
	popup(player, "This is your plot! Scare a kid through the crawl hole, then hatch an egg in the middle of the map.")
end

local function unclaim(leaving)
	for bedroom, work in working do
		if work.player == leaving then stopRoom(bedroom) end
	end
	local plot = claims:release(leaving)
	if not plot then return end
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
	if not Remotes.checkArgs("Rebirth", ...) then return false, "Bad request" end
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
	inventoryChanged(player)
	player.CharacterAdded:Connect(function()
		task.defer(syncTools, player)
		task.defer(sendHome, player)
	end)
	if profile.Unsaved then popup(player, "Studio test: progress will not be saved") end
	claim(player)
end

function GameService.Start()
	-- every live remote, created from the one list in Remotes
	local remotes = Remotes.createLive(Net)
	popupRemote = remotes.Popup
	rebirthRemote = remotes.Rebirth
	inventoryRemote = remotes.InventoryChanged
	cueRemote = remotes.ManualCue
	remotes.ManualTap.OnServerEvent:Connect(manualTap)
	rebirthRemote.OnServerInvoke = rebirth
	remotes.GetInventory.OnServerInvoke = getInventory
	remotes.HoldMonster.OnServerEvent:Connect(holdMonster)
	remotes.FavoriteMonster.OnServerEvent:Connect(favoriteMonster)

	-- the hub egg: odds generated from Config, shown before anyone spends
	local egg = hub.Egg
	egg.HatchPrompt.Triggered:Connect(hatch)
	egg.BillboardGui.Text.Text = Config.EGG_NAME .. " - " .. Config.EGG_COST .. " Fear"
	egg.HatchPrompt.ObjectText = Config.EGG_NAME
	local odds = hub.EggOdds:FindFirstChildWhichIsA("SurfaceGui")
	if odds then odds.Text.Text = "Odds\n" .. Config.oddsText() end
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:IsA("Model") then setLabel(plot.OwnerSign, "Free plot") end
	end
	PlayerData.OnLoaded(onLoaded)
	task.spawn(function()
		while true do
			task.wait(0.1)
			scheduler:tick(os.clock())
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastManual[player] = nil
		manualSessions[player] = nil
		unclaim(player)
	end)
end

return GameService
