-- The first-time tutorial. The current step is worked out from what the save actually holds, not from a stored counter,
-- so a disconnect, a respawn or doing things out of order can't lose a step or get a player stuck.
-- It starts at the crawl-hole scare: plots are auto-assigned, by the owner's decision (docs/spec/OVERRIDES.md).
local Tutorial = {}

Tutorial.STEPS = {
	{id = "manual", text = "Crawl into a room and scare the sleeping kid!"},
	{id = "egg", text = "Well done! Go to the egg shrine and hatch your free Promise Egg."},
	{id = "hold", text = "Your monster is in your hotbar. Select it to hold it."},
	{id = "place", text = "Take it to an empty display case and press E (or tap) to place it."},
	{id = "watch", text = "Watch through the window: your monster earns Fear by itself!"},
	{id = "box", text = "Go to the shop and press E: your first visit gets a FREE Rare accessory box."},
	{id = "open", text = "Open your Inventory, go to Items and open the box."},
	{id = "equip", text = "Go to a display case, press F (or tap Accessory) and equip your accessory."},
	{id = "done", text = "That's the loop!"},
}

local INDEX_OF = {}
for i, step in Tutorial.STEPS do INDEX_OF[step.id] = i end
Tutorial.COUNT = #Tutorial.STEPS

function Tutorial.indexOf(id: string): number
	return INDEX_OF[id]
end

-- the step this save is on, or nil when finished. isHolding: a monster is in the player's hand right now.
function Tutorial.current(d, isHolding: boolean): string?
	local t = d.Tutorial
	if t.Complete then return nil end
	if next(d.Monsters) == nil then
		return if t.ManualDone then "egg" else "manual"
	end
	if not t.ScareSeen then
		if next(d.Placed) ~= nil then return "watch" end
		return if isHolding then "place" else "hold"
	end
	if not t.FreeBoxClaimed then return "box" end
	if next(d.CaseAccessories) ~= nil then return "done" end
	if next(d.Accessories) ~= nil then return "equip" end
	return "open"
end

-- the free egg: exactly once, and only at its step
function Tutorial.canHatchPromiseEgg(d): boolean
	return not d.Tutorial.EggUsed and Tutorial.current(d, false) == "egg"
end

return Tutorial
