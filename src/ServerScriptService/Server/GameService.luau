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
local MonsterRig = require(Shared:WaitForChild("MonsterRig"))
local Tutorial = require(Shared:WaitForChild("Tutorial"))
local PlotLayout = require(Shared:WaitForChild("PlotLayout"))
local Net = require(Shared:WaitForChild("Net"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local DataTemplate = require(script.Parent.DataTemplate)
local PlayerData = require(script.Parent.PlayerData)
local RateLimiter = require(script.Parent.RateLimiter)
local GuestKids = require(script.Parent.GuestKids)
local RoomStyles = require(script.Parent.RoomStyles)
local PlotFrame = require(script.Parent.PlotFrame)
local PlotClaims = require(script.Parent.PlotClaims)
local Premium = require(script.Parent.Premium)
local PlotFloors = require(script.Parent.PlotFloors)
local Fusion = require(script.Parent.Fusion)
local Rebirth = require(script.Parent.Rebirth)
local Shop = require(script.Parent.Shop)
local Tracker = require(script.Parent.Tracker)
local AccessoryLook = require(script.Parent.AccessoryLook)
local Inventory = require(script.Parent.Inventory)
local ScareScheduler = require(script.Parent.ScareScheduler)

local GameService = {}

local plotsFolder = workspace:WaitForChild("Plots")
local hub = workspace:WaitForChild("Hub")
local template = ServerStorage:WaitForChild("PlotTemplate")

local rng = Random.new()
local popupRemote, rebirthRemote, inventoryRemote, cueRemote, tutorialRemote, openCaseRemote, shopRemote, trackerRemote, revealRemote -- created in Start, from one list

local allowHatch = RateLimiter.new(Config.LIMITS.hatch.capacity, Config.LIMITS.hatch.refillPerSecond)
local allowShowcase = RateLimiter.new(Config.LIMITS.showcase.capacity, Config.LIMITS.showcase.refillPerSecond)
local allowRebirth = RateLimiter.new(Config.LIMITS.rebirth.capacity, Config.LIMITS.rebirth.refillPerSecond)
local allowSettings = RateLimiter.new(Config.LIMITS.settings.capacity, Config.LIMITS.settings.refillPerSecond)
local allowInventory = RateLimiter.new(Config.LIMITS.inventory.capacity, Config.LIMITS.inventory.refillPerSecond)
local allowManual = RateLimiter.new(Config.LIMITS.manual.capacity, Config.LIMITS.manual.refillPerSecond)
local allowItems = RateLimiter.new(Config.LIMITS.items.capacity, Config.LIMITS.items.refillPerSecond)

local claims = PlotClaims.new()
local plotOf = claims.plotOf -- [player] = plot Model
local lastManual = {} -- [player] = os.clock() of their last manual scare
local manualSessions = {} -- [player] = the manual scare in progress
local working = {} -- [bedroom] = {player, uid} for a monster doing automatic scares
local reacting = {} -- [bedroom] = true while its guest is reacting, so nothing else can scare it
local tutorialSent = {} -- [player] = what they were last told, so a repeat isn't sent
local lastHatch = {} -- [player] = the last hatch request and its answer, so a retry can't hatch twice
local lastRebirth = {} -- [player] = os.clock() of their last rebirth
local SIZE_SCALE = {}
for _, size in Config.Balance.fusion.sizes do SIZE_SCALE[size.id] = size.modelScale end

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
	local maxed = Config.unlockedBedrooms(d.Rebirths) >= Config.MAX_BEDROOMS
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
local function makeMonster(bedroom, tier, record)
	local scale = SIZE_SCALE[record.Size] or 1
	local spot = bedroom.MonsterSpot.CFrame * CFrame.new(0, 0.25, 0)
	local m, worker
	if record.Kind == Config.MONSTER_KIND then
		m = JeffRig.build(bedroom, spot, "JeffDisplay", scale)
		worker = JeffRig.build(m, roomOrigin(bedroom), "JeffRoom", scale)
	else
		m = MonsterRig.build(bedroom, spot, record.Kind, "PlaceholderDisplay", scale, Config.displayName(record.Kind))
		worker = MonsterRig.build(m, roomOrigin(bedroom), record.Kind, "PlaceholderRoom", scale)
	end
	worker.Name = "RoomWorker"
	local _, path = setScareRoute(bedroom, worker, tier.interval)
	if record.Kind == Config.MONSTER_KIND then JeffRig.idle(worker, path) else worker:PivotTo(CFrame.new(path[1])) end
	local h = Instance.new("Highlight") h.FillTransparency = 1 h.OutlineColor = tier.color h.Parent = m
	AccessoryLook.dressMonster(m, record.Mutation)
	return m
end

-- the kid's reaction at the moment Jeff pops up: it sits bolt upright, jumps and shakes with a "!", then runs off.
-- A room follows its owner's reduced-scares setting.
local function playScare(bedroom, player)
	local guest = bedroom:FindFirstChild("Guest")
	if guest and guest.Parent then
		local d = player and data(player)
		GuestKids.scare(guest, d and d.Settings.ReducedScares)
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
	local slot = tostring(bedroom:GetAttribute("Index"))
	local _, accessoryId = Payout.accessoryOf(d, slot)
	AccessoryLook.show(bedroom, accessoryId)
	local uid = d.Placed[slot]
	local monster = uid and d.Monsters[uid]
	local tier = monster and Config.TIER_BY_NAME[monster.Tier]
	if not tier then
		info.MonsterName.Text = "Empty"
		info.MonsterName.TextColor3 = Color3.new(1, 1, 1)
		info.Cash.Text = "Hold a monster and press E"
		info.Factors.Text = ""
	else
		local b = roomPayout(d, bedroom, monster)
		local extras = {}
		if monster.Size ~= "Normal" then table.insert(extras, monster.Size) end
		if monster.Mutation then table.insert(extras, monster.Mutation) end
		info.MonsterName.Text = Config.displayName(monster.Kind) .. " - " .. tier.name .. (if #extras > 0 then " (" .. table.concat(extras, ", ") .. ")" else "")
		info.MonsterName.TextColor3 = tier.color
		info.MonsterName.Font = Enum.Font.FredokaOne
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
			tool.Name = monster.Tier .. " " .. Config.displayName(monster.Kind)
			tool.CanBeDropped = false
			if monster.Kind == Config.MONSTER_KIND then JeffRig.buildMini(tool, 0.3) else MonsterRig.buildMini(tool, monster.Kind) end
			tool.ToolTip = "👻 " .. Config.short(monster.BaseFear) .. " / scare. Press E at your display case"
			tool:SetAttribute("Uid", uid)
			tool.Parent = backpack
			have[uid] = tool
		end
	end
	return have
end

-- what the tutorial points at for this step, on this player's own plot; nil for steps that point at the interface
local function tutorialTarget(player, d, id)
	if id == "egg" then return hub.Egg end
	if id == "box" then return workspace.Stations:FindFirstChild("ShopClaim") end
	local bedrooms = bedroomsOf(player)
	if not bedrooms then return nil end
	local unlocked = Config.unlockedBedrooms(d.Rebirths)
	for index = 1, unlocked do
		local b = bedrooms:FindFirstChild("Bedroom" .. index)
		local busy = d.Placed[tostring(index)] ~= nil
		if b then
			if id == "manual" and not busy then return b.CrawlHole end
			if id == "place" and not busy then return b.ShowcaseGlass end
			if id == "watch" and busy then return b.Window end
			if id == "equip" then return b.ShowcaseBase end
		end
	end
	return nil
end

local UI_TARGETS = {hold = "hotbar", open = "inventory"}

-- tells the client where the tutorial stands. Called after anything that could change it; the step comes from the save.
local function tutorialChanged(player)
	local d = data(player)
	if not d then return end
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local id = Tutorial.current(d, held ~= nil and held:GetAttribute("Uid") ~= nil)
	player:SetAttribute("PromiseEgg", Tutorial.canHatchPromiseEgg(d))
	if id then d.Tutorial.Step = Tutorial.indexOf(id) end
	local target = id and tutorialTarget(player, d, id)
	local key = tostring(id) .. ":" .. (target and target:GetFullName() or "")
	if tutorialSent[player] == key then return end
	tutorialSent[player] = key
	if not id then
		tutorialRemote:FireClient(player, {id = "none"})
		return
	end
	local text = Tutorial.STEPS[Tutorial.indexOf(id)].text
	if id == "done" then
		local slot = next(d.CaseAccessories)
		local mult = slot and Payout.accessoryOf(d, slot) or 1
		text = "Your case now pays x" .. mult .. " Fear! Next: hatch more eggs, rebirth for more rooms, and check back as the shop, fusion and trackers open."
	end
	tutorialRemote:FireClient(player, {
		id = id,
		index = Tutorial.indexOf(id),
		total = Tutorial.COUNT,
		text = text,
		target = target,
		position = target and target.Position,
		ui = UI_TARGETS[id],
	})
end

-- everything that changes the inventory ends here: the hotbar view, the client's panel and the tutorial all follow the save
local function inventoryChanged(player)
	syncTools(player)
	local d = data(player)
	if d then inventoryRemote:FireClient(player, Inventory.snapshot(d)) end
	tutorialChanged(player)
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
		b.ShowcaseBase.AccessoryPrompt.Enabled = open
		if open then
			makeGuest(b.GuestSpot)
			showInfo(player, b)
		end
	end
end

-- a scare has landed: the kid reacts, the room rerolls and a fresh kid gets into bed
local function resetRoom(player, bedroom)
	reacting[bedroom] = true
	playScare(bedroom, player)
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
		local roomJeff = monster and monster:FindFirstChild("RoomWorker")
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
		if not d.Tutorial.ScareSeen then
			d.Tutorial.ScareSeen = true
			tutorialChanged(work.player)
		end
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
	makeMonster(bedroom, tier, record)
	bedroom.ShowcaseGlass.PlacePrompt.ActionText = "Pick Up"
	working[bedroom] = {player = player, uid = uid, tier = record.Tier}
	scheduler:add(bedroom, tier.interval, os.clock())
	showInfo(player, bedroom)
end

-- what hatches from an egg of this rarity: the stand-in with a payout rolled in the band, or, once the roster is on, a species
-- at its own listed payout. TestRoster is a Studio-only preview, and IsStudio is false on real servers.
local function rollMonster(tier)
	local rosterOn = Config.Balance.content.hatchRoster
		or (game:GetService("RunService"):IsStudio() and ServerStorage:GetAttribute("TestRoster") == true)
	if rosterOn then
		local species = Config.pickSpecies(tier.name, rng:NextNumber())
		return species.id, species.baseFear
	end
	return Config.MONSTER_KIND, rng:NextInteger(tier.min, tier.max)
end

-- the egg shrine's panel asks for this. Returns true and the result, or false and a reason for the player.
local function hatchEgg(player, ...)
	if not allowHatch(player) then return false, "Slow down!" end
	if not Remotes.checkArgs("HatchEgg", ...) then return false, "Bad request" end
	local eggId, requestId = ...
	local last = lastHatch[player]
	if last and last.requestId == requestId then return true, last.result end -- a retry of a hatch that already happened
	local d = data(player)
	if not d then return false, "Still loading" end
	local egg = Config.EGGS[eggId]
	if not egg then return false, "Bad request" end
	local promise = egg.source == "tutorial"
	if promise then
		if not Tutorial.canHatchPromiseEgg(d) then return false, "Not available" end
	elseif egg.source ~= "fear" or not egg.live then
		return false, "Not available"
	end
	if Inventory.isFull(d) then return false, "Inventory is full (" .. Config.INVENTORY_CAP .. ")" end
	if not promise and d.Fear < egg.price then return false, "Need " .. Config.short(egg.price) .. " Fear" end
	-- no yields from the checks above to here, so a double request cannot spend once and hatch twice
	local tier = Config.pickFromEgg(eggId, rng:NextNumber(0, 100))
	local kind, baseFear = rollMonster(tier)
	-- the tutorial's egg never mutates, so it can't surprise a new player
	local mutation = if promise then nil else Config.pickMutation(rng:NextNumber(0, 100))
	-- a test helper set from the command bar; IsStudio is false on real servers
	local forced = game:GetService("RunService"):IsStudio() and ServerStorage:GetAttribute("TestForceMutation")
	if type(forced) == "string" and not promise then mutation = forced end
	Inventory.add(d, DataTemplate.newMonster(kind, tier.name, baseFear, promise and "tutorial" or "egg", mutation))
	if promise then
		d.Tutorial.EggUsed = true
	else
		setFear(player, d, d.Fear - egg.price)
	end
	inventoryChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	local result = {kind = Config.displayName(kind), tier = tier.name, baseFear = baseFear, mutation = mutation}
	lastHatch[player] = {requestId = requestId, result = result}
	return true, result
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
			d.Tutorial.ManualDone = true
			tutorialChanged(player)
			cueRemote:FireClient(player, {phase = "done", word = word, amount = amount})
			playScare(b, player)
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

-- settings: only these keys, and clients get them back as attributes
local function publishSettings(player, d)
	player:SetAttribute("ReducedScares", d.Settings.ReducedScares)
	player:SetAttribute("MusicVolume", d.Settings.MusicVolume)
	player:SetAttribute("SfxVolume", d.Settings.SfxVolume)
end

local function setSetting(player, ...)
	if not allowSettings(player) or not Remotes.checkArgs("SetSetting", ...) then return end
	local d = data(player)
	local key, on = ...
	if d and key == "ReducedScares" then
		d.Settings.ReducedScares = on
		publishSettings(player, d)
	end
end

local function setVolume(player, ...)
	if not allowSettings(player) or not Remotes.checkArgs("SetVolume", ...) then return end
	local d = data(player)
	local key, value = ...
	if d and (key == "MusicVolume" or key == "SfxVolume") then
		d.Settings[key] = math.clamp(value, 0, 1)
		publishSettings(player, d)
	end
end

-- the client names the monsters; the server checks everything again and makes the new one, or changes nothing
local function fuseMonsters(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("FuseMonsters", ...) then return false, "missing" end
	local d = data(player)
	if not d then return false, "missing" end
	local uids = ...
	local uid, why = Fusion.fuse(d, uids)
	if not uid then return false, why end
	inventoryChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	return true
end

-- the stall's prompt opens the shop on the client; the first visit also gives the free box, once ever
local function claimFreeBox(player)
	if not allowItems(player) then return end
	local d = data(player)
	local spot = workspace.Stations:FindFirstChild("ShopClaim")
	if not d or not spot or not near(player, spot, spot.ShopPrompt.MaxActivationDistance) then return end
	if not Inventory.claimFreeBox(d) then return end
	inventoryChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	popup(player, "Free Rare box! Open it in your Inventory, under Items.")
end

local function getShop(player, ...)
	if not allowInventory(player) or not Remotes.checkArgs("GetShop", ...) then return nil end
	local d = data(player)
	return d and Shop.stateFor(d, os.time())
end

-- the client names an item and the rotation it was looking at; the price, stock and item all come from the server
local function buyShopItem(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("BuyShopItem", ...) then return false, "unavailable" end
	local d = data(player)
	if not d then return false, "unavailable" end
	local itemId, rotation = ...
	local ok, why = Shop.buy(d, itemId, rotation, os.time())
	if ok then
		setFear(player, d, d.Fear)
		inventoryChanged(player)
		task.spawn(PlayerData.SaveNowAsync, player)
	end
	return ok, why, Shop.stateFor(d, os.time())
end

-- Trackers. The server picks and keeps the spot, and only tells that player where it is.
local function digNodes()
	local folder = workspace:FindFirstChild("DigNodes")
	return folder and folder:GetChildren() or {}
end

local function nodeNamed(name)
	local folder = workspace:FindFirstChild("DigNodes")
	return folder and name and folder:FindFirstChild(name)
end

local function trackerChanged(player)
	local d = data(player)
	if not d then return end
	if Tracker.tidy(d, function(name) return nodeNamed(name) ~= nil end, os.time()) then
		popup(player, "Your tracker's trail went cold. It's back in your Items.")
		inventoryChanged(player)
	end
	local uid, active = Tracker.active(d)
	local node = active and nodeNamed(active.Node)
	trackerRemote:FireClient(player, node and {uid = uid, position = node.Position, expiresAt = active.ExpiresAt} or {})
end

local function activateTracker(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("ActivateTracker", ...) then return false end
	local d = data(player)
	local uid = ...
	if not d then return false end
	local names = {}
	for _, node in digNodes() do table.insert(names, node.Name) end
	table.sort(names)
	local ok, why = Tracker.activate(d, uid, names, rng:NextNumber(0, 1), os.time())
	if not ok then
		popup(player, why == "busy" and "You're already following a tracker" or "That tracker can't be used right now")
		return false
	end
	inventoryChanged(player)
	trackerChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	return true
end

-- the server checks it's this player's own dig, and that they're really standing at the spot
local function digEgg(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("Dig", ...) then return false end
	local d = data(player)
	local uid = ...
	local t = d and d.Trackers[uid]
	local node = t and nodeNamed(t.Node)
	if not node or not near(player, node, Config.Balance.trackers.digDistance) then return false end
	if not Tracker.dig(d, uid, os.time()) then return false end
	inventoryChanged(player)
	trackerChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	popup(player, "You dug up a Buried Moon Egg! Hatch it in your Inventory, under Items.")
	return true
end

-- hatches an egg you already own. The egg is used up and the monster added together.
local function hatchOwnedEgg(player, ...)
	if not allowHatch(player) or not Remotes.checkArgs("HatchOwnedEgg", ...) then return false end
	local d = data(player)
	local uid = ...
	local eggId = d and d.Eggs[uid]
	if not eggId then return false end
	if Inventory.isFull(d) then
		popup(player, "Your inventory is full (" .. Config.INVENTORY_CAP .. ")")
		return false
	end
	local tier = Config.pickFromEgg(eggId, rng:NextNumber(0, 100))
	local kind, baseFear = rollMonster(tier)
	d.Eggs[uid] = nil
	Inventory.add(d, DataTemplate.newMonster(kind, tier.name, baseFear, "dig"))
	inventoryChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	revealRemote:FireClient(player, {kind = Config.displayName(kind), tier = tier.name, baseFear = baseFear})
	return true
end

local function openBox(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("OpenBox", ...) then return false end
	local d = data(player)
	local boxUid = ...
	if not d then return false end
	local uid, id = Inventory.openBox(d, boxUid, rng:NextNumber(0, 100))
	if not uid then return false end
	inventoryChanged(player)
	task.spawn(PlayerData.SaveNowAsync, player)
	return true, {id = id, mult = Config.ACCESSORY_MULT[id]}
end

-- equip and remove: the client names a bedroom, the server checks it's theirs and that they're at it
local function ownCase(player, d, slot)
	local bedrooms = bedroomsOf(player)
	local b = bedrooms and bedrooms:FindFirstChild("Bedroom" .. slot)
	if not b or not near(player, b.ShowcaseBase, 30) then return nil end
	return b
end

local function equipAccessory(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("EquipAccessory", ...) then return false end
	local d = data(player)
	local slot, uid = ...
	local b = d and ownCase(player, d, slot)
	if not b or not Inventory.equip(d, b:GetAttribute("Index"), uid, Config.unlockedBedrooms(d.Rebirths)) then return false end
	showInfo(player, b)
	inventoryChanged(player)
	return true
end

local function unequipAccessory(player, ...)
	if not allowItems(player) or not Remotes.checkArgs("UnequipAccessory", ...) then return false end
	local d = data(player)
	local slot = ...
	local b = d and ownCase(player, d, slot)
	if not b or not Inventory.unequip(d, b:GetAttribute("Index")) then return false end
	showInfo(player, b)
	inventoryChanged(player)
	return true
end

-- the case's Accessory prompt opens the panel on that case
local function useAccessoryPrompt(player, b)
	if not allowItems(player) or not ownedOrWarn(player, b) then return end
	if not near(player, b.ShowcaseBase, b.ShowcaseBase.AccessoryPrompt.MaxActivationDistance) then return end
	openCaseRemote:FireClient(player, tostring(b:GetAttribute("Index")))
end

-- everything a bedroom copy needs once it's on a plot
local function setupBedroom(b)
	addFactorsLine(b)
	setBedroomTier(b, Config.NORMAL_TIER)
	b.CrawlHole.ScarePrompt.ActionText = "Crawl In"
	b.CrawlHole.ScarePrompt.Triggered:Connect(function(p) manualScare(p, b) end)
	local accessoryPrompt = Instance.new("ProximityPrompt")
	accessoryPrompt.Name = "AccessoryPrompt"
	accessoryPrompt.ActionText = "Accessory"
	accessoryPrompt.KeyboardKeyCode = Enum.KeyCode.F
	accessoryPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	accessoryPrompt.MaxActivationDistance = 10
	accessoryPrompt.RequiresLineOfSight = false
	accessoryPrompt.UIOffset = Vector2.new(0, 70)
	accessoryPrompt.Triggered:Connect(function(p) useAccessoryPrompt(p, b) end)
	accessoryPrompt.Parent = b.ShowcaseBase
	b.ShowcaseGlass.PlacePrompt.Triggered:Connect(function(p) useShowcase(p, b) end)
end

-- lift pads carry anyone, so visitors can tour upper floors too
local function connectLift(pad, destination)
	pad.LiftPrompt.Triggered:Connect(function(p)
		if not allowItems(p) or not near(p, pad, pad.LiftPrompt.MaxActivationDistance) then return end
		if p.Character then p.Character:PivotTo(destination.CFrame + Vector3.new(0, 4, 0)) end
	end)
end

-- builds any floors this player has reached that aren't on their plot yet: a deck and six more bedrooms, numbered on from the last
local function buildFloors(player)
	local d = data(player)
	local plot = plotOf[player]
	if not d or not plot then return end
	local bedrooms = plot.Contents.Bedrooms
	local frame = PlotFrame.of(plot)
	for floor = 2, PlotLayout.floorsVisible(Config.unlockedBedrooms(d.Rebirths)) do
		if not plot.Contents:FindFirstChild("Floor" .. floor) then
			local _, up, down = PlotFloors.build(plot.Contents, floor, frame)
			connectLift(up, down)
			connectLift(down, up)
			local lifted = frame * CFrame.new(0, PlotLayout.floorHeight(floor), 0)
			for _, source in ipairs(template.Bedrooms:GetChildren()) do
				local copy = source:Clone()
				local index = PlotLayout.bedroomIndex(floor, source:GetAttribute("Index"))
				copy.Name = "Bedroom" .. index
				copy:SetAttribute("Index", index)
				PlotFrame.place(copy, lifted)
				copy.Parent = bedrooms
				setupBedroom(copy)
			end
		end
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
	for _, b in ipairs(bedrooms:GetChildren()) do setupBedroom(b) end
	buildFloors(player)
	setLabel(plot.OwnerSign, player.DisplayName .. "'s Plot")
	refreshLocks(player)
	for key, uid in d.Placed do
		local b = bedrooms:FindFirstChild("Bedroom" .. key)
		if b and b:GetAttribute("Index") <= Config.unlockedBedrooms(d.Rebirths) then startRoom(player, b, uid) end
	end
	sendHome(player)
	tutorialChanged(player)
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
	local rooms = Config.unlockedBedrooms(d.Rebirths)
	-- no yields from the check to the change, so parallel requests cannot rebirth twice for one price
	local ok, why, cost = Rebirth.apply(d, lastRebirth[player], os.clock())
	if not ok then
		if why == "maxed" then return false, "All bedrooms unlocked" end
		if why == "cooldown" then return false, "Slow down!" end
		return false, "Need " .. Config.short(cost) .. " Fear"
	end
	lastRebirth[player] = os.clock()
	setFear(player, d, d.Fear)
	publishRebirth(player, d)
	buildFloors(player)
	refreshLocks(player)
	inventoryChanged(player)
	local newFloor = PlotLayout.floorsVisible(Config.unlockedBedrooms(d.Rebirths)) > PlotLayout.floorsVisible(rooms)
	task.spawn(PlayerData.SaveNowAsync, player)
	return true, "Rebirth! New bedroom" .. (newFloor and " and a new floor" or "") .. " unlocked, x" .. Config.rebirthMult(d.Rebirths) .. " Fear"
end

local function onLoaded(profile)
	local player, d = profile.Player, profile.Data
	-- test helpers, set from the Studio command bar. IsStudio is false on real servers, so they can't reach real saves.
	if game:GetService("RunService"):IsStudio() then
		local fear = ServerStorage:GetAttribute("TestGrantFear")
		if type(fear) == "number" then d.Fear = math.clamp(math.floor(fear), 0, Config.MAX_FEAR) end
		if ServerStorage:GetAttribute("TestGrantTracker") == true then Tracker.add(d) end
	end
	local ls = Instance.new("Folder") ls.Name = "leaderstats"
	local fear = Instance.new("IntValue") fear.Name = "Fear" fear.Value = d.Fear fear.Parent = ls -- numeric stat first
	local rb = Instance.new("IntValue") rb.Name = "Rebirths" rb.Parent = ls
	ls.Parent = player
	publishRebirth(player, d)
	inventoryChanged(player)
	-- the tutorial's "hold" step moves on when a monster is really in the player's hand
	local function watchHand(char)
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then task.defer(tutorialChanged, player) end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then task.defer(tutorialChanged, player) end
		end)
	end
	if player.Character then watchHand(player.Character) end
	player.CharacterAdded:Connect(function(char)
		watchHand(char)
		task.defer(syncTools, player)
		task.defer(sendHome, player)
		task.defer(tutorialChanged, player)
	end)
	publishSettings(player, d)
	trackerChanged(player) -- resume a dig in progress at the same spot
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
	tutorialRemote = remotes.TutorialStep
	openCaseRemote = remotes.OpenCase
	shopRemote = remotes.ShopChanged
	trackerRemote = remotes.TrackerState
	revealRemote = remotes.HatchReveal
	remotes.GetShop.OnServerInvoke = getShop
	remotes.BuyShopItem.OnServerInvoke = buyShopItem
	remotes.ActivateTracker.OnServerInvoke = activateTracker
	remotes.Dig.OnServerInvoke = digEgg
	remotes.HatchOwnedEgg.OnServerInvoke = hatchOwnedEgg
	remotes.FuseMonsters.OnServerInvoke = fuseMonsters
	remotes.SetSetting.OnServerEvent:Connect(setSetting)
	remotes.SetVolume.OnServerEvent:Connect(setVolume)
	-- only when real products exist. The purchase counts only once the save has written, so Roblox retries otherwise, and
	-- a retry can't grant twice.
	if Premium.configured() then
		game:GetService("MarketplaceService").ProcessReceipt = function(info)
			local player = Players:GetPlayerByUserId(info.PlayerId)
			local d = player and data(player)
			if not d then return Enum.ProductPurchaseDecision.NotProcessedYet end
			local outcome = Premium.grant(d, info.PurchaseId, Premium.product(info.ProductId))
			if outcome == "unknown" then return Enum.ProductPurchaseDecision.NotProcessedYet end
			setFear(player, d, d.Fear)
			if not PlayerData.SaveNowAsync(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end
	remotes.HatchEgg.OnServerInvoke = hatchEgg
	remotes.OpenBox.OnServerInvoke = openBox
	remotes.EquipAccessory.OnServerInvoke = equipAccessory
	remotes.UnequipAccessory.OnServerInvoke = unequipAccessory
	remotes.TutorialDone.OnServerEvent:Connect(function(player, ...)
		local d = data(player)
		if d and Remotes.checkArgs("TutorialDone", ...) and Tutorial.current(d, false) == "done" then
			d.Tutorial.Complete = true
			tutorialChanged(player)
			task.spawn(PlayerData.SaveNowAsync, player)
		end
	end)
	remotes.ManualTap.OnServerEvent:Connect(manualTap)
	rebirthRemote.OnServerInvoke = rebirth
	remotes.GetInventory.OnServerInvoke = getInventory
	remotes.HoldMonster.OnServerEvent:Connect(holdMonster)
	remotes.FavoriteMonster.OnServerEvent:Connect(favoriteMonster)

	-- the hub egg: odds generated from Config, shown before anyone spends
	local egg = hub.Egg
	-- the prompt opens the egg panel on the client, which shows every egg's odds before anyone spends
	egg.HatchPrompt.ActionText = "Open Eggs"
	local shopClaim = workspace:WaitForChild("Stations"):WaitForChild("ShopClaim")
	shopClaim.ShopPrompt.Triggered:Connect(claimFreeBox)
	setLabel(hub.ShopSign, "Shop")
	-- the shop's prompt is also how the tutorial's free box is claimed
	egg.BillboardGui.Text.Text = "Egg Shrine"
	egg.HatchPrompt.ObjectText = "Egg Shrine"
	local odds = hub.EggOdds:FindFirstChildWhichIsA("SurfaceGui")
	if odds then odds.Text.Text = Config.EGG_NAME .. "\n" .. Config.EGG_COST .. " Fear\n" .. Config.oddsText() end
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
	-- tells clients when new stock arrives, and retires abandoned digs
	task.spawn(function()
		local rotation = Shop.rotationAt(os.time())
		local sinceTidy = 0
		while true do
			task.wait(1)
			local now = Shop.rotationAt(os.time())
			if now ~= rotation then
				rotation = now
				shopRemote:FireAllClients()
			end
			sinceTidy += 1
			if sinceTidy >= 15 then
				sinceTidy = 0
				for _, player in ipairs(Players:GetPlayers()) do
					local d = data(player)
					if d and Tracker.active(d) then trackerChanged(player) end
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastManual[player] = nil
		manualSessions[player] = nil
		tutorialSent[player] = nil
		lastRebirth[player] = nil
		lastHatch[player] = nil
		unclaim(player)
	end)
end

return GameService
