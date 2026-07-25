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

local function createCoin(addCleanup: AddCleanup, name: string): Part
	local coin = trackInstance(addCleanup, Instance.new("Part")) :: Part
	coin.Name = name
	coin.Anchored = true
	coin.CanTouch = true
	coin:SetAttribute(RunConfig.Attributes.CoinId, name)
	coin.Parent = Workspace
	return coin
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
		return {
			revision = counts.collectCoin,
			phase = RunConfig.Phases.Running,
			startedAtServerTime = 1,
			finishedElapsedSeconds = nil,
			coinCount = counts.collectCoin,
			collectedCoinIds = { "RouterCoin" },
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
		fireTouch = function(coin, hit)
			local connection = touchConnections[coin]

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

local function startCoinHarness(addCleanup: AddCleanup, name: string): (Harness, Part)
	local coin = createCoin(addCleanup, name)
	CollectionService:AddTag(coin, RunConfig.Tags.Coin)
	local harness = createHarness(addCleanup)
	TestRunner.assertTrue(harness.router:Start())
	return harness, coin
end

testWithCleanup("WorldTriggerService connects existing tagged Coin at Start", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "ExistingRouterCoin")
	local character, rootPart = createCharacter(addCleanup, "ExistingRouterCoinCharacter")
	harness.mapCharacter(character, createPlayerIdentity("ExistingRouterCoinPlayer", character))

	harness.fireTouch(coin, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(coin), 1)
	TestRunner.assertEqual(harness.counts.collectCoin, 1)
end)

testWithCleanup("WorldTriggerService connects Coin tagged after Start", function(addCleanup)
	local coin = createCoin(addCleanup, "LateRouterCoin")
	local harness = createHarness(addCleanup)
	TestRunner.assertTrue(harness.router:Start())
	local character, rootPart = createCharacter(addCleanup, "LateRouterCoinCharacter")
	harness.mapCharacter(character, createPlayerIdentity("LateRouterCoinPlayer", character))

	CollectionService:AddTag(coin, RunConfig.Tags.Coin)
	task.wait()
	harness.fireTouch(coin, rootPart)

	TestRunner.assertEqual(harness.getConnectCount(coin), 1)
	TestRunner.assertEqual(harness.counts.collectCoin, 1)
end)

testWithCleanup("WorldTriggerService disconnects Coin when tag is removed", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "RemovedTagRouterCoin")
	local character, rootPart = createCharacter(addCleanup, "RemovedTagRouterCoinCharacter")
	harness.mapCharacter(character, createPlayerIdentity("RemovedTagRouterCoinPlayer", character))

	CollectionService:RemoveTag(coin, RunConfig.Tags.Coin)
	task.wait()
	harness.fireTouch(coin, rootPart)

	TestRunner.assertFalse(harness.isConnected(coin))
	TestRunner.assertEqual(harness.counts.collectCoin, 0)
end)

testWithCleanup("WorldTriggerService disconnects Coin when Instance is destroyed", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "DestroyedRouterCoin")

	TestRunner.assertTrue(harness.isConnected(coin))
	coin:Destroy()
	task.wait()

	TestRunner.assertFalse(harness.isConnected(coin))
end)

testWithCleanup("WorldTriggerService repeated Start does not duplicate Coin connection", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "IdempotentRouterCoin")

	TestRunner.assertFalse(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(coin), 1)
end)

testWithCleanup("WorldTriggerService Coin ignores non-character touching Part", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "NonCharacterRouterCoin")
	local unrelatedPart = trackInstance(addCleanup, Instance.new("Part")) :: Part
	unrelatedPart.Parent = Workspace

	harness.fireTouch(coin, unrelatedPart)

	TestRunner.assertEqual(harness.counts.collectCoin, 0)
end)

testWithCleanup("WorldTriggerService Coin ignores NPC without Player", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "NpcRouterCoin")
	local _, rootPart = createCharacter(addCleanup, "NpcRouterCoinCharacter")

	harness.fireTouch(coin, rootPart)

	TestRunner.assertEqual(harness.counts.collectCoin, 0)
end)

testWithCleanup("WorldTriggerService Coin resolves accessory Handle to player character", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "AccessoryRouterCoin")
	local character = createCharacter(addCleanup, "AccessoryRouterCoinCharacter")
	local player = createPlayerIdentity("AccessoryRouterCoinPlayer", character)
	local accessory = Instance.new("Accessory")
	accessory.Parent = character
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Parent = accessory
	harness.mapCharacter(character, player)

	harness.fireTouch(coin, handle)

	TestRunner.assertEqual(harness.counts.collectCoin, 1)
end)

testWithCleanup("WorldTriggerService Coin calls only coin API and sends returned snapshot", function(addCleanup)
	local harness, coin = startCoinHarness(addCleanup, "CoinApiRouterCoin")
	local character, rootPart, humanoid = createCharacter(addCleanup, "CoinApiRouterCoinCharacter")
	harness.mapCharacter(character, createPlayerIdentity("CoinApiRouterCoinPlayer", character))

	harness.fireTouch(coin, rootPart)

	TestRunner.assertEqual(harness.counts.collectCoin, 1)
	TestRunner.assertEqual(harness.counts.startRun, 0)
	TestRunner.assertEqual(harness.counts.reachCheckpoint, 0)
	TestRunner.assertEqual(harness.counts.remote, 1)
	TestRunner.assertEqual(humanoid.Health, 100)
end)

testWithCleanup("WorldTriggerService safely ignores tagged Coin non-BasePart", function(addCleanup)
	local folder = trackInstance(addCleanup, Instance.new("Folder"))
	folder.Name = "TaggedCoinFolder"
	folder.Parent = Workspace
	CollectionService:AddTag(folder, RunConfig.Tags.Coin)
	local harness = createHarness(addCleanup)

	TestRunner.assertTrue(harness.router:Start())
	TestRunner.assertEqual(harness.getConnectCount(folder), 0)
	TestRunner.assertFalse(harness.isConnected(folder))
end)

return true
