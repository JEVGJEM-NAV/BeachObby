--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local RotatingHazardService = require(ServerScriptService.Services.RotatingHazardService)
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
	geometry: Folder,
	hazards: Folder,
	models: { [string]: Model },
	pivots: { [string]: BasePart },
	entries: { any },
	signal: FakeSignal,
	clock: { value: number },
	service: any?,
}

local function assertNear(actual: number, expected: number, tolerance: number?)
	TestRunner.assertTrue(math.abs(actual - expected) <= (tolerance or 0.00001), string.format("Expected %.8f, got %.8f", expected, actual))
end

local function assertVectorClose(actual: Vector3, expected: Vector3, tolerance: number?)
	TestRunner.assertTrue((actual - expected).Magnitude <= (tolerance or 0.001), string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
end

local function assertRotationClose(actual: CFrame, expected: CFrame, tolerance: number?)
	local minimumDot = 1 - (tolerance or 0.00001)
	TestRunner.assertTrue(actual.RightVector:Dot(expected.RightVector) >= minimumDot)
	TestRunner.assertTrue(actual.UpVector:Dot(expected.UpVector) >= minimumDot)
	TestRunner.assertTrue(actual.LookVector:Dot(expected.LookVector) >= minimumDot)
end

local function createFakeSignal(): FakeSignal
	local signal = { connectCount = 0, disconnectCount = 0, callbacks = {} } :: any

	function signal:Connect(callback: () -> ())
		self.connectCount += 1
		local active = true
		local index = #self.callbacks + 1
		self.callbacks[index] = callback
		local owner = self
		return {
			Disconnect = function()
				if not active then return end
				active = false
				owner.disconnectCount += 1
				owner.callbacks[index] = function() end
			end,
		}
	end

	function signal:Fire()
		for _, callback in self.callbacks do callback() end
	end

	return signal
end

local function createPart(name: string, parent: Instance, cframe: CFrame, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.CFrame = cframe
	part.Size = size
	part.Anchored = true
	part.Parent = parent
	return part
end

local function addRotator(harness: Harness, index: number)
	local suffix = index == 1 and "" or tostring(index)
	local modelName = "LaserAssembly" .. suffix
	local pivotName = "CenterSphere" .. suffix
	local pivotCFrame = CFrame.new(index * 20, 4, index * -10) * CFrame.Angles(0, math.rad(index * 10), 0)
	local pivot = createPart(pivotName, harness.geometry, pivotCFrame, Vector3.new(5, 5, 5))
	local model = Instance.new("Model")
	model.Name = modelName
	model.Parent = harness.hazards
	createPart("LaserBar" .. suffix, model, pivotCFrame, Vector3.new(20, 1, 2))
	model.WorldPivot = pivotCFrame

	harness.models[modelName] = model
	harness.pivots[pivotName] = pivot
	table.insert(harness.entries, {
		Id = "Laser" .. tostring(index),
		SceneName = harness.scene.Name,
		ModelName = modelName,
		PivotPartName = pivotName,
		RotationAxis = "Y",
		SecondsPerRevolution = 6,
		PhaseOffset = 0,
		Direction = -1,
	})
end

local function createHarness(count: number?): Harness
	local world = Instance.new("Folder")
	world.Name = "RotatingHazardTestWorld"
	local scene = Instance.new("Model")
	scene.Name = "TestScene"
	scene.Parent = world
	local geometry = Instance.new("Folder")
	geometry.Name = "Geometry"
	geometry.Parent = scene
	local hazards = Instance.new("Folder")
	hazards.Name = "Hazards"
	hazards.Parent = scene
	local harness: Harness = {
		world = world,
		scene = scene,
		geometry = geometry,
		hazards = hazards,
		models = {},
		pivots = {},
		entries = {},
		signal = createFakeSignal(),
		clock = { value = 100 },
		service = nil,
	}
	for index = 1, count or 1 do addRotator(harness, index) end
	return harness
end

local function construct(harness: Harness)
	harness.service = RotatingHazardService.new({
		WorldRoot = harness.world,
		ConfigEntries = harness.entries,
		HeartbeatSignal = harness.signal,
		Now = function() return harness.clock.value end,
	})
	return harness.service
end

local function withHarness(callback: (Harness) -> ())
	local harness = createHarness()
	local ok, failure = xpcall(function() callback(harness) end, debug.traceback)
	if harness.service ~= nil then harness.service:Destroy() end
	harness.world:Destroy()
	if not ok then error(failure, 0) end
end

local function expectInvalid(mutator: (Harness) -> ())
	withHarness(function(harness)
		mutator(harness)
		TestRunner.assertError(function() construct(harness) end)
	end)
end

TestRunner.test("RotatingHazardService constructor accepts valid dependencies", function()
	withHarness(function(harness) TestRunner.assertTrue(typeof(construct(harness)) == "table") end)
end)

TestRunner.test("RotatingHazardService Start connects exactly one Heartbeat", function()
	withHarness(function(harness)
		TestRunner.assertTrue(construct(harness):Start())
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("RotatingHazardService repeated Start is idempotent and preserves epoch", function()
	withHarness(function(harness)
		local service = construct(harness)
		TestRunner.assertTrue(service:Start())
		harness.clock.value = 101
		TestRunner.assertFalse(service:Start())
		harness.clock.value = 103
		harness.signal:Fire()
		local pivot = harness.pivots.CenterSphere.CFrame
		assertRotationClose(harness.models.LaserAssembly:GetPivot(), pivot * CFrame.Angles(0, math.pi, 0))
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("RotatingHazardService Destroy disconnects and stops movement", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		service:Destroy()
		local stopped = harness.models.LaserAssembly:GetPivot()
		harness.clock.value = 103
		harness.signal:Fire()
		TestRunner.assertEqual(harness.signal.disconnectCount, 1)
		TestRunner.assertEqual(harness.models.LaserAssembly:GetPivot(), stopped)
		harness.service = nil
	end)
end)

TestRunner.test("RotatingHazardService repeated Destroy is safe", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		TestRunner.assertTrue(service:Destroy())
		TestRunner.assertFalse(service:Destroy())
		TestRunner.assertEqual(harness.signal.disconnectCount, 1)
		harness.service = nil
	end)
end)

TestRunner.test("RotatingHazardService angle starts at configured phase", function()
	assertNear(RotatingHazardService.CalculateAngleRadians(0, 6, 0, 1), 0)
	assertNear(RotatingHazardService.CalculateAngleRadians(0, 6, 0.25, 1), math.pi / 2)
end)

TestRunner.test("RotatingHazardService direction changes angle sign", function()
	assertNear(RotatingHazardService.CalculateAngleRadians(1.5, 6, 0, 1), math.pi / 2)
	assertNear(RotatingHazardService.CalculateAngleRadians(1.5, 6, 0, -1), -math.pi / 2)
end)

TestRunner.test("RotatingHazardService half and full cycles are deterministic", function()
	assertNear(math.abs(RotatingHazardService.CalculateAngleRadians(3, 6, 0, -1)), math.pi)
	assertNear(RotatingHazardService.CalculateAngleRadians(6, 6, 0, -1), 0)
	assertNear(RotatingHazardService.CalculateAngleRadians(18, 6, 0, -1), 0)
end)

TestRunner.test("RotatingHazardService large absolute time does not accumulate drift", function()
	local first = RotatingHazardService.CalculateAngleRadians(1.25, 6, 0.125, -1)
	local later = RotatingHazardService.CalculateAngleRadians(600001.25, 6, 0.125, -1)
	assertNear(first, later, 0.000001)
end)

TestRunner.test("RotatingHazardService fixed pivot has no translation drift", function()
	withHarness(function(harness)
		local service = construct(harness)
		local fixed = harness.pivots.CenterSphere.CFrame
		service:Start()
		for _, elapsed in { 1.5, 3, 6, 601.25, 6000 } do
			harness.clock.value = 100 + elapsed
			harness.signal:Fire()
			assertVectorClose(harness.models.LaserAssembly:GetPivot().Position, fixed.Position)
		end
	end)
end)

TestRunner.test("RotatingHazardService keeps external CenterSphere stationary", function()
	withHarness(function(harness)
		local original = harness.pivots.CenterSphere.CFrame
		local service = construct(harness)
		service:Start()
		for _, elapsed in { 1, 2, 3, 6, 30 } do
			harness.clock.value = 100 + elapsed
			harness.signal:Fire()
			TestRunner.assertEqual(harness.pivots.CenterSphere.CFrame, original)
		end
	end)
end)

TestRunner.test("RotatingHazardService preserves assembly descendant geometry through PivotTo", function()
	withHarness(function(harness)
		local model = harness.models.LaserAssembly
		local bar = model.LaserBar :: BasePart
		local child = createPart("Visual", model, bar.CFrame * CFrame.new(5, 2, 0), Vector3.new(1, 1, 1))
		local initialDistance = (child.Position - bar.Position).Magnitude
		local service = construct(harness)
		service:Start()
		harness.clock.value = 101.5
		harness.signal:Fire()
		assertNear((child.Position - bar.Position).Magnitude, initialDistance)
	end)
end)

TestRunner.test("RotatingHazardService updates multiple entries with one Heartbeat", function()
	local harness = createHarness(3)
	local ok, failure = xpcall(function()
		local service = construct(harness)
		service:Start()
		harness.clock.value = 101.5
		harness.signal:Fire()
		TestRunner.assertEqual(harness.signal.connectCount, 1)
		for index = 1, 3 do
			local suffix = index == 1 and "" or tostring(index)
			local model = harness.models["LaserAssembly" .. suffix]
			local pivot = harness.pivots["CenterSphere" .. suffix]
			assertVectorClose(model:GetPivot().Position, pivot.Position)
		end
	end, debug.traceback)
	if harness.service ~= nil then harness.service:Destroy() end
	harness.world:Destroy()
	if not ok then error(failure, 0) end
end)

TestRunner.test("RotatingHazardService rejects invalid angle arguments", function()
	for _, values in {
		{ math.huge, 6, 0, 1 },
		{ 0, 0, 0, 1 },
		{ 0, math.huge, 0, 1 },
		{ 0, 6, -0.1, 1 },
		{ 0, 6, 1, 1 },
		{ 0, 6, 0, 0 },
	} do
		TestRunner.assertError(function()
			RotatingHazardService.CalculateAngleRadians(values[1], values[2], values[3], values[4])
		end)
	end
end)

TestRunner.test("RotatingHazardService rejects empty identity fields", function()
	for _, field in { "Id", "SceneName", "ModelName", "PivotPartName" } do
		expectInvalid(function(harness) harness.entries[1][field] = "" end)
	end
end)

TestRunner.test("RotatingHazardService rejects duplicate Ids", function()
	local harness = createHarness(2)
	local ok, failure = xpcall(function()
		harness.entries[2].Id = harness.entries[1].Id
		TestRunner.assertError(function() construct(harness) end)
	end, debug.traceback)
	harness.world:Destroy()
	if not ok then error(failure, 0) end
end)

TestRunner.test("RotatingHazardService rejects invalid timing phase axis and direction", function()
	for _, mutation in {
		function(entry) entry.SecondsPerRevolution = 0 end,
		function(entry) entry.SecondsPerRevolution = -1 end,
		function(entry) entry.SecondsPerRevolution = math.huge end,
		function(entry) entry.SecondsPerRevolution = 0 / 0 end,
		function(entry) entry.PhaseOffset = -0.1 end,
		function(entry) entry.PhaseOffset = 1 end,
		function(entry) entry.RotationAxis = "Diagonal" end,
		function(entry) entry.Direction = 0 end,
	} do
		expectInvalid(function(harness) mutation(harness.entries[1]) end)
	end
end)

TestRunner.test("RotatingHazardService rejects missing duplicate or wrong Scene", function()
	expectInvalid(function(harness) harness.scene:Destroy() end)
	expectInvalid(function(harness)
		local duplicate = Instance.new("Model")
		duplicate.Name = harness.scene.Name
		duplicate.Parent = harness.world
	end)
	expectInvalid(function(harness)
		local name = harness.scene.Name
		harness.scene:Destroy()
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = harness.world
	end)
end)

TestRunner.test("RotatingHazardService rejects missing duplicate or wrong Model", function()
	expectInvalid(function(harness) harness.models.LaserAssembly:Destroy() end)
	expectInvalid(function(harness)
		local duplicate = Instance.new("Model")
		duplicate.Name = "LaserAssembly"
		duplicate.Parent = harness.scene
	end)
	expectInvalid(function(harness)
		harness.models.LaserAssembly:Destroy()
		local folder = Instance.new("Folder")
		folder.Name = "LaserAssembly"
		folder.Parent = harness.scene
	end)
end)

TestRunner.test("RotatingHazardService rejects missing duplicate or wrong Pivot", function()
	expectInvalid(function(harness) harness.pivots.CenterSphere:Destroy() end)
	expectInvalid(function(harness)
		createPart("CenterSphere", harness.scene, CFrame.new(), Vector3.new(1, 1, 1))
	end)
	expectInvalid(function(harness)
		harness.pivots.CenterSphere:Destroy()
		local folder = Instance.new("Folder")
		folder.Name = "CenterSphere"
		folder.Parent = harness.geometry
	end)
end)

TestRunner.test("RotatingHazardService safely skips removed runtime Model", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		harness.models.LaserAssembly:Destroy()
		harness.clock.value = 103
		harness.signal:Fire()
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("RotatingHazardService safely skips removed runtime Pivot", function()
	withHarness(function(harness)
		local service = construct(harness)
		service:Start()
		harness.pivots.CenterSphere:Destroy()
		harness.clock.value = 103
		harness.signal:Fire()
		TestRunner.assertEqual(harness.signal.connectCount, 1)
	end)
end)

TestRunner.test("RotatingHazardService does not apply damage or create movers", function()
	withHarness(function(harness)
		local humanoid = Instance.new("Humanoid")
		humanoid.Parent = harness.scene
		local service = construct(harness)
		service:Start()
		harness.clock.value = 103
		harness.signal:Fire()
		TestRunner.assertEqual(humanoid.Health, 100)
		for _, descendant in harness.scene:GetDescendants() do
			TestRunner.assertFalse(descendant:IsA("Constraint"))
			TestRunner.assertFalse(descendant:IsA("BodyMover"))
		end
	end)
end)

TestRunner.test("RotatingHazardService has no Player session or remote dependency", function()
	withHarness(function(harness)
		local state = { revision = 7, phase = "Running", coinCount = 3 }
		local descendantCount = #harness.world:GetDescendants()
		local service = construct(harness)
		service:Start()
		harness.clock.value = 103
		harness.signal:Fire()
		TestRunner.assertEqual(state.revision, 7)
		TestRunner.assertEqual(state.phase, "Running")
		TestRunner.assertEqual(state.coinCount, 3)
		TestRunner.assertEqual(#harness.world:GetDescendants(), descendantCount)
	end)
end)

return true
