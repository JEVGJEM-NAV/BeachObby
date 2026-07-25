--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldTriggerService = require(ServerScriptService.Services.WorldTriggerService)
local TestRunner = require(script.Parent.TestRunner)

type CleanupCallback = () -> ()
type AddCleanup = (CleanupCallback) -> ()

type CapturedTouchConnection = {
	connected: boolean,
	callback: (BasePart) -> (),
	Disconnect: (self: CapturedTouchConnection) -> (),
}

type CallCounts = {
	startRun: number,
	reachCheckpoint: number,
	collectCoin: number,
	finishRun: number,
	remote: number,
}

type Harness = {
	router: any,
	counts: CallCounts,
	mapCharacter: (Model, Player) -> (),
	fireTouch: (BasePart, BasePart) -> (),
	getConnectCount: (Instance) -> number,
	isConnected: (Instance) -> boolean,
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

local function createFinish(addCleanup: AddCleanup, name: string): Part
	local finishPart = trackInstance(addCleanup, Instance.new("Part")) :: Part
	finishPart.Name = name
	finishPart.Anchored = true
	finishPart.CanTouch = true
	finishPart:SetAttribute(RunConfig.Attributes.RequiredCheckpointOrder, 2)
	finishPart.Parent = Workspace
	return finishPart
end

local function createCharacter(addCleanup: AddCleanup, name: string): (Model, BasePart, Humanoid)
	local character = trackInstance(addCleanup, Instance.new("Model")) :: Model
	character.Name = name

	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Anchored = true
	rootPart.Parent = character

	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
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

local function createHarness(addCleanup: AddCleanup): Harness
	local playersByCharacter: { [Model]: Player } = {}
	local touchConnections: { [Instance]: CapturedTouchConnection } = {}
	local connectCounts: { [Instance]: number } = {}
	local counts: CallCounts = {
		startRun = 0,
		reachCheckpoint = 0,
		collectCoin = 0,
		finishRun = 0,
		remote = 0,
	}

	local fakePlayers = {}

	function fakePlayers:GetPlayerFromCharacter(character: Model): Player?
		return playersByCharacter[character]
	end

	local fakeSessionService = {}

	function fakeSessionService:StartRun(_player: Player, _startedAtServerTime: number)
		counts.startRun += 1
		return nil
	end

	function fakeSessionService:ReachCheckpoint(_player: Player, _checkpoint: Instance)
		counts.reachCheckpoint += 1
		return nil
	end

	function fakeSessionService:CollectCoin(_player: Player, _coin: Instance)
		counts.collectCoin += 1
		return nil
	end

	function fakeSessionService:FinishRun(_player: Player, _finishPart: Instance)
		counts.finishRun += 1
		return {
			revision = counts.finishRun,
			phase = RunConfig.Phases.Finished,
			startedAtServerTime = 1,
			finishedElapsedSeconds = 2,
			coinCount = 0,
			collectedCoinIds = {},
		}
	end

	local fakeRemote = {}

	function fakeRemote:FireClient(_player: Player, _snapshot: any)
		counts.remote += 1
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
				Disconnect = function(self)
					self.connected = false
				end,
			}

			touchConnections[instance] = connection
			return connection
		end,
	}

	local router = WorldTriggerService.new(fakeSessionService, fakeRemote, dependencies)
	addCleanup(function()
		router:Destroy()
	end)

	return {
		router = router,
		counts = counts,
		mapCharacter = function(character, player)
			playersByCharacter[character] = player
		end,
		fireTouch = function(finishPart, hit)
			local connection = touchConnections[finishPart]

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
	}
end

local function startFinishHarness(addCleanup: AddCleanup, name: string): (Harness, Part)
	local finishPart = createFinish(addCleanup, name)
	CollectionService:AddTag(finishPart, RunConfig.Tags.Finish)
	local harness = createHarness(addCleanup)
	TestRunner.assertTrue(harness.router:Start())
	return harness, finishPart
end

testWithCleanup("WorldTriggerService connects existing tagged Finish at Start", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "ExistingRouterFinish")
	local character, rootPart = createCharacter(addCleanup, "ExistingRouterFinishCharacter")
	harness.mapCharacter(character, createPlayerIdentity("ExistingRouterFinishPlayer", character))

	harness.fireTouch(finishPart, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(finishPart), 1)
	TestRunner.assertEqual(harness.counts.finishRun, 1)
end)

testWithCleanup("WorldTriggerService connects Finish tagged after Start", function(addCleanup)
	local finishPart = createFinish(addCleanup, "LateRouterFinish")
	local harness = createHarness(addCleanup)
	TestRunner.assertTrue(harness.router:Start())
	local character, rootPart = createCharacter(addCleanup, "LateRouterFinishCharacter")
	harness.mapCharacter(character, createPlayerIdentity("LateRouterFinishPlayer", character))

	CollectionService:AddTag(finishPart, RunConfig.Tags.Finish)
	task.wait()
	harness.fireTouch(finishPart, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(finishPart), 1)
	TestRunner.assertEqual(harness.counts.finishRun, 1)
end)

testWithCleanup("WorldTriggerService disconnects Finish when tag is removed", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "RemovedTagRouterFinish")
	local character, rootPart = createCharacter(addCleanup, "RemovedTagRouterFinishCharacter")
	harness.mapCharacter(character, createPlayerIdentity("RemovedTagRouterFinishPlayer", character))

	CollectionService:RemoveTag(finishPart, RunConfig.Tags.Finish)
	task.wait()
	harness.fireTouch(finishPart, rootPart)

	TestRunner.assertFalse(harness.isConnected(finishPart))
	TestRunner.assertEqual(harness.counts.finishRun, 0)
end)

testWithCleanup("WorldTriggerService disconnects Finish when Instance is destroyed", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "DestroyedRouterFinish")

	TestRunner.assertTrue(harness.isConnected(finishPart))
	finishPart:Destroy()
	task.wait()

	TestRunner.assertFalse(harness.isConnected(finishPart))
end)

testWithCleanup("WorldTriggerService repeated Start does not duplicate Finish connection", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "IdempotentRouterFinish")

	TestRunner.assertFalse(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(finishPart), 1)
end)

testWithCleanup("WorldTriggerService Finish ignores non-character touching Part", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "NonCharacterRouterFinish")
	local unrelatedPart = trackInstance(addCleanup, Instance.new("Part")) :: Part
	unrelatedPart.Parent = Workspace

	harness.fireTouch(finishPart, unrelatedPart)

	TestRunner.assertEqual(harness.counts.finishRun, 0)
end)

testWithCleanup("WorldTriggerService Finish ignores NPC without Player", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "NpcRouterFinish")
	local _, rootPart = createCharacter(addCleanup, "NpcRouterFinishCharacter")

	harness.fireTouch(finishPart, rootPart)

	TestRunner.assertEqual(harness.counts.finishRun, 0)
end)

testWithCleanup("WorldTriggerService Finish resolves accessory Handle to player character", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "AccessoryRouterFinish")
	local character = createCharacter(addCleanup, "AccessoryRouterFinishCharacter")
	local player = createPlayerIdentity("AccessoryRouterFinishPlayer", character)
	local accessory = Instance.new("Accessory")
	accessory.Parent = character
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Parent = accessory
	harness.mapCharacter(character, player)

	harness.fireTouch(finishPart, handle)

	TestRunner.assertEqual(harness.counts.finishRun, 1)
end)

testWithCleanup("WorldTriggerService Finish calls only finish API and sends returned snapshot", function(addCleanup)
	local harness, finishPart = startFinishHarness(addCleanup, "FinishApiRouterPart")
	local character, rootPart, humanoid = createCharacter(addCleanup, "FinishApiRouterCharacter")
	harness.mapCharacter(character, createPlayerIdentity("FinishApiRouterPlayer", character))

	harness.fireTouch(finishPart, rootPart)

	TestRunner.assertEqual(harness.counts.finishRun, 1)
	TestRunner.assertEqual(harness.counts.startRun, 0)
	TestRunner.assertEqual(harness.counts.reachCheckpoint, 0)
	TestRunner.assertEqual(harness.counts.collectCoin, 0)
	TestRunner.assertEqual(harness.counts.remote, 1)
	TestRunner.assertEqual(humanoid.Health, 100)
end)

testWithCleanup("WorldTriggerService safely ignores tagged Finish non-BasePart", function(addCleanup)
	local folder = trackInstance(addCleanup, Instance.new("Folder"))
	folder.Name = "TaggedFinishFolder"
	folder.Parent = Workspace
	CollectionService:AddTag(folder, RunConfig.Tags.Finish)
	local harness = createHarness(addCleanup)

	TestRunner.assertTrue(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(folder), 0)
	TestRunner.assertFalse(harness.isConnected(folder))
end)

return true
