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
local waterStartCheckpoint = world:WaitForChild("Scene01_HotBeach")
	:WaitForChild("Triggers")
	:WaitForChild("WaterStartCheckpoint") :: BasePart

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

local function createCoin(addCleanup: AddCleanup, name: string, coinId: any, addTag: boolean?): Part
	local coin = Instance.new("Part")
	coin.Name = name
	coin.Anchored = true
	coin.Parent = Workspace
	coin:SetAttribute(RunConfig.Attributes.CoinId, coinId)

	if addTag ~= false then
		CollectionService:AddTag(coin, RunConfig.Tags.Coin)
	end

	addCleanup(function()
		if coin.Parent ~= nil then
			coin:Destroy()
		end
	end)

	return coin
end

local function createCharacter(addCleanup: AddCleanup, name: string): Model
	local character = Instance.new("Model")
	character.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character

	character.PrimaryPart = rootPart
	character.Parent = Workspace

	addCleanup(function()
		if character.Parent ~= nil then
			character:Destroy()
		end
	end)

	return character
end

local function createRunningSession(name: string, startedAtServerTime: number)
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity(name)
	service:CreateSession(player)
	service:StartRun(player, startedAtServerTime)
	return service, player
end

testWithCleanup("GameSessionService ignores Coin before run start", function(addCleanup)
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity("CoinBeforeStart")
	local coin = createCoin(addCleanup, "CoinBeforeStartPart", "BeforeStart")
	service:CreateSession(player)

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
	local snapshot = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(snapshot.coinCount, 0)
	TestRunner.assertEqual(snapshot.revision, 0)
end)

testWithCleanup("GameSessionService accepts a valid Coin while running", function(addCleanup)
	local service, player = createRunningSession("ValidCoinPlayer", 10)
	local coin = createCoin(addCleanup, "ValidCoin", "Valid")

	TestRunner.assertTrue(service:CollectCoin(player, coin) ~= nil)
end)

testWithCleanup("GameSessionService Coin increments coinCount by one", function(addCleanup)
	local service, player = createRunningSession("CoinCountPlayer", 20)
	local coin = createCoin(addCleanup, "CoinCountCoin", "Count")

	local snapshot = service:CollectCoin(player, coin) :: any

	TestRunner.assertEqual(snapshot.coinCount, 1)
end)

testWithCleanup("GameSessionService Coin increments revision exactly once", function(addCleanup)
	local service, player = createRunningSession("CoinRevisionPlayer", 30)
	local coin = createCoin(addCleanup, "CoinRevisionCoin", "Revision")
	local before = service:GetSnapshot(player) :: any

	local after = service:CollectCoin(player, coin) :: any

	TestRunner.assertEqual(after.revision, before.revision + 1)
end)

testWithCleanup("GameSessionService Coin adds CoinId to collectedCoinIds", function(addCleanup)
	local service, player = createRunningSession("CoinIdPlayer", 40)
	local coin = createCoin(addCleanup, "CoinIdCoin", "CollectedId")

	local snapshot = service:CollectCoin(player, coin) :: any

	TestRunner.assertEqual(#snapshot.collectedCoinIds, 1)
	TestRunner.assertEqual(snapshot.collectedCoinIds[1], "CollectedId")
end)

testWithCleanup("GameSessionService ignores repeated collection of the same Coin", function(addCleanup)
	local service, player = createRunningSession("RepeatedCoinPlayer", 50)
	local coin = createCoin(addCleanup, "RepeatedCoin", "Repeated")
	service:CollectCoin(player, coin)
	local first = service:GetSnapshot(player) :: any

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
	local second = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(second.coinCount, first.coinCount)
	TestRunner.assertEqual(second.revision, first.revision)
end)

testWithCleanup("GameSessionService repeated Coin returns only one snapshot", function(addCleanup)
	local service, player = createRunningSession("SingleSnapshotPlayer", 60)
	local coin = createCoin(addCleanup, "SingleSnapshotCoin", "SingleSnapshot")
	local returnedSnapshots = 0

	if service:CollectCoin(player, coin) ~= nil then
		returnedSnapshots += 1
	end

	if service:CollectCoin(player, coin) ~= nil then
		returnedSnapshots += 1
	end

	TestRunner.assertEqual(returnedSnapshots, 1)
end)

testWithCleanup("GameSessionService two Coins increment count to two", function(addCleanup)
	local service, player = createRunningSession("TwoCoinsPlayer", 70)
	local firstCoin = createCoin(addCleanup, "FirstCoin", "First")
	local secondCoin = createCoin(addCleanup, "SecondCoin", "Second")

	service:CollectCoin(player, firstCoin)
	local snapshot = service:CollectCoin(player, secondCoin) :: any

	TestRunner.assertEqual(snapshot.coinCount, 2)
end)

testWithCleanup("GameSessionService players collect the same Coin independently", function(addCleanup)
	local service = GameSessionService.new(startSpawn)
	local firstPlayer = createPlayerIdentity("FirstCoinPlayer")
	local secondPlayer = createPlayerIdentity("SecondCoinPlayer")
	local coin = createCoin(addCleanup, "SharedCoin", "Shared")
	service:CreateSession(firstPlayer)
	service:CreateSession(secondPlayer)
	service:StartRun(firstPlayer, 80)
	service:StartRun(secondPlayer, 90)

	TestRunner.assertTrue(service:CollectCoin(firstPlayer, coin) ~= nil)
	TestRunner.assertTrue(service:CollectCoin(secondPlayer, coin) ~= nil)
	TestRunner.assertEqual((service:GetSnapshot(firstPlayer) :: any).coinCount, 1)
	TestRunner.assertEqual((service:GetSnapshot(secondPlayer) :: any).coinCount, 1)
end)

testWithCleanup("GameSessionService Coin preserves phase", function(addCleanup)
	local service, player = createRunningSession("CoinPhasePlayer", 100)
	local coin = createCoin(addCleanup, "CoinPhaseCoin", "Phase")
	service:CollectCoin(player, coin)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).phase, RunConfig.Phases.Running)
end)

testWithCleanup("GameSessionService Coin preserves startedAtServerTime", function(addCleanup)
	local service, player = createRunningSession("CoinStartTimePlayer", 123.45)
	local coin = createCoin(addCleanup, "CoinStartTimeCoin", "StartTime")
	service:CollectCoin(player, coin)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).startedAtServerTime, 123.45)
end)

testWithCleanup("GameSessionService Coin preserves current checkpoint", function(addCleanup)
	local service, player = createRunningSession("CoinCheckpointPlayer", 110)
	local coin = createCoin(addCleanup, "CoinCheckpointCoin", "Checkpoint")
	local character = createCharacter(addCleanup, "CoinCheckpointCharacter")
	service:ReachCheckpoint(player, waterStartCheckpoint)
	service:CollectCoin(player, coin)

	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local offset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	TestRunner.assertTrue((character:GetPivot().Position - (waterStartCheckpoint.CFrame + offset).Position).Magnitude < 0.01)
end)

testWithCleanup("GameSessionService rejects non-string CoinId", function(addCleanup)
	local service, player = createRunningSession("InvalidCoinIdPlayer", 120)
	local coin = createCoin(addCleanup, "InvalidCoinIdCoin", 123)

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).coinCount, 0)
end)

testWithCleanup("GameSessionService rejects empty CoinId", function(addCleanup)
	local service, player = createRunningSession("EmptyCoinIdPlayer", 130)
	local coin = createCoin(addCleanup, "EmptyCoinIdCoin", "")

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
end)

testWithCleanup("GameSessionService rejects Instance without Coin tag", function(addCleanup)
	local service, player = createRunningSession("UntaggedCoinPlayer", 140)
	local coin = createCoin(addCleanup, "UntaggedCoin", "Untagged", false)

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
end)

testWithCleanup("GameSessionService rejects tagged non-BasePart Instance", function(addCleanup)
	local service, player = createRunningSession("NonPartCoinPlayer", 150)
	local folder = Instance.new("Folder")
	folder.Name = "CoinFolder"
	folder.Parent = Workspace
	CollectionService:AddTag(folder, RunConfig.Tags.Coin)
	addCleanup(function()
		if folder.Parent ~= nil then
			folder:Destroy()
		end
	end)

	TestRunner.assertEqual(service:CollectCoin(player, folder), nil)
end)

testWithCleanup("GameSessionService Coin snapshots use separate collectedCoinIds arrays", function(addCleanup)
	local service, player = createRunningSession("CoinArrayCopyPlayer", 160)
	local coin = createCoin(addCleanup, "CoinArrayCopyCoin", "ArrayCopy")
	service:CollectCoin(player, coin)

	local first = service:GetSnapshot(player) :: any
	local second = service:GetSnapshot(player) :: any
	TestRunner.assertFalse(first.collectedCoinIds == second.collectedCoinIds)
end)

testWithCleanup("GameSessionService Coin snapshot mutation does not change server collection", function(addCleanup)
	local service, player = createRunningSession("CoinMutationPlayer", 170)
	local coin = createCoin(addCleanup, "CoinMutationCoin", "Original")
	service:CollectCoin(player, coin)
	local snapshot = service:GetSnapshot(player) :: any
	table.insert(snapshot.collectedCoinIds, "Injected")
	snapshot.coinCount = 99

	local fresh = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(fresh.coinCount, 1)
	TestRunner.assertEqual(#fresh.collectedCoinIds, 1)
	TestRunner.assertEqual(fresh.collectedCoinIds[1], "Original")
end)

testWithCleanup("GameSessionService collectedCoinIds order is deterministic", function(addCleanup)
	local service, player = createRunningSession("SortedCoinPlayer", 180)
	local zCoin = createCoin(addCleanup, "ZCoin", "Zulu")
	local aCoin = createCoin(addCleanup, "ACoin", "Alpha")
	service:CollectCoin(player, zCoin)
	local snapshot = service:CollectCoin(player, aCoin) :: any

	TestRunner.assertEqual(snapshot.collectedCoinIds[1], "Alpha")
	TestRunner.assertEqual(snapshot.collectedCoinIds[2], "Zulu")
end)

testWithCleanup("GameSessionService handles Coin for unknown or removed session safely", function(addCleanup)
	local service, player = createRunningSession("RemovedCoinPlayer", 190)
	local unknownPlayer = createPlayerIdentity("UnknownCoinPlayer")
	local coin = createCoin(addCleanup, "RemovedSessionCoin", "Removed")
	service:RemoveSession(player)

	TestRunner.assertEqual(service:CollectCoin(player, coin), nil)
	TestRunner.assertEqual(service:CollectCoin(unknownPlayer, coin), nil)
end)

return true
