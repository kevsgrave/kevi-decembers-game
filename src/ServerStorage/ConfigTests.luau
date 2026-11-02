-- Config checks, including intentionally broken tables. Runs nothing in the game and changes nothing.
-- Studio command bar: print(require(game.ServerStorage.ConfigTests)())
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")

return function(balance: any?, validator: any?, remotes: any?): string
	local Balance = balance or require(Shared.Balance)
	local ConfigValidator = validator or require(Shared.ConfigValidator)
	local Remotes = remotes or require(Shared.Remotes)
	local lines, failed = {}, 0

	local function check(name: string, ok: boolean, detail: string?)
		if not ok then failed += 1 end
		table.insert(lines, `{if ok then "PASS" else "FAIL"}  {name}{if detail then " -> " .. detail else ""}`)
	end
	local function copy(v: any): any
		if type(v) ~= "table" then return v end
		local out = {}
		for k, child in v do out[k] = copy(child) end
		return out
	end
	local function row(list: any, id: string): any
		for _, r in list do
			if r.id == id then return r end
		end
		error("no row " .. id)
	end

	-- the shipped data
	local problems = ConfigValidator.problems(Balance)
	check("shipped Balance has no problems", #problems == 0, table.concat(problems, "; "))
	local plain, status = ConfigValidator.load(Balance)

	-- values the design notes fix, pinned so a typo can't slip through the totals
	local expectedTiers = {GOD = {0.001, 16}, Diamond = {0.05, 4}, Platinum = {1, 2}, Gold = {5, 1.5}, Silver = {20, 1.2}, Normal = {73.949, 1}}
	for id, want in expectedTiers do
		local t = row(plain.bedroomTiers, id)
		check(`bedroom tier {id} is {want[1]}% x{want[2]}`, t.chance == want[1] and t.mult == want[2])
	end
	local expectedRarities = {Common = {25, 400, 15}, Rare = {200, 800, 10}, Epic = {400, 1500, 8}, Legendary = {800, 2500, 5}, Mythic = {1200, 5000, 5}, SPOOKY = {8000, 15000, 3.5}}
	for id, want in expectedRarities do
		local r = row(plain.rarities, id)
		check(`rarity {id} is {want[1]}-{want[2]} every {want[3]}s`, r.minFear == want[1] and r.maxFear == want[2] and r.scareSeconds == want[3])
	end
	check("seven rarities", #plain.rarities == 7)
	local tutorialEgg = row(plain.eggs, "TutorialEgg")
	check("tutorial egg is 80 Epic / 20 Legendary", tutorialEgg.odds.Epic == 80 and tutorialEgg.odds.Legendary == 20)
	check("fusion is 4/3/3", row(plain.fusion.recipes, "Large").count == 4 and row(plain.fusion.recipes, "Mega").count == 3 and row(plain.fusion.recipes, "MASSIVE").count == 3)
	check("shop rotates every 300s", plain.shop.rotationSeconds == 300)
	check("manual base is 100", plain.manual.baseFear == 100)
	check("start with 3 of 6 bedrooms", plain.rebirth.startBedrooms == 3 and plain.rebirth.bedroomsPerFloor == 6)

	-- the tags
	check("confirmed: Diamond chance", status["bedroomTiers.Diamond.chance"].tag == "confirmed")
	check("provisional and noted: GOD chance", status["bedroomTiers.GOD.chance"].tag == "provisional" and status["bedroomTiers.GOD.chance"].note ~= nil)
	check("provisional: Secret payout", status["rarities.Secret.minFear"].tag == "provisional")
	check("confirmed: tutorial Epic odds", status["eggs.TutorialEgg.odds.Epic"].tag == "confirmed")

	-- each broken table must produce a problem naming the fault
	local broken = {
		{"bedroom odds off by 1%", "bedroomTiers: odds total", function(b) row(b.bedroomTiers, "Silver").chance.value = 21 end},
		{"egg odds total 99%", "eggs.SpookyEgg.odds: odds total", function(b) row(b.eggs, "SpookyEgg").odds.Common.value = 59 end},
		{"box odds off", "accessories box RareBox: odds total", function(b) b.accessories.items[1].weight.value = 10 end},
		{"egg rolls an unknown rarity", 'unknown rarity "Megarare"', function(b) row(b.eggs, "SpookyEgg").odds.Megarare = b.eggs[1].odds.Common end},
		{"duplicate rarity id", 'rarities: duplicate id "Rare"', function(b) row(b.rarities, "Epic").id = "Rare" end},
		{"duplicate egg id", 'eggs: duplicate id "SpookyEgg"', function(b) row(b.eggs, "MoonlitEgg").id = "SpookyEgg" end},
		{"missing rarity", '"Secret" is missing', function(b) table.remove(b.rarities, 7) end},
		{"missing mutation", '"UnHoly" is missing', function(b) table.remove(b.mutations, 5) end},
		{"negative price", "eggs.SpookyEgg.price", function(b) row(b.eggs, "SpookyEgg").price.value = -5 end},
		{"fractional price", "shop.items.RareBox.price", function(b) row(b.shop.items, "RareBox").price.value = 10.5 end},
		{"NaN multiplier", "mutations.Golden.mult: expected a finite number", function(b) row(b.mutations, "Golden").mult.value = 0 / 0 end},
		{"infinite multiplier", "bedroomTiers.GOD.mult: expected a finite number", function(b) row(b.bedroomTiers, "GOD").mult.value = math.huge end},
		{"multiplier below 1", "accessories.items.CandleCharm.mult", function(b) b.accessories.items[1].mult.value = 0.5 end},
		{"payout min above max", "rarities.Rare: minFear", function(b) row(b.rarities, "Rare").minFear.value = 9000 end},
		{"number with no tag", "rebirth.floorCap: 3 has no C() or P() tag", function(b) b.rebirth.floorCap = 3 end},
		{"recipe uses unknown size", 'uses unknown size "Tiny"', function(b) row(b.fusion.recipes, "Large").from = "Tiny" end},
		{"sizes shrink", "fusion.sizes.Mega: mult must grow", function(b) row(b.fusion.sizes, "Mega").mult.value = 1.2 end},
		{"shop sells an unknown box", "shop.items.FakeBox: no accessory box", function(b) row(b.shop.items, "RareBox").id = "FakeBox" end},
		{"stock min above max", "shop.items.EpicBox: stockMin", function(b) row(b.shop.items, "EpicBox").stockMin.value = 9 end},
		{"tutorial points at a missing egg", "tutorial.eggId", function(b) b.tutorial.eggId = "NoEgg" end},
		{"missing section", "rebirth", function(b) b.rebirth = nil end},
	}
	for _, case in broken do
		local data = copy(Balance)
		case[3](data)
		local found = table.concat(ConfigValidator.problems(data), "\n")
		check(`broken: {case[1]}`, string.find(found, case[2], 1, true) ~= nil, if found == "" then "nothing reported" else nil)
	end

	-- the startup error itself: load must refuse and list every fault
	local data = copy(Balance)
	row(data.bedroomTiers, "Silver").chance.value = 21
	row(data.eggs, "SpookyEgg").price.value = -5
	local ok, message = pcall(ConfigValidator.load, data)
	check("load refuses bad data and lists both faults", not ok and string.find(tostring(message), "2 problem(s)", 1, true) ~= nil)
	table.insert(lines, "  sample startup error:\n  " .. tostring(message))

	-- the remote contract
	check("Rebirth takes no arguments", Remotes.checkArgs("Rebirth") == true)
	check("Rebirth refuses an extra argument", Remotes.checkArgs("Rebirth", 1) == false)
	check("HatchEgg takes two ids", Remotes.checkArgs("HatchEgg", "SpookyEgg", "req1") == true)
	check("HatchEgg refuses a number id", Remotes.checkArgs("HatchEgg", 5, "req1") == false)
	check("HatchEgg refuses an oversized id", Remotes.checkArgs("HatchEgg", string.rep("x", 65), "req1") == false)
	check("FuseMonsters takes an id list", Remotes.checkArgs("FuseMonsters", {"m1", "m2"}, "req1") == true)
	check("FuseMonsters refuses a map", Remotes.checkArgs("FuseMonsters", {a = "m1"}, "req1") == false)
	check("clients can't call a server-to-client remote", Remotes.checkArgs("Popup", "hi") == false)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} lines)`)
	return table.concat(lines, "\n")
end
