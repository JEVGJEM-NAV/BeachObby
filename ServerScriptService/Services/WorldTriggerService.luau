--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)

type RunStateSnapshot = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	coinCount: number,
	collectedCoinIds: { string },
}

type SessionService = {
	StartRun: (self: SessionService, player: Player, startedAtServerTime: number) -> RunStateSnapshot?,
	ReachCheckpoint: (self: SessionService, player: Player, checkpoint: Instance) -> RunStateSnapshot?,
	CollectCoin: (self: SessionService, player: Player, coin: Instance) -> RunStateSnapshot?,
}

type Disconnectable = {
	Disconnect: (self: Disconnectable) -> (),
}

type TriggerConnection = {
	touched: Disconnectable,
	destroying: Disconnectable,
}

export type Dependencies = {
	players: any,
	collectionService: any,
	workspace: any,
	connectTouched: (BasePart, (BasePart) -> ()) -> Disconnectable,
}

type RouterFields = {
	_sessionService: SessionService,
	_runStateUpdated: any,
	_dependencies: Dependencies,
	_started: boolean,
	_triggerConnections: { [string]: { [Instance]: TriggerConnection } },
	_lifecycleConnections: { Disconnectable },
}

local Router = {}
Router.__index = Router

export type RouterService = typeof(setmetatable({} :: RouterFields, Router))

local WorldTriggerService = {}
local defaultRouter: RouterService? = nil

local function createDefaultDependencies(): Dependencies
	return {
		players = Players,
		collectionService = CollectionService,
		workspace = Workspace,
		connectTouched = function(instance, callback)
			return instance.Touched:Connect(callback)
		end,
	}
end

local function resolveCharacterAndPlayer(self: RouterService, hit: BasePart): (Model?, Player?)
	local character = hit:FindFirstAncestorOfClass("Model")

	if character == nil then
		return nil, nil
	end

	return character, self._dependencies.players:GetPlayerFromCharacter(character)
end

local function handleHazardTouch(self: RouterService, hit: BasePart)
	local character, player = resolveCharacterAndPlayer(self, hit)

	if character == nil or player == nil or player.Character ~= character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid == nil or humanoid.Health <= 0 then
		return
	end

	humanoid.Health = 0
end

local function disconnectTrigger(self: RouterService, tagName: string, instance: Instance)
	local connectionsForTag = self._triggerConnections[tagName]

	if connectionsForTag == nil then
		return
	end

	local connections = connectionsForTag[instance]

	if connections == nil then
		return
	end

	connectionsForTag[instance] = nil
	connections.touched:Disconnect()
	connections.destroying:Disconnect()
end

local function connectTrigger(self: RouterService, tagName: string, instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local connectionsForTag = self._triggerConnections[tagName]

	if connectionsForTag == nil then
		connectionsForTag = {}
		self._triggerConnections[tagName] = connectionsForTag
	end

	if connectionsForTag[instance] ~= nil then
		return
	end

	local touchedConnection = self._dependencies.connectTouched(instance, function(hit)
		if tagName == RunConfig.Tags.Hazard then
			handleHazardTouch(self, hit)
			return
		end

		local character, player = resolveCharacterAndPlayer(self, hit)

		if character == nil or player == nil or player.Character ~= character then
			return
		end

		local snapshot: RunStateSnapshot?

		if tagName == RunConfig.Tags.RunStart then
			snapshot = self._sessionService:StartRun(player, self._dependencies.workspace:GetServerTimeNow())
		elseif tagName == RunConfig.Tags.Checkpoint then
			snapshot = self._sessionService:ReachCheckpoint(player, instance)
		elseif tagName == RunConfig.Tags.Coin then
			snapshot = self._sessionService:CollectCoin(player, instance)
		end

		if snapshot ~= nil then
			self._runStateUpdated:FireClient(player, snapshot)
		end
	end)

	local destroyingConnection: Disconnectable
	destroyingConnection = instance.Destroying:Connect(function()
		disconnectTrigger(self, tagName, instance)
	end)

	connectionsForTag[instance] = {
		touched = touchedConnection,
		destroying = destroyingConnection,
	}
end

function Router.Start(self: RouterService): boolean
	if self._started then
		return false
	end

	self._started = true

	local routedTags = {
		RunConfig.Tags.RunStart,
		RunConfig.Tags.Checkpoint,
		RunConfig.Tags.Hazard,
		RunConfig.Tags.Coin,
	}

	for _, tagName in routedTags do
		for _, instance in self._dependencies.collectionService:GetTagged(tagName) do
			connectTrigger(self, tagName, instance)
		end

		table.insert(
			self._lifecycleConnections,
			self._dependencies.collectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
				connectTrigger(self, tagName, instance)
			end)
		)

		table.insert(
			self._lifecycleConnections,
			self._dependencies.collectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
				disconnectTrigger(self, tagName, instance)
			end)
		)
	end

	return true
end

function Router.Destroy(self: RouterService)
	for tagName, connectionsForTag in self._triggerConnections do
		local instances = {}

		for instance in connectionsForTag do
			table.insert(instances, instance)
		end

		for _, instance in instances do
			disconnectTrigger(self, tagName, instance)
		end
	end

	for _, connection in self._lifecycleConnections do
		connection:Disconnect()
	end

	table.clear(self._lifecycleConnections)
	self._started = false
end

function WorldTriggerService.new(
	sessionService: SessionService,
	runStateUpdated: any,
	dependencies: Dependencies?
): RouterService
	return setmetatable({
		_sessionService = sessionService,
		_runStateUpdated = runStateUpdated,
		_dependencies = dependencies or createDefaultDependencies(),
		_started = false,
		_triggerConnections = {},
		_lifecycleConnections = {},
	}, Router)
end

function WorldTriggerService.Start(sessionService: SessionService, runStateUpdated: RemoteEvent): boolean
	if defaultRouter == nil then
		defaultRouter = WorldTriggerService.new(sessionService, runStateUpdated)
	end

	return defaultRouter:Start()
end

return table.freeze(WorldTriggerService)
