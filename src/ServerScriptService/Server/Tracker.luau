-- Trackers: Owned -> Activated at a private dig spot -> dug, which turns the tracker into a saved egg.
-- An abandoned dig goes back to Owned, so a paid tracker is never lost. Works on a save table with no yields.
-- GameService checks the digger's real distance; only this player's own save can ever hold their dig.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local B = Config.Balance.trackers

local Tracker = {}

function Tracker.add(d): string
	local uid = "t" .. d.NextUid
	d.NextUid += 1
	d.Trackers[uid] = {State = "Owned"}
	return uid
end

-- the one dig in progress, if any
function Tracker.active(d): (string?, any)
	for uid, t in d.Trackers do
		if t.State == "Activated" then return uid, t end
	end
	return nil
end

-- reserves a dig spot, picked by the server. One at a time. Returns true, or false and why.
function Tracker.activate(d, uid: string, nodeNames: {string}, r: number, now: number): (boolean, string?)
	local t = d.Trackers[uid]
	if not t or t.State ~= "Owned" then return false, "missing" end
	if Tracker.active(d) then return false, "busy" end
	if #nodeNames == 0 then return false, "noSpots" end
	t.State = "Activated"
	t.Node = nodeNames[math.clamp(math.floor(r * #nodeNames) + 1, 1, #nodeNames)]
	t.ExpiresAt = now + B.digExpireSeconds
	return true
end

-- Abandoned digs go back to Owned. A spot that no longer exists does too, so nothing is stuck after a map update.
-- Returns true if anything changed.
function Tracker.tidy(d, nodeExists: (string) -> boolean, now: number): boolean
	local changed = false
	for _, t in d.Trackers do
		if t.State == "Activated" and ((t.ExpiresAt or 0) <= now or not nodeExists(t.Node)) then
			t.State, t.Node, t.ExpiresAt = "Owned", nil, nil
			changed = true
		end
	end
	return changed
end

-- finishes the dig: the tracker is used up and the egg is saved, together, so it can't pay twice. Returns the egg's uid or nil.
function Tracker.dig(d, uid: string, now: number): string?
	local t = d.Trackers[uid]
	if not t or t.State ~= "Activated" or (t.ExpiresAt or 0) <= now then return nil end
	d.Trackers[uid] = nil
	local eggUid = "e" .. d.NextUid
	d.NextUid += 1
	d.Eggs[eggUid] = B.rewardEgg
	return eggUid
end

return Tracker
