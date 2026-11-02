-- The one Fear formula. The server pays from it and the case displays it, so what's shown is what's paid.
local Config = require(script.Parent.Config)

local B = Config.Balance
local sizeMult, mutationMult, accessoryMult = {}, {}, {}
for _, s in B.fusion.sizes do sizeMult[s.id] = s.mult end
for _, m in B.mutations do mutationMult[m.id] = m.mult end
for _, a in B.accessories.items do accessoryMult[a.id] = a.mult end

local Payout = {}

-- the accessory equipped on a bedroom's case in this save: its multiplier and id, x1 if none
function Payout.accessoryOf(d, slot: string): (number, string?)
	local uid = d.CaseAccessories[slot]
	local id = uid and d.Accessories[uid]
	return id and accessoryMult[id] or 1, id
end

-- every factor of one automatic scare, and the rounded total
function Payout.scare(monster, roomMult: number, rebirths: number, accessory: number?)
	local b = {
		base = monster.BaseFear,
		room = roomMult,
		size = sizeMult[monster.Size] or 1,
		mutation = mutationMult[monster.Mutation] or 1,
		accessory = accessory or 1,
		rebirth = Config.rebirthMult(rebirths),
	}
	b.total = math.round(b.base * b.room * b.size * b.mutation * b.accessory * b.rebirth)
	return b
end

-- the factors as a short line for the case, leaving out anything at x1
function Payout.describe(b, roomName: string, sizeName: string?, mutationName: string?): string
	local parts = {Config.short(b.base) .. " base"}
	local function add(mult, name)
		if mult ~= 1 then table.insert(parts, "x" .. mult .. " " .. name) end
	end
	add(b.room, roomName)
	add(b.size, sizeName or "Size")
	add(b.mutation, mutationName or "Mutation")
	add(b.accessory, "Accessory")
	add(b.rebirth, "Rebirth")
	return table.concat(parts, " ")
end

-- how a tap lands on the timing bar: fraction runs 0 to 1 across the cue, nil means no tap. Returns the bonus and a word.
function Payout.timing(fraction: number?): (number, string)
	local m = B.manual
	if fraction then
		local off = math.abs(fraction - m.perfectAt)
		if off <= m.perfectWidth / 2 then return m.maxTimingBonus, "Perfect!" end
		if off <= m.goodWidth / 2 then return m.goodTimingBonus, "Good!" end
	end
	return 1, "Boo!"
end

-- a manual scare: its own formula, no bedroom tier
function Payout.manual(rebirths: number, timingBonus: number?): number
	return math.round(B.manual.baseFear * (1 + B.manual.multPerRebirth * rebirths) * (timingBonus or 1))
end

return Payout
