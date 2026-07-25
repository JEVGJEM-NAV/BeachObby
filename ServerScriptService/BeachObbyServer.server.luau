--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local GameSessionServiceModule = require(ServerScriptService.Services.GameSessionService)

local beachObby = ReplicatedStorage:FindFirstChild("BeachObby")
assert(beachObby ~= nil and beachObby:IsA("Folder"), "ReplicatedStorage.BeachObby must be a Folder")

local remotes = beachObby:FindFirstChild("Remotes")
assert(remotes ~= nil and remotes:IsA("Folder"), "ReplicatedStorage.BeachObby.Remotes must be a Folder")

local runStateUpdated = remotes:FindFirstChild(RunConfig.Remotes.RunStateUpdated)
assert(runStateUpdated ~= nil and runStateUpdated:IsA("RemoteEvent"), "RunStateUpdated must be a RemoteEvent")

local getRunStateInstance = remotes:FindFirstChild(RunConfig.Remotes.GetRunState)
assert(getRunStateInstance ~= nil and getRunStateInstance:IsA("RemoteFunction"), "GetRunState must be a RemoteFunction")
local getRunState = getRunStateInstance :: RemoteFunction

local initialCheckpoint = Workspace:FindFirstChild("SpawnLocation")
assert(initialCheckpoint ~= nil and initialCheckpoint:IsA("BasePart"), "Workspace.SpawnLocation must be a BasePart")

local GameSessionService, didStart = GameSessionServiceModule.Start(Players, initialCheckpoint)

if didStart then
	getRunState.OnServerInvoke = function(player)
		return GameSessionService:GetSnapshot(player)
	end
end
