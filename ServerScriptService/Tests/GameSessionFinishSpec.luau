--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local TestRunner = require(script.Parent.TestRunner)

local world = Workspace:WaitForChild("BeachObby"):WaitForChild("World")
local startSpawn = world:WaitForChild("Scene01_HotBeach"):WaitForChild("Start"):WaitForChild("StartSpawn") :: BasePart
local waterStartCheckpoint = world:WaitForChild("Scene01_HotBeach"):WaitForChild("Triggers"):WaitForChild("WaterStartCheckpoint") :: BasePart
local laserIslandStartCheckpoint = world:WaitForChild("Scene02_Water"):WaitForChild("Triggers"):WaitForChild("LaserIslandStartCheckpoint") :: BasePart
local palmBaseCheckpoint = world:WaitForChild("Scene03_LaserIsland"):WaitForChild("Triggers"):WaitForChild("PalmBaseCheckpoint") :: BasePart

type CleanupCallback = () -> ()
type AddCleanup = (CleanupCallback) -> ()

local function testWithCleanup(name: string, callback: (AddCleanup) -> ())
	TestRunner.test(name, function()
		local cleanupCallbacks: { CleanupCallback } = {}

		local function addCleanup(cleanupCallback: CleanupCallback)
			table.insert(cleanupCallbacks, cleanupCallback)
		end

		local succeeded, failureMessage = xpcall(function()
			callback(addCleanup)
		end, debug.traceback)

		for index = #cleanupCallbacks, 1, -1 do
			pcall(cleanupCallbacks[index])
		end

		if not succeeded then
			error(failureMessage, 0)
		end
	end)
end

local function createPlayerIdentity(name: string): Player
	return ({ Name = name } :: any) :: Player
end

local function trackInstance(addCleanup: AddCleanup, instance: Instance): Instance
	addCleanup(function()
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end)

	return instance
end

local function createFinish(
	addCleanup: AddCleanup,
	name: string,
	requiredCheckpointOrder: any,
	addTag: boolean?
): Part
	local finishPart = trackInstance(addCleanup, Instance.new("Part")) :: Part
	finishPart.Name = name
	finishPart.Anchored = true
	finishPart:SetAttribute(RunConfig.Attributes.RequiredCheckpointOrder, requiredCheckpointOrder)
	finishPart.Parent = Workspace

	if addTag ~= false then
		CollectionService:AddTag(finishPart, RunConfig.Tags.Finish)
	end

	return finishPart
end

local function createCoin(addCleanup: AddCleanup, name: string): Part
	local coin = trackInstance(addCleanup, Instance.new("Part")) :: Part
	coin.Name = name
	coin.Anchored = true
	coin:SetAttribute(RunConfig.Attributes.CoinId, name)
	coin.Parent = Workspace
	CollectionService:AddTag(coin, RunConfig.Tags.Coin)
	return coin
end

local function createCharacter(addCleanup: AddCleanup, name: string): Model
	local character = trackInstance(addCleanup, Instance.new("Model")) :: Model
	character.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character

	character.PrimaryPart = rootPart
	character.Parent = Workspace
	return character
end

local function createService(now: number)
	local clock = {
		now = now,
	}
	local service = GameSessionService.new(startSpawn, {
		getServerTimeNow = function()
			return clock.now
		end,
	})
	return service, clock
end

local function createRunningSession(name: string, startedAtServerTime: number, now: number)
	local service, clock = createService(now)
	local player = createPlayerIdentity(name)
	service:CreateSession(player)
	service:StartRun(player, startedAtServerTime)
	return service, player, clock
end

local function createReadySession(name: string, startedAtServerTime: number, now: number)
	local service, player, clock = createRunningSession(name, startedAtServerTime, now)
	service:ReachCheckpoint(player, waterStartCheckpoint)
	service:ReachCheckpoint(player, laserIslandStartCheckpoint)
	service:ReachCheckpoint(player, palmBaseCheckpoint)
	return service, player, clock
end

testWithCleanup("GameSessionService ignores Finish before run start", function(addCleanup)
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity("FinishBeforeStart")
	local finishPart = createFinish(addCleanup, "FinishBeforeStartPart", 4)
	service:CreateSession(player)

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
	local snapshot = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(snapshot.phase, RunConfig.Phases.NotStarted)
	TestRunner.assertEqual(snapshot.revision, 0)
	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, nil)
end)

testWithCleanup("GameSessionService ignores Finish before required checkpoint", function(addCleanup)
	local service, player = createRunningSession("FinishBeforeCheckpoint", 10, 20)
	local finishPart = createFinish(addCleanup, "FinishBeforeCheckpointPart", 4)
	local before = service:GetSnapshot(player) :: any

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
	local after = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(after.phase, RunConfig.Phases.Running)
	TestRunner.assertEqual(after.revision, before.revision)
end)

testWithCleanup("GameSessionService accepts Finish after required checkpoint", function(addCleanup)
	local service, player = createReadySession("ValidFinish", 10, 25)
	local finishPart = createFinish(addCleanup, "ValidFinishPart", 4)

	TestRunner.assertTrue(service:FinishRun(player, finishPart) ~= nil)
end)

testWithCleanup("GameSessionService Finish sets phase Finished", function(addCleanup)
	local service, player = createReadySession("FinishPhase", 10, 30)
	local finishPart = createFinish(addCleanup, "FinishPhasePart", 4)
	local snapshot = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(snapshot.phase, RunConfig.Phases.Finished)
end)

testWithCleanup("GameSessionService Finish sets finishedElapsedSeconds", function(addCleanup)
	local service, player = createReadySession("FinishElapsed", 10, 35)
	local finishPart = createFinish(addCleanup, "FinishElapsedPart", 4)
	local snapshot = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, 25)
end)

testWithCleanup("GameSessionService Finish elapsed uses startedAtServerTime", function(addCleanup)
	local service, player = createReadySession("FinishElapsedFromStart", 12.5, 42.75)
	local finishPart = createFinish(addCleanup, "FinishElapsedFromStartPart", 4)
	local snapshot = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, 30.25)
end)

testWithCleanup("GameSessionService Finish normalizes negative elapsed to zero", function(addCleanup)
	local service, player = createReadySession("NegativeFinishElapsed", 50, 40)
	local finishPart = createFinish(addCleanup, "NegativeFinishElapsedPart", 4)
	local snapshot = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(snapshot.finishedElapsedSeconds, 0)
end)

testWithCleanup("GameSessionService Finish increments revision exactly once", function(addCleanup)
	local service, player = createReadySession("FinishRevision", 10, 50)
	local finishPart = createFinish(addCleanup, "FinishRevisionPart", 4)
	local before = service:GetSnapshot(player) :: any
	local after = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(after.revision, before.revision + 1)
end)

testWithCleanup("GameSessionService Finish returns exactly one successful snapshot", function(addCleanup)
	local service, player = createReadySession("SingleFinishSnapshot", 10, 55)
	local finishPart = createFinish(addCleanup, "SingleFinishSnapshotPart", 4)
	local returnedSnapshots = 0

	if service:FinishRun(player, finishPart) ~= nil then
		returnedSnapshots += 1
	end

	if service:FinishRun(player, finishPart) ~= nil then
		returnedSnapshots += 1
	end

	TestRunner.assertEqual(returnedSnapshots, 1)
end)

testWithCleanup("GameSessionService ignores repeated Finish", function(addCleanup)
	local service, player = createReadySession("RepeatedFinish", 10, 60)
	local finishPart = createFinish(addCleanup, "RepeatedFinishPart", 4)
	service:FinishRun(player, finishPart)
	local first = service:GetSnapshot(player) :: any

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
	local second = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(second.revision, first.revision)
end)

testWithCleanup("GameSessionService repeated Finish does not recalculate elapsed", function(addCleanup)
	local service, player, clock = createReadySession("StableFinishElapsed", 10, 65)
	local finishPart = createFinish(addCleanup, "StableFinishElapsedPart", 4)
	service:FinishRun(player, finishPart)
	local first = service:GetSnapshot(player) :: any
	clock.now = 100

	service:FinishRun(player, finishPart)
	local second = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(second.finishedElapsedSeconds, first.finishedElapsedSeconds)
end)

testWithCleanup("GameSessionService repeated Finish returns no second snapshot", function(addCleanup)
	local service, player = createReadySession("NoSecondFinishSnapshot", 10, 70)
	local finishPart = createFinish(addCleanup, "NoSecondFinishSnapshotPart", 4)

	TestRunner.assertTrue(service:FinishRun(player, finishPart) ~= nil)
	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
end)

testWithCleanup("GameSessionService Finish preserves startedAtServerTime", function(addCleanup)
	local service, player = createReadySession("FinishPreservesStart", 17.25, 75)
	local finishPart = createFinish(addCleanup, "FinishPreservesStartPart", 4)
	service:FinishRun(player, finishPart)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).startedAtServerTime, 17.25)
end)

testWithCleanup("GameSessionService Finish preserves checkpoint", function(addCleanup)
	local service, player = createReadySession("FinishPreservesCheckpoint", 10, 80)
	local finishPart = createFinish(addCleanup, "FinishPreservesCheckpointPart", 4)
	local character = createCharacter(addCleanup, "FinishCheckpointCharacter")
	service:FinishRun(player, finishPart)

	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local offset = palmBaseCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	TestRunner.assertTrue((character:GetPivot().Position - (palmBaseCheckpoint.CFrame + offset).Position).Magnitude < 0.01)
end)

testWithCleanup("GameSessionService Finish preserves coinCount", function(addCleanup)
	local service, player = createReadySession("FinishPreservesCoinCount", 10, 85)
	local finishPart = createFinish(addCleanup, "FinishPreservesCoinCountPart", 4)
	local coin = createCoin(addCleanup, "FinishPreservesCoinCountCoin")
	service:CollectCoin(player, coin)
	service:FinishRun(player, finishPart)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).coinCount, 1)
end)

testWithCleanup("GameSessionService Finish preserves collectedCoinIds", function(addCleanup)
	local service, player = createReadySession("FinishPreservesCoinIds", 10, 90)
	local finishPart = createFinish(addCleanup, "FinishPreservesCoinIdsPart", 4)
	local coin = createCoin(addCleanup, "FinishPreservedCoin")
	service:CollectCoin(player, coin)
	service:FinishRun(player, finishPart)
	local snapshot = service:GetSnapshot(player) :: any

	TestRunner.assertEqual(#snapshot.collectedCoinIds, 1)
	TestRunner.assertEqual(snapshot.collectedCoinIds[1], "FinishPreservedCoin")
end)

testWithCleanup("GameSessionService ignores StartRun after Finished", function(addCleanup)
	local service, player = createReadySession("StartAfterFinish", 10, 95)
	local finishPart = createFinish(addCleanup, "StartAfterFinishPart", 4)
	service:FinishRun(player, finishPart)
	local before = service:GetSnapshot(player) :: any

	TestRunner.assertEqual(service:StartRun(player, 100), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, before.revision)
end)

testWithCleanup("GameSessionService ignores ReachCheckpoint after Finished", function(addCleanup)
	local service, player = createReadySession("CheckpointAfterFinish", 10, 100)
	local finishPart = createFinish(addCleanup, "CheckpointAfterFinishPart", 4)
	service:FinishRun(player, finishPart)
	local laterCheckpoint = trackInstance(addCleanup, Instance.new("Part")) :: Part
	laterCheckpoint.Name = "LaterCheckpoint"
	laterCheckpoint:SetAttribute(RunConfig.Attributes.CheckpointId, "Later")
	laterCheckpoint:SetAttribute(RunConfig.Attributes.CheckpointOrder, 5)
	laterCheckpoint:SetAttribute(RunConfig.Attributes.RespawnOffset, Vector3.new(0, 4, 0))
	laterCheckpoint.Parent = Workspace
	CollectionService:AddTag(laterCheckpoint, RunConfig.Tags.Checkpoint)

	TestRunner.assertEqual(service:ReachCheckpoint(player, laterCheckpoint), nil)
end)

testWithCleanup("GameSessionService ignores CollectCoin after Finished", function(addCleanup)
	local service, player = createReadySession("CoinAfterFinish", 10, 105)
	local finishPart = createFinish(addCleanup, "CoinAfterFinishPart", 4)
	local coin = createCoin(addCleanup, "CoinAfterFinishCoin")
	service:FinishRun(player, finishPart)

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).coinCount, 0)
end)

testWithCleanup("GameSessionService rejects invalid RequiredCheckpointOrder", function(addCleanup)
	local service, player = createReadySession("InvalidFinishOrder", 10, 110)
	local zeroOrder = createFinish(addCleanup, "ZeroFinishOrder", 0)
	local fractionalOrder = createFinish(addCleanup, "FractionalFinishOrder", 2.5)

	TestRunner.assertEqual(service:FinishRun(player, zeroOrder), nil)
	TestRunner.assertEqual(service:FinishRun(player, fractionalOrder), nil)
end)

testWithCleanup("GameSessionService rejects missing RequiredCheckpointOrder", function(addCleanup)
	local service, player = createReadySession("MissingFinishOrder", 10, 115)
	local finishPart = createFinish(addCleanup, "MissingFinishOrderPart", nil)

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
end)

testWithCleanup("GameSessionService rejects untagged Finish Part", function(addCleanup)
	local service, player = createReadySession("UntaggedFinish", 10, 120)
	local finishPart = createFinish(addCleanup, "UntaggedFinishPart", 4, false)

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
end)

testWithCleanup("GameSessionService rejects tagged Finish non-BasePart", function(addCleanup)
	local service, player = createReadySession("NonPartFinish", 10, 125)
	local folder = trackInstance(addCleanup, Instance.new("Folder"))
	folder.Name = "TaggedFinishFolder"
	folder.Parent = Workspace
	folder:SetAttribute(RunConfig.Attributes.RequiredCheckpointOrder, 4)
	CollectionService:AddTag(folder, RunConfig.Tags.Finish)

	TestRunner.assertEqual(service:FinishRun(player, folder), nil)
end)

testWithCleanup("GameSessionService handles Finish for unknown or removed session safely", function(addCleanup)
	local service, player = createReadySession("RemovedFinishSession", 10, 130)
	local unknownPlayer = createPlayerIdentity("UnknownFinishPlayer")
	local finishPart = createFinish(addCleanup, "RemovedFinishSessionPart", 4)
	service:RemoveSession(player)

	TestRunner.assertEqual(service:FinishRun(player, finishPart), nil)
	TestRunner.assertEqual(service:FinishRun(unknownPlayer, finishPart), nil)
end)

testWithCleanup("GameSessionService finishes players independently with different elapsed times", function(addCleanup)
	local service, clock = createService(0)
	local firstPlayer = createPlayerIdentity("FirstFinishPlayer")
	local secondPlayer = createPlayerIdentity("SecondFinishPlayer")
	local finishPart = createFinish(addCleanup, "IndependentFinishPart", 4)
	service:CreateSession(firstPlayer)
	service:CreateSession(secondPlayer)
	service:StartRun(firstPlayer, 10)
	service:StartRun(secondPlayer, 20)
	for _, checkpoint in { waterStartCheckpoint, laserIslandStartCheckpoint, palmBaseCheckpoint } do
		service:ReachCheckpoint(firstPlayer, checkpoint)
		service:ReachCheckpoint(secondPlayer, checkpoint)
	end

	clock.now = 30
	service:FinishRun(firstPlayer, finishPart)
	clock.now = 55
	service:FinishRun(secondPlayer, finishPart)

	TestRunner.assertEqual((service:GetSnapshot(firstPlayer) :: any).finishedElapsedSeconds, 20)
	TestRunner.assertEqual((service:GetSnapshot(secondPlayer) :: any).finishedElapsedSeconds, 35)
end)

testWithCleanup("GameSessionService Finish snapshot excludes Finish Instance", function(addCleanup)
	local service, player = createReadySession("FinishSnapshotContract", 10, 135)
	local finishPart = createFinish(addCleanup, "FinishSnapshotContractPart", 4)
	local snapshot = service:FinishRun(player, finishPart) :: any

	TestRunner.assertEqual(snapshot.finishPart, nil)
	TestRunner.assertEqual(snapshot.currentCheckpoint, nil)

	for _, value in snapshot do
		TestRunner.assertFalse(typeof(value) == "Instance")
	end
end)

return true
