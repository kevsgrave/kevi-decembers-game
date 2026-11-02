-- The tutorial, eggs, boxes and accessories, tested on throwaway save tables. Touches nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.TutorialTests)())
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")

local CONFIG_PATH = 'require%(game:GetService%("ReplicatedStorage"%):WaitForChild%("Shared"%):WaitForChild%("Config"%)%)'

return function(): string
	local lines, failed = {}, 0
	local function check(name: string, ok: boolean, detail: string?)
		if not ok then failed += 1 end
		table.insert(lines, `{if ok then "PASS" else "FAIL"}  {name}{if detail then " -> " .. detail else ""}`)
	end

	local server = ServerScriptService.Server:Clone()
	ReplicatedStorage.Shared:Clone().Parent = server
	for _, name in {"DataTemplate", "Inventory"} do
		server[name].Source = server[name].Source:gsub(CONFIG_PATH, "require(script.Parent.Shared.Config)")
	end
	local Config = require(server.Shared.Config)
	local Payout = require(server.Shared.Payout)
	local DataTemplate = require(server.DataTemplate)
	local Inventory = require(server.Inventory)
	local Tutorial = require(server.Shared.Tutorial)

	-- a save and rejoin: through JSON like the data store, then the load path
	local function rejoin(d)
		local loaded, why = DataTemplate.prepare(HttpService:JSONDecode(HttpService:JSONEncode(d)))
		assert(loaded, why)
		return loaded
	end

	-- each real action, as GameService does it
	local actions = {
		manual = function(d) d.Tutorial.ManualDone = true d.Fear += 100 end,
		egg = function(d)
			assert(Tutorial.canHatchPromiseEgg(d), "promise egg should be available")
			d.Tutorial.EggUsed = true
			return Inventory.add(d, DataTemplate.newMonster("Jeff", "Epic", 900, "tutorial"))
		end,
		place = function(d) return Inventory.place(d, 1, next(d.Monsters), 3) end,
		watch = function(d) d.Tutorial.ScareSeen = true end,
		box = function(d) return Inventory.claimFreeBox(d) end,
		open = function(d) return Inventory.openBox(d, next(d.Boxes), 0) end,
		equip = function(d) return Inventory.equip(d, 1, next(d.Accessories), 3) end,
	}

	-- start to finish, in order
	local d = DataTemplate.new()
	local order = {"manual", "egg", "hold", "place", "watch", "box", "open", "equip", "done"}
	check("a new player starts at the crawl-hole scare, with no claim step", Tutorial.current(d, false) == "manual")
	local inOrder = true
	for _, id in order do
		local holding = id == "place"
		if Tutorial.current(d, holding) ~= id then inOrder = false end
		if actions[id] then actions[id](d) end
	end
	check("the steps run in order to the finish", inOrder)
	d.Tutorial.Complete = true
	check("finished means no more steps", Tutorial.current(d, false) == nil)

	-- disconnect after every action: a save and rejoin must land on the next step, with nothing lost or granted twice
	d = DataTemplate.new()
	local resumed = true
	local rows = {}
	for _, id in order do
		local holding = id == "place"
		d = rejoin(d)
		if Tutorial.current(d, holding) ~= id then
			resumed = false
			table.insert(rows, id .. " became " .. tostring(Tutorial.current(d, holding)))
		end
		if actions[id] then actions[id](d) end
		d = rejoin(d)
	end
	check("rejoining at every step resumes the same step", resumed, table.concat(rows, ", "))
	local monsters, accessories, boxes = 0, 0, 0
	for _ in d.Monsters do monsters += 1 end
	for _ in d.Accessories do accessories += 1 end
	for _ in d.Boxes do boxes += 1 end
	check("the whole run grants one monster, one accessory and no leftover box", monsters == 1 and accessories == 1 and boxes == 0)

	-- holding depends on the moment, not the save
	local holdCheck = DataTemplate.new()
	actions.manual(holdCheck) actions.egg(holdCheck)
	check("not holding asks you to hold", Tutorial.current(holdCheck, false) == "hold")
	check("holding asks you to place", Tutorial.current(holdCheck, true) == "place")

	-- going backward can't get stuck
	local back = DataTemplate.new()
	actions.manual(back) actions.egg(back) actions.place(back)
	check("watching with a monster placed", Tutorial.current(back, false) == "watch")
	Inventory.pickUp(back, 1)
	check("picking it up before a scare goes back a step, not stuck", Tutorial.current(back, false) == "hold")
	Inventory.place(back, 2, next(back.Monsters), 3)
	check("placing again carries on", Tutorial.current(back, false) == "watch")

	-- rewards are once only
	local once = DataTemplate.new()
	actions.manual(once)
	check("promise egg available at its step", Tutorial.canHatchPromiseEgg(once))
	actions.egg(once)
	check("promise egg can't be hatched twice", not Tutorial.canHatchPromiseEgg(once))
	check("promise egg isn't offered before the scare", not Tutorial.canHatchPromiseEgg(DataTemplate.new()))
	local claimed = DataTemplate.new()
	check("free box claims once", Inventory.claimFreeBox(claimed) ~= nil)
	check("a second claim gets nothing", Inventory.claimFreeBox(claimed) == nil)
	local count = 0
	for _ in claimed.Boxes do count += 1 end
	check("exactly one box", count == 1)
	check("a rejoin can't claim again", Inventory.claimFreeBox(rejoin(claimed)) == nil)

	-- older saves
	local old = DataTemplate.prepare({SchemaVersion = 3, Fear = 900, Rebirths = 0, NextUid = 2, TotalFearEarned = 100, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare", BaseFear = 300}}, Placed = {["1"] = "m1"}, Hotbar = {}})
	check("an older save with a placed monster joins at watching", old ~= nil and Tutorial.current(old, false) == "watch")
	check("an older save with a monster gets no promise egg", not Tutorial.canHatchPromiseEgg(old))

	-- egg odds, exact at the edges
	check("promise egg is exactly 80/20", Config.pickFromEgg("TutorialEgg", 0).name == "Epic" and Config.pickFromEgg("TutorialEgg", 79.999).name == "Epic" and Config.pickFromEgg("TutorialEgg", 80).name == "Legendary" and Config.pickFromEgg("TutorialEgg", 99.999).name == "Legendary")
	local rng = Random.new(5)
	local epics, rolls = 0, 200000
	for _ = 1, rolls do
		if Config.pickFromEgg("TutorialEgg", rng:NextNumber(0, 100)).name == "Epic" then epics += 1 end
	end
	check("200,000 promise eggs come out near 80% Epic", math.abs(epics / rolls - 0.8) < 0.005, string.format("%.2f%%", epics / rolls * 100))
	for _, egg in Config.Balance.eggs do
		local seen = {}
		for r = 0, 99.99, 0.01 do seen[Config.pickFromEgg(egg.id, r).name] = true end
		local matches = true
		for name in seen do
			if not egg.odds[name] then matches = false end
		end
		for name, chance in egg.odds do
			if chance >= 0.1 and not seen[name] then matches = false end
		end
		check(`{egg.id} only rolls what it discloses`, matches)
	end
	check("five Fear eggs are on sale", (function()
		local n = 0
		for _, egg in Config.Balance.eggs do
			if egg.source == "fear" and egg.live then n += 1 end
		end
		return n == 5
	end)())

	-- boxes and accessories
	local inv = DataTemplate.new()
	local box = Inventory.addBox(inv, "RareBox")
	local accessoryUid, accessoryId = Inventory.openBox(inv, box, 0)
	check("opening a box gives its first item at a roll of 0", accessoryId == Config.BOX_ITEMS.RareBox[1].id and inv.Accessories[accessoryUid] == accessoryId)
	check("the box is used up", inv.Boxes[box] == nil)
	check("a box can't be opened twice", Inventory.openBox(inv, box, 0) == nil)
	local boxLast = Inventory.addBox(inv, "RareBox")
	local _, lastId = Inventory.openBox(inv, boxLast, 99.999)
	check("the top of the roll gives its last item", lastId == Config.BOX_ITEMS.RareBox[#Config.BOX_ITEMS.RareBox].id)
	check("a locked case refuses an accessory", not Inventory.equip(inv, 4, accessoryUid, 3))
	check("an accessory you don't own is refused", not Inventory.equip(inv, 1, "a999", 3))
	check("equip on an open case", Inventory.equip(inv, 1, accessoryUid, 3) == true and inv.CaseAccessories["1"] == accessoryUid)
	check("one accessory can't be on two cases", not Inventory.equip(inv, 2, accessoryUid, 3) and inv.CaseAccessories["2"] == nil)
	local second = next(inv.Accessories)
	if second == accessoryUid then
		for uid in inv.Accessories do
			if uid ~= accessoryUid then second = uid end
		end
	end
	check("a case holds one accessory: a new one swaps, losing nothing", Inventory.equip(inv, 1, second, 3) == true and inv.CaseAccessories["1"] == second and inv.Accessories[accessoryUid] ~= nil)
	check("removing frees the case and keeps the accessory", Inventory.unequip(inv, 1) == true and inv.CaseAccessories["1"] == nil and inv.Accessories[second] ~= nil)
	check("removing from an empty case does nothing", Inventory.unequip(inv, 1) == false)

	-- the equipped accessory raises the real payout
	Inventory.equip(inv, 1, accessoryUid, 3)
	local mult = (Payout.accessoryOf(inv, "1"))
	local monster = DataTemplate.newMonster("Jeff", "Epic", 1000, "tutorial")
	check("the accessory raises the case's payout", mult > 1 and Payout.scare(monster, 1, 0, mult).total == math.round(1000 * mult) and Payout.scare(monster, 1, 0, 1).total == 1000)
	local snap = Inventory.snapshot(inv)
	check("the panel lists accessories, where they are, and the index", #snap.accessories == 2 and #snap.boxes == 0 and snap.index ~= nil)
	local back2 = rejoin(inv)
	check("accessories and cases survive a rejoin", back2.CaseAccessories["1"] == accessoryUid and back2.Accessories[accessoryUid] == accessoryId)
	local repaired = DataTemplate.prepare({SchemaVersion = 3, Fear = 1, Rebirths = 0, NextUid = 3, TotalFearEarned = 0, Monsters = {}, Placed = {}, Hotbar = {}, Accessories = {a1 = "BoneCharm"}, CaseAccessories = {["1"] = "a1", ["2"] = "a1", ["3"] = "gone"}})
	local cases = 0
	for _ in repaired.CaseAccessories do cases += 1 end
	check("an accessory on two cases, or a missing one, is repaired on load", cases == 1 and repaired.Accessories.a1 == "BoneCharm")

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
