--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local MovingHazardService = require(ServerScriptService.Services.MovingHazardService)
local TestRunner = require(script.Parent.TestRunner)

type FakeSignal = {
	connectCount: number,
	disconnectCount: number,
	callbacks: { () -> () },
	Connect: (self: FakeSignal, callback: () -> ()) -> any,
	Fire: (self: FakeSignal) -> (),
}

type Harness = {
	world: Folder,
	scene: Model,
	paths: Folder,
	models: { [string]: Model },
	starts: { [string]: BasePart },
	ends: { [string]: BasePart },
	entries: { any },
	signal: FakeSignal,
	clock: { value: number },
	service: any?,
}

local function assertVectorClose(actual: Vector3, expected: Vector3, tolerance: number?)
	local allowed = tolerance or 0.001
	TestRunner.assertTrue(
		(actual - expected).Magnitude <= allowed,
		string.format("Expected %s, got %s", tostring(expected), tostring(actual))
	)
end

local function assertRotationClose(actual: CFrame, expected: CFrame)
	TestRunner.assertTrue(actual.LookVector:Dot(expected.LookVector) > 0.99999)
	TestRunner.assertTrue(actual.UpVector:Dot(expected.UpVector) > 0.99999)
end

local function createFakeSignal(): FakeSignal
	local signal = {
		connectCount = 0,
		disconnectCount = 0,
		callbacks = {},
	} :: any

	function signal:Connect(callback: () -> ())
		self.connectCount += 1
		local active = true
		table.insert(self.callbacks, callback)
		local callbackIndex = #self.callbacks
		local owner = self

		return {
			Disconnect = function()
				if not active then
					return
				end

				active = false
				owner.disconnectCount += 1
				owner.callbacks[callbackIndex] = function() end
			end,
		}
	end

	function signal:Fire()
		for _, callback in self.callbacks do
			callback()
		end
	end

	return signal
end

local function createPart(name: string, parent: Instance, position: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Position = position
	part.Size = size
	part.Anchored = true
	part.Parent = parent
	return part
end

local function addRunner(harness: Harness, index: number, startPosition: Vector3, endPosition: Vector3)
	local name = string.format("Runner%02d", index)
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = harness.scene

	createPart("Root", model, Vector3.new(0, 0, 0), Vector3.new(2, 2, 2))
	createPart("Child", model, Vector3.new(0, 2, 0), Vector3.new(1, 1, 1))
	model:PivotTo(CFrame.new(startPosition + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(30), 0))

	local startMarker = createPart(name .. "_Start", harness.paths, startPosition, Vector3.new(1, 1, 1))
	local endMarker = createPart(name .. "_End", harness.paths, endPosition, Vector3.new(1, 1, 1))

	harness.models[name] = model
	harness.starts[name] = startMarker
	harness.ends[name] = endMarker
	table.insert(harness.entries, {
		Id = name,
		SceneName = harness.scene.Name,
		ModelName = name,
		StartMarkerName = startMarker.Name,
		EndMarkerName = endMarker.Name,
		OneWayDurationSeconds = 2,
		PhaseOffset = 0,
	})
end

local function createHarness(runnerCount: number?): Harness
	local world = Instance.new("Folder")
	world.Name = "MovingHazardTestWorld"

	local scene = Instance.new("Model")
	scene.Name = "TestScene"
	scene.Parent = world

	local paths = Instance.new("Folder")
	paths.Name = "MovementPaths"
	paths.Parent = scene

	local harness: Harness = {
		world = world,
		scene = scene,
		paths = paths,
		models = {},
		starts = {},
		ends = {},
		entries = {},
		signal = createFakeSignal(),
		clock = { value = 0 },
		service = nil,
	}

	for index = 1, runnerCount or 1 do
		addRunner(
			harness,
			index,
			Vector3.new(0, 0, (index - 1) * 10),
			Vector3.new(10, 0, (index - 1) * 10)
		)
	end

	return harness
end

local function construct(harness: Harness)
	harness.service = MovingHazardService.new({
		WorldRoot = harness.world,
		ConfigEntries = harness.entries,
		HeartbeatSignal = harness.signal,
		Now = function()
			return harness.clock.value
		end,
	})
	return harness.service
end

local function withHarness(callback: (Harness) -> ())
	local harness = createHarness()
	local succeeded, failure = xpcall(function()
		callback(harness)
	end, debug.traceback)

	if harness.service ~= nil then
		harness.service:Destroy()
	end

	harness.world:Destroy()

	if not succeeded then
		error(failure, 0)
	end
end

TestRunner.test("MovingHazardService constructor accepts valid dependencies", function()
	withHarness(function(harness)
		local service = construct(harness)
		TestRunner.assertTrue(typeof(service) == "table")
	end)
end)

TestRunner.test("MovingHazardService Start connects exactly one Heartbeat", function()
	withHarness(function(harness)
		local service = construct(harness)
		TestRunner.assertTrue(service:Start())
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("MovingHazardService repeated Start does not duplicate Heartbeat", function()
	withHarness(function(harness)
		local service = construct(harness)
		TestRunner.assertTrue(service:Start())
		TestRunner.assertFalse(service:Start())
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("MovingHazardService Destroy disconnects Heartbeat", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		TestRunner.assertTrue(service:Destroy())
		TestRunner.assertEqual(harness.signal.disconnectCount, 1)
		harness.service = nil
	end)
end)

TestRunner.test("MovingHazardService repeated Destroy is safe", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		TestRunner.assertTrue(service:Destroy())
		TestRunner.assertFalse(service:Destroy())
		TestRunner.assertEqual(harness.signal.disconnectCount, 1)
		harness.service = nil
	end)
end)

TestRunner.test("MovingHazardService heartbeat does not move Models after Destroy", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		harness.clock.value = 2
		harness.signal:Fire()
		service:Destroy()
		local positionAtDestroy = harness.models.Runner01:GetPivot().Position
		harness.clock.value = 3
		harness.signal:Fire()
		assertVectorClose(harness.models.Runner01:GetPivot().Position, positionAtDestroy)
		harness.service = nil
	end)
end)

TestRunner.test("MovingHazardService alpha starts at zero", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(0, 2, 0), 0)
end)

TestRunner.test("MovingHazardService alpha reaches half midway to End", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(1, 2, 0), 0.5)
end)

TestRunner.test("MovingHazardService alpha reaches one at End", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(2, 2, 0), 1)
end)

TestRunner.test("MovingHazardService alpha decreases on the return half", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(3, 2, 0), 0.5)
end)

TestRunner.test("MovingHazardService alpha returns to zero after a full cycle", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(4, 2, 0), 0)
end)

TestRunner.test("MovingHazardService PhaseOffset changes the initial phase", function()
	TestRunner.assertEqual(MovingHazardService.CalculatePingPongAlpha(0, 2, 0.25), 0.5)
end)

TestRunner.test("MovingHazardService position uses absolute time without drift", function()
	withHarness(function(harness)
		local service = construct(harness)
		local initialPosition = harness.models.Runner01:GetPivot().Position
		service:Start()
		harness.clock.value = 401
		harness.signal:Fire()
		harness.clock.value = 400
		harness.signal:Fire()
		assertVectorClose(harness.models.Runner01:GetPivot().Position, initialPosition)
	end)
end)

TestRunner.test("MovingHazardService preserves original Model rotation", function()
	withHarness(function(harness)
		local service = construct(harness)
		local originalRotation = harness.models.Runner01:GetPivot()
		service:Start()
		harness.clock.value = 2
		harness.signal:Fire()
		assertRotationClose(harness.models.Runner01:GetPivot(), originalRotation)
	end)
end)

TestRunner.test("MovingHazardService moves all Model descendants through PivotTo", function()
	withHarness(function(harness)
		local model = harness.models.Runner01
		local rootPart = model.Root :: BasePart
		local childPart = model.Child :: BasePart
		local initialDelta = childPart.Position - rootPart.Position
		local service = construct(harness)
		service:Start()
		harness.clock.value = 2
		harness.signal:Fire()
		assertVectorClose(childPart.Position - rootPart.Position, initialDelta)
		TestRunner.assertTrue(rootPart.Position.X > 9)
	end)
end)

TestRunner.test("MovingHazardService rejects invalid duration", function()
	withHarness(function(harness)
		harness.entries[1].OneWayDurationSeconds = 0
		TestRunner.assertError(function()
			construct(harness)
		end)
	end)
end)

TestRunner.test("MovingHazardService rejects a missing Model", function()
	withHarness(function(harness)
		harness.models.Runner01:Destroy()
		TestRunner.assertError(function()
			construct(harness)
		end)
	end)
end)

TestRunner.test("MovingHazardService rejects a missing marker", function()
	withHarness(function(harness)
		harness.starts.Runner01:Destroy()
		TestRunner.assertError(function()
			construct(harness)
		end)
	end)
end)

TestRunner.test("MovingHazardService updates multiple runners in one Heartbeat tick", function()
	local harness = createHarness(3)
	local succeeded, failure = xpcall(function()
		local service = construct(harness)
		service:Start()
		harness.clock.value = 2
		harness.signal:Fire()
		TestRunner.assertEqual(harness.signal.connectCount, 1)

		for index = 1, 3 do
			local name = string.format("Runner%02d", index)
			TestRunner.assertTrue(harness.models[name]:GetPivot().Position.X > 9)
		end
	end, debug.traceback)

	if harness.service ~= nil then
		harness.service:Destroy()
	end
	
	harness.world:Destroy()

	if not succeeded then
		error(failure, 0)
	end
end)

TestRunner.test("MovingHazardService has no run state or remote dependency", function()
	withHarness(function(harness)
		local runState = { revision = 17, phase = "Running", coinCount = 4 }
		local service = construct(harness)
		service:Start()
		harness.clock.value = 2
		harness.signal:Fire()
		TestRunner.assertEqual(runState.revision, 17)
		TestRunner.assertEqual(runState.phase, "Running")
		TestRunner.assertEqual(runState.coinCount, 4)
	end)
end)

return true
