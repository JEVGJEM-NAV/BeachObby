--!strict

-- Presentation only: authoritative run state remains on the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local function waitForNamedChild(parent: Instance, childName: string): Instance
	local child = parent:FindFirstChild(childName)

	while child == nil do
		task.wait()
		child = parent:FindFirstChild(childName)
	end

	return child
end

local localPlayer = Players.LocalPlayer
local playerGui = waitForNamedChild(localPlayer, "PlayerGui")
local beachObbyHUD = waitForNamedChild(playerGui, "BeachObbyHUD")
local statusFrame = waitForNamedChild(beachObbyHUD, "StatusFrame")
local timerLabel = waitForNamedChild(statusFrame, "TimerLabel") :: TextLabel
local coinLabel = waitForNamedChild(statusFrame, "CoinLabel") :: TextLabel

local RunStateController = require(waitForNamedChild(script.Parent, "RunStateController"))

type RunStateSnapshot = {
	revision: number,
	phase: string,
	startedAtServerTime: number?,
	finishedElapsedSeconds: number?,
	coinCount: number,
	collectedCoinIds: { string },
}

local currentState: RunStateSnapshot? = nil

local function sanitizeElapsedSeconds(value: any): number
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return 0
	end

	return math.max(value, 0)
end

local function formatTime(elapsedSeconds: any): string
	local totalHundredths = math.floor(sanitizeElapsedSeconds(elapsedSeconds) * 100 + 1e-6)
	local minutes = math.floor(totalHundredths / 6000)
	local seconds = math.floor(totalHundredths / 100) % 60
	local hundredths = totalHundredths % 100

	return string.format("Time %02d:%02d.%02d", minutes, seconds, hundredths)
end

local function formatCoinCount(value: any): string
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < 0 then
		return "Coins 0"
	end

	return string.format("Coins %d", math.floor(value))
end

local function updateTimer()
	local state = currentState

	if state == nil or state.phase == "NotStarted" then
		timerLabel.Text = formatTime(0)
	elseif state.phase == "Running" then
		local startedAtServerTime = sanitizeElapsedSeconds(state.startedAtServerTime)
		timerLabel.Text = formatTime(Workspace:GetServerTimeNow() - startedAtServerTime)
	elseif state.phase == "Finished" then
		timerLabel.Text = formatTime(state.finishedElapsedSeconds)
	else
		timerLabel.Text = formatTime(0)
	end
end

local function applyState(state: RunStateSnapshot)
	currentState = state
	coinLabel.Text = formatCoinCount(state.coinCount)
	updateTimer()
end

RunStateController.Init()
RunStateController.Subscribe(applyState)

local initialState = RunStateController.GetState()

if initialState ~= nil then
	applyState(initialState)
else
	timerLabel.Text = formatTime(0)
	coinLabel.Text = formatCoinCount(nil)
end

RunService.RenderStepped:Connect(function()
	if currentState ~= nil and currentState.phase == "Running" then
		updateTimer()
	end
end)
