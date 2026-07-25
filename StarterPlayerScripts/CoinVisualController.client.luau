--!strict

-- Presentation only: collected coin visibility is local to this player.
-- Server-owned coin state is consumed through RunStateController.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local RunStateController = require(script.Parent:WaitForChild("RunStateController"))

type RunStateSnapshot = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	coinCount: number,
	collectedCoinIds: { string },
}

local collectedCoinIds: { [string]: boolean } = {}
local destroyingConnections: { [Instance]: RBXScriptConnection } = {}

local function disconnectCoin(instance: Instance, restoreVisibility: boolean)
	local connection = destroyingConnections[instance]

	if connection ~= nil then
		connection:Disconnect()
		destroyingConnections[instance] = nil
	end

	if restoreVisibility and instance:IsA("BasePart") then
		instance.LocalTransparencyModifier = 0
	end
end

local function applyCoinVisibility(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end

	local coinId = instance:GetAttribute(RunConfig.Attributes.CoinId)

	if typeof(coinId) ~= "string" or coinId == "" then
		return
	end

	instance.LocalTransparencyModifier = if collectedCoinIds[coinId] then 1 else 0
end

local function connectCoin(instance: Instance)
	if not instance:IsA("BasePart") or destroyingConnections[instance] ~= nil then
		return
	end

	destroyingConnections[instance] = instance.Destroying:Connect(function()
		disconnectCoin(instance, false)
	end)

	pcall(applyCoinVisibility, instance)
end

local function applyState(state: RunStateSnapshot)
	local nextCollectedCoinIds: { [string]: boolean } = {}

	for _, coinId in state.collectedCoinIds do
		nextCollectedCoinIds[coinId] = true
	end

	collectedCoinIds = nextCollectedCoinIds

	for _, instance in CollectionService:GetTagged(RunConfig.Tags.Coin) do
		pcall(applyCoinVisibility, instance)
	end
end

for _, instance in CollectionService:GetTagged(RunConfig.Tags.Coin) do
	connectCoin(instance)
end

CollectionService:GetInstanceAddedSignal(RunConfig.Tags.Coin):Connect(connectCoin)
CollectionService:GetInstanceRemovedSignal(RunConfig.Tags.Coin):Connect(function(instance)
	disconnectCoin(instance, true)
end)

RunStateController.Init()
RunStateController.Subscribe(applyState)

local initialState = RunStateController.GetState()

if initialState ~= nil then
	applyState(initialState)
end
