--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local TestRunner = require(script.Parent.TestRunner)

local verticalSlice = Workspace:WaitForChild("BeachObby"):WaitForChild("VerticalSlice")
local startSpawn = verticalSlice:WaitForChild("StartSpawn") :: BasePart
local midCheckpoint = verticalSlice:WaitForChild("Triggers"):WaitForChild("MidCheckpoint") :: BasePart

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
	position: Vector3?
): Part
	local checkpoint = Instance.new("Part")
	checkpoint.Name = name
	checkpoint.Anchored = true
	checkpoint.Position = position or Vector3.zero
	checkpoint:SetAttribute(RunConfig.Attributes.CheckpointId, checkpointId)
	checkpoint:SetAttribute(RunConfig.Attributes.CheckpointOrder, checkpointOrder)
	checkpoint:SetAttribute(RunConfig.Attributes.RespawnOffset, respawnOffset)
	checkpoint.Parent = Workspace
	return checkpoint
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

TestRunner.test("GameSessionService session begins at Start checkpoint order 1", function()
	local service, player = createRunningSession("InitialCheckpoint", 10)
	local sameOrderCheckpoint = createCheckpoint("SameOrder", "OtherStart", 1, Vector3.new(0, 4, 0))

	TestRunner.assertEqual(service:ReachCheckpoint(player, sameOrderCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	sameOrderCheckpoint:Destroy()
end)

TestRunner.test("GameSessionService ignores checkpoint before start", function()
	local service = GameSessionService.new(startSpawn)
	local player = createPlayerIdentity("CheckpointBeforeStart")
	service:CreateSession(player)

	TestRunner.assertEqual(service:ReachCheckpoint(player, midCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 0)
end)

TestRunner.test("GameSessionService accepts MidCheckpoint while running", function()
	local service, player = createRunningSession("AcceptMid", 20)
	local snapshot = service:ReachCheckpoint(player, midCheckpoint)

	TestRunner.assertTrue(snapshot ~= nil)
	TestRunner.assertEqual((snapshot :: any).phase, RunConfig.Phases.Running)
end)

TestRunner.test("GameSessionService checkpoint increments revision exactly once", function()
	local service, player = createRunningSession("CheckpointRevision", 30)
	local before = service:GetSnapshot(player) :: any
	local after = service:ReachCheckpoint(player, midCheckpoint) :: any

	TestRunner.assertEqual(after.revision, before.revision + 1)
end)

TestRunner.test("GameSessionService ignores repeated MidCheckpoint", function()
	local service, player = createRunningSession("RepeatedMid", 40)
	local first = service:ReachCheckpoint(player, midCheckpoint) :: any

	TestRunner.assertEqual(service:ReachCheckpoint(player, midCheckpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, first.revision)
end)

TestRunner.test("GameSessionService does not roll back from MidCheckpoint to StartSpawn", function()
	local service, player = createRunningSession("NoRollback", 50)
	service:ReachCheckpoint(player, midCheckpoint)
	local revisionAtMid = (service:GetSnapshot(player) :: any).revision

	TestRunner.assertEqual(service:ReachCheckpoint(player, startSpawn), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, revisionAtMid)
end)

TestRunner.test("GameSessionService checkpoint preserves startedAtServerTime", function()
	local service, player = createRunningSession("PreserveStartTime", 123.45)
	service:ReachCheckpoint(player, midCheckpoint)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).startedAtServerTime, 123.45)
end)

TestRunner.test("GameSessionService checkpoint preserves coinCount", function()
	local service, player = createRunningSession("PreserveCoins", 60)
	service:ReachCheckpoint(player, midCheckpoint)

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
	service:ReachCheckpoint(secondPlayer, midCheckpoint)
	service:PlaceCharacterAtCheckpoint(firstPlayer, firstCharacter)
	service:PlaceCharacterAtCheckpoint(secondPlayer, secondCharacter)

	local respawnOffset = midCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(firstCharacter:GetPivot().Position, startSpawn.Position + Vector3.new(0, 4, 0))
	assertVectorClose(secondCharacter:GetPivot().Position, midCheckpoint.Position + respawnOffset)

	firstCharacter:Destroy()
	secondCharacter:Destroy()
end)

TestRunner.test("GameSessionService checkpoint snapshot excludes checkpoint Instance", function()
	local service, player = createRunningSession("CheckpointSnapshot", 90)
	local snapshot = service:ReachCheckpoint(player, midCheckpoint) :: any

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

	checkpoint:Destroy()
end)

TestRunner.test("GameSessionService rejects invalid CheckpointOrder", function()
	local service, player = createRunningSession("InvalidCheckpointOrder", 110)
	local zeroOrder = createCheckpoint("ZeroOrder", "Zero", 0, Vector3.new(0, 4, 0))
	local fractionalOrder = createCheckpoint("FractionalOrder", "Fractional", 2.5, Vector3.new(0, 4, 0))

	TestRunner.assertEqual(service:ReachCheckpoint(player, zeroOrder), nil)
	TestRunner.assertEqual(service:ReachCheckpoint(player, fractionalOrder), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	zeroOrder:Destroy()
	fractionalOrder:Destroy()
end)

TestRunner.test("GameSessionService rejects invalid RespawnOffset", function()
	local service, player = createRunningSession("InvalidRespawnOffset", 120)
	local checkpoint = createCheckpoint("InvalidOffset", "InvalidOffset", 2, "not-a-vector")

	TestRunner.assertEqual(service:ReachCheckpoint(player, checkpoint), nil)
	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, 1)

	checkpoint:Destroy()
end)

TestRunner.test("GameSessionService places character at checkpoint with offset", function()
	local service, player = createRunningSession("PlaceAtCheckpoint", 130)
	local character = createCharacter("PlacedCharacter")
	service:ReachCheckpoint(player, midCheckpoint)

	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, character))
	local respawnOffset = midCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	assertVectorClose(character:GetPivot().Position, midCheckpoint.Position + respawnOffset)

	character:Destroy()
end)

TestRunner.test("GameSessionService respawn placement preserves run state", function()
	local service, player = createRunningSession("PlacementPreservesState", 140)
	local character = createCharacter("StatePreservedCharacter")
	service:ReachCheckpoint(player, midCheckpoint)
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

	TestRunner.assertEqual(service:ReachCheckpoint(player, midCheckpoint), nil)
	TestRunner.assertFalse(service:PlaceCharacterAtCheckpoint(player, character))

	character:Destroy()
end)

return true
