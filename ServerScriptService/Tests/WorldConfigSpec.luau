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

return true
