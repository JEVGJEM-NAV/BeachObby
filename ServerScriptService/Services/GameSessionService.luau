--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)

export type RunStateSnapshot = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	coinCount: number,
	collectedCoinIds: { string },
}

type SessionState = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	currentCheckpoint: BasePart,
	currentCheckpointId: string,
	currentCheckpointOrder: number,
	collectedCoinIds: { [string]: boolean },
	coinCount: number,
}

type ServiceFields = {
	_defaultCheckpoint: BasePart,
	_sessions: { [Player]: SessionState },
}

local GameSessionService = {}
GameSessionService.__index = GameSessionService

export type Service = typeof(setmetatable({} :: ServiceFields, GameSessionService))

local defaultService: Service? = nil
local lifecycleConnections: { RBXScriptConnection } = {}

local function createSnapshot(session: SessionState): RunStateSnapshot
	local collectedCoinIds = {}

	for coinId in session.collectedCoinIds do
		table.insert(collectedCoinIds, coinId)
	end

	table.sort(collectedCoinIds)

	return {
		revision = session.revision,
		phase = session.phase,
		startedAtServerTime = session.startedAtServerTime,
		finishedElapsedSeconds = session.finishedElapsedSeconds,
		coinCount = session.coinCount,
		collectedCoinIds = collectedCoinIds,
	}
end

function GameSessionService.new(defaultCheckpoint: BasePart): Service
	return setmetatable({
		_defaultCheckpoint = defaultCheckpoint,
		_sessions = {},
	}, GameSessionService)
end

function GameSessionService.CreateSession(self: Service, player: Player): boolean
	if self._sessions[player] ~= nil then
		return false
	end

	self._sessions[player] = {
		revision = 0,
		phase = RunConfig.Phases.NotStarted,
		startedAtServerTime = nil,
		finishedElapsedSeconds = nil,
		currentCheckpoint = self._defaultCheckpoint,
		currentCheckpointId = "Start",
		currentCheckpointOrder = 1,
		collectedCoinIds = {},
		coinCount = 0,
	}

	return true
end

function GameSessionService.RemoveSession(self: Service, player: Player): boolean
	if self._sessions[player] == nil then
		return false
	end

	self._sessions[player] = nil
	return true
end

function GameSessionService.GetSnapshot(self: Service, player: Player): RunStateSnapshot?
	local session = self._sessions[player]

	if session == nil then
		return nil
	end

	return createSnapshot(session)
end

function GameSessionService.Start(players: Players, defaultCheckpoint: BasePart): (Service, boolean)
	if defaultService ~= nil then
		return defaultService, false
	end

	local service = GameSessionService.new(defaultCheckpoint)
	defaultService = service

	for _, player in players:GetPlayers() do
		service:CreateSession(player)
	end

	table.insert(lifecycleConnections, players.PlayerAdded:Connect(function(player)
		service:CreateSession(player)
	end))

	table.insert(lifecycleConnections, players.PlayerRemoving:Connect(function(player)
		service:RemoveSession(player)
	end))

	return service, true
end

return table.freeze(GameSessionService)
