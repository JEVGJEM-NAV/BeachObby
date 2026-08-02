--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local TestRunner = require(script.Parent.TestRunner)

local defaultCheckpoint = Workspace:WaitForChild("BeachObby")
	:WaitForChild("World")
	:WaitForChild("Scene01_HotBeach")
	:WaitForChild("Start")
	:WaitForChild("StartSpawn") :: BasePart

local function createPlayerIdentity(name: string): Player
	return ({ Name = name } :: any) :: Player
end

TestRunner.test("GameSessionService starts a run", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("StartRun")

	service:CreateSession(player)
	local snapshot = service:StartRun(player, 123.45)

	TestRunner.assertTrue(snapshot ~= nil)
	TestRunner.assertEqual(snapshot.revision, 1)
	TestRunner.assertEqual(snapshot.phase, RunConfig.Phases.Running)
	TestRunner.assertEqual(snapshot.startedAtServerTime, 123.45)
	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, nil)
	TestRunner.assertEqual(snapshot.coinCount, 0)
end)

TestRunner.test("GameSessionService does not restart a running run", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("StartOnce")

	service:CreateSession(player)
	TestRunner.assertTrue(service:StartRun(player, 10) ~= nil)
	TestRunner.assertEqual(service:StartRun(player, 20), nil)

	local snapshot = service:GetSnapshot(player)
	TestRunner.assertEqual(snapshot.revision, 1)
	TestRunner.assertEqual(snapshot.startedAtServerTime, 10)
end)

TestRunner.test("GameSessionService handles start for an unknown player safely", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local unknownPlayer = createPlayerIdentity("UnknownStart")

	TestRunner.assertEqual(service:StartRun(unknownPlayer, 10), nil)
end)

TestRunner.test("GameSessionService starts players independently", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local firstPlayer = createPlayerIdentity("FirstStart")
	local secondPlayer = createPlayerIdentity("SecondStart")

	service:CreateSession(firstPlayer)
	service:CreateSession(secondPlayer)
	service:StartRun(firstPlayer, 100)

	local firstSnapshot = service:GetSnapshot(firstPlayer)
	local secondSnapshot = service:GetSnapshot(secondPlayer)

	TestRunner.assertEqual(firstSnapshot.phase, RunConfig.Phases.Running)
	TestRunner.assertEqual(firstSnapshot.startedAtServerTime, 100)
	TestRunner.assertEqual(firstSnapshot.revision, 1)
	TestRunner.assertEqual(secondSnapshot.phase, RunConfig.Phases.NotStarted)
	TestRunner.assertEqual(secondSnapshot.startedAtServerTime, nil)
	TestRunner.assertEqual(secondSnapshot.revision, 0)
end)

TestRunner.test("GameSessionService rejects invalid start times", function()
	local service = GameSessionService.new(defaultCheckpoint)
	local player = createPlayerIdentity("InvalidStartTime")

	service:CreateSession(player)
	TestRunner.assertEqual(service:StartRun(player, 0 / 0), nil)
	TestRunner.assertEqual(service:StartRun(player, math.huge), nil)

	local snapshot = service:GetSnapshot(player)
	TestRunner.assertEqual(snapshot.phase, RunConfig.Phases.NotStarted)
	TestRunner.assertEqual(snapshot.revision, 0)
end)

return true
