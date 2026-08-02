--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionService = require(ServerScriptService.Services.GameSessionService)
local WorldTriggerService = require(ServerScriptService.Services.WorldTriggerService)
local TestRunner = require(script.Parent.TestRunner)

local world = Workspace:WaitForChild("BeachObby"):WaitForChild("World")
local startSpawn = world:WaitForChild("Scene01_HotBeach"):WaitForChild("Start"):WaitForChild("StartSpawn") :: BasePart
local waterStartCheckpoint = world:WaitForChild("Scene01_HotBeach")
	:WaitForChild("Triggers")
	:WaitForChild("WaterStartCheckpoint") :: BasePart

type CleanupCallback = () -> ()
type AddCleanup = (CleanupCallback) -> ()

type CapturedTouchConnection = {
	connected: boolean,
	callback: (BasePart) -> (),
	disconnectCount: number,
	Disconnect: (self: CapturedTouchConnection) -> (),
}

type Harness = {
	router: any,
	mapCharacter: (Model, Player) -> (),
	fireTouch: (BasePart, BasePart) -> (),
	getConnectCount: (Instance) -> number,
	isConnected: (Instance) -> boolean,
	getRemoteSendCount: () -> number,
}

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

local function trackInstance(addCleanup: AddCleanup, instance: Instance): Instance
	addCleanup(function()
		if instance.Parent ~= nil then
			instance:Destroy()
		end
	end)

	return instance
end

local function createHazard(addCleanup: AddCleanup, name: string): Part
	local hazard = trackInstance(addCleanup, Instance.new("Part")) :: Part
	hazard.Name = name
	hazard.Anchored = true
	hazard.CanTouch = true
	hazard.Parent = Workspace
	return hazard
end

local function createCharacter(addCleanup: AddCleanup, name: string, includeHumanoid: boolean?): (Model, BasePart, Humanoid?)
	local character = trackInstance(addCleanup, Instance.new("Model")) :: Model
	character.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character

	local humanoid: Humanoid? = nil

	if includeHumanoid ~= false then
		humanoid = Instance.new("Humanoid")
		humanoid.MaxHealth = 100
		humanoid.Health = 100
		humanoid.Parent = character
	end

	character.PrimaryPart = rootPart
	character.Parent = Workspace
	return character, rootPart, humanoid
end

local function createPlayerIdentity(name: string, character: Model): Player
	return ({
		Name = name,
		Character = character,
	} :: any) :: Player
end

local function createNoOpSessionService(): any
	local sessionService = {}

	function sessionService:StartRun(_player: Player, _startedAtServerTime: number)
		return nil
	end

	function sessionService:ReachCheckpoint(_player: Player, _checkpoint: Instance)
		return nil
	end

	return sessionService
end

local function createHarness(addCleanup: AddCleanup, sessionService: any?): Harness
	local playersByCharacter: { [Model]: Player } = {}
	local touchConnections: { [Instance]: CapturedTouchConnection } = {}
	local connectCounts: { [Instance]: number } = {}
	local remoteSendCount = 0

	local fakePlayers = {}

	function fakePlayers:GetPlayerFromCharacter(character: Model): Player?
		return playersByCharacter[character]
	end

	local fakeRemote = {}

	function fakeRemote:FireClient(_player: Player, _snapshot: any)
		remoteSendCount += 1
	end

	local dependencies = {
		players = fakePlayers,
		collectionService = CollectionService,
		workspace = Workspace,
		connectTouched = function(instance: BasePart, callback: (BasePart) -> ())
			connectCounts[instance] = (connectCounts[instance] or 0) + 1

			local connection: CapturedTouchConnection = {
				connected = true,
				callback = callback,
				disconnectCount = 0,
				Disconnect = function(self)
					if not self.connected then
						return
					end

					self.connected = false
					self.disconnectCount += 1
				end,
			}

			touchConnections[instance] = connection
			return connection
		end,
	}

	local router = WorldTriggerService.new(sessionService or createNoOpSessionService(), fakeRemote, dependencies)
	addCleanup(function()
		router:Destroy()
	end)

	return {
		router = router,
		mapCharacter = function(character, player)
			playersByCharacter[character] = player
		end,
		fireTouch = function(hazard, hit)
			local connection = touchConnections[hazard]

			if connection ~= nil and connection.connected then
				connection.callback(hit)
			end
		end,
		getConnectCount = function(instance)
			return connectCounts[instance] or 0
		end,
		isConnected = function(instance)
			local connection = touchConnections[instance]
			return connection ~= nil and connection.connected
		end,
		getRemoteSendCount = function()
			return remoteSendCount
		end,
	}
end

local function startHazardHarness(
	addCleanup: AddCleanup,
	name: string,
	sessionService: any?
): (Harness, Part)
	local hazard = createHazard(addCleanup, name)
	CollectionService:AddTag(hazard, RunConfig.Tags.Hazard)

	local harness = createHarness(addCleanup, sessionService)
	TestRunner.assertTrue(harness.router:Start())
	return harness, hazard
end

testWithCleanup("WorldTriggerService Hazard kills a living player Humanoid", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "LivingPlayerHazard")
	local character, rootPart, humanoid = createCharacter(addCleanup, "LivingPlayerCharacter")
	local player = createPlayerIdentity("LivingPlayer", character)
	harness.mapCharacter(character, player)

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual((humanoid :: Humanoid).Health, 0)
end)

testWithCleanup("WorldTriggerService Hazard safely ignores an already dead Humanoid", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "DeadPlayerHazard")
	local character, rootPart, humanoid = createCharacter(addCleanup, "DeadPlayerCharacter")
	local player = createPlayerIdentity("DeadPlayer", character)
	harness.mapCharacter(character, player)

	harness.fireTouch(hazard, rootPart)
	local repeatedTouchesSucceeded = pcall(function()
		harness.fireTouch(hazard, rootPart)
		harness.fireTouch(hazard, rootPart)
	end)

	TestRunner.assertTrue(repeatedTouchesSucceeded)
	TestRunner.assertEqual((humanoid :: Humanoid).Health, 0)
end)

testWithCleanup("WorldTriggerService Hazard ignores a non-character Part", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "NonCharacterHazard")
	local unrelatedPart = trackInstance(addCleanup, Instance.new("Part")) :: Part
	unrelatedPart.Parent = Workspace

	local succeeded = pcall(function()
		harness.fireTouch(hazard, unrelatedPart)
	end)

	TestRunner.assertTrue(succeeded)
end)

testWithCleanup("WorldTriggerService Hazard ignores a player Model without Humanoid", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "NoHumanoidHazard")
	local character, rootPart = createCharacter(addCleanup, "NoHumanoidCharacter", false)
	local player = createPlayerIdentity("NoHumanoidPlayer", character)
	harness.mapCharacter(character, player)

	local succeeded = pcall(function()
		harness.fireTouch(hazard, rootPart)
	end)

	TestRunner.assertTrue(succeeded)
end)

testWithCleanup("WorldTriggerService Hazard ignores an NPC Humanoid without Player", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "NpcHazard")
	local _, rootPart, humanoid = createCharacter(addCleanup, "NpcCharacter")

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual((humanoid :: Humanoid).Health, 100)
end)

testWithCleanup("WorldTriggerService Hazard kills only the touching player", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "TwoPlayerHazard")
	local firstCharacter, firstRoot, firstHumanoid = createCharacter(addCleanup, "FirstHazardCharacter")
	local secondCharacter, _, secondHumanoid = createCharacter(addCleanup, "SecondHazardCharacter")
	harness.mapCharacter(firstCharacter, createPlayerIdentity("FirstHazardPlayer", firstCharacter))
	harness.mapCharacter(secondCharacter, createPlayerIdentity("SecondHazardPlayer", secondCharacter))

	harness.fireTouch(hazard, firstRoot)

	TestRunner.assertEqual((firstHumanoid :: Humanoid).Health, 0)
	TestRunner.assertEqual((secondHumanoid :: Humanoid).Health, 100)
end)

testWithCleanup("WorldTriggerService Hazard resolves an accessory Handle to its player character", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "AccessoryHazard")
	local character, _, humanoid = createCharacter(addCleanup, "AccessoryCharacter")
	local player = createPlayerIdentity("AccessoryPlayer", character)
	local accessory = Instance.new("Accessory")
	accessory.Name = "TestAccessory"
	accessory.Parent = character
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Parent = accessory
	harness.mapCharacter(character, player)

	harness.fireTouch(hazard, handle)

	TestRunner.assertEqual((humanoid :: Humanoid).Health, 0)
end)

testWithCleanup("WorldTriggerService Hazard does not change session revision", function(addCleanup)
	local character, rootPart = createCharacter(addCleanup, "RevisionCharacter")
	local player = createPlayerIdentity("RevisionPlayer", character)
	local service = GameSessionService.new(startSpawn)
	service:CreateSession(player)
	service:StartRun(player, 100)
	local harness, hazard = startHazardHarness(addCleanup, "RevisionHazard", service)
	harness.mapCharacter(character, player)
	local before = service:GetSnapshot(player) :: any

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).revision, before.revision)
end)

testWithCleanup("WorldTriggerService Hazard does not change session phase", function(addCleanup)
	local character, rootPart = createCharacter(addCleanup, "PhaseCharacter")
	local player = createPlayerIdentity("PhasePlayer", character)
	local service = GameSessionService.new(startSpawn)
	service:CreateSession(player)
	service:StartRun(player, 110)
	local harness, hazard = startHazardHarness(addCleanup, "PhaseHazard", service)
	harness.mapCharacter(character, player)

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).phase, RunConfig.Phases.Running)
end)

testWithCleanup("WorldTriggerService Hazard does not change startedAtServerTime", function(addCleanup)
	local character, rootPart = createCharacter(addCleanup, "StartTimeCharacter")
	local player = createPlayerIdentity("StartTimePlayer", character)
	local service = GameSessionService.new(startSpawn)
	service:CreateSession(player)
	service:StartRun(player, 123.45)
	local harness, hazard = startHazardHarness(addCleanup, "StartTimeHazard", service)
	harness.mapCharacter(character, player)

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual((service:GetSnapshot(player) :: any).startedAtServerTime, 123.45)
end)

testWithCleanup("WorldTriggerService Hazard does not change current checkpoint", function(addCleanup)
	local character, rootPart = createCharacter(addCleanup, "CheckpointStateCharacter")
	local player = createPlayerIdentity("CheckpointStatePlayer", character)
	local service = GameSessionService.new(startSpawn)
	service:CreateSession(player)
	service:StartRun(player, 130)
	service:ReachCheckpoint(player, waterStartCheckpoint)
	local harness, hazard = startHazardHarness(addCleanup, "CheckpointStateHazard", service)
	harness.mapCharacter(character, player)
	harness.fireTouch(hazard, rootPart)

	local placementCharacter = createCharacter(addCleanup, "CheckpointPlacementCharacter", false)
	TestRunner.assertTrue(service:PlaceCharacterAtCheckpoint(player, placementCharacter))
	local offset = waterStartCheckpoint:GetAttribute(RunConfig.Attributes.RespawnOffset) :: Vector3
	TestRunner.assertTrue(
		(placementCharacter:GetPivot().Position - (waterStartCheckpoint.CFrame + offset).Position).Magnitude < 0.01
	)
end)

testWithCleanup("WorldTriggerService connects an existing tagged Hazard at Start", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "ExistingTaggedHazard")
	local character, rootPart, humanoid = createCharacter(addCleanup, "ExistingTaggedCharacter")
	harness.mapCharacter(character, createPlayerIdentity("ExistingTaggedPlayer", character))

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(hazard), 1)
	TestRunner.assertEqual((humanoid :: Humanoid).Health, 0)
end)

testWithCleanup("WorldTriggerService connects a Hazard tagged after Start", function(addCleanup)
	local hazard = createHazard(addCleanup, "LateTaggedHazard")
	local harness = createHarness(addCleanup)
	TestRunner.assertTrue(harness.router:Start())
	local character, rootPart, humanoid = createCharacter(addCleanup, "LateTaggedCharacter")
	harness.mapCharacter(character, createPlayerIdentity("LateTaggedPlayer", character))

	CollectionService:AddTag(hazard, RunConfig.Tags.Hazard)
	task.wait()
	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(hazard), 1)
	TestRunner.assertEqual((humanoid :: Humanoid).Health, 0)
end)

testWithCleanup("WorldTriggerService disconnects Hazard when its tag is removed", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "RemovedTagHazard")
	local character, rootPart, humanoid = createCharacter(addCleanup, "RemovedTagCharacter")
	harness.mapCharacter(character, createPlayerIdentity("RemovedTagPlayer", character))

	CollectionService:RemoveTag(hazard, RunConfig.Tags.Hazard)
	task.wait()
	harness.fireTouch(hazard, rootPart)

	TestRunner.assertFalse(harness.isConnected(hazard))
	TestRunner.assertEqual((humanoid :: Humanoid).Health, 100)
end)

testWithCleanup("WorldTriggerService disconnects Hazard when its Instance is destroyed", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "DestroyedHazard")

	TestRunner.assertTrue(harness.isConnected(hazard))
	hazard:Destroy()
	task.wait()

	TestRunner.assertFalse(harness.isConnected(hazard))
end)

testWithCleanup("WorldTriggerService repeated Start does not duplicate Hazard connection", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "IdempotentStartHazard")

	TestRunner.assertFalse(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(hazard), 1)
end)

testWithCleanup("WorldTriggerService safely ignores tagged non-BasePart Instance", function(addCleanup)
	local taggedFolder = trackInstance(addCleanup, Instance.new("Folder"))
	taggedFolder.Name = "TaggedHazardFolder"
	taggedFolder.Parent = Workspace
	CollectionService:AddTag(taggedFolder, RunConfig.Tags.Hazard)
	local harness = createHarness(addCleanup)

	TestRunner.assertTrue(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(taggedFolder), 0)
	TestRunner.assertFalse(harness.isConnected(taggedFolder))
end)

testWithCleanup("WorldTriggerService Hazard does not send RunStateUpdated", function(addCleanup)
	local harness, hazard = startHazardHarness(addCleanup, "NoRemoteHazard")
	local character, rootPart = createCharacter(addCleanup, "NoRemoteCharacter")
	harness.mapCharacter(character, createPlayerIdentity("NoRemotePlayer", character))

	harness.fireTouch(hazard, rootPart)

	TestRunner.assertEqual(harness.getRemoteSendCount(), 0)
end)

return true
