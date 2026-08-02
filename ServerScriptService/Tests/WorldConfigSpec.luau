--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.TestRunner)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)

local expectedRoot = {
	BeachObby = "BeachObby",
	World = "World",
	Environment = "Environment",
}

local expectedScenes = {
	HotBeach = "Scene01_HotBeach",
	Water = "Scene02_Water",
	LaserIsland = "Scene03_LaserIsland",
	PalmFinish = "Scene04_PalmFinish",
}

local expectedShared = {
	SharedEnvironment = "SharedEnvironment",
}

local expectedEnvironment = {
	OceanSurface = "OceanSurface",
	OceanKill = "OceanKill",
}

local expectedCommonFolders = {
	Start = "Start",
	Geometry = "Geometry",
	Hazards = "Hazards",
	MovementPaths = "MovementPaths",
	Coins = "Coins",
	Triggers = "Triggers",
}

local expectedGroups = {
	Root = expectedRoot,
	Scenes = expectedScenes,
	Shared = expectedShared,
	Environment = expectedEnvironment,
	CommonFolders = expectedCommonFolders,
}

local function countKeys(values: { [string]: string }): number
	local count = 0

	for _ in values do
		count += 1
	end

	return count
end

local function assertGroupMatches(actual: { [string]: string }, expected: { [string]: string })
	TestRunner.assertEqual(countKeys(actual), countKeys(expected))

	for name, expectedValue in expected do
		TestRunner.assertEqual(actual[name], expectedValue)
	end
end

local function assertValuesUnique(values: { [string]: string })
	local seen = {}

	for _, value in values do
		TestRunner.assertFalse(seen[value] == true, string.format("Duplicate value %q", value))
		seen[value] = true
	end
end

TestRunner.test("WorldConfig root table is frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig))
end)

TestRunner.test("WorldConfig nested tables are frozen", function()
	for groupName in expectedGroups do
		TestRunner.assertTrue(table.isfrozen(WorldConfig[groupName]), string.format("%s must be frozen", groupName))
	end
end)

TestRunner.test("WorldConfig Root contains exactly the expected names", function()
	assertGroupMatches(WorldConfig.Root, expectedRoot)
	TestRunner.assertTrue((WorldConfig.Root :: any).VerticalSlice == nil)
end)

TestRunner.test("WorldConfig Scenes contains exactly four expected names", function()
	assertGroupMatches(WorldConfig.Scenes, expectedScenes)
	TestRunner.assertEqual(countKeys(WorldConfig.Scenes), 4)
end)

TestRunner.test("WorldConfig scene names are unique", function()
	assertValuesUnique(WorldConfig.Scenes)
end)

TestRunner.test("WorldConfig SharedEnvironment has the expected name", function()
	assertGroupMatches(WorldConfig.Shared, expectedShared)
	assertGroupMatches(WorldConfig.Environment, expectedEnvironment)
	TestRunner.assertEqual(countKeys(WorldConfig.Environment), 2)
end)

TestRunner.test("WorldConfig CommonFolders contains exactly the expected names", function()
	assertGroupMatches(WorldConfig.CommonFolders, expectedCommonFolders)
end)

TestRunner.test("WorldConfig common folder names are unique", function()
	assertValuesUnique(WorldConfig.CommonFolders)
end)

TestRunner.test("WorldConfig required values are non-empty strings", function()
	for groupName, expectedGroup in expectedGroups do
		local actualGroup = WorldConfig[groupName]
		TestRunner.assertFalse(actualGroup == nil, string.format("%s is required", groupName))

		for name in expectedGroup do
			local value = actualGroup[name]
			TestRunner.assertTrue(typeof(value) == "string", string.format("%s.%s must be a string", groupName, name))
			TestRunner.assertTrue(value ~= "", string.format("%s.%s must not be empty", groupName, name))
		end
	end
end)

TestRunner.test("WorldConfig rejects changing an existing value", function()
	TestRunner.assertError(function()
		WorldConfig.Root.BeachObby = "Changed"
	end)
	TestRunner.assertError(function()
		WorldConfig.Environment.OceanKill = "Changed"
	end)
	TestRunner.assertEqual(WorldConfig.Root.BeachObby, "BeachObby")
	TestRunner.assertEqual(WorldConfig.Environment.OceanKill, "OceanKill")
end)

TestRunner.test("WorldConfig rejects adding a new value", function()
	TestRunner.assertError(function()
		(WorldConfig.Root :: any).NewValue = "NewValue"
	end)
	TestRunner.assertTrue((WorldConfig.Root :: any).NewValue == nil)
end)

local function assertArrayUnique(values: { string })
	local seen: { [string]: boolean } = {}

	for _, value in values do
		TestRunner.assertFalse(seen[value] == true, string.format("Duplicate value %q", value))
		seen[value] = true
	end
end

TestRunner.test("WorldConfig HotBeach table is frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.HotBeach))
end)

TestRunner.test("WorldConfig HotBeach LoungeNames are frozen and unique", function()
	local names = WorldConfig.HotBeach.LoungeNames
	TestRunner.assertTrue(table.isfrozen(names))
	TestRunner.assertEqual(#names, 7)
	assertArrayUnique(names)

	for index = 1, 7 do
		TestRunner.assertEqual(names[index], string.format("Lounge%02d", index))
	end
end)

TestRunner.test("WorldConfig HotBeach RunnerNames are frozen and unique", function()
	local names = WorldConfig.HotBeach.RunnerNames
	TestRunner.assertTrue(table.isfrozen(names))
	TestRunner.assertEqual(#names, 3)
	assertArrayUnique(names)

	for index = 1, 3 do
		TestRunner.assertEqual(names[index], string.format("Runner%02d", index))
	end
end)

TestRunner.test("WorldConfig HotBeach CoinIds are frozen and unique", function()
	local coinIds = WorldConfig.HotBeach.CoinIds
	TestRunner.assertTrue(table.isfrozen(coinIds))
	TestRunner.assertEqual(#coinIds, 4)
	assertArrayUnique(coinIds)
end)

TestRunner.test("WorldConfig HotBeach CoinIds contain the expected stable IDs", function()
	local expected = { "DemoCoin", "HotBeachCoin01", "HotBeachCoin02", "HotBeachCoin03" }

	for index, expectedId in expected do
		TestRunner.assertEqual(WorldConfig.HotBeach.CoinIds[index], expectedId)
	end
end)

TestRunner.test("WorldConfig HotBeach WaterStart checkpoint ID is stable", function()
	TestRunner.assertEqual(WorldConfig.HotBeach.StartSpawn, "StartSpawn")
	TestRunner.assertEqual(WorldConfig.HotBeach.StartLine, "StartLine")
	TestRunner.assertEqual(WorldConfig.HotBeach.WaterStartCheckpoint, "WaterStartCheckpoint")
	TestRunner.assertEqual(WorldConfig.HotBeach.WaterStartCheckpointId, "WaterStart")
end)

TestRunner.test("WorldConfig HotBeach values are non-empty strings", function()
	local hotBeach = WorldConfig.HotBeach
	local stableNames = {
		hotBeach.SceneFootprint,
		hotBeach.HotSandVisual,
		hotBeach.HotSandHazard,
		hotBeach.LoungersFolder,
		hotBeach.StickFiguresFolder,
		hotBeach.StartSpawn,
		hotBeach.StartLine,
		hotBeach.WaterStartCheckpoint,
		hotBeach.WaterStartCheckpointId,
	}

	for _, value in stableNames do
		TestRunner.assertTrue(typeof(value) == "string")
		TestRunner.assertTrue(value ~= "")
	end

	for _, values in { hotBeach.LoungeNames, hotBeach.RunnerNames, hotBeach.CoinIds } do
		for _, value in values do
			TestRunner.assertTrue(typeof(value) == "string")
			TestRunner.assertTrue(value ~= "")
		end
	end
end)

TestRunner.test("WorldConfig HotBeach rejects changing or adding values", function()
	TestRunner.assertError(function()
		WorldConfig.HotBeach.WaterStartCheckpointId = "Changed"
	end)
	TestRunner.assertError(function()
		WorldConfig.HotBeach.LoungeNames[1] = "Changed"
	end)
	TestRunner.assertError(function()
		(WorldConfig.HotBeach :: any).NewValue = "NewValue"
	end)
	TestRunner.assertEqual(WorldConfig.HotBeach.WaterStartCheckpointId, "WaterStart")
	TestRunner.assertEqual(WorldConfig.HotBeach.LoungeNames[1], "Lounge01")
	TestRunner.assertTrue((WorldConfig.HotBeach :: any).NewValue == nil)
end)

TestRunner.test("WorldConfig MovingHazards tables are frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.MovingHazards))
	TestRunner.assertTrue(table.isfrozen(WorldConfig.MovingHazards.Runners))
	for _, entry in WorldConfig.MovingHazards.Runners do
		TestRunner.assertTrue(table.isfrozen(entry))
	end
end)

TestRunner.test("WorldConfig MovingHazards defines exactly three runners", function()
	TestRunner.assertEqual(#WorldConfig.MovingHazards.Runners, 3)
end)

TestRunner.test("WorldConfig moving runner identities are unique", function()
	local ids: { string } = {}
	local modelNames: { string } = {}
	for _, entry in WorldConfig.MovingHazards.Runners do
		table.insert(ids, entry.Id)
		table.insert(modelNames, entry.ModelName)
	end
	assertArrayUnique(ids)
	assertArrayUnique(modelNames)
end)

TestRunner.test("WorldConfig moving runner names are non-empty strings", function()
	for _, entry in WorldConfig.MovingHazards.Runners do
		for _, value in { entry.Id, entry.SceneName, entry.ModelName, entry.StartMarkerName, entry.EndMarkerName } do
			TestRunner.assertTrue(typeof(value) == "string")
			TestRunner.assertTrue(value ~= "")
		end
	end
end)

TestRunner.test("WorldConfig moving runner durations are positive", function()
	for _, entry in WorldConfig.MovingHazards.Runners do
		TestRunner.assertTrue(typeof(entry.OneWayDurationSeconds) == "number")
		TestRunner.assertTrue(entry.OneWayDurationSeconds > 0)
	end
end)

TestRunner.test("WorldConfig moving runner phases are normalized", function()
	for _, entry in WorldConfig.MovingHazards.Runners do
		TestRunner.assertTrue(typeof(entry.PhaseOffset) == "number")
		TestRunner.assertTrue(entry.PhaseOffset >= 0)
		TestRunner.assertTrue(entry.PhaseOffset < 1)
	end
end)

TestRunner.test("WorldConfig moving runners do not all share one schedule", function()
	local first = WorldConfig.MovingHazards.Runners[1]
	local differs = false
	for index = 2, #WorldConfig.MovingHazards.Runners do
		local entry = WorldConfig.MovingHazards.Runners[index]
		if entry.PhaseOffset ~= first.PhaseOffset or entry.OneWayDurationSeconds ~= first.OneWayDurationSeconds then
			differs = true
		end
	end
	TestRunner.assertTrue(differs)
end)

TestRunner.test("WorldConfig rejects changing or extending MovingHazards", function()
	local entry = WorldConfig.MovingHazards.Runners[1]
	TestRunner.assertError(function()
		entry.OneWayDurationSeconds = 1
	end)
	TestRunner.assertError(function()
		(WorldConfig.MovingHazards.Runners :: any)[4] = entry
	end)
	TestRunner.assertError(function()
		(WorldConfig.MovingHazards :: any).NewValue = "NewValue"
	end)
	TestRunner.assertEqual(entry.OneWayDurationSeconds, 6)
	TestRunner.assertEqual(#WorldConfig.MovingHazards.Runners, 3)
	TestRunner.assertTrue((WorldConfig.MovingHazards :: any).NewValue == nil)
end)

TestRunner.test("WorldConfig MovingHazards defines two frozen sharks", function()
	local sharks = WorldConfig.MovingHazards.Sharks
	TestRunner.assertTrue(typeof(sharks) == "table")
	TestRunner.assertTrue(table.isfrozen(sharks))
	TestRunner.assertEqual(#sharks, 2)

	for _, entry in sharks do
		TestRunner.assertTrue(table.isfrozen(entry))
	end
end)

TestRunner.test("WorldConfig shark entries retain their stable contract", function()
	local expected = {
		{
			Id = "Shark01",
			SceneName = "Scene02_Water",
			ModelName = "Shark01",
			StartMarkerName = "Shark01_Start",
			EndMarkerName = "Shark01_End",
			OneWayDurationSeconds = 6,
			PhaseOffset = 0.1,
		},
		{
			Id = "Shark02",
			SceneName = "Scene02_Water",
			ModelName = "Shark02",
			StartMarkerName = "Shark02_Start",
			EndMarkerName = "Shark02_End",
			OneWayDurationSeconds = 6,
			PhaseOffset = 0.35,
		},
	}

	for index, contract in expected do
		local entry = WorldConfig.MovingHazards.Sharks[index]
		for fieldName, expectedValue in contract do
			TestRunner.assertEqual(entry[fieldName], expectedValue)
		end
	end
end)

TestRunner.test("WorldConfig moving hazard identities are unique across runners and sharks", function()
	local ids: { string } = {}
	local modelNames: { string } = {}
	for _, entries in { WorldConfig.MovingHazards.Runners, WorldConfig.MovingHazards.Sharks } do
		for _, entry in entries do
			table.insert(ids, entry.Id)
			table.insert(modelNames, entry.ModelName)
		end
	end
	assertArrayUnique(ids)
	assertArrayUnique(modelNames)
end)

TestRunner.test("WorldConfig shark marker names are non-empty and unique", function()
	local markerNames: { string } = {}
	for _, entry in WorldConfig.MovingHazards.Sharks do
		for _, markerName in { entry.StartMarkerName, entry.EndMarkerName } do
			TestRunner.assertTrue(typeof(markerName) == "string")
			TestRunner.assertTrue(markerName ~= "")
			table.insert(markerNames, markerName)
		end
	end
	assertArrayUnique(markerNames)
end)

TestRunner.test("WorldConfig shark timing is valid and asynchronous", function()
	local first = WorldConfig.MovingHazards.Sharks[1]
	local second = WorldConfig.MovingHazards.Sharks[2]
	for _, entry in WorldConfig.MovingHazards.Sharks do
		TestRunner.assertTrue(entry.OneWayDurationSeconds > 0)
		TestRunner.assertTrue(entry.PhaseOffset >= 0)
		TestRunner.assertTrue(entry.PhaseOffset < 1)
	end
	TestRunner.assertTrue(
		first.PhaseOffset ~= second.PhaseOffset or first.OneWayDurationSeconds ~= second.OneWayDurationSeconds
	)
	if first.OneWayDurationSeconds == second.OneWayDurationSeconds then
		local phaseDifference = (second.PhaseOffset - first.PhaseOffset) % 1
		TestRunner.assertTrue(math.abs(phaseDifference - 0.5) > 0.001)
	end
end)

TestRunner.test("WorldConfig rejects changing or extending sharks", function()
	local sharks = WorldConfig.MovingHazards.Sharks
	TestRunner.assertError(function()
		sharks[1].PhaseOffset = 0
	end)
	TestRunner.assertError(function()
		(sharks :: any)[3] = sharks[1]
	end)
	TestRunner.assertEqual(sharks[1].PhaseOffset, 0.1)
	TestRunner.assertEqual(sharks[2].PhaseOffset, 0.35)
	TestRunner.assertEqual(#sharks, 2)
end)

TestRunner.test("WorldConfig runner timing remains unchanged", function()
	local expectedPhases = { 0, 0.2, 0.55 }
	for index, entry in WorldConfig.MovingHazards.Runners do
		TestRunner.assertEqual(entry.Id, string.format("Runner%02d", index))
		TestRunner.assertEqual(entry.OneWayDurationSeconds, 6)
		TestRunner.assertEqual(entry.PhaseOffset, expectedPhases[index])
	end
end)

TestRunner.test("WorldConfig Water table is frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.Water))
end)

TestRunner.test("WorldConfig Water RingNames are frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.Water.RingNames))
end)

TestRunner.test("WorldConfig Water CoinIds are frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.Water.CoinIds))
end)

TestRunner.test("WorldConfig Water defines exactly eight rings", function()
	TestRunner.assertEqual(#WorldConfig.Water.RingNames, 8)
	for index = 1, 8 do
		TestRunner.assertEqual(WorldConfig.Water.RingNames[index], string.format("Ring%02d", index))
	end
end)

TestRunner.test("WorldConfig Water ring names are unique", function()
	assertArrayUnique(WorldConfig.Water.RingNames)
end)

TestRunner.test("WorldConfig Water defines exactly four CoinIds", function()
	TestRunner.assertEqual(#WorldConfig.Water.CoinIds, 4)
	for index = 1, 4 do
		TestRunner.assertEqual(WorldConfig.Water.CoinIds[index], string.format("WaterCoin%02d", index))
	end
end)

TestRunner.test("WorldConfig Water CoinIds are unique", function()
	assertArrayUnique(WorldConfig.Water.CoinIds)
end)

TestRunner.test("WorldConfig Water and HotBeach CoinIds do not overlap", function()
	local hotBeachIds: { [string]: boolean } = {}
	for _, coinId in WorldConfig.HotBeach.CoinIds do
		hotBeachIds[coinId] = true
	end
	for _, coinId in WorldConfig.Water.CoinIds do
		TestRunner.assertFalse(hotBeachIds[coinId] == true)
	end
end)

TestRunner.test("WorldConfig Water checkpoint ID is stable", function()
	TestRunner.assertEqual(WorldConfig.Water.LaserIslandStartCheckpoint, "LaserIslandStartCheckpoint")
	TestRunner.assertEqual(WorldConfig.Water.LaserIslandStartCheckpointId, "LaserIslandStart")
	TestRunner.assertFalse(WorldConfig.Water.LaserIslandStartCheckpointId == WorldConfig.HotBeach.WaterStartCheckpointId)
end)

TestRunner.test("WorldConfig Water names are non-empty strings", function()
	local water = WorldConfig.Water
	for _, value in {
		water.SceneFootprint,
		water.WaterSurface,
		water.RingsFolder,
		water.SharksFolder,
		water.LaserIslandStartCheckpoint,
		water.LaserIslandStartCheckpointId,
	} do
		TestRunner.assertTrue(typeof(value) == "string")
		TestRunner.assertTrue(value ~= "")
	end
	local fieldCount = 0
	for _ in water do fieldCount += 1 end
	TestRunner.assertEqual(fieldCount, 8)
	TestRunner.assertTrue((water :: any).WaterKillPlane == nil)
	for _, values in { water.RingNames, water.CoinIds } do
		for _, value in values do
			TestRunner.assertTrue(typeof(value) == "string")
			TestRunner.assertTrue(value ~= "")
		end
	end
end)

TestRunner.test("WorldConfig rejects changing Water values", function()
	TestRunner.assertError(function()
		WorldConfig.Water.LaserIslandStartCheckpointId = "Changed"
	end)
	TestRunner.assertError(function()
		WorldConfig.Water.RingNames[1] = "Changed"
	end)
	TestRunner.assertEqual(WorldConfig.Water.LaserIslandStartCheckpointId, "LaserIslandStart")
	TestRunner.assertEqual(WorldConfig.Water.RingNames[1], "Ring01")
end)

TestRunner.test("WorldConfig rejects extending Water values", function()
	TestRunner.assertError(function()
		(WorldConfig.Water :: any).NewValue = "NewValue"
	end)
	TestRunner.assertError(function()
		(WorldConfig.Water.CoinIds :: any)[5] = "WaterCoin05"
	end)
	TestRunner.assertTrue((WorldConfig.Water :: any).NewValue == nil)
	TestRunner.assertEqual(#WorldConfig.Water.CoinIds, 4)
end)

TestRunner.test("WorldConfig LaserIsland tables are frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.LaserIsland))
	TestRunner.assertTrue(table.isfrozen(WorldConfig.LaserIsland.CoinIds))
end)

TestRunner.test("WorldConfig LaserIsland retains the approved stable names", function()
	local laserIsland = WorldConfig.LaserIsland
	TestRunner.assertEqual(laserIsland.IslandBase, "IslandBase")
	TestRunner.assertEqual(laserIsland.CenterSphere, "CenterSphere")
	TestRunner.assertEqual(laserIsland.LaserAssembly, "LaserAssembly")
	TestRunner.assertEqual(laserIsland.LaserBar, "LaserBar")
	TestRunner.assertEqual(laserIsland.PalmBaseCheckpoint, "PalmBaseCheckpoint")
	TestRunner.assertEqual(laserIsland.PalmBaseCheckpointId, "PalmBase")
end)

TestRunner.test("WorldConfig LaserIsland defines five unique CoinIds", function()
	local coinIds = WorldConfig.LaserIsland.CoinIds
	TestRunner.assertEqual(#coinIds, 5)
	for index, coinId in coinIds do
		TestRunner.assertEqual(coinId, string.format("LaserIslandCoin%02d", index))
	end
	assertArrayUnique(coinIds)
end)

TestRunner.test("WorldConfig LaserIsland CoinIds do not overlap prior scenes", function()
	local prior: { [string]: boolean } = {}
	for _, ids in { WorldConfig.HotBeach.CoinIds, WorldConfig.Water.CoinIds } do
		for _, id in ids do prior[id] = true end
	end
	for _, id in WorldConfig.LaserIsland.CoinIds do
		TestRunner.assertFalse(prior[id] == true)
	end
end)

TestRunner.test("WorldConfig RotatingHazards defines one frozen laser", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.RotatingHazards))
	TestRunner.assertTrue(table.isfrozen(WorldConfig.RotatingHazards.Lasers))
	TestRunner.assertEqual(#WorldConfig.RotatingHazards.Lasers, 1)
	TestRunner.assertTrue(table.isfrozen(WorldConfig.RotatingHazards.Lasers[1]))
end)

TestRunner.test("WorldConfig rotating laser retains the approved contract", function()
	local entry = WorldConfig.RotatingHazards.Lasers[1]
	local expected = {
		Id = "LaserIslandLaser",
		SceneName = "Scene03_LaserIsland",
		ModelName = "LaserAssembly",
		PivotPartName = "CenterSphere",
		RotationAxis = "Y",
		SecondsPerRevolution = 6,
		PhaseOffset = 0,
		Direction = -1,
	}
	for name, value in expected do TestRunner.assertEqual(entry[name], value) end
end)

TestRunner.test("WorldConfig rotating fields have valid values", function()
	for _, entry in WorldConfig.RotatingHazards.Lasers do
		for _, field in { "Id", "SceneName", "ModelName", "PivotPartName", "RotationAxis" } do
			TestRunner.assertTrue(typeof(entry[field]) == "string" and entry[field] ~= "")
		end
		TestRunner.assertTrue(entry.SecondsPerRevolution > 0)
		TestRunner.assertTrue(entry.PhaseOffset >= 0 and entry.PhaseOffset < 1)
		TestRunner.assertTrue(entry.RotationAxis == "X" or entry.RotationAxis == "Y" or entry.RotationAxis == "Z")
		TestRunner.assertTrue(entry.Direction == -1 or entry.Direction == 1)
	end
end)

TestRunner.test("WorldConfig hazard Ids are unique across moving and rotating services", function()
	local ids: { string } = {}
	for _, entries in {
		WorldConfig.MovingHazards.Runners,
		WorldConfig.MovingHazards.Sharks,
		WorldConfig.RotatingHazards.Lasers,
	} do
		for _, entry in entries do table.insert(ids, entry.Id) end
	end
	assertArrayUnique(ids)
end)

TestRunner.test("WorldConfig rotating contract contains no Instances CFrames or Vector3s", function()
	local function inspect(value: any)
		local valueType = typeof(value)
		TestRunner.assertFalse(valueType == "Instance")
		TestRunner.assertFalse(valueType == "CFrame")
		TestRunner.assertFalse(valueType == "Vector3")
		if valueType == "table" then
			for key, child in value do
				inspect(key)
				inspect(child)
			end
		end
	end
	inspect(WorldConfig.LaserIsland)
	inspect(WorldConfig.RotatingHazards)
end)

TestRunner.test("WorldConfig rejects rotating and LaserIsland mutation", function()
	local entry = WorldConfig.RotatingHazards.Lasers[1]
	TestRunner.assertError(function() entry.Direction = 1 end)
	TestRunner.assertError(function() (WorldConfig.RotatingHazards.Lasers :: any)[2] = entry end)
	TestRunner.assertError(function() WorldConfig.LaserIsland.CoinIds[1] = "Changed" end)
	TestRunner.assertError(function() (WorldConfig.LaserIsland :: any).NewValue = "Changed" end)
	TestRunner.assertEqual(entry.Direction, -1)
	TestRunner.assertEqual(#WorldConfig.RotatingHazards.Lasers, 1)
	TestRunner.assertEqual(WorldConfig.LaserIsland.CoinIds[1], "LaserIslandCoin01")
end)

TestRunner.test("WorldConfig PalmFinish tables are frozen", function()
	TestRunner.assertTrue(table.isfrozen(WorldConfig.PalmFinish))
	TestRunner.assertTrue(table.isfrozen(WorldConfig.PalmFinish.Spiral))
	TestRunner.assertTrue(table.isfrozen(WorldConfig.PalmFinish.CoinIds))
end)

TestRunner.test("WorldConfig PalmFinish retains the approved stable names", function()
	local palmFinish = WorldConfig.PalmFinish
	local expected = {
		EntryPlatform = "EntryPlatform",
		SummitPlatform = "SummitPlatform",
		PalmTree = "PalmTree",
		Trunk = "Trunk",
		TrunkCore = "TrunkCore",
		CrownNeck = "CrownNeck",
		CrownHub = "CrownHub",
		Fronds = "Fronds",
		FrondPrefix = "Frond",
		HotSandIsland = "HotSandIsland",
		HotSandTint = "HotSandTint",
		PalmFallCatch = "PalmFallCatch",
		PalmUpperFallCatch = "PalmUpperFallCatch",
		FinishLine = "FinishLine",
	}
	for name, value in expected do TestRunner.assertEqual(palmFinish[name], value) end
	TestRunner.assertEqual(palmFinish.Spiral.FolderName, "SpiralSteps")
	TestRunner.assertEqual(palmFinish.Spiral.StepPrefix, "Step")
end)

TestRunner.test("WorldConfig PalmFinish defines the approved frond contract", function()
	local palmFinish = WorldConfig.PalmFinish
	TestRunner.assertEqual(palmFinish.FrondPrefix, "Frond")
	TestRunner.assertEqual(palmFinish.FrondCount, 8)
	for index = 1, palmFinish.FrondCount do
		TestRunner.assertEqual(string.format("%s%02d", palmFinish.FrondPrefix, index), string.format("Frond%02d", index))
	end
	TestRunner.assertTrue((palmFinish :: any).FrondNames == nil)
end)

TestRunner.test("WorldConfig PalmFinish defines three unique passive coin marker names", function()
	local names = WorldConfig.PalmFinish.CoinIds
	local fieldCount = 0
	for _ in WorldConfig.PalmFinish do fieldCount += 1 end
	TestRunner.assertTrue(table.isfrozen(names))
	TestRunner.assertEqual(fieldCount, 17)
	TestRunner.assertEqual(#names, 3)
	assertArrayUnique(names)
	for index = 1, 3 do
		TestRunner.assertEqual(names[index], string.format("PalmCoin%02d", index))
		TestRunner.assertTrue(string.match(names[index], "^PalmCoin%d%d$") ~= nil)
	end
end)

TestRunner.test("WorldConfig PalmFinish spiral tuning is deterministic", function()
	local spiral = WorldConfig.PalmFinish.Spiral
	local expected = {
		FolderName = "SpiralSteps",
		StepPrefix = "Step",
		StepCount = 73,
		CenterX = 164,
		CenterZ = -184,
		InitialAngleRadians = math.pi,
		AngularIncrementRadians = math.pi / 12,
		Radius = 9.5,
		FirstCenterY = 2.125,
		VerticalRise = 0.5,
		StepWidth = 5.5,
		StepHeight = 0.75,
		StepDepth = 4,
	}
	for name, value in expected do TestRunner.assertEqual(spiral[name], value) end
	local intervals = spiral.StepCount - 1
	local revolutions = intervals * spiral.AngularIncrementRadians / (2 * math.pi)
	local totalRise = intervals * spiral.VerticalRise
	TestRunner.assertEqual(intervals, 72)
	TestRunner.assertEqual(revolutions, 3)
	TestRunner.assertEqual(totalRise, 36)
	for _, derivedName in { "Intervals", "Revolutions", "TotalRise" } do
		TestRunner.assertTrue((spiral :: any)[derivedName] == nil)
	end
end)

TestRunner.test("WorldConfig PalmFinish contract contains only frozen data values", function()
	local function inspect(value: any)
		local valueType = typeof(value)
		if valueType == "table" then
			TestRunner.assertTrue(table.isfrozen(value))
			for key, child in value do
				local keyType = typeof(key)
				TestRunner.assertTrue(keyType == "string" or keyType == "number")
				inspect(child)
			end
			return
		end
		TestRunner.assertTrue(valueType == "string" or valueType == "number" or valueType == "boolean")
		TestRunner.assertFalse(valueType == "Instance")
		TestRunner.assertFalse(valueType == "CFrame")
		TestRunner.assertFalse(valueType == "Vector3")
		TestRunner.assertFalse(valueType == "function")
		TestRunner.assertFalse(valueType == "thread")
		TestRunner.assertFalse(valueType == "userdata")
	end
	inspect(WorldConfig.PalmFinish)
end)

TestRunner.test("WorldConfig rejects PalmFinish mutation", function()
	local palmFinish = WorldConfig.PalmFinish
	TestRunner.assertError(function() palmFinish.EntryPlatform = "Changed" end)
	TestRunner.assertError(function() palmFinish.Spiral.Radius = 1 end)
	TestRunner.assertError(function() palmFinish.CoinIds[1] = "Changed" end)
	TestRunner.assertError(function() palmFinish.HotSandIsland = "Changed" end)
	TestRunner.assertError(function() palmFinish.HotSandTint = "Changed" end)
	TestRunner.assertError(function() palmFinish.PalmUpperFallCatch = "Changed" end)
	TestRunner.assertError(function() (palmFinish :: any).NewValue = "Changed" end)
	TestRunner.assertEqual(palmFinish.EntryPlatform, "EntryPlatform")
	TestRunner.assertEqual(palmFinish.Spiral.Radius, 9.5)
	TestRunner.assertEqual(palmFinish.CoinIds[1], "PalmCoin01")
	TestRunner.assertEqual(palmFinish.HotSandIsland, "HotSandIsland")
	TestRunner.assertEqual(palmFinish.HotSandTint, "HotSandTint")
	TestRunner.assertEqual(palmFinish.PalmUpperFallCatch, "PalmUpperFallCatch")
	TestRunner.assertTrue((palmFinish :: any).NewValue == nil)
end)

TestRunner.test("Progression checkpoint definitions are frozen and exactly ordered", function()
	local progression = WorldConfig.Progression
	local checkpoints = progression.Checkpoints
	local expected = {
		{
			Scene = WorldConfig.Scenes.HotBeach,
			Folder = WorldConfig.CommonFolders.Start,
			Name = WorldConfig.HotBeach.StartSpawn,
			Id = "Start",
			Order = 1,
		},
		{
			Scene = WorldConfig.Scenes.HotBeach,
			Folder = WorldConfig.CommonFolders.Triggers,
			Name = WorldConfig.HotBeach.WaterStartCheckpoint,
			Id = WorldConfig.HotBeach.WaterStartCheckpointId,
			Order = 2,
		},
		{
			Scene = WorldConfig.Scenes.Water,
			Folder = WorldConfig.CommonFolders.Triggers,
			Name = WorldConfig.Water.LaserIslandStartCheckpoint,
			Id = WorldConfig.Water.LaserIslandStartCheckpointId,
			Order = 3,
		},
		{
			Scene = WorldConfig.Scenes.LaserIsland,
			Folder = WorldConfig.CommonFolders.Triggers,
			Name = WorldConfig.LaserIsland.PalmBaseCheckpoint,
			Id = WorldConfig.LaserIsland.PalmBaseCheckpointId,
			Order = 4,
		},
	}

	TestRunner.assertTrue(table.isfrozen(progression))
	TestRunner.assertTrue(table.isfrozen(checkpoints))
	TestRunner.assertEqual(#checkpoints, 4)

	for index, expectedDefinition in expected do
		local definition = checkpoints[index]
		local fieldCount = 0
		TestRunner.assertTrue(table.isfrozen(definition))
		for _ in definition do fieldCount += 1 end
		TestRunner.assertEqual(fieldCount, 5)
		TestRunner.assertEqual(definition.Scene, expectedDefinition.Scene)
		TestRunner.assertEqual(definition.Folder, expectedDefinition.Folder)
		TestRunner.assertEqual(definition.Name, expectedDefinition.Name)
		TestRunner.assertEqual(definition.Id, expectedDefinition.Id)
		TestRunner.assertEqual(definition.Order, expectedDefinition.Order)
	end

	TestRunner.assertEqual(checkpoints[1].Id, "Start")
	TestRunner.assertEqual(checkpoints[2].Id, "WaterStart")
	TestRunner.assertEqual(checkpoints[3].Id, "LaserIslandStart")
	TestRunner.assertEqual(checkpoints[4].Id, "PalmBase")
	TestRunner.assertTrue((checkpoints :: any)[5] == nil)
end)

TestRunner.test("Progression finish definition is frozen and stable", function()
	local finish = WorldConfig.Progression.Finish
	local fieldCount = 0
	for _ in finish do fieldCount += 1 end

	TestRunner.assertTrue(table.isfrozen(finish))
	TestRunner.assertEqual(fieldCount, 4)
	TestRunner.assertEqual(finish.Scene, WorldConfig.Scenes.PalmFinish)
	TestRunner.assertEqual(finish.Folder, WorldConfig.CommonFolders.Triggers)
	TestRunner.assertEqual(finish.Name, WorldConfig.PalmFinish.FinishLine)
	TestRunner.assertEqual(finish.Name, "FinishLine")
	TestRunner.assertEqual(finish.RequiredCheckpointOrder, 4)
end)

TestRunner.test("Progression config is recursively frozen and data only", function()
	local visited: { [any]: boolean } = {}

	local function inspect(value: any)
		local valueType = typeof(value)
		if valueType == "table" then
			TestRunner.assertTrue(table.isfrozen(value))
			if visited[value] then return end
			visited[value] = true
			for key, child in value do
				inspect(key)
				inspect(child)
			end
			return
		end

		TestRunner.assertTrue(valueType == "string" or valueType == "number" or valueType == "boolean")
		TestRunner.assertFalse(valueType == "Instance")
		TestRunner.assertFalse(valueType == "Vector3")
		TestRunner.assertFalse(valueType == "CFrame")
		TestRunner.assertFalse(valueType == "function")
		TestRunner.assertFalse(valueType == "thread")
		TestRunner.assertFalse(valueType == "userdata")
	end

	inspect(WorldConfig.Progression)
end)

TestRunner.test("Scene CoinIds resolve exactly sixteen unique final names", function()
	local sceneContracts = {
		{
			Actual = WorldConfig.HotBeach.CoinIds,
			Expected = { "DemoCoin", "HotBeachCoin01", "HotBeachCoin02", "HotBeachCoin03" },
		},
		{
			Actual = WorldConfig.Water.CoinIds,
			Expected = { "WaterCoin01", "WaterCoin02", "WaterCoin03", "WaterCoin04" },
		},
		{
			Actual = WorldConfig.LaserIsland.CoinIds,
			Expected = {
				"LaserIslandCoin01",
				"LaserIslandCoin02",
				"LaserIslandCoin03",
				"LaserIslandCoin04",
				"LaserIslandCoin05",
			},
		},
		{
			Actual = WorldConfig.PalmFinish.CoinIds,
			Expected = { "PalmCoin01", "PalmCoin02", "PalmCoin03" },
		},
	}
	local expectedSceneCounts = { 4, 4, 5, 3 }
	local seen: { [string]: boolean } = {}
	local total = 0

	for sceneIndex, contract in sceneContracts do
		TestRunner.assertEqual(#contract.Actual, expectedSceneCounts[sceneIndex])
		TestRunner.assertEqual(#contract.Actual, #contract.Expected)
		for index, expectedId in contract.Expected do
			local coinId = contract.Actual[index]
			TestRunner.assertTrue(typeof(coinId) == "string")
			TestRunner.assertTrue(coinId ~= "")
			TestRunner.assertEqual(coinId, expectedId)
			TestRunner.assertFalse(seen[coinId] == true, string.format("Duplicate CoinId %q", coinId))
			TestRunner.assertTrue(string.match(coinId, "Marker$") == nil)
			seen[coinId] = true
			total += 1
		end
	end

	TestRunner.assertEqual(total, 16)
end)

return true
