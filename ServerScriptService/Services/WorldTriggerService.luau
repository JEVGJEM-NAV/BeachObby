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
}

local WorldTriggerService = {}

local started = false
local triggerConnections: { [string]: { [Instance]: RBXScriptConnection } } = {}
local lifecycleConnections: { RBXScriptConnection } = {}

local function resolvePlayer(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")

	if character == nil then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function disconnectTrigger(tagName: string, instance: Instance)
	local connectionsForTag = triggerConnections[tagName]

	if connectionsForTag == nil then
		return
	end

	local connection = connectionsForTag[instance]

	if connection == nil then
		return
	end

	connection:Disconnect()
	connectionsForTag[instance] = nil
end

local function connectTrigger(
	tagName: string,
	instance: Instance,
	sessionService: SessionService,
	runStateUpdated: RemoteEvent
)
	if not instance:IsA("BasePart") then
		return
	end

	local connectionsForTag = triggerConnections[tagName]

	if connectionsForTag == nil then
		connectionsForTag = {}
		triggerConnections[tagName] = connectionsForTag
	end

	if connectionsForTag[instance] ~= nil then
		return
	end

	connectionsForTag[instance] = instance.Touched:Connect(function(hit)
		local player = resolvePlayer(hit)

		if player == nil then
			return
		end

		local snapshot: RunStateSnapshot?

		if tagName == RunConfig.Tags.RunStart then
			snapshot = sessionService:StartRun(player, Workspace:GetServerTimeNow())
		elseif tagName == RunConfig.Tags.Checkpoint then
			snapshot = sessionService:ReachCheckpoint(player, instance)
		end

		if snapshot ~= nil then
			runStateUpdated:FireClient(player, snapshot)
		end
	end)
end

function WorldTriggerService.Start(sessionService: SessionService, runStateUpdated: RemoteEvent): boolean
	if started then
		return false
	end

	started = true

	local routedTags = {
		RunConfig.Tags.RunStart,
		RunConfig.Tags.Checkpoint,
	}

	for _, tagName in routedTags do
		for _, instance in CollectionService:GetTagged(tagName) do
			connectTrigger(tagName, instance, sessionService, runStateUpdated)
		end

		table.insert(
			lifecycleConnections,
			CollectionService:GetInstanceAddedSignal(tagName):Connect(function(instance)
				connectTrigger(tagName, instance, sessionService, runStateUpdated)
			end)
		)

		table.insert(
			lifecycleConnections,
			CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(instance)
				disconnectTrigger(tagName, instance)
			end)
		)
	end

	return true
end

return table.freeze(WorldTriggerService)
