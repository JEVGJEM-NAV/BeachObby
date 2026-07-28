--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.TestRunner)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)

local expectedRoot = {
	BeachObby = "BeachObby",
	World = "World",
	VerticalSlice = "VerticalSlice",
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
	TestRunner.assertEqual(WorldConfig.Root.BeachObby, "BeachObby")
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
		hotBeach.WaterStartMarker,
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
	TestRunner.assertEqual(WorldConfig.Water.LaserIslandStartCheckpointId, "LaserIslandStart")
	TestRunner.assertFalse(WorldConfig.Water.LaserIslandStartCheckpointId == WorldConfig.HotBeach.WaterStartCheckpointId)
end)

TestRunner.test("WorldConfig Water names are non-empty strings", function()
	local water = WorldConfig.Water
	for _, value in {
		water.SceneFootprint,
		water.WaterSurface,
		water.WaterKillPlane,
		water.RingsFolder,
		water.SharksFolder,
		water.LaserIslandStartMarker,
		water.LaserIslandStartCheckpointId,
	} do
		TestRunner.assertTrue(typeof(value) == "string")
		TestRunner.assertTrue(value ~= "")
	end
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

return true
