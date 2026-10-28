-- From the LihFolk vault, "Saved Inventory End to End" 3.2.
-- RateLimiter.new(capacity, refillPerSecond) returns allow(player): boolean.
local Players = game:GetService("Players")

type Bucket = { Tokens: number, Updated: number }

local RateLimiter = {}
local allBuckets: { { [Player]: Bucket } } = {}

function RateLimiter.new(capacity: number, refillPerSecond: number): (Player) -> boolean
	local buckets: { [Player]: Bucket } = {}
	table.insert(allBuckets, buckets)
	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { Tokens = capacity, Updated = now }
			buckets[player] = bucket
		end
		bucket.Tokens = math.min(capacity, bucket.Tokens + (now - bucket.Updated) * refillPerSecond)
		bucket.Updated = now
		if bucket.Tokens < 1 then
			return false
		end
		bucket.Tokens -= 1
		return true
	end
end

-- One cleanup for every limiter, so leaving players do not leak buckets.
Players.PlayerRemoving:Connect(function(player: Player)
	for _, buckets in allBuckets do
		buckets[player] = nil
	end
end)

return RateLimiter
