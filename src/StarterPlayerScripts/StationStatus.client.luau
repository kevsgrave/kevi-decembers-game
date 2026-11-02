-- The live line under each station's floating title: restock countdown, fuse progress, rebirth cost and so on.
-- Shows server-owned values only. MapBuilder tags each line "StationStatus" and names its station in an attribute.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local fear = player:WaitForChild("leaderstats"):WaitForChild("Fear")
local getRemote = Net.Function("GetInventory")
local changedRemote = Net.Event("InventoryChanged")

local WHITE, READY = Color3.new(1, 1, 1), Color3.fromRGB(150, 255, 110)

local recipeFrom = {}
for _, r in ipairs(Config.Balance.fusion.recipes) do recipeFrom[r.from] = r end

local inventory = nil
changedRemote.OnClientEvent:Connect(function(state) inventory = state end)
task.spawn(function()
	local ok, state = pcall(getRemote.InvokeServer, getRemote)
	if ok and state and not inventory then inventory = state end
end)

-- the group closest to a fuse, using the same rule as the forge panel: not placed, not favorited, can still grow
local function fuseProgress()
	local counts = {}
	local best, bestNeed = 0, recipeFrom.Normal and recipeFrom.Normal.count or 4
	for _, row in ipairs(inventory and inventory.rows or {}) do
		local recipe = recipeFrom[row.size]
		if recipe and not row.placedIn and not row.favorited then
			local key = table.concat({row.kind, row.tier, row.size, row.mutation or ""}, "|")
			counts[key] = (counts[key] or 0) + 1
			if counts[key] / recipe.count > best / bestNeed then
				best, bestNeed = counts[key], recipe.count
			end
		end
	end
	return math.min(best, bestNeed), bestNeed
end

local function indexProgress()
	local found = 0
	local index = inventory and inventory.index or {}
	for _, m in ipairs(Config.Balance.monsters) do
		if index[m.id] then found += 1 end
	end
	return found, #Config.Balance.monsters
end

local rotation = Config.Balance.shop.rotationSeconds
local LINES = {
	Shop = function()
		local left = rotation - workspace:GetServerTimeNow() % rotation
		return string.format("New stock in %d:%02d", math.floor(left / 60), math.floor(left % 60)), WHITE
	end,
	Egg = function()
		if player:GetAttribute("PromiseEgg") == true then return "A free egg is ready!", READY end
		return Config.short(Config.EGG_COST) .. " Fear", WHITE
	end,
	Fuse = function()
		local have, need = fuseProgress()
		return have .. "/" .. need, if have >= need then READY else WHITE
	end,
	Rebirth = function()
		local cost = player:GetAttribute("RebirthCost") or 0
		if cost < 0 then return "All bedrooms unlocked", READY end
		return Config.short(cost) .. " Fear", if fear.Value >= cost then READY else WHITE
	end,
	Index = function()
		local found, total = indexProgress()
		return found .. "/" .. total .. " found", WHITE
	end,
	Tracker = function()
		local text = player:GetAttribute("TrackerText")
		if text then return text, READY end
		return "No tracker active", WHITE
	end,
}

while true do
	for _, line in CollectionService:GetTagged("StationStatus") do
		local show = LINES[line:GetAttribute("Station")]
		if show then
			line.Text, line.TextColor3 = show()
		end
	end
	task.wait(1)
end
