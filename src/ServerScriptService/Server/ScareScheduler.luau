-- One scheduler for every room's automatic scares: Sleeping -> Scaring -> Paying -> Resetting -> Sleeping.
-- It's driven by one loop rather than one per room. Time is passed in and nothing yields, so tests can run it without Studio.
-- hooks.begin(id) starts the scare and returns the seconds until it lands.
-- hooks.pay(id) pays and returns true, or false if this scare isn't valid. hooks.reset(id) must not yield.
local ScareScheduler = {}
ScareScheduler.__index = ScareScheduler

function ScareScheduler.new(hooks)
	return setmetatable({hooks = hooks, rooms = {}}, ScareScheduler)
end

-- the first scare starts on the next tick; adding a room again restarts its cycle
function ScareScheduler:add(id, interval: number, now: number)
	self.rooms[id] = {state = "Sleeping", interval = interval, nextAt = now}
end

-- removing a room is what stops it paying, even with a scare in progress
function ScareScheduler:remove(id)
	self.rooms[id] = nil
end

function ScareScheduler:stateOf(id): string?
	local room = self.rooms[id]
	return room and room.state
end

-- runs one hook without letting an error in one room stop the others
function ScareScheduler:call(name: string, id): any
	local ok, result = pcall(self.hooks[name], id)
	if not ok then warn(`[ScareScheduler] {name} failed: {result}`) end
	return ok and result
end

function ScareScheduler:tick(now: number)
	for id, room in self.rooms do
		if now >= room.nextAt then
			if room.state == "Sleeping" then
				room.state = "Scaring"
				-- keep to the due time so the tick length can't stretch a 15s scare, but after a server stall start from now, so it can't cause a burst of payouts
				room.startedAt = if now - room.nextAt < room.interval then room.nextAt else now
				room.nextAt = now + (self:call("begin", id) or 0)
			end
			-- begin may have removed the room, and a scare that lands right away pays on this tick
			if self.rooms[id] == room and room.state == "Scaring" and now >= room.nextAt then
				room.state = "Paying"
				if self:call("pay", id) and self.rooms[id] == room then
					room.state = "Resetting"
					self:call("reset", id)
				end
				if self.rooms[id] == room then
					room.state = "Sleeping"
					room.nextAt = room.startedAt + room.interval
				end
			end
		end
	end
end

return ScareScheduler
