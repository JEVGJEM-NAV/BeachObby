--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local remotes = ReplicatedStorage.BeachObby.Remotes
local runStateUpdated = remotes:WaitForChild(RunConfig.Remotes.RunStateUpdated) :: RemoteEvent
local getRunState = remotes:WaitForChild(RunConfig.Remotes.GetRunState) :: RemoteFunction

export type RunStateSnapshot = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	coinCount: number,
	collectedCoinIds: { string },
}

export type Subscriber = (RunStateSnapshot) -> ()

local RunStateController = {}

local initialized = false
local state: RunStateSnapshot? = nil
local subscribers: { [number]: Subscriber } = {}
local nextSubscriberId = 0
local runStateConnection: RBXScriptConnection? = nil

local function copySnapshot(snapshot: RunStateSnapshot): RunStateSnapshot
	return {
		revision = snapshot.revision,
		phase = snapshot.phase,
		startedAtServerTime = snapshot.startedAtServerTime,
		finishedElapsedSeconds = snapshot.finishedElapsedSeconds,
		coinCount = snapshot.coinCount,
		collectedCoinIds = table.clone(snapshot.collectedCoinIds),
	}
end

local function normalizeSnapshot(candidate: any): RunStateSnapshot?
	if type(candidate) ~= "table" or type(candidate.revision) ~= "number" then
		return nil
	end

	if type(candidate.phase) ~= "string" or type(candidate.coinCount) ~= "number" then
		return nil
	end

	if candidate.startedAtServerTime ~= nil and type(candidate.startedAtServerTime) ~= "number" then
		return nil
	end

	if candidate.finishedElapsedSeconds ~= nil and type(candidate.finishedElapsedSeconds) ~= "number" then
		return nil
	end

	if type(candidate.collectedCoinIds) ~= "table" then
		return nil
	end

	local collectedCoinIds = {}

	for _, coinId in candidate.collectedCoinIds do
		if type(coinId) ~= "string" then
			return nil
		end

		table.insert(collectedCoinIds, coinId)
	end

	return {
		revision = candidate.revision,
		phase = candidate.phase,
		startedAtServerTime = candidate.startedAtServerTime,
		finishedElapsedSeconds = candidate.finishedElapsedSeconds,
		coinCount = candidate.coinCount,
		collectedCoinIds = collectedCoinIds,
	}
end

local function notifySubscribers()
	local currentState = state

	if currentState == nil then
		return
	end

	for _, subscriber in subscribers do
		pcall(subscriber, copySnapshot(currentState))
	end
end

local function applySnapshot(candidate: any)
	local snapshot = normalizeSnapshot(candidate)

	if snapshot == nil then
		return
	end

	if state ~= nil and snapshot.revision <= state.revision then
		return
	end

	state = snapshot
	notifySubscribers()
end

function RunStateController.Init()
	if initialized then
		return
	end

	initialized = true
	runStateConnection = runStateUpdated.OnClientEvent:Connect(applySnapshot)

	local succeeded, initialSnapshot = pcall(function()
		return getRunState:InvokeServer()
	end)

	if not succeeded then
		if runStateConnection ~= nil then
			runStateConnection:Disconnect()
			runStateConnection = nil
		end

		initialized = false
		error(string.format("Failed to get initial run state: %s", tostring(initialSnapshot)), 2)
	end

	applySnapshot(initialSnapshot)
end

function RunStateController.GetState(): RunStateSnapshot?
	if state == nil then
		return nil
	end

	return copySnapshot(state)
end

function RunStateController.Subscribe(callback: Subscriber): () -> ()
	nextSubscriberId += 1
	local subscriberId = nextSubscriberId
	local subscribed = true

	subscribers[subscriberId] = callback

	if state ~= nil then
		pcall(callback, copySnapshot(state))
	end

	return function()
		if not subscribed then
			return
		end

		subscribed = false
		subscribers[subscriberId] = nil
	end
end

return table.freeze(RunStateController)
