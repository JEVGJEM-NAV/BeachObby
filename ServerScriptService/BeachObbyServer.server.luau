--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local GameSessionServiceModule = require(ServerScriptService.Services.GameSessionService)
local MovingHazardService = require(ServerScriptService.Services.MovingHazardService)
local RotatingHazardService = require(ServerScriptService.Services.RotatingHazardService)
local WorldTriggerService = require(ServerScriptService.Services.WorldTriggerService)

local beachObby = ReplicatedStorage:FindFirstChild("BeachObby")
assert(beachObby ~= nil and beachObby:IsA("Folder"), "ReplicatedStorage.BeachObby must be a Folder")

local remotes = beachObby:FindFirstChild("Remotes")
assert(remotes ~= nil and remotes:IsA("Folder"), "ReplicatedStorage.BeachObby.Remotes must be a Folder")

local runStateUpdated = remotes:FindFirstChild(RunConfig.Remotes.RunStateUpdated)
assert(runStateUpdated ~= nil and runStateUpdated:IsA("RemoteEvent"), "RunStateUpdated must be a RemoteEvent")
local runStateUpdatedRemote = runStateUpdated :: RemoteEvent

local getRunStateInstance = remotes:FindFirstChild(RunConfig.Remotes.GetRunState)
assert(getRunStateInstance ~= nil and getRunStateInstance:IsA("RemoteFunction"), "GetRunState must be a RemoteFunction")
local getRunState = getRunStateInstance :: RemoteFunction

local workspaceBeachObby = Workspace:FindFirstChild("BeachObby")
assert(workspaceBeachObby ~= nil and workspaceBeachObby:IsA("Folder"), "Workspace.BeachObby must be a Folder")

local world = workspaceBeachObby:FindFirstChild(WorldConfig.Root.World)
assert(world ~= nil and world:IsA("Model"), "Workspace.BeachObby.World must be a Model")

local initialCheckpointDefinition = WorldConfig.Progression.Checkpoints[1]
assert(typeof(initialCheckpointDefinition) == "table", "Initial checkpoint definition must be a table")
assert(initialCheckpointDefinition.Order == 1, "Initial checkpoint definition must have Order 1")
assert(initialCheckpointDefinition.Id == "Start", "Initial checkpoint definition must have Id 'Start'")

local initialScene = world:FindFirstChild(initialCheckpointDefinition.Scene)
assert(initialScene ~= nil and initialScene:IsA("Model"), "Initial checkpoint scene must be a Model")

local initialContainer = initialScene:FindFirstChild(initialCheckpointDefinition.Folder)
assert(initialContainer ~= nil and initialContainer:IsA("Folder"), "Initial checkpoint container must be a Folder")

local initialCheckpoint = initialContainer:FindFirstChild(initialCheckpointDefinition.Name)
assert(initialCheckpoint ~= nil and initialCheckpoint:IsA("SpawnLocation"), "Initial checkpoint must be a SpawnLocation")

local GameSessionService, didStart = GameSessionServiceModule.Start(Players, initialCheckpoint)

if didStart then
	getRunState.OnServerInvoke = function(player)
		return GameSessionService:GetSnapshot(player)
	end
end

WorldTriggerService.Start(GameSessionService, runStateUpdatedRemote)

local movingHazardEntries = {}

for _, entry in WorldConfig.MovingHazards.Runners do
	table.insert(movingHazardEntries, entry)
end

for _, entry in WorldConfig.MovingHazards.Sharks do
	table.insert(movingHazardEntries, entry)
end

local movingHazards = MovingHazardService.new({
	WorldRoot = world,
	ConfigEntries = movingHazardEntries,
	HeartbeatSignal = RunService.Heartbeat,
	Now = function()
		return Workspace:GetServerTimeNow()
	end,
})

movingHazards:Start()

local rotatingHazards = RotatingHazardService.new({
	WorldRoot = world,
	ConfigEntries = WorldConfig.RotatingHazards.Lasers,
	HeartbeatSignal = RunService.Heartbeat,
	Now = function()
		return Workspace:GetServerTimeNow()
	end,
})

rotatingHazards:Start()
