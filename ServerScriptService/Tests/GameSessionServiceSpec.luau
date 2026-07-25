--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local TestRunner = require(script.Parent.TestRunner)

local defaultCheckpoint = Workspace:WaitForChild("SpawnLocation") :: BasePart

local function createPlayerIdentity(name: string): Player
	return ({ Name = name } :: any) :: Player
end

TestRunner.test("GameSessionService creates an initial session", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("InitialSession")

	TestRunner.assertTrue(service:CreateSession(player))
	TestRunner.assertTrue(service:GetSnapshot(player) ~= nil)
end)

TestRunner.test("GameSessionService initialization is idempotent", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("Idempotent")

	TestRunner.assertTrue(service:CreateSession(player))
	TestRunner.assertFalse(service:CreateSession(player))
	TestRunner.assertEqual(service:GetSnapshot(player).revision, 0)
end)

TestRunner.test("GameSessionService initial snapshot has expected values", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("InitialSnapshot")

	service:CreateSession(player)
	local snapshot = service:GetSnapshot(player)

	TestRunner.assertTrue(snapshot ~= nil)
	TestRunner.assertEqual(snapshot.revision, 0)
	TestRunner.assertEqual(snapshot.phase, RunConfig.Phases.NotStarted)
	TestRunner.assertEqual(snapshot.startedAtServerTime, nil)
	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, nil)
	TestRunner.assertEqual(snapshot.coinCount, 0)
	TestRunner.assertEqual(#snapshot.collectedCoinIds, 0)
end)

TestRunner.test("GameSessionService snapshot excludes internal fields and Instances", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("PublicFields")

	service:CreateSession(player)
	local snapshot = service:GetSnapshot(player) :: any
	local allowedFields = {
		revision = true,
		phase = true,
		startedAtServerTime = true,
		finishedElapsedSeconds = true,
		coinCount = true,
		collectedCoinIds = true,
	}

	TestRunner.assertEqual(snapshot.currentCheckpoint, nil)
	TestRunner.assertEqual(snapshot.currentCheckpointId, nil)
	TestRunner.assertEqual(snapshot.currentCheckpointOrder, nil)

	for fieldName, value in snapshot do
		TestRunner.assertTrue(allowedFields[fieldName] == true, string.format("Unexpected snapshot field %s", fieldName))
		TestRunner.assertFalse(typeof(value) == "Instance", string.format("%s must not contain an Instance", fieldName))
	end
end)

TestRunner.test("GameSessionService returns a new snapshot table", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("SnapshotCopy")

	service:CreateSession(player)
	local first = service:GetSnapshot(player)
	local second = service:GetSnapshot(player)

	TestRunner.assertFalse(first == second)
end)

TestRunner.test("GameSessionService returns a new collectedCoinIds table", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("CoinIdsCopy")

	service:CreateSession(player)
	local first = service:GetSnapshot(player)
	local second = service:GetSnapshot(player)

	TestRunner.assertFalse(first.collectedCoinIds == second.collectedCoinIds)
end)

TestRunner.test("GameSessionService snapshot mutation does not change server state", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("SnapshotMutation")

	service:CreateSession(player)
	local snapshot = service:GetSnapshot(player)
	snapshot.revision = 99
	snapshot.phase = RunConfig.Phases.Finished
	snapshot.coinCount = 99
	table.insert(snapshot.collectedCoinIds, "Injected")

	local freshSnapshot = service:GetSnapshot(player)
	TestRunner.assertEqual(freshSnapshot.revision, 0)
	TestRunner.assertEqual(freshSnapshot.phase, RunConfig.Phases.NotStarted)
	TestRunner.assertEqual(freshSnapshot.coinCount, 0)
	TestRunner.assertEqual(#freshSnapshot.collectedCoinIds, 0)
end)

TestRunner.test("GameSessionService keeps player sessions independent", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local firstPlayer = createPlayerIdentity("FirstPlayer")
	local secondPlayer = createPlayerIdentity("SecondPlayer")

	service:CreateSession(firstPlayer)
	service:CreateSession(secondPlayer)

	local firstSnapshot = service:GetSnapshot(firstPlayer)
	local secondSnapshot = service:GetSnapshot(secondPlayer)
	firstSnapshot.coinCount = 50
	table.insert(firstSnapshot.collectedCoinIds, "FirstOnly")

	TestRunner.assertFalse(firstSnapshot == secondSnapshot)
	TestRunner.assertEqual(secondSnapshot.coinCount, 0)
	TestRunner.assertEqual(#secondSnapshot.collectedCoinIds, 0)
	TestRunner.assertEqual(service:GetSnapshot(firstPlayer).coinCount, 0)
end)

TestRunner.test("GameSessionService removes a session", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("Removed")

	service:CreateSession(player)
	TestRunner.assertTrue(service:RemoveSession(player))
	TestRunner.assertEqual(service:GetSnapshot(player), nil)
	TestRunner.assertFalse(service:RemoveSession(player))
end)

TestRunner.test("GameSessionService handles an unknown player safely", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local unknownPlayer = createPlayerIdentity("Unknown")

	TestRunner.assertEqual(service:GetSnapshot(unknownPlayer), nil)
	TestRunner.assertFalse(service:RemoveSession(unknownPlayer))
end)

return true
