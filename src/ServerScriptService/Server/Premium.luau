-- Robux products, for when the owner has real ones. Balance.premium.products is empty, so today nothing here runs and no
-- Robux interface exists. Each receipt is granted once ever, however many times Roblox retries it.
-- Only guaranteed Fear packs are supported: no paid randomness, and no transfer of game pass ownership, which Roblox doesn't allow.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Premium = {}

function Premium.configured(): boolean
	return next(Config.Balance.premium.products) ~= nil
end

function Premium.product(productId: number)
	for _, product in Config.Balance.premium.products do
		if product.productId == productId then return product end
	end
	return nil
end

-- Returns "granted", "already" or "unknown". The receipt and the reward change together.
function Premium.grant(d, receiptId: string, product): string
	if not product then return "unknown" end
	if d.Receipts[receiptId] then return "already" end
	d.Receipts[receiptId] = true
	d.Fear = math.min(d.Fear + product.grantFear, Config.MAX_FEAR)
	return "granted"
end

return Premium
