--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

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
	_getServerTimeNow: () -> number,
	_sessions: { [Player]: SessionState },
	_characterAddedConnections: { [Player]: RBXScriptConnection },
	_warnedProblems: { [string]: boolean },
}

local GameSessionService = {}
GameSessionService.__index = GameSessionService

export type Service = typeof(setmetatable({} :: ServiceFields, GameSessionService))
export type Dependencies = {
	getServerTimeNow: () -> number,
}

local defaultService: Service? = nil
local lifecycleConnections: { RBXScriptConnection } = {}

local function getServerTimeNow(): number
	return Workspace:GetServerTimeNow()
end

local function readCheckpointContract(checkpoint: BasePart): (string?, number?, Vector3?)
	local checkpointId = checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId)
	local checkpointOrder = checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder)
	local respawnOffset = checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset)

	if typeof(checkpointId) ~= "string" or checkpointId == "" then
		return nil, nil, nil
	end

	if
		typeof(checkpointOrder) ~= "number"
		or checkpointOrder <= 0
		or checkpointOrder % 1 ~= 0
	then
		return nil, nil, nil
	end

	if typeof(respawnOffset) ~= "Vector3" then
		return nil, nil, nil
	end

	return checkpointId, checkpointOrder, respawnOffset
end

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

function GameSessionService.new(defaultCheckpoint: BasePart, dependencies: Dependencies?): Service
	local checkpointId, checkpointOrder = readCheckpointContract(defaultCheckpoint)
	assert(
		defaultCheckpoint:IsA("BasePart")
			and defaultCheckpoint:IsDescendantOf(Workspace)
			and CollectionService:HasTag(defaultCheckpoint, RunConfig.Tags.Checkpoint)
			and checkpointId == "Start"
			and checkpointOrder == 1,
		"Default checkpoint must be in Workspace, tagged Checkpoint, and have CheckpointId 'Start', CheckpointOrder 1, and a Vector3 RespawnOffset"
	)

	return setmetatable({
		_defaultCheckpoint = defaultCheckpoint,
		_getServerTimeNow = if dependencies == nil then getServerTimeNow else dependencies.getServerTimeNow,
		_sessions = {},
		_characterAddedConnections = {},
		_warnedProblems = {},
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
		currentCheckpointId = self._defaultCheckpoint:GetAttribute(RunConfig.Attributes.CheckpointId) :: string,
		currentCheckpointOrder = self._defaultCheckpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder) :: number,
		collectedCoinIds = {},
		coinCount = 0,
	}

	return true
end

function GameSessionService.RemoveSession(self: Service, player: Player): boolean
	if self._sessions[player] == nil then
		return false
	end

	local characterAddedConnection = self._characterAddedConnections[player]

	if characterAddedConnection ~= nil then
		characterAddedConnection:Disconnect()
		self._characterAddedConnections[player] = nil
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

function GameSessionService.StartRun(self: Service, player: Player, startedAtServerTime: number): RunStateSnapshot?
	local session = self._sessions[player]

	if session == nil or session.phase ~= RunConfig.Phases.NotStarted then
		return nil
	end

	if
		startedAtServerTime ~= startedAtServerTime
		or startedAtServerTime == math.huge
		or startedAtServerTime == -math.huge
	then
		return nil
	end

	session.phase = RunConfig.Phases.Running
	session.startedAtServerTime = startedAtServerTime
	session.revision += 1

	return createSnapshot(session)
end

function GameSessionService.ReachCheckpoint(self: Service, player: Player, checkpoint: Instance): RunStateSnapshot?
	local session = self._sessions[player]

	if
		session == nil
		or session.phase ~= RunConfig.Phases.Running
		or not checkpoint:IsA("BasePart")
		or not checkpoint:IsDescendantOf(Workspace)
		or not CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint)
	then
		return nil
	end

	local checkpointId, checkpointOrder = readCheckpointContract(checkpoint)

	if checkpointId == nil or checkpointOrder == nil or checkpointOrder ~= session.currentCheckpointOrder + 1 then
		return nil
	end

	session.currentCheckpoint = checkpoint
	session.currentCheckpointId = checkpointId
	session.currentCheckpointOrder = checkpointOrder
	session.revision += 1

	return createSnapshot(session)
end

function GameSessionService.CollectCoin(self: Service, player: Player, coin: Instance): RunStateSnapshot?
	local session = self._sessions[player]

	if
		session == nil
		or session.phase ~= RunConfig.Phases.Running
		or not coin:IsA("BasePart")
		or not coin:IsDescendantOf(Workspace)
		or not CollectionService:HasTag(coin, RunConfig.Tags.Coin)
	then
		return nil
	end

	local coinId = coin:GetAttribute(RunConfig.Attributes.CoinId)

	if typeof(coinId) ~= "string" or coinId == "" or session.collectedCoinIds[coinId] then
		return nil
	end

	session.collectedCoinIds[coinId] = true
	session.coinCount += 1
	session.revision += 1

	return createSnapshot(session)
end

function GameSessionService.FinishRun(self: Service, player: Player, finishPart: Instance): RunStateSnapshot?
	local session = self._sessions[player]

	if
		session == nil
		or session.phase ~= RunConfig.Phases.Running
		or typeof(session.startedAtServerTime) ~= "number"
		or not finishPart:IsA("BasePart")
		or not finishPart:IsDescendantOf(Workspace)
		or not CollectionService:HasTag(finishPart, RunConfig.Tags.Finish)
	then
		return nil
	end

	local requiredCheckpointOrder = finishPart:GetAttribute(RunConfig.Attributes.RequiredCheckpointOrder)

	if
		typeof(requiredCheckpointOrder) ~= "number"
		or requiredCheckpointOrder <= 0
		or requiredCheckpointOrder % 1 ~= 0
		or session.currentCheckpointOrder ~= requiredCheckpointOrder
	then
		return nil
	end

	local elapsed = self._getServerTimeNow() - session.startedAtServerTime

	if
		typeof(elapsed) ~= "number"
		or elapsed ~= elapsed
		or elapsed == math.huge
		or elapsed == -math.huge
		or elapsed < 0
	then
		elapsed = 0
	end

	session.phase = RunConfig.Phases.Finished
	session.finishedElapsedSeconds = elapsed
	session.revision += 1

	return createSnapshot(session)
end

function GameSessionService.PlaceCharacterAtCheckpoint(
	self: Service,
	player: Player,
	character: Model
): boolean
	local session = self._sessions[player]

	if session == nil or character.Parent == nil then
		return false
	end

	local checkpoint = session.currentCheckpoint
	local _, _, respawnOffset = readCheckpointContract(checkpoint)

	if not checkpoint:IsDescendantOf(Workspace) or respawnOffset == nil then
		local warningKey = string.format("invalid-checkpoint:%s", session.currentCheckpointId)

		if not self._warnedProblems[warningKey] then
			self._warnedProblems[warningKey] = true
			warn(
				string.format(
					"Beach Obby: checkpoint %q is unavailable or invalid; using StartSpawn",
					session.currentCheckpointId
				)
			)
		end

		checkpoint = self._defaultCheckpoint
		local _, _, defaultOffset = readCheckpointContract(checkpoint)
		respawnOffset = defaultOffset
	end

	if not checkpoint:IsDescendantOf(Workspace) or respawnOffset == nil then
		if not self._warnedProblems["invalid-default-checkpoint"] then
			self._warnedProblems["invalid-default-checkpoint"] = true
			warn("Beach Obby: StartSpawn is unavailable or invalid; character placement skipped")
		end

		return false
	end

	character:PivotTo(checkpoint.CFrame + respawnOffset)
	return true
end

local function connectPlayerLifecycle(service: Service, players: Players, player: Player)
	service:CreateSession(player)

	if service._characterAddedConnections[player] ~= nil then
		return
	end

	local function placeCharacter(character: Model)
		task.spawn(function()
			local rootPart = character:WaitForChild("HumanoidRootPart", 5)

			if
				rootPart == nil
				or not rootPart:IsA("BasePart")
				or player.Parent ~= players
				or player.Character ~= character
				or service:GetSnapshot(player) == nil
			then
				return
			end

			service:PlaceCharacterAtCheckpoint(player, character)
		end)
	end

	service._characterAddedConnections[player] = player.CharacterAdded:Connect(placeCharacter)

	if player.Character ~= nil then
		placeCharacter(player.Character)
	end
end

function GameSessionService.Start(players: Players, defaultCheckpoint: BasePart): (Service, boolean)
	if defaultService ~= nil then
		return defaultService, false
	end

	local service = GameSessionService.new(defaultCheckpoint)
	defaultService = service

	for _, player in players:GetPlayers() do
		connectPlayerLifecycle(service, players, player)
	end

	table.insert(lifecycleConnections, players.PlayerAdded:Connect(function(player)
		connectPlayerLifecycle(service, players, player)
	end))

	table.insert(lifecycleConnections, players.PlayerRemoving:Connect(function(player)
		service:RemoveSession(player)
	end))

	return service, true
end

return table.freeze(GameSessionService)
