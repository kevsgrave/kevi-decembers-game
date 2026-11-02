-- The shop and trackers, tested on throwaway save tables with a fake clock. Touches nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.ShopTests)())
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
	for _, name in {"DataTemplate", "Inventory", "Shop", "Tracker"} do
		server[name].Source = server[name].Source:gsub(CONFIG_PATH, "require(script.Parent.Shared.Config)")
	end
	local Config = require(server.Shared.Config)
	local DataTemplate = require(server.DataTemplate)
	local Shop = require(server.Shop)
	local Tracker = require(server.Tracker)
	local AccessoryLook = require(server.AccessoryLook)
	local B = Config.Balance.shop

	local function rich()
		local d = DataTemplate.new()
		d.Fear = 1e12
		return d
	end
	local function rejoin(d)
		local loaded, why = DataTemplate.prepare(HttpService:JSONDecode(HttpService:JSONEncode(d)))
		assert(loaded, why)
		return loaded
	end
	local function total(t)
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	-- a rotation whose lineup includes this item
	local function rotationWith(itemId)
		for r = 1, 100000 do
			if table.find(Shop.lineup(r), itemId) then return r end
		end
		error("never on sale: " .. itemId)
	end
	local function timeOf(rotation) return rotation * B.rotationSeconds + 10 end

	-- rotation
	check("a rotation lasts 300 seconds", Shop.rotationAt(300) == 1 and Shop.rotationAt(599) == 1 and Shop.rotationAt(600) == 2 and Shop.endsAt(1) == 600)
	local a, b = Shop.lineup(12345), Shop.lineup(12345)
	check("every server gets the same lineup", table.concat(a, ",") == table.concat(b, ","))
	local changes, rare, sizeOk, uniqueOk = 0, 0, true, true
	local counts = {}
	local rotations = 20000
	for r = 1, rotations do
		local line = Shop.lineup(r)
		if #line < B.offersMin or #line > B.offersMax then sizeOk = false end
		local seen = {}
		for _, id in line do
			if seen[id] then uniqueOk = false end
			seen[id] = true
			counts[id] = (counts[id] or 0) + 1
		end
		if seen.RareBox then rare += 1 end
		if table.concat(line, ",") ~= table.concat(Shop.lineup(r + 1), ",") then changes += 1 end
	end
	check("lineups stay between the limits", sizeOk)
	check("no item twice in a lineup", uniqueOk)
	check("the Rare box is always there", rare == rotations)
	check("the lineup changes from one rotation to the next", changes > rotations / 2, string.format("%.0f%% of rotations", changes / rotations * 100))
	check("rarer items appear less often", counts.EpicBox > counts.LegendaryBox and counts.LegendaryBox > counts.SecretBox)
	check("item chances match the config", math.abs(counts.EpicBox / rotations - 0.6) < 0.02 and math.abs(counts.LegendaryBox / rotations - 0.2) < 0.02 and math.abs(counts.SecretBox / rotations - 0.03) < 0.01 and math.abs(counts.Tracker / rotations - 0.02) < 0.01, string.format("Epic %.1f%%, Legendary %.1f%%, Secret %.1f%%, Tracker %.1f%%", counts.EpicBox / rotations * 100, counts.LegendaryBox / rotations * 100, counts.SecretBox / rotations * 100, counts.Tracker / rotations * 100))
	check("trackers are especially rare", counts.Tracker < rotations * 0.2, string.format("%.1f%% of rotations", counts.Tracker / rotations * 100))

	-- buying
	local rotation = rotationWith("RareBox")
	local now = timeOf(rotation)
	local d = rich()
	local before = d.Fear
	local ok, why = Shop.buy(d, "RareBox", rotation, now)
	check("a purchase charges the config price and gives the box", ok and d.Fear == before - 2500 and total(d.Boxes) == 1)
	check("stock goes down", Shop.stateFor(d, now).offers[1].left == 2)

	-- last stock, races and replays
	Shop.buy(d, "RareBox", rotation, now)
	local third = Shop.buy(d, "RareBox", rotation, now)
	local fourth, reason = Shop.buy(d, "RareBox", rotation, now)
	check("the last one sells", third == true)
	check("a double purchase on the last one fails, with no charge", not fourth and reason == "soldOut" and d.Fear == before - 7500 and total(d.Boxes) == 3)
	check("stock never goes negative", Shop.stateFor(d, now).offers[1].left == 0)
	local race = rich()
	local wins = 0
	for _ = 1, 50 do
		if Shop.buy(race, "RareBox", rotation, now) then wins += 1 end
	end
	check("50 requests at once buy only the stock", wins == 3 and total(race.Boxes) == 3)

	-- a rejoin can't refill stock
	local back = rejoin(d)
	local afterRejoin, whyRejoin = Shop.buy(back, "RareBox", rotation, now)
	check("rejoining doesn't refill stock", not afterRejoin and whyRejoin == "soldOut")
	check("the purchase survives a rejoin", total(back.Boxes) == 3)

	-- a new rotation does
	local nextRotation = rotation + 1
	local nextNow = timeOf(nextRotation)
	check("the next rotation brings fresh stock", Shop.stateFor(d, nextNow).offers[1].left == B.items[1].stock)

	-- stale and made-up requests
	local fresh = rich()
	local fear = fresh.Fear
	local stale, whyStale = Shop.buy(fresh, "RareBox", rotation - 1, now)
	check("a slow purchase from the old shop fails", not stale and whyStale == "stale" and fresh.Fear == fear)
	local future = Shop.buy(fresh, "RareBox", rotation + 1, now)
	check("a purchase from a future rotation fails", not future)
	local fake, whyFake = Shop.buy(fresh, "FreeMoneyBox", rotation, now)
	check("a made-up item fails", not fake and whyFake == "unavailable" and fresh.Fear == fear)
	local offRotation
	for r = 1, 100000 do
		if not table.find(Shop.lineup(r), "SecretBox") then offRotation = r break end
	end
	local missing, whyMissing = Shop.buy(fresh, "SecretBox", offRotation, timeOf(offRotation))
	check("an item not on sale this rotation fails", not missing and whyMissing == "unavailable")
	local poor = DataTemplate.new()
	poor.Fear = 100
	local cant, whyPoor = Shop.buy(poor, "RareBox", rotation, now)
	check("not enough Fear fails, with no charge and no item", not cant and whyPoor == "poor" and poor.Fear == 100 and total(poor.Boxes) == 0)

	-- trackers
	local trackerRotation = rotationWith("Tracker")
	local trackerNow = timeOf(trackerRotation)
	local t = rich()
	check("a tracker can be bought", Shop.buy(t, "Tracker", trackerRotation, trackerNow) == true and total(t.Trackers) == 1)
	local again = Shop.buy(t, "Tracker", trackerRotation, trackerNow)
	check("trackers are limited to one per rotation", again == false)
	local uid = next(t.Trackers)
	local nodes = {"NodeA", "NodeB", "NodeC"}
	local exists = function(name) return table.find(nodes, name) ~= nil end
	local start = 1000
	check("activating reserves a spot the server picks", Tracker.activate(t, uid, nodes, 0.5, start) == true and t.Trackers[uid].Node == "NodeB")
	check("the top of the roll stays in range", (function()
		local x = rich()
		local tu = Tracker.add(x)
		Tracker.activate(x, tu, nodes, 0.9999, start)
		return x.Trackers[tu].Node == "NodeC"
	end)())
	local second = Tracker.add(t)
	local busy, whyBusy = Tracker.activate(t, second, nodes, 0, start)
	check("only one dig at a time", not busy and whyBusy == "busy")
	check("activating a tracker you don't own fails", Tracker.activate(rich(), uid, nodes, 0, start) == false)

	-- a disconnect keeps the same spot
	local resumed = rejoin(t)
	check("rejoining resumes the same spot", resumed.Trackers[uid].State == "Activated" and resumed.Trackers[uid].Node == "NodeB")

	-- another player can't take it
	local visitor = rich()
	check("a visitor can't dig your egg", Tracker.dig(visitor, uid, start + 1) == nil and total(visitor.Eggs) == 0)
	check("your tracker is untouched", t.Trackers[uid] ~= nil)

	-- awarded once
	local egg = Tracker.dig(t, uid, start + 1)
	check("digging gives the Buried Moon Egg", egg ~= nil and t.Eggs[egg] == "BuriedMoonEgg")
	check("the tracker is used up", t.Trackers[uid] == nil)
	check("replaying the dig gives nothing", Tracker.dig(t, uid, start + 2) == nil and total(t.Eggs) == 1)
	check("a dig before activating gives nothing", Tracker.dig(t, second, start + 2) == nil and t.Trackers[second] ~= nil)
	check("the egg survives a rejoin", rejoin(t).Eggs[egg] == "BuriedMoonEgg")

	-- expiring and restoring
	local e = rich()
	local eu = Tracker.add(e)
	Tracker.activate(e, eu, nodes, 0, start)
	local expiry = start + Config.Balance.trackers.digExpireSeconds
	check("nothing expires early", Tracker.tidy(e, exists, expiry - 1) == false and e.Trackers[eu].State == "Activated")
	check("a dig after expiry gives nothing", Tracker.dig(e, eu, expiry) == nil)
	check("an abandoned dig gives the tracker back", Tracker.tidy(e, exists, expiry) == true and e.Trackers[eu].State == "Owned" and e.Trackers[eu].Node == nil)
	check("it can be used again", Tracker.activate(e, eu, nodes, 0, expiry) == true)
	local gone = rich()
	local gu = Tracker.add(gone)
	Tracker.activate(gone, gu, {"OldNode"}, 0, start)
	check("a spot removed by a map update gives the tracker back", Tracker.tidy(gone, exists, start + 1) == true and gone.Trackers[gu].State == "Owned")
	check("no spots to dig fails without using the tracker", (function()
		local x = rich()
		local xu = Tracker.add(x)
		local done, whyNot = Tracker.activate(x, xu, {}, 0, start)
		return not done and whyNot == "noSpots" and x.Trackers[xu].State == "Owned"
	end)())

	-- accessories have looks
	local allLooks = true
	for _, item in Config.Balance.accessories.items do
		if not AccessoryLook.LOOKS[item.id] then allLooks = false end
	end
	check("every accessory has a look on the case", allLooks)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
