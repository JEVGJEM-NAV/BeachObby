--!strict

local RunService = game:GetService("RunService")

if not RunService:IsStudio() or game:GetAttribute("RunAutomatedTests") ~= true then
	return
end

local TestRunner = require(script.Parent.TestRunner)

require(script.Parent.RunConfigSpec)
require(script.Parent.GameSessionServiceSpec)
require(script.Parent.GameSessionStartSpec)
require(script.Parent.GameSessionCheckpointSpec)
require(script.Parent.WorldTriggerHazardSpec)
require(script.Parent.GameSessionCoinSpec)
require(script.Parent.WorldTriggerCoinSpec)
require(script.Parent.GameSessionFinishSpec)
require(script.Parent.WorldTriggerFinishSpec)
require(script.Parent.WorldConfigSpec)
require(script.Parent.WorldHotBeachSpec)
require(script.Parent.MovingHazardServiceSpec)
require(script.Parent.RotatingHazardServiceSpec)
require(script.Parent.WorldWaterSpec)
require(script.Parent.WorldLaserIslandSpec)
require(script.Parent.WorldTemporaryAccessSpec)
TestRunner.run()
