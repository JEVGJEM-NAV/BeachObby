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
assert(workspaceBeachObby ~= nil, "Workspace.BeachObby must exist")

local verticalSlice = workspaceBeachObby:FindFirstChild("VerticalSlice")
assert(verticalSlice ~= nil and verticalSlice:IsA("Model"), "Workspace.BeachObby.VerticalSlice must be a Model")

local initialCheckpoint = verticalSlice:FindFirstChild("StartSpawn")
assert(initialCheckpoint ~= nil and initialCheckpoint:IsA("SpawnLocation"), "StartSpawn must be a SpawnLocation")

local GameSessionService, didStart = GameSessionServiceModule.Start(Players, initialCheckpoint)

if didStart then
	getRunState.OnServerInvoke = function(player)
		return GameSessionService:GetSnapshot(player)
	end
end

WorldTriggerService.Start(GameSessionService, runStateUpdatedRemote)

local world = workspaceBeachObby:FindFirstChild(WorldConfig.Root.World)
assert(world ~= nil and world:IsA("Model"), "Workspace.BeachObby.World must be a Model")

local movingHazards = MovingHazardService.new({
	WorldRoot = world,
	ConfigEntries = WorldConfig.MovingHazards.Runners,
	HeartbeatSignal = RunService.Heartbeat,
	Now = function()
		return Workspace:GetServerTimeNow()
	end,
})

movingHazards:Start()
