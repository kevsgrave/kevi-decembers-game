-- Where each bedroom number lives across floors, worked out from Balance. Phase 7 builds floors from this.
-- Saves use the bedroom number as the stable slot: 1-6 is floor 1, 7-12 floor 2. Odd bays are on the left of the aisle.
local Config = require(script.Parent.Config)

local rebirth = Config.Balance.rebirth
local PER_FLOOR = rebirth.bedroomsPerFloor

local PlotLayout = {}

PlotLayout.MAX_BEDROOMS = PER_FLOOR * rebirth.floorCap

function PlotLayout.floorOf(index: number): number return math.ceil(index / PER_FLOOR) end
function PlotLayout.bayOf(index: number): number return (index - 1) % PER_FLOOR + 1 end
function PlotLayout.bedroomIndex(floor: number, bay: number): number return (floor - 1) * PER_FLOOR + bay end
function PlotLayout.sideOf(index: number): string return if index % 2 == 1 then "left" else "right" end
function PlotLayout.slotId(index: number): string return `F{PlotLayout.floorOf(index)}-B{PlotLayout.bayOf(index)}` end

-- studs above floor 1, for lifting a copy of the bedroom template
function PlotLayout.floorHeight(floor: number): number return (floor - 1) * rebirth.floorHeight end

-- a new floor appears as soon as the one below is fully unlocked, up to the cap
function PlotLayout.floorsVisible(unlocked: number): number
	return math.min(rebirth.floorCap, math.floor(unlocked / PER_FLOOR) + 1)
end

return PlotLayout
