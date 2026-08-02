--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local TestRunner = require(script.Parent.TestRunner)

local world = Workspace:WaitForChild("BeachObby"):WaitForChild("World")
local hotBeach = world:WaitForChild("Scene01_HotBeach")
local startSpawn = hotBeach:WaitForChild("Start"):WaitForChild("StartSpawn") :: BasePart
local waterStartCheckpoint = hotBeach:WaitForChild("Triggers"):WaitForChild("WaterStartCheckpoint") :: BasePart
local laserIslandStartCheckpoint = world:WaitForChild("Scene02_Water")
	:WaitForChild("Triggers")
	:WaitForChild("LaserIslandStartCheckpoint") :: BasePart
local palmBaseCheckpoint = world:WaitForChild("Scene03_LaserIsland")
	:WaitForChild("Triggers")
	:WaitForChild("PalmBaseCheckpoint") :: BasePart

local function createPlayerIdentity(name: string): Player
	return ({ Name = name } :: any) :: Player
end

local function createRunningSession(name: string, startedAtServerTime: number)
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity(name)
	service:CreateSession(player)
	service:StartRun(player, startedAtServerTime)
	return service, player
end

local function createCheckpoint(
	name: string,
	checkpointId: any,
	checkpointOrder: any,
	respawnOffset: any,
	position: Vector3?,
	addTag: boolean?
): Part
	local checkpoint = Instance.new("Part")
	checkpoint.Name = name
	checkpoint.Anchored = true
	checkpoint.Position = position or Vector3.zero
	checkpoint:SetAttribute(RunConfig.Attributes.CheckpointId, checkpointId)
	checkpoint:SetAttribute(RunConfig.Attributes.CheckpointOrder, checkpointOrder)
	checkpoint:SetAttribute(RunConfig.Attributes.RespawnOffset, respawnOffset)
	checkpoint.Parent = Workspace
	if addTag ~= false then
		CollectionService:AddTag(checkpoint, RunConfig.Tags.Checkpoint)
	end
	return checkpoint
end

local function destroyCheckpoint(checkpoint: Part)
	CollectionService:RemoveTag(checkpoint, RunConfig.Tags.Checkpoint)
	checkpoint:Destroy()
end

local function createCharacter(name: string): Model
	local character = Instance.new("Model")
	character.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Parent = character

	character.PrimaryPart = rootPart
	character.Parent = Workspace
	return character
end

local function assertVectorClose(actual: Vector3, expected: Vector3, tolerance: number?)
	local maximumDistance = tolerance or 0.01
	TestRunner.assertTrue(
		(actual - expected).Magnitude <= maximumDistance,
		string.format("Expected %s near %s", tostring(actual), tostring(expected))
	)
end

local function assertSnapshotsEqual(actual: any, expected: any)
	TestRunner.assertEqual(actual.revision, expected.revision)
	TestRunner.assertEqual(actual.phase, expected.phase)
	TestRunner.assertEqual(actual.startedAtServerTime, expected.startedAtServerTime)
	TestRunner.assertEqual(actual.finishedElapsedSeconds, expected.finishedElapsedSeconds)
	TestRunner.assertEqual(actual.coinCount, expected.coinCount)
	TestRunner.assertEqual(#actual.collectedCoinIds, #expected.collectedCoinIds)
	for index, coinId in expected.collectedCoinIds do
		TestRunner.assertEqual(actual.collectedCoinIds[index], coinId)
	end
end

TestRunner.test("GameSessionService session begins at Start checkpoint order 1", function()
	local service, player = createRunningSession("InitialCheckpoint", 10)
	local sameOrderCheckpoint = createCheckpoint("SameOrder", "OtherStart", 1, Vector3.new(0, 4, 0))

	TestRunner.assertEqual(service:ReachCheckpoint(player, sameOrderCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	destroyCheckpoint(sameOrderCheckpoint)
end)

TestRunner.test("GameSessionService ignores checkpoint before start", function()
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity("CheckpointBeforeStart")
	service:CreateSession(player)

	TestRunner.assertEqual(service:ReachCheckpoint(player, waterStartCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 0)
end)

TestRunner.test("GameSessionService accepts WaterStartCheckpoint while running", function()
	local service, player = createRunningSession("AcceptMid", 20)
	local snapshot = service:ReachCheckpoint(player, waterStartCheckpoint)

	TestRunner.assertTrue(snapshot ~= nil)
	TestRunner.assertEqual((snapshot :: any).phase, RunConfig.Phases.Running)
end)

TestRunner.test("GameSessionService checkpoint increments revision exactly once", function()
	local service, player = createRunningSession("CheckpointRevision", 30)
	local before = service:GetSnapshot(player) :: any
	local after = service:ReachCheckpoint(player, waterStartCheckpoint) :: any

	TestRunner.assertEqual(after.revision, before.revision + 1)
end)

TestRunner.test("GameSessionService ignores repeated WaterStartCheckpoint", function()
	local service, player = createRunningSession("RepeatedMid", 40)
	local first = service:ReachCheckpoint(player, waterStartCheckpoint) :: any

	TestRunner.assertEqual(service:ReachCheckpoint(player, waterStartCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, first.revision)
end)

TestRunner.test("GameSessionService does not roll back from WaterStartCheckpoint to StartSpawn", function()
	local service, player = createRunningSession("NoRollback", 50)
	service:ReachCheckpoint(player, waterStartCheckpoint)
	local revisionAtMid = (service:GetSnapshot(player) :: any).revision

	TestRunner.assertEqual(service:ReachCheckpoint(player, startSpawn), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, revisionAtMid)
end)

TestRunner.test("GameSessionService checkpoint preserves startedAtServerTime", function()
	local service, player = createRunningSession("PreserveStartTime", 123.45)
	service:ReachCheckpoint(player, waterStartCheckpoint)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).startedAtServerTime, 123.45)
end)

TestRunner.test("GameSessionService checkpoint preserves coinCount", function()
	local service, player = createRunningSession("PreserveCoins", 60)
	service:ReachCheckpoint(player, waterStartCheckpoint)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).coinCount, 0)
end)

TestRunner.test("GameSessionService keeps player checkpoints independent", function()
	local service = GameSessionService.new(startSpawn)
	local firstPlayer = createPlayerIdentity("CheckpointFirst")
	local secondPlayer = createPlayerIdentity("CheckpointSecond")
	local firstCharacter = createCharacter("CheckpointFirstCharacter")
	local secondCharacter = createCharacter("CheckpointSecondCharacter")

	service:CreateSession(firstPlayer)
	service:CreateSession(secondPlayer)
	service:StartRun(firstPlayer, 70)
	service:StartRun(secondPlayer, 80)
	service:ReachCheckpoint(secondPlayer, waterStartCheckpoint)
	service:PlaceCharacterAtCheckpoint(firstPlayer, firstCharacter)
	service:PlaceCharacterAtCheckpoint(secondPlayer, secondCharacter)

	local respawnOffset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(firstCharacter:GetPivot().Position, startSpawn.Position + Vector3.new(0, 4, 0))
	assertVectorClose(secondCharacter:GetPivot().Position, waterStartCheckpoint.Position + respawnOffset)

	firstCharacter:Destroy()
	secondCharacter:Destroy()
end)

TestRunner.test("GameSessionService checkpoint snapshot excludes checkpoint Instance", function()
	local service, player = createRunningSession("CheckpointSnapshot", 90)
	local snapshot = service:ReachCheckpoint(player, waterStartCheckpoint) :: any

	TestRunner.assertEqual(snapshot.currentCheckpoint, nil)
	TestRunner.assertEqual(snapshot.currentCheckpointId, nil)
	TestRunner.assertEqual(snapshot.currentCheckpointOrder, nil)
	TestRunner.assertEqual(snapshot.respawnOffset, nil)

	for _, value in snapshot do
		TestRunner.assertFalse(typeof(value) == "Instance")
	end
end)

TestRunner.test("GameSessionService rejects invalid CheckpointId", function()
	local service, player = createRunningSession("InvalidCheckpointId", 100)
	local checkpoint = createCheckpoint("InvalidId", "", 2, Vector3.new(0, 4, 0))

	TestRunner.assertEqual(service:ReachCheckpoint(player, checkpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	destroyCheckpoint(checkpoint)
end)

TestRunner.test("GameSessionService rejects invalid CheckpointOrder", function()
	local service, player = createRunningSession("InvalidCheckpointOrder", 110)
	local zeroOrder = createCheckpoint("ZeroOrder", "Zero", 0, Vector3.new(0, 4, 0))
	local fractionalOrder = createCheckpoint("FractionalOrder", "Fractional", 2.5, Vector3.new(0, 4, 0))

	TestRunner.assertEqual(service:ReachCheckpoint(player, zeroOrder), nil)
	TestRunner.assertEqual(service:ReachCheckpoint(player, fractionalOrder), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	destroyCheckpoint(zeroOrder)
	destroyCheckpoint(fractionalOrder)
end)

TestRunner.test("GameSessionService rejects invalid RespawnOffset", function()
	local service, player = createRunningSession("InvalidRespawnOffset", 120)
	local checkpoint = createCheckpoint("InvalidOffset", "InvalidOffset", 2, "not-a-vector")

	TestRunner.assertEqual(service:ReachCheckpoint(player, checkpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	destroyCheckpoint(checkpoint)
end)

TestRunner.test("GameSessionService places character at checkpoint with offset", function()
	local service, player = createRunningSession("PlaceAtCheckpoint", 130)
	local character = createCharacter("PlacedCharacter")
	service:ReachCheckpoint(player, waterStartCheckpoint)

	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local respawnOffset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(character:GetPivot().Position, waterStartCheckpoint.Position + respawnOffset)

	character:Destroy()
end)

TestRunner.test("GameSessionService respawn placement preserves run state", function()
	local service, player = createRunningSession("PlacementPreservesState", 140)
	local character = createCharacter("StatePreservedCharacter")
	service:ReachCheckpoint(player, waterStartCheckpoint)
	local before = service:GetSnapshot(player) :: any

	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local after = service:GetSnapshot(player) :: any
	TestRunner.assertEqual(after.revision, before.revision)
	TestRunner.assertEqual(after.phase, before.phase)
	TestRunner.assertEqual(after.startedAtServerTime, before.startedAtServerTime)
	TestRunner.assertEqual(after.finishedElapsedSeconds, before.finishedElapsedSeconds)
	TestRunner.assertEqual(after.coinCount, before.coinCount)
	TestRunner.assertEqual(#after.collectedCoinIds, #before.collectedCoinIds)

	character:Destroy()
end)

TestRunner.test("GameSessionService handles checkpoint operations after session removal", function()
	local service, player = createRunningSession("RemovedCheckpointSession", 150)
	local character = createCharacter("RemovedSessionCharacter")
	service:RemoveSession(player)

	TestRunner.assertEqual(service:ReachCheckpoint(player, waterStartCheckpoint), nil)
	TestRunner.assertFalse(service:PlaceCharacterAtCheckpoint(player, character))

	character:Destroy()
end)

TestRunner.test("ReachCheckpoint accepts checkpoint orders 2 3 and 4 only in exact sequence", function()
	local service, player = createRunningSession("ExactCheckpointSequence", 160)
	local expectedRevision = 1

	for _, checkpoint in { waterStartCheckpoint, laserIslandStartCheckpoint, palmBaseCheckpoint } do
		local snapshot = service:ReachCheckpoint(player, checkpoint) :: any
		expectedRevision += 1
		TestRunner.assertTrue(snapshot ~= nil)
		TestRunner.assertEqual(snapshot.revision, expectedRevision)
		for _, value in snapshot do
			TestRunner.assertFalse(typeof(value) == "Instance")
		end
	end
end)

TestRunner.test("ReachCheckpoint rejects order 3 while current order is 1 without changing state", function()
	local service, player = createRunningSession("RejectOrderThreeSkip", 170)
	local before = service:GetSnapshot(player) :: any
	local character = createCharacter("RejectOrderThreeCharacter")

	TestRunner.assertEqual(service:ReachCheckpoint(player, laserIslandStartCheckpoint), nil)
	local after = service:GetSnapshot(player) :: any
	assertSnapshotsEqual(after, before)
	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	assertVectorClose(character:GetPivot().Position, startSpawn.Position + Vector3.new(0, 4, 0))

	character:Destroy()
end)

TestRunner.test("ReachCheckpoint rejects order 4 while current order is 2 without changing state", function()
	local service, player = createRunningSession("RejectOrderFourSkip", 180)
	service:ReachCheckpoint(player, waterStartCheckpoint)
	local before = service:GetSnapshot(player) :: any
	local character = createCharacter("RejectOrderFourCharacter")

	TestRunner.assertEqual(service:ReachCheckpoint(player, palmBaseCheckpoint), nil)
	local after = service:GetSnapshot(player) :: any
	assertSnapshotsEqual(after, before)
	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local offset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(character:GetPivot().Position, waterStartCheckpoint.Position + offset)

	character:Destroy()
end)

TestRunner.test("ReachCheckpoint rejects an untagged checkpoint with otherwise valid attributes", function()
	local service, player = createRunningSession("RejectUntaggedCheckpoint", 190)
	local checkpoint = createCheckpoint("UntaggedOrderTwo", "UntaggedOrderTwo", 2, Vector3.new(0, 4, 0), nil, false)
	local before = service:GetSnapshot(player) :: any
	local character = createCharacter("RejectUntaggedCharacter")

	TestRunner.assertEqual(service:ReachCheckpoint(player, checkpoint), nil)
	local after = service:GetSnapshot(player) :: any
	assertSnapshotsEqual(after, before)
	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	assertVectorClose(character:GetPivot().Position, startSpawn.Position + Vector3.new(0, 4, 0))

	character:Destroy()
	destroyCheckpoint(checkpoint)
end)

TestRunner.test("Rejected checkpoint skip keeps respawn at the latest accepted checkpoint", function()
	local service, player = createRunningSession("RejectedSkipRespawn", 200)
	service:ReachCheckpoint(player, waterStartCheckpoint)
	local before = service:GetSnapshot(player) :: any
	local character = createCharacter("RejectedSkipRespawnCharacter")

	TestRunner.assertEqual(service:ReachCheckpoint(player, palmBaseCheckpoint), nil)
	local after = service:GetSnapshot(player) :: any
	assertSnapshotsEqual(after, before)
	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local offset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(character:GetPivot().Position, waterStartCheckpoint.Position + offset)

	character:Destroy()
end)

return true
