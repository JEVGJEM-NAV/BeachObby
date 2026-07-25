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
}

local WorldTriggerService = {}

local started = false
local triggerConnections: { [Instance]: RBXScriptConnection } = {}
local lifecycleConnections: { RBXScriptConnection } = {}

local function resolvePlayer(hit: BasePart): Player?
	local character = hit:FindFirstAncestorOfClass("Model")

	if character == nil then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function disconnectTrigger(instance: Instance)
	local connection = triggerConnections[instance]

	if connection == nil then
		return
	end

	connection:Disconnect()
	triggerConnections[instance] = nil
end

local function connectRunStart(instance: Instance, sessionService: SessionService, runStateUpdated: RemoteEvent)
	if triggerConnections[instance] ~= nil or not instance:IsA("BasePart") then
		return
	end

	triggerConnections[instance] = instance.Touched:Connect(function(hit)
		local player = resolvePlayer(hit)

		if player == nil then
			return
		end

		local snapshot = sessionService:StartRun(player, Workspace:GetServerTimeNow())

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

	for _, instance in CollectionService:GetTagged(RunConfig.Tags.RunStart) do
		connectRunStart(instance, sessionService, runStateUpdated)
	end

	table.insert(
		lifecycleConnections,
		CollectionService:GetInstanceAddedSignal(RunConfig.Tags.RunStart):Connect(function(instance)
			connectRunStart(instance, sessionService, runStateUpdated)
		end)
	)

	table.insert(
		lifecycleConnections,
		CollectionService:GetInstanceRemovedSignal(RunConfig.Tags.RunStart):Connect(disconnectTrigger)
	)

	return true
end

return table.freeze(WorldTriggerService)
