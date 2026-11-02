-- Plot, room and station checks on the place as it stands in Edit. Runs nothing in the game and changes nothing.
-- Studio command bar: print(require(game.ServerStorage.PlotTests)())
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

return function(): string
	local lines, failed = {}, 0
	local function check(name: string, ok: boolean, detail: string?)
		if not ok then failed += 1 end
		table.insert(lines, `{if ok then "PASS" else "FAIL"}  {name}{if detail then " -> " .. detail else ""}`)
	end

	-- copies, so a Studio session that already required the old modules still tests the current source
	local PlotClaims = require(ServerScriptService.Server.PlotClaims:Clone())
	local PlotLayout = require(ReplicatedStorage.Shared:Clone().PlotLayout)

	-- claims: eight players at once, then every way it can go wrong
	local claims = PlotClaims.new()
	local allClaimed = true
	for i = 1, 8 do
		if not claims:claim("plot" .. i, "player" .. i) then allClaimed = false end
	end
	check("eight players claim eight plots at once", allClaimed)
	local owners = {}
	local unique = true
	for i = 1, 8 do
		local owner = claims.ownerOf["plot" .. i]
		if owners[owner] then unique = false end
		owners[owner] = true
	end
	check("no two owners share a plot", unique)
	local ok, why = claims:claim("plot1", "player9")
	check("a ninth player can't take a claimed plot", ok == false and why == "taken" and claims.ownerOf.plot1 == "player1")
	ok, why = claims:claim("plot9", "player1")
	check("a player can't own two plots", ok == false and why == "already" and claims.plotOf.player1 == "plot1")
	check("release frees the plot and returns it", claims:release("player1") == "plot1" and claims.ownerOf.plot1 == nil and claims.plotOf.player1 == nil)
	check("releasing twice does nothing", claims:release("player1") == nil)
	check("the freed plot can be claimed again", claims:claim("plot1", "player9") == true)
	check("the old owner can claim a different free plot", claims:claim("plot10", "player1") == true)
	local race = PlotClaims.new()
	local first, second = race:claim("plot1", "a"), race:claim("plot1", "b")
	check("of two requests for one plot, only the first wins", first == true and second == false and race.ownerOf.plot1 == "a")

	-- floors as data
	check("bedroom 7 is floor 2 bay 1", PlotLayout.floorOf(7) == 2 and PlotLayout.bayOf(7) == 1 and PlotLayout.slotId(7) == "F2-B1")
	check("bedroom 6 is floor 1 bay 6", PlotLayout.floorOf(6) == 1 and PlotLayout.bayOf(6) == 6)
	check("floor 2 bay 3 is bedroom 9", PlotLayout.bedroomIndex(2, 3) == 9)
	check("floor 2 appears at 6 rooms, not before", PlotLayout.floorsVisible(5) == 1 and PlotLayout.floorsVisible(6) == 2)
	check("floors stop at the cap", PlotLayout.floorsVisible(PlotLayout.MAX_BEDROOMS + 6) == 3)
	check("floor 1 sits at height 0", PlotLayout.floorHeight(1) == 0 and PlotLayout.floorHeight(2) > 0)

	-- the bedroom template
	local bedrooms = ServerStorage.PlotTemplate.Bedrooms
	check("six bays", #bedrooms:GetChildren() == 6)
	local left, right = 0, 0
	for i = 1, 6 do
		local b = bedrooms:FindFirstChild("Bedroom" .. i)
		if not b then
			check(`Bedroom{i} exists`, false)
			continue
		end
		local mid = b.RoomFloor.Position
		local side = math.sign(mid.X)
		if side < 0 then left += 1 else right += 1 end
		check(`Bedroom{i} is on the side its number says`, PlotLayout.sideOf(i) == if side < 0 then "left" else "right")
		-- facing the room from the aisle
		local viewerRight = Vector3.new(side, 0, 0):Cross(Vector3.new(0, 1, 0))
		check(`Bedroom{i} glass left, window right`, (b.ShowcaseGlass.Position - mid):Dot(viewerRight) < 0 and (b.Window.Position - mid):Dot(viewerRight) > 0)
		check(`Bedroom{i} floor is large`, b.RoomFloor.Size.X >= 28 and b.RoomFloor.Size.Z >= 28)
		local lamp = b.Lamp:FindFirstChildWhichIsA("PointLight", true)
		check(`Bedroom{i} nightlight is dim`, lamp ~= nil and lamp.Brightness <= 1)
		check(`Bedroom{i} has crawl hole and place prompts`, b.CrawlHole:FindFirstChild("ScarePrompt") ~= nil and b.ShowcaseGlass:FindFirstChild("PlacePrompt") ~= nil)
		check(`Bedroom{i} has a lock sign`, b.Lock:FindFirstChildWhichIsA("SurfaceGui") ~= nil)
	end
	check("three rooms each side of the aisle", left == 3 and right == 3)

	-- the plots as they stand before anyone claims
	local plots = workspace.Plots:GetChildren()
	check("eight plots", #plots == 8)
	local BLUE_MIN = 0.7
	for _, plot in plots do
		check(`{plot.Name} is empty and unowned`, #plot.Contents:GetChildren() == 0 and plot.OwnerSign:FindFirstChildWhichIsA("SurfaceGui").Text.Text == "Free plot")
		check(`{plot.Name} floor is blue and studded`, plot.Floor.Color.B >= BLUE_MIN and plot.Floor:FindFirstChildOfClass("Texture") ~= nil)
		check(`{plot.Name} has a pink carpet`, plot.Carpet.Color.R > 0.9 and plot.Carpet.Color.G < 0.5)
		check(`{plot.Name} frame is set`, typeof(plot:GetAttribute("Frame")) == "CFrame")
		check(`{plot.Name} has an arrival point`, plot:FindFirstChild("SpawnPoint") ~= nil)
	end

	-- spawn and hub
	local spawns = {}
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") then table.insert(spawns, d) end
	end
	check("exactly one spawn", #spawns == 1)
	local spawn = spawns[1]
	if spawn then
		check("spawn is neutral and hidden", spawn.Neutral and spawn.Transparency == 1 and spawn:FindFirstChildWhichIsA("Decal") == nil)
		check("spawn is in the hub, on no plot", not spawn:IsDescendantOf(workspace.Plots) and spawn.Position.Magnitude < 50)
	end
	check("egg with hatch prompt", workspace.Hub.Egg:FindFirstChild("HatchPrompt") ~= nil)
	check("shop stall", workspace.Hub:FindFirstChild("ShopStall") ~= nil)
	local stations = workspace:FindFirstChild("Stations")
	check("stations built", stations ~= nil)
	if stations then
		check("fusing sign", stations:FindFirstChild("FusingSign") ~= nil)
		check("the book has its prompt", stations:FindFirstChild("IndexSpot") ~= nil and stations.IndexSpot:FindFirstChild("IndexPrompt") ~= nil)
		local fuseSpot = stations:FindFirstChild("FuseSpot")
		check("the fuse machine has its prompt", fuseSpot ~= nil and fuseSpot:FindFirstChild("FusePrompt") ~= nil)
		local shopSpot = stations:FindFirstChild("ShopClaim")
		check("the shop has its prompt", shopSpot ~= nil and shopSpot:FindFirstChild("ShopPrompt") ~= nil)
		local pad = stations:FindFirstChild("RebirthPad")
		check("rebirth station has its prompt", pad ~= nil and pad:FindFirstChild("RebirthPrompt") ~= nil)
		local ghosts = 0
		for _, c in stations:GetChildren() do
			if c.Name == "Ghost" then ghosts += 1 end
		end
		check("floating ghosts", ghosts >= 8)
		local camp = stations:FindFirstChild("DigCampSpot")
		check("the dig camp has its prompt", camp ~= nil and camp:FindFirstChild("TrackerPrompt") ~= nil)
		-- every station's floating title has a live line the client knows how to fill
		local CollectionService = game:GetService("CollectionService")
		local seen = {}
		for _, line in CollectionService:GetTagged("StationStatus") do
			seen[line:GetAttribute("Station")] = true
		end
		for _, name in {"Shop", "Egg", "Fuse", "Rebirth", "Index", "Tracker"} do
			check(name .. " has a live status line", seen[name] == true)
		end
		-- ghosts: every variant is well made, with a face, and stays close to home while moving
		local Motion = require(game:GetService("ReplicatedStorage").Shared:WaitForChild("MapMotion"))
		local tagged = CollectionService:GetTagged("Ghost")
		check("many ghosts move", #tagged >= 25)
		local badGhosts = 0
		for _, ghost in tagged do
			local home, drift = ghost:GetAttribute("Home"), ghost:GetAttribute("Drift") or 0
			if not home or not ghost:FindFirstChild("Head") then
				badGhosts += 1
			else
				for t = 0, 60, 5 do
					if (Motion.ghost(home, t, ghost:GetAttribute("Phase") or 0, drift).Position - home.Position).Magnitude > drift * 1.5 + 1 then badGhosts += 1 end
				end
			end
		end
		check("ghosts stay close to home", badGhosts == 0, tostring(badGhosts))
		check("a glow never goes fully see-through", Motion.pulse(0.1, 2, 1) < 0.8 and Motion.pulse(0, 0, 1) >= 0)
		check("ghost blinks are brief", not Motion.blinking(1, 0) and Motion.blinking(0, 0))
		local badMeshes = 0
		for _, f in {workspace.Hub, stations, workspace:FindFirstChild("World"), workspace:FindFirstChild("Scenery"), workspace:FindFirstChild("Paths"), workspace:FindFirstChild("Ground")} do
			for _, d in f:GetDescendants() do
				if d:IsA("MeshPart") then badMeshes += 1 end
			end
		end
		check("the map is parts only, no generated meshes", badMeshes == 0, tostring(badMeshes))
	end
	local nodes = workspace:FindFirstChild("DigNodes")
	check("tracker dig spots exist", nodes ~= nil and #nodes:GetChildren() >= 12)
	if nodes then
		local blocked = {}
		for _, node in nodes:GetChildren() do
			for _, part in workspace:GetPartBoundsInRadius(node.Position + Vector3.new(0, 3, 0), 5) do
				if part.CanCollide and part.Name ~= "Tile" and part ~= workspace:FindFirstChild("Baseplate") then
					table.insert(blocked, node.Name .. " by " .. part:GetFullName())
				end
			end
		end
		check("every dig spot is clear to stand on", #blocked == 0, table.concat(blocked, ", "))
	end
	local lighting = game:GetService("Lighting")
	check("no pumpkins or other Halloween props left", (function()
		for _, d in workspace:GetDescendants() do
			local n = d.Name:lower()
			if n:find("pumpkin") or n:find("cauldron") or n:find("scarecrow") or n:find("witch") then return false end
		end
		return true
	end)())
	check("the ground is built", workspace:FindFirstChild("Ground") ~= nil and #workspace.Ground:GetChildren() > 500)
	check("a misty late afternoon", lighting.ClockTime > 12 and lighting.ClockTime < 19)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
