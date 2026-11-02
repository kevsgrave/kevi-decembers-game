-- Fusion, mutations, rebirth and floors, tested on throwaway save tables. Touches nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.ProgressTests)())
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
	for _, name in {"DataTemplate", "Inventory", "Fusion", "Rebirth"} do
		server[name].Source = server[name].Source:gsub(CONFIG_PATH, "require(script.Parent.Shared.Config)")
	end
	local Config = require(server.Shared.Config)
	local Payout = require(server.Shared.Payout)
	local PlotLayout = require(server.Shared.PlotLayout)
	local DataTemplate = require(server.DataTemplate)
	local Inventory = require(server.Inventory)
	local Fusion = require(server.Fusion)
	local Rebirth = require(server.Rebirth)

	local function rejoin(d)
		local loaded, why = DataTemplate.prepare(HttpService:JSONDecode(HttpService:JSONEncode(d)))
		assert(loaded, why)
		return loaded
	end
	local function count(t)
		local n = 0
		for _ in t do n += 1 end
		return n
	end
	local function give(d, n, size, tier, mutation, base)
		local uids = {}
		for i = 1, n do
			local m = DataTemplate.newMonster("Jeff", tier or "Rare", (base or 300) + i, "egg", mutation)
			m.Size = size or "Normal"
			table.insert(uids, Inventory.add(d, m))
		end
		return uids
	end
	-- a failed fusion must leave the save exactly as it was
	local function untouched(d, uids)
		local before = HttpService:JSONEncode(d)
		local result, why = Fusion.fuse(d, uids)
		return result == nil and HttpService:JSONEncode(d) == before, why
	end

	-- the recipes
	local d = DataTemplate.new()
	local four = give(d, 4)
	local large = Fusion.fuse(d, four)
	check("4 Normal make 1 Large", large ~= nil and d.Monsters[large].Size == "Large" and count(d.Monsters) == 1)
	check("the new one has a new id", table.find(four, large) == nil)
	check("the ingredients are gone, once", d.Monsters[four[1]] == nil and d.Monsters[four[4]] == nil)
	check("it keeps the best payout among those used", d.Monsters[large].BaseFear == 304)
	check("it records where it came from", d.Monsters[large].Provenance == "fusion")
	local mega = Fusion.fuse(d, {large, give(d, 1, "Large")[1], give(d, 1, "Large")[1]})
	check("3 Large make 1 Mega", mega ~= nil and d.Monsters[mega].Size == "Mega")
	local massive = Fusion.fuse(d, {mega, give(d, 1, "Mega")[1], give(d, 1, "Mega")[1]})
	check("3 Mega make 1 MASSIVE", massive ~= nil and d.Monsters[massive].Size == "MASSIVE")
	local topped = give(d, 3, "MASSIVE")
	local ok, why = untouched(d, topped)
	check("MASSIVE is the biggest, and refusing changes nothing", ok and why == "maxSize")

	-- refusals change nothing at all
	local r = DataTemplate.new()
	local a = give(r, 4)
	ok, why = untouched(r, {a[1], a[2], a[3]})
	check("too few refused", ok and why == "count")
	local fives = give(r, 1)
	ok, why = untouched(r, {a[1], a[2], a[3], a[4], fives[1]})
	check("too many refused", ok and why == "count")
	ok, why = untouched(r, {a[1], a[1], a[2], a[3]})
	check("the same monster twice refused", ok and why == "missing")
	ok, why = untouched(r, {a[1], a[2], a[3], "m999"})
	check("a monster you don't own refused", ok and why == "missing")
	ok, why = untouched(r, {"m999", "m998", "m997", "m996"})
	check("all made up refused", ok and why == "missing")
	local epic = give(r, 1, "Normal", "Epic")
	ok, why = untouched(r, {a[1], a[2], a[3], epic[1]})
	check("different rarity refused", ok and why == "different")
	local golden = give(r, 1, "Normal", "Rare", "Golden")
	ok, why = untouched(r, {a[1], a[2], a[3], golden[1]})
	check("different mutation refused", ok and why == "different")
	local bigger = give(r, 1, "Large")
	ok, why = untouched(r, {a[1], a[2], a[3], bigger[1]})
	check("different size refused", ok and why == "different")
	Inventory.setFavorite(r, a[1], true)
	ok, why = untouched(r, a)
	check("a favorite is protected", ok and why == "favorite")
	Inventory.setFavorite(r, a[1], false)
	Inventory.place(r, 1, a[2], 3)
	ok, why = untouched(r, a)
	check("a placed monster is protected", ok and why == "placed")
	Inventory.pickUp(r, 1)

	-- repeated requests
	local rep = DataTemplate.new()
	local ingredients = give(rep, 8)
	local firstFour = {ingredients[1], ingredients[2], ingredients[3], ingredients[4]}
	check("a fusion works", Fusion.fuse(rep, firstFour) ~= nil)
	check("repeating the same request does nothing", Fusion.fuse(rep, firstFour) == nil and count(rep.Monsters) == 5)
	check("the hotbar drops the used monsters", table.find(rep.Hotbar, ingredients[1]) == nil)

	-- mutations carry over, and persist
	local mutant = DataTemplate.new()
	local goldens = give(mutant, 4, "Normal", "Rare", "Golden")
	local fused = Fusion.fuse(mutant, goldens)
	check("a fusion keeps the mutation", mutant.Monsters[fused].Mutation == "Golden")
	local back = rejoin(mutant)
	check("size and mutation survive a rejoin", back.Monsters[fused].Size == "Large" and back.Monsters[fused].Mutation == "Golden")
	check("the index remembers the best size and mutations", back.IndexSeen.Jeff.BestSize == "Large" and back.IndexSeen.Jeff.Mutations.Golden == true)

	-- mutation odds
	local rolled, rolls = {}, 1000000
	local rng = Random.new(77)
	for i = 1, rolls do
		local id = Config.pickMutation(rng:NextNumber(0, 100)) or "None"
		rolled[id] = (rolled[id] or 0) + 1
		if i % 200000 == 0 then task.wait() end
	end
	for id, want in {None = 96.6, Golden = 2, Haunted = 0.9, Creepy = 0.35, Cursed = 0.13, UnHoly = 0.02} do
		local got = (rolled[id] or 0) / rolls * 100
		check(`{id} rolls about {want}%`, math.abs(got - want) <= math.max(want * 0.1, 0.01), string.format("%.3f%%", got))
	end
	local allFive = true
	for _, id in {"Golden", "Haunted", "Creepy", "Cursed", "UnHoly"} do
		local m = DataTemplate.newMonster("Jeff", "Rare", 100, "egg", id)
		local total = Payout.scare(m, 1, 0).total
		if not (total > 100) then allFive = false end
	end
	check("all five mutations raise the payout", allFive)
	check("every mutation has a look", (function()
		local Look = require(server.AccessoryLook)
		for _, m in Config.Balance.mutations do
			if not Look.MUTATIONS[m.id] then return false end
		end
		return true
	end)())

	-- rebirth schedule and rooms
	local schedule = {50000, 150000, 450000, 1350000, 4050000, 12150000, 36450000, 109350000, 328050000}
	local costsMatch = true
	for i, want in schedule do
		if Config.rebirthCost(i - 1) ~= want then costsMatch = false end
	end
	check("rebirth costs follow the schedule", costsMatch)
	check("rooms go 3, 4, 5, 6, 7", Config.unlockedBedrooms(0) == 3 and Config.unlockedBedrooms(1) == 4 and Config.unlockedBedrooms(3) == 6 and Config.unlockedBedrooms(4) == 7)
	check("the multiplier goes up by 0.25", Config.rebirthMult(0) == 1 and Config.rebirthMult(4) == 2)
	check("floor 2 appears at the sixth room, not before", PlotLayout.floorsVisible(Config.unlockedBedrooms(2)) == 1 and PlotLayout.floorsVisible(Config.unlockedBedrooms(3)) == 2)
	check("room 7 is on floor 2", PlotLayout.floorOf(Config.unlockedBedrooms(4)) == 2)
	check("floor 3 appears at the twelfth room", PlotLayout.floorsVisible(Config.unlockedBedrooms(9)) == 3)

	-- spending
	local re = DataTemplate.new()
	give(re, 2)
	re.Fear = 70000
	local done = Rebirth.apply(re, nil, 100)
	check("a rebirth spends the cost and keeps the rest", done == true and re.Fear == 20000 and re.Rebirths == 1)
	check("monsters are kept", count(re.Monsters) == 2)
	local poor, whyPoor, cost = Rebirth.apply(re, nil, 200)
	check("not enough Fear refused, and it says how much", not poor and whyPoor == "poor" and cost == 150000 and re.Fear == 20000 and re.Rebirths == 1)
	re.Fear = 1e9
	local fast, whyFast = Rebirth.apply(re, 100, 100 + Config.Balance.rebirth.cooldownSeconds - 0.1)
	check("the cooldown refuses a repeat", not fast and whyFast == "cooldown" and re.Rebirths == 1)
	local attempts = 0
	local last = 100
	for t = 1, 20 do
		local now = 100 + t * 0.1
		local good = Rebirth.apply(re, last, now)
		if good then
			attempts += 1
			last = now
		end
	end
	check("20 requests in 2 seconds rebirth at most once", attempts <= 1)
	local capped = DataTemplate.new()
	capped.Fear = Config.MAX_FEAR
	local steps = 0
	local clock = 0
	while Rebirth.apply(capped, nil, clock) do
		steps += 1
		clock += 100
		if steps > 100 then break end
	end
	check("rebirths stop when every floor is unlocked", Config.unlockedBedrooms(capped.Rebirths) == Config.MAX_BEDROOMS and steps == Config.MAX_BEDROOMS - Config.START_BEDROOMS, tostring(steps))
	local kept = rejoin(re)
	check("rebirth survives a rejoin", kept.Rebirths == re.Rebirths and kept.Fear == re.Fear)

	-- income math
	local m = DataTemplate.newMonster("Jeff", "Rare", 300, "egg", "Golden")
	m.Size = "Mega"
	local b = Payout.scare(m, 2, 4, 1.25)
	check("income math multiplies every factor once", b.total == math.round(300 * 2 * 2.25 * 1.2 * 1.25 * 2), tostring(b.total))
	check("manual scares use rebirth, not the room", Payout.manual(4) == 200)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
