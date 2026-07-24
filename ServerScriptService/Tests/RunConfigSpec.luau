--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestRunner = require(script.Parent.TestRunner)
local RunConfig = require(
	ReplicatedStorage:WaitForChild("BeachObby"):WaitForChild("Shared"):WaitForChild("RunConfig")
)

local expectedConstants = {
	Tags = {
		RunStart = "RunStart",
		Checkpoint = "Checkpoint",
		Hazard = "Hazard",
		Coin = "Coin",
		Finish = "Finish",
	},
	Attributes = {
		CheckpointId = "CheckpointId",
		CheckpointOrder = "CheckpointOrder",
		RespawnOffset = "RespawnOffset",
		CoinId = "CoinId",
		RequiredCheckpointOrder = "RequiredCheckpointOrder",
	},
	Phases = {
		NotStarted = "NotStarted",
		Running = "Running",
		Finished = "Finished",
	},
	Remotes = {
		RunStateUpdated = "RunStateUpdated",
		GetRunState = "GetRunState",
	},
}

local function assertConstantsMatch(groupName: string)
	local actualGroup = RunConfig[groupName]
	local expectedGroup = expectedConstants[groupName]

	for constantName, expectedValue in expectedGroup do
		TestRunner.assertEqual(
			actualGroup[constantName],
			expectedValue,
			string.format("%s.%s has an unexpected value", groupName, constantName)
		)
	end
end

TestRunner.test("RunConfig contains every tag", function()
	assertConstantsMatch("Tags")
end)

TestRunner.test("RunConfig contains every attribute", function()
	assertConstantsMatch("Attributes")
end)

TestRunner.test("RunConfig contains every phase", function()
	assertConstantsMatch("Phases")
end)

TestRunner.test("RunConfig contains every remote", function()
	assertConstantsMatch("Remotes")
end)

TestRunner.test("RunConfig required values are not nil", function()
	for groupName, expectedGroup in expectedConstants do
		local actualGroup = RunConfig[groupName]

		TestRunner.assertFalse(actualGroup == nil, string.format("%s is required", groupName))

		for constantName in expectedGroup do
			TestRunner.assertFalse(
				actualGroup[constantName] == nil,
				string.format("%s.%s is required", groupName, constantName)
			)
		end
	end
end)

TestRunner.test("RunConfig root table is frozen", function()
	TestRunner.assertTrue(table.isfrozen(RunConfig))
end)

TestRunner.test("RunConfig nested tables are frozen", function()
	for groupName in expectedConstants do
		TestRunner.assertTrue(table.isfrozen(RunConfig[groupName]), string.format("%s must be frozen", groupName))
	end
end)

TestRunner.test("RunConfig rejects changing an existing constant", function()
	TestRunner.assertError(function()
		RunConfig.Tags.RunStart = "Changed"
	end)
	TestRunner.assertEqual(RunConfig.Tags.RunStart, "RunStart")
end)

TestRunner.test("RunConfig rejects adding a new constant", function()
	TestRunner.assertError(function()
		RunConfig.Tags.NewConstant = "NewConstant"
	end)
	TestRunner.assertFalse(RunConfig.Tags.NewConstant ~= nil)
end)

return true
