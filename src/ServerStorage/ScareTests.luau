-- Scare timing, payout math and room odds, tested with a fake clock. Touches nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.ScareTests)())
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

return function(): string
	local lines, failed = {}, 0
	local function check(name: string, ok: boolean, detail: string?)
		if not ok then failed += 1 end
		table.insert(lines, `{if ok then "PASS" else "FAIL"}  {name}{if detail then " -> " .. detail else ""}`)
	end

	-- copies, so a session that already required the old modules still tests the current source
	local shared = ReplicatedStorage.Shared:Clone()
	local Config = require(shared.Config)
	local Payout = require(shared.Payout)
	local ScareScheduler = require(ServerScriptService.Server.ScareScheduler:Clone())

	-- a scheduler that records what it does; runs fake time forward in small ticks
	local function rig(popAfter)
		local log = {pays = {}, begins = 0, resets = 0}
		local clock = 0
		local s
		s = ScareScheduler.new({
			begin = function() log.begins += 1 return popAfter or 2 end,
			pay = function(id)
				if log.refuse then return false end
				table.insert(log.pays, {id = id, at = clock})
				return true
			end,
			reset = function() log.resets += 1 end,
		})
		local function run(seconds)
			local stop = clock + seconds
			while clock < stop do
				clock += 0.1
				s:tick(clock)
			end
		end
		return s, log, run, function() return clock end
	end
	local function count(log, id)
		local n = 0
		for _, p in log.pays do
			if p.id == id then n += 1 end
		end
		return n
	end

	-- every rarity pays at its own speed
	for _, r in Config.Balance.rarities do
		local s, log, run = rig(1)
		s:add("room", r.scareSeconds, 0)
		run(r.scareSeconds * 10)
		check(`{r.id} pays once every {r.scareSeconds}s`, count(log, "room") == 10, `{count(log, "room")} in {r.scareSeconds * 10}s`)
	end
	local s, log, run = rig(2)
	s:add("room", 15, 0)
	run(62)
	check("a Common's pays land 15s apart", #log.pays == 5 and math.abs(log.pays[2].at - log.pays[1].at - 15) < 0.21 and math.abs(log.pays[5].at - log.pays[1].at - 60) < 0.21)
	check("one reset per pay", log.resets == #log.pays and log.begins == #log.pays)

	-- no earnings when it shouldn't earn
	s, log, run = rig(2)
	run(60)
	check("no monster placed, no earnings", #log.pays == 0)
	s:add("room", 5, 0.1)
	run(1)
	s:remove("room")
	run(60)
	check("picked up mid-scare: never pays", #log.pays == 0 and log.begins == 1)
	s:add("room", 5, 61.1)
	run(11)
	local paidAfter = #log.pays
	s:remove("room")
	run(60)
	check("picked up later: pays stop dead", #log.pays == paidAfter and paidAfter >= 2)
	s, log, run = rig(1)
	s:add("room", 10, 0)
	run(3)
	s:add("room", 10, 3)
	run(0.5)
	check("placing again restarts the cycle, with no double pay", #log.pays == 1 and log.begins == 2)

	-- several rooms and a disconnect
	s, log, run = rig(1)
	s:add("a", 5, 0)
	s:add("b", 8, 0)
	s:add("c", 15, 0)
	run(40)
	check("rooms run at their own speeds", count(log, "a") == 8 and count(log, "b") == 5 and count(log, "c") == 3)
	local before = #log.pays
	s:remove("a") s:remove("b") s:remove("c")
	run(100)
	check("owner leaving stops every room", #log.pays == before)

	-- a stall doesn't print money
	s, log, run = rig(1)
	s:add("room", 5, 0)
	s:tick(0.1)
	s:tick(1.2)
	local paid = #log.pays
	s:tick(500)
	s:tick(500.1)
	s:tick(502)
	check("a 500s server stall gives one scare, not a hundred", #log.pays == paid + 1)

	-- invalid scare
	s, log, run = rig(1)
	log.refuse = true
	s:add("room", 5, 0)
	run(20)
	check("an invalid scare pays nothing and doesn't reset", #log.pays == 0 and log.resets == 0)
	check("the room keeps trying", log.begins >= 3)

	-- a broken room can't stop the others
	local good = 0
	local errored = ScareScheduler.new({
		begin = function(id)
			if id == "bad" then error("deliberately broken room for this test") end
			return 0
		end,
		pay = function(id) if id == "good" then good += 1 end return true end,
		reset = function() end,
	})
	errored:add("bad", 5, 0)
	errored:add("good", 5, 0)
	for t = 1, 195 do errored:tick(t / 10) end
	check("one broken room doesn't stop the others", good == 4, tostring(good))

	-- the formula
	local rare = {BaseFear = 300, Size = "Normal"}
	check("base only", Payout.scare(rare, 1, 0).total == 300)
	check("bedroom tier", Payout.scare(rare, 16, 0).total == 4800)
	check("rebirth", Payout.scare(rare, 1, 4).total == 600)
	local full = Payout.scare({BaseFear = 300, Size = "Large", Mutation = "Haunted"}, 2, 2, 1.5)
	check("every factor multiplies", full.total == math.round(300 * 2 * 1.5 * 1.4 * 1.5 * 1.5), tostring(full.total))
	check("factors are all reported", full.base == 300 and full.room == 2 and full.size == 1.5 and full.mutation == 1.4 and full.accessory == 1.5 and full.rebirth == 1.5)
	check("the total is a whole number", Payout.scare({BaseFear = 333, Size = "Normal"}, 1.2, 1).total % 1 == 0)
	local line = Payout.describe(Payout.scare(rare, 1.5, 4), "Gold")
	check("the case explains the math", line == "300 base x1.5 Gold x2 Rebirth", line)
	check("x1 factors are left out", Payout.describe(Payout.scare(rare, 1, 0), "Normal") == "300 base")
	check("unknown size or mutation counts as x1", Payout.scare({BaseFear = 100, Size = "Huge", Mutation = "Fake"}, 1, 0).total == 100)

	-- the accessory slot, ready for the accessory phase
	local d = {CaseAccessories = {["1"] = "a1", ["2"] = "gone"}, Accessories = {a1 = "LanternTag"}}
	check("an equipped accessory counts", (Payout.accessoryOf(d, "1")) == 1.25)
	check("no accessory, or a missing one, is x1", (Payout.accessoryOf(d, "3")) == 1 and (Payout.accessoryOf(d, "2")) == 1)

	-- manual scares
	check("manual base is exactly 100", Payout.manual(0) == 100)
	check("manual scales with rebirth", Payout.manual(4) == 200)
	check("perfect timing adds 20%", Payout.manual(0, 1.2) == 120)
	local M = Config.Balance.manual
	check("a tap on the mark is Perfect", (Payout.timing(M.perfectAt)) == M.maxTimingBonus)
	check("a tap near the mark is Good", (Payout.timing(M.perfectAt + M.goodWidth / 2 - 0.001)) == M.goodTimingBonus)
	check("a tap far off has no bonus", (Payout.timing(0)) == 1)
	check("no tap has no bonus", (Payout.timing(nil)) == 1)
	check("cooldown is 8s", Config.MANUAL_COOLDOWN == 8)

	-- room odds over many rolls, from a fixed seed
	local rng = Random.new(20261102)
	local rolls = 1000000
	local seen = {}
	for i = 1, rolls do
		local name = Config.pickBedroomTier(rng:NextNumber(0, 100)).name
		seen[name] = (seen[name] or 0) + 1
		if i % 200000 == 0 then task.wait() end
	end
	for name, want in {Normal = 73.949, Silver = 20, Gold = 5, Platinum = 1, Diamond = 0.05, GOD = 0.001} do
		local got = (seen[name] or 0) / rolls * 100
		check(`{name} rolls about {want}%`, math.abs(got - want) <= math.max(want * 0.1, 0.001), string.format("%.4f%%", got))
	end

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
