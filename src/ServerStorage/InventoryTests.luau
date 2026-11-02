-- Save and inventory rules, tested on throwaway tables. Touches no real save and changes nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.InventoryTests)())
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

	-- copies pointed at a fresh Shared, so a session that already required the old modules still tests the current source
	local server = ServerScriptService.Server:Clone()
	ReplicatedStorage.Shared:Clone().Parent = server
	for _, name in {"DataTemplate", "Inventory"} do
		server[name].Source = server[name].Source:gsub(CONFIG_PATH, "require(script.Parent.Shared.Config)")
	end
	local Config = require(server.Shared.Config)
	local DataTemplate = require(server.DataTemplate)
	local Inventory = require(server.Inventory)

	local function fresh()
		local d = DataTemplate.new()
		return d
	end
	local function monster(tier, fear)
		return DataTemplate.newMonster("Jeff", tier or "Rare", fear or 300, "egg")
	end
	-- a save and rejoin: through JSON like the data store, then the load path
	local function rejoin(d)
		local loaded, why = DataTemplate.prepare(HttpService:JSONDecode(HttpService:JSONEncode(d)))
		assert(loaded, why)
		return loaded
	end
	local function total(d)
		return Inventory.count(d)
	end

	-- unique instances with stable payouts
	local d = fresh()
	local a = Inventory.add(d, monster("Rare", 300))
	local b = Inventory.add(d, monster("Rare", 700))
	check("two copies of a species are distinct", a ~= b and d.Monsters[a].BaseFear == 300 and d.Monsters[b].BaseFear == 700)
	check("hatching records the species", d.Index.Jeff == true)
	check("a new monster is on the hotbar", d.Hotbar[1] == a and d.Hotbar[2] == b)

	-- placing and the ways it can fail
	local ok, why = Inventory.place(d, 1, a, 3)
	check("place in an open room", ok and d.Placed["1"] == a)
	check("placing leaves the hotbar", table.find(d.Hotbar, a) == nil)
	ok, why = Inventory.place(d, 1, b, 3)
	check("an occupied case refuses", not ok and why == "occupied" and d.Placed["1"] == a)
	ok, why = Inventory.place(d, 2, a, 3)
	check("the same monster can't be in two rooms", not ok and why == "deployed" and d.Placed["2"] == nil)
	ok, why = Inventory.place(d, 4, b, 3)
	check("a locked room refuses", not ok and why == "locked" and d.Placed["4"] == nil)
	ok, why = Inventory.place(d, 2, nil, 3)
	check("nothing held refuses", not ok and why == "missing")
	ok, why = Inventory.place(d, 2, "m999", 3)
	check("a uid you don't own refuses", not ok and why == "missing")

	-- two requests at once for one monster
	local other = Inventory.add(d, monster())
	local first = Inventory.place(d, 2, other, 3)
	local second = Inventory.place(d, 3, other, 3)
	check("of two requests for one monster, only the first wins", first == true and second == false and d.Placed["3"] == nil)

	-- picking up and moving
	check("pick up returns the monster", Inventory.pickUp(d, 1) == a and d.Placed["1"] == nil and table.find(d.Hotbar, a) ~= nil)
	check("picking up twice does nothing", Inventory.pickUp(d, 1) == nil)
	check("the monster can move to another room", Inventory.place(d, 3, a, 3) == true and d.Placed["3"] == a)
	check("moving doesn't change how many you own", total(d) == 3 and d.Monsters[a].BaseFear == 300)
	local unlockedLater = Inventory.place(d, 4, b, 4)
	check("a room opens once unlocked", unlockedLater == true)

	-- someone else's save
	local visitor = fresh()
	local mine = Inventory.add(d, monster())
	ok, why = Inventory.place(visitor, 1, mine, 3)
	check("another player's monster isn't yours to place", not ok and why == "missing" and visitor.Placed["1"] == nil)
	check("another player's monster can't go on your hotbar", Inventory.putOnHotbar(visitor, mine) == false)
	check("another player's monster can't be favorited by you", Inventory.setFavorite(visitor, mine, true) == false)

	-- hotbar is a limited view, never the inventory
	local big = fresh()
	for _ = 1, 20 do Inventory.add(big, monster()) end
	check("hotbar stops at its limit", #big.Hotbar == Config.HOTBAR_SLOTS)
	check("the inventory keeps them all", total(big) == 20)
	check("a stored monster can be brought to the hotbar", Inventory.putOnHotbar(big, "m20") and table.find(big.Hotbar, "m20") ~= nil and #big.Hotbar == Config.HOTBAR_SLOTS)
	check("the hotbar swap loses nothing", total(big) == 20)
	Inventory.place(big, 1, "m20", 3)
	check("a placed monster can't be put on the hotbar", Inventory.putOnHotbar(big, "m20") == false)
	Inventory.putOnHotbar(big, "m15") -- fills the slot that placing freed
	check("picking up with a full hotbar loses nothing", #big.Hotbar == Config.HOTBAR_SLOTS and Inventory.pickUp(big, 1) == "m20" and table.find(big.Hotbar, "m20") == nil)
	check("still 20 owned", total(big) == 20 and big.Monsters.m20 ~= nil)

	-- capacity
	local full = fresh()
	for _ = 1, Config.INVENTORY_CAP do Inventory.add(full, monster()) end
	check(`inventory is full at {Config.INVENTORY_CAP}`, Inventory.isFull(full))

	-- favorites
	check("favorite saves on the monster", Inventory.setFavorite(d, a, true) and d.Monsters[a].Favorited == true)
	check("unfavorite clears it", Inventory.setFavorite(d, a, false) and d.Monsters[a].Favorited == nil)

	-- the panel's copy
	local snap = Inventory.snapshot(d)
	local row
	for _, r in snap.rows do
		if r.uid == a then row = r end
	end
	check("the panel shows where a monster is", row ~= nil and row.placedIn == "3" and row.baseFear == 300 and snap.capacity == Config.INVENTORY_CAP)
	row.baseFear = 999999
	check("changing the panel's copy can't touch the save", d.Monsters[a].BaseFear == 300)

	-- rejoin
	d.Fear = 1234
	d.TotalFearEarned = 5678
	d.Rebirths = 2
	Inventory.setFavorite(d, b, true)
	local back = rejoin(d)
	check("rejoin keeps Fear, lifetime and rebirths", back.Fear == 1234 and back.TotalFearEarned == 5678 and back.Rebirths == 2)
	check("rejoin keeps monsters and payouts", total(back) == total(d) and back.Monsters[a].BaseFear == 300 and back.Monsters[b].Favorited == true)
	check("rejoin keeps placements", back.Placed["3"] == a and back.Placed["4"] == b)
	check("rejoin keeps the species index", back.Index.Jeff == true)
	check("rejoin doesn't reuse a uid", Inventory.add(back, monster()) ~= a and back.NextUid == d.NextUid + 1)
	back.Tutorial.Step = 4
	back.Tutorial.FreeBoxClaimed = true
	back.Accessories.a1 = "BoneCharm"
	back.CaseAccessories["1"] = "a1"
	back.Boxes.b1 = "RareBox"
	back.Eggs.e1 = "StarterEgg"
	back.Trackers.t1 = {State = "Owned"}
	back.Settings.ReducedScares = true
	back.Receipts.r1 = true
	local again = rejoin(back)
	check("rejoin keeps tutorial, accessories, cases, boxes, eggs, trackers, settings and receipts",
		again.Tutorial.Step == 4 and again.Tutorial.FreeBoxClaimed and again.Accessories.a1 == "BoneCharm" and again.CaseAccessories["1"] == "a1"
			and again.Boxes.b1 == "RareBox" and again.Eggs.e1 == "StarterEgg" and again.Trackers.t1.State == "Owned" and again.Settings.ReducedScares and again.Receipts.r1)

	-- migrations and damaged saves
	local v1 = DataTemplate.prepare({SchemaVersion = 1, Fear = 700, Rebirths = 1, NextUid = 4, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare"}, m2 = {Kind = "Jeff", Tier = "Epic"}, m3 = {Kind = "Jeff", Tier = "Common"}}, Placed = {["1"] = "m2"}})
	check("a v1 save migrates with everything kept", v1 ~= nil and v1.SchemaVersion == DataTemplate.CurrentVersion and v1.Fear == 700 and v1.Rebirths == 1 and v1.NextUid == 4 and v1.Monsters.m2.Tier == "Epic" and v1.Placed["1"] == "m2")
	check("v1 monsters get a fixed payout in their band", v1.Monsters.m1.BaseFear == 500 and v1.Monsters.m2.BaseFear == 950)
	check("v1 hotbar holds the unplaced monsters", #v1.Hotbar == 2 and table.find(v1.Hotbar, "m2") == nil)
	local v2 = DataTemplate.prepare({SchemaVersion = 2, Fear = 1, TotalFearEarned = 9, Rebirths = 0, NextUid = 2, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare", BaseFear = 321, Size = "Normal", Provenance = "egg"}}, Placed = {}})
	check("a v2 save migrates and keeps its payout", v2 ~= nil and v2.Monsters.m1.BaseFear == 321 and v2.TotalFearEarned == 9 and v2.Hotbar[1] == "m1")
	local _, newer = DataTemplate.prepare({SchemaVersion = DataTemplate.CurrentVersion + 1})
	check("a newer save is refused, not overwritten", newer == "newer")
	local _, nan = DataTemplate.prepare({SchemaVersion = DataTemplate.CurrentVersion, Fear = 0 / 0})
	check("NaN Fear is refused", nan == "corrupt")
	local _, badMonster = DataTemplate.prepare({SchemaVersion = DataTemplate.CurrentVersion, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare", BaseFear = 0 / 0}}})
	check("a NaN payout is refused", badMonster == "corrupt")
	local repaired = DataTemplate.prepare({SchemaVersion = DataTemplate.CurrentVersion, Fear = 1, Rebirths = 0, NextUid = 2, TotalFearEarned = 0, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare", BaseFear = 5}}, Placed = {["1"] = "m1", ["2"] = "m1", ["3"] = "gone"}, Hotbar = {"m1", "m1", "gone"}})
	local placements = 0
	for _ in repaired.Placed do placements += 1 end
	check("a monster placed twice is repaired to one room, and kept", placements == 1 and repaired.Monsters.m1 ~= nil)
	check("the hotbar drops placed, missing and repeated entries", #repaired.Hotbar == 0)

	-- nobody gets stuck below the first egg
	check("starting Fear buys the live egg", Config.START_FEAR >= Config.EGG_COST)
	local stuck = DataTemplate.prepare({SchemaVersion = 3, Fear = 250, Rebirths = 0, NextUid = 1, TotalFearEarned = 0, Monsters = {}, Placed = {}, Hotbar = {}})
	check("an old save at 250 Fear with no monsters is topped up to the egg price", stuck ~= nil and stuck.Fear == Config.START_FEAR and stuck.Fear >= Config.EGG_COST)
	local rich = DataTemplate.prepare({SchemaVersion = 3, Fear = 9000, Rebirths = 0, NextUid = 1, TotalFearEarned = 0, Monsters = {}, Placed = {}, Hotbar = {}})
	check("a richer save with no monsters is left alone", rich ~= nil and rich.Fear == 9000)
	local owner = DataTemplate.prepare({SchemaVersion = 3, Fear = 10, Rebirths = 0, NextUid = 2, TotalFearEarned = 0, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare", BaseFear = 300}}, Placed = {}, Hotbar = {}})
	check("a save that owns a monster gets no top-up", owner ~= nil and owner.Fear == 10)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
