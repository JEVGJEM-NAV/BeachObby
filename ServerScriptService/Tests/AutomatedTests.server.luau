--!strict

local RunService = game:GetService("RunService")

if not RunService:IsStudio() or game:GetAttribute("RunAutomatedTests") ~= true then
	return
end

local TestRunner = require(script.Parent.TestRunner)

require(script.Parent.RunConfigSpec)
require(script.Parent.GameSessionServiceSpec)
TestRunner.run()
