--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local TestRunner = require(script.Parent.TestRunner)

local beachObby = workspace:WaitForChild(WorldConfig.Root.BeachObby)
local world = beachObby:WaitForChild(WorldConfig.Root.World)
local environment = world:WaitForChild(WorldConfig.Root.Environment)

type Bounds = { min: Vector3, max: Vector3 }

local function assertExactChildren(parent: Instance, expected: { [string]: string })
	local seen: { [string]: boolean } = {}
	local count = 0
	for _, child in parent:GetChildren() do
		count += 1
		TestRunner.assertFalse(seen[child.Name] == true, parent:GetFullName() .. " has duplicate child " .. child.Name)
		seen[child.Name] = true
		local className = expected[child.Name]
		TestRunner.assertTrue(className ~= nil, parent:GetFullName() .. " has unexpected child " .. child.Name)
		TestRunner.assertTrue(child:IsA(className), child:GetFullName() .. " must be " .. className)
	end
	local expectedCount = 0
	for name in expected do
		expectedCount += 1
		TestRunner.assertTrue(seen[name] == true, parent:GetFullName() .. " is missing " .. name)
	end
	TestRunner.assertEqual(count, expectedCount)
end

local function namedDescendantCount(root: Instance, name: string): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant.Name == name then count += 1 end
	end
	return count
end

local function includePart(bounds: Bounds, part: BasePart)
	local half = part.Size / 2
	for _, x in { -half.X, half.X } do
		for _, y in { -half.Y, half.Y } do
			for _, z in { -half.Z, half.Z } do
				local point = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
				bounds.min = Vector3.new(
					math.min(bounds.min.X, point.X),
					math.min(bounds.min.Y, point.Y),
					math.min(bounds.min.Z, point.Z)
				)
				bounds.max = Vector3.new(
					math.max(bounds.max.X, point.X),
					math.max(bounds.max.Y, point.Y),
					math.max(bounds.max.Z, point.Z)
				)
			end
		end
	end
end

local function getAabb(root: Instance): Bounds
	local bounds = {
		min = Vector3.new(math.huge, math.huge, math.huge),
		max = Vector3.new(-math.huge, -math.huge, -math.huge),
	}
	local partCount = 0
	if root:IsA("BasePart") then
		partCount += 1
		includePart(bounds, root)
	end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			includePart(bounds, descendant)
		end
	end
	TestRunner.assertTrue(partCount > 0, root:GetFullName() .. " must contain a BasePart")
	return bounds
end

local function horizontalGap(first: Bounds, second: Bounds): number
	local dx = math.max(second.min.X - first.max.X, first.min.X - second.max.X, 0)
	local dz = math.max(second.min.Z - first.max.Z, first.min.Z - second.max.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function ringCenter(ring: Model): Vector3
	local sum = Vector3.zero
	local segments = ring.LandingSegments:GetChildren()
	for _, segment in segments do
		sum += (segment :: BasePart).Position
	end
	return sum / #segments
end

local function horizontalRadius(ring: Model): number
	local center = ringCenter(ring)
	local radius = 0
	for _, segment in ring.LandingSegments:GetChildren() do
		local part = segment :: BasePart
		local half = part.Size / 2
		for _, x in { -half.X, half.X } do
			for _, z in { -half.Z, half.Z } do
				local corner = part.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
				radius = math.max(
					radius,
					(Vector2.new(corner.X, corner.Z) - Vector2.new(center.X, center.Z)).Magnitude
				)
			end
		end
	end
	return radius
end

local function ringGap(first: Model, second: Model): number
	local firstCenter = ringCenter(first)
	local secondCenter = ringCenter(second)
	return (Vector2.new(secondCenter.X, secondCenter.Z) - Vector2.new(firstCenter.X, firstCenter.Z)).Magnitude
		- horizontalRadius(first) - horizontalRadius(second)
end

local function platformToRingGap(platform: BasePart, ring: Model): number
	local center = ringCenter(ring)
	local closestX = math.clamp(center.X, platform.Position.X - platform.Size.X / 2, platform.Position.X + platform.Size.X / 2)
	local closestZ = math.clamp(center.Z, platform.Position.Z - platform.Size.Z / 2, platform.Position.Z + platform.Size.Z / 2)
	local distance = (Vector2.new(center.X, center.Z) - Vector2.new(closestX, closestZ)).Magnitude
	return distance - horizontalRadius(ring)
end

local function countTaggedDescendants(root: Instance, tagName: string): number
	local count = 0
	for _, instance in CollectionService:GetTagged(tagName) do
		if instance:IsDescendantOf(root) then count += 1 end
	end
	return count
end

local function assertAbsentReleaseShell()
	TestRunner.assertTrue(beachObby:FindFirstChild("TemporaryAccess") == nil)
	for _, name in { "TemporaryAccess", "SpawnBridge", "BridgeSegment01", "BridgeSegment02", "BridgeSegment03" } do
		TestRunner.assertEqual(namedDescendantCount(beachObby, name), 0)
	end
end

TestRunner.test("Release hierarchy contains no TemporaryAccess or SpawnBridge", function()
	assertExactChildren(beachObby, {
		[WorldConfig.Root.World] = "Model",
	})
	assertAbsentReleaseShell()
	assertExactChildren(world, {
		[WorldConfig.Root.Environment] = "Folder",
		[WorldConfig.Scenes.HotBeach] = "Model",
		[WorldConfig.Scenes.Water] = "Model",
		[WorldConfig.Scenes.LaserIsland] = "Model",
		[WorldConfig.Scenes.PalmFinish] = "Model",
		SharedEnvironment = "Model",
	})
end)

TestRunner.test("Production spawn and scene route remain connected without temporary access", function()
	assertAbsentReleaseShell()
	local enabledSpawns: { SpawnLocation } = {}
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then
			table.insert(enabledSpawns, descendant)
		end
	end
	TestRunner.assertEqual(#enabledSpawns, 1)
	local scene01 = world[WorldConfig.Scenes.HotBeach]
	local scene02 = world[WorldConfig.Scenes.Water]
	local scene03 = world[WorldConfig.Scenes.LaserIsland]
	local scene04 = world[WorldConfig.Scenes.PalmFinish]
	local spawn = scene01.Start.StartSpawn :: SpawnLocation
	TestRunner.assertEqual(enabledSpawns[1], spawn)
	TestRunner.assertTrue(spawn.CFrame:FuzzyEq(CFrame.new(111, 2.5, 10), 0.001))
	TestRunner.assertEqual(spawn.Size, Vector3.new(12, 1, 12))
	TestRunner.assertTrue(spawn.Anchored and spawn.CanCollide and spawn.CanTouch and spawn.CanQuery)
	TestRunner.assertTrue(CollectionService:HasTag(spawn, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(spawn:GetAttribute(RunConfig.Attributes.CheckpointId), "Start")
	TestRunner.assertEqual(spawn:GetAttribute(RunConfig.Attributes.CheckpointOrder), 1)
	TestRunner.assertEqual(spawn:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))

	local spawnBounds = getAabb(spawn)
	local startBounds = getAabb(scene01.Geometry.StartPlatform)
	TestRunner.assertTrue(spawnBounds.min.X >= startBounds.min.X and spawnBounds.max.X <= startBounds.max.X)
	TestRunner.assertTrue(spawnBounds.min.Z >= startBounds.min.Z and spawnBounds.max.Z <= startBounds.max.Z)
	TestRunner.assertTrue(math.abs(spawnBounds.min.Y - startBounds.max.Y) <= 0.001)

	local scene01Route: { Instance } = { scene01.Geometry.StartPlatform }
	for index = 1, 7 do table.insert(scene01Route, scene01.Geometry.Loungers[string.format("Lounge%02d", index)]) end
	table.insert(scene01Route, scene01.Geometry.EndPlatform)
	for index = 1, #scene01Route - 1 do
		TestRunner.assertTrue(horizontalGap(getAabb(scene01Route[index]), getAabb(scene01Route[index + 1])) <= 2.001)
	end

	TestRunner.assertTrue(horizontalGap(getAabb(scene01.Geometry.EndPlatform), getAabb(scene02.Geometry.EntryPlatform)) <= 0.001)
	local ring01 = scene02.Geometry.Rings.Ring01 :: Model
	local ring08 = scene02.Geometry.Rings.Ring08 :: Model
	for index = 1, 8 do
		local ring = scene02.Geometry.Rings[string.format("Ring%02d", index)] :: Model
		TestRunner.assertEqual(#ring.LandingSegments:GetChildren(), 16)
		for segmentIndex = 1, 16 do
			local segment = ring.LandingSegments:FindFirstChild(string.format("Segment%02d", segmentIndex))
			TestRunner.assertTrue(segment ~= nil and segment:IsA("Part"))
		end
	end
	TestRunner.assertTrue(math.abs(platformToRingGap(scene02.Geometry.EntryPlatform, ring01) - 0.993499) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(ring01).max.Y - getAabb(scene02.Geometry.EntryPlatform).max.Y - 0.15) <= 0.001)
	local maximumRingGap = 0
	for index = 1, 7 do
		local first = scene02.Geometry.Rings[string.format("Ring%02d", index)] :: Model
		local second = scene02.Geometry.Rings[string.format("Ring%02d", index + 1)] :: Model
		local gap = ringGap(first, second)
		TestRunner.assertTrue(gap >= 1, string.format("Ring gap %d is too small: %.3f", index, gap))
		TestRunner.assertTrue(gap <= 4, string.format("Ring gap %d is too large: %.3f", index, gap))
		TestRunner.assertTrue(math.abs(getAabb(first).max.Y - getAabb(second).max.Y) <= 0.001)
		maximumRingGap = math.max(maximumRingGap, gap)
	end
	TestRunner.assertTrue(math.abs(maximumRingGap - 2.193554) <= 0.001)
	TestRunner.assertTrue(math.abs(platformToRingGap(scene02.Geometry.ExitPlatform, ring08) - 0.993499) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(ring08).max.Y - getAabb(scene02.Geometry.ExitPlatform).max.Y - 0.15) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene02.Geometry.ExitPlatform), getAabb(scene03.Geometry.EntryPlatform)) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene03.Geometry.EntryPlatform), getAabb(scene03.Geometry.IslandBase)) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene03.Geometry.IslandBase), getAabb(scene03.Geometry.ExitPlatform)) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene03.Geometry.ExitPlatform), getAabb(scene04.Geometry.EntryPlatform)) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene04.Geometry.EntryPlatform), getAabb(scene04.Geometry.SpiralSteps.Step01)) <= 0.001)
	for index = 1, 72 do
		TestRunner.assertTrue(horizontalGap(
			getAabb(scene04.Geometry.SpiralSteps[string.format("Step%02d", index)]),
			getAabb(scene04.Geometry.SpiralSteps[string.format("Step%02d", index + 1)])
		) <= 0.001)
	end
	TestRunner.assertTrue(horizontalGap(getAabb(scene04.Geometry.SpiralSteps.Step73), getAabb(scene04.Geometry.SummitPlatform)) <= 0.001)
	TestRunner.assertTrue(horizontalGap(getAabb(scene04.Geometry.SummitPlatform), getAabb(scene04.Triggers.FinishLine)) <= 0.001)

	local runStarts = CollectionService:GetTagged(RunConfig.Tags.RunStart)
	TestRunner.assertEqual(#runStarts, 1)
	TestRunner.assertEqual(runStarts[1], scene01.Start.StartLine)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Checkpoint), 4)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Coin), 16)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Finish), 1)
end)

TestRunner.test("Release hierarchy contains no development-only collidable shortcuts", function()
	assertAbsentReleaseShell()
	assertExactChildren(beachObby, {
		[WorldConfig.Root.World] = "Model",
	})
	local worldColliderCount = 0
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("BasePart") then
			TestRunner.assertTrue(descendant:IsDescendantOf(world), descendant:GetFullName() .. " is outside World")
			if descendant:IsDescendantOf(world) and descendant.CanCollide then worldColliderCount += 1 end
		end
	end
	TestRunner.assertTrue(worldColliderCount > 0)
	for _, child in beachObby:GetChildren() do TestRunner.assertFalse(child:IsA("BasePart")) end
	for _, tag in {
		RunConfig.Tags.RunStart,
		RunConfig.Tags.Checkpoint,
		RunConfig.Tags.Coin,
		RunConfig.Tags.Finish,
	} do
		for _, instance in CollectionService:GetTagged(tag) do TestRunner.assertTrue(instance:IsDescendantOf(world)) end
	end
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.RunStart), 1)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Checkpoint), 4)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Coin), 16)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Finish), 1)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Hazard), 10)
end)

TestRunner.test("Legacy VerticalSlice remains absent after temporary access removal", function()
	assertAbsentReleaseShell()
	assertExactChildren(beachObby, { [WorldConfig.Root.World] = "Model" })
	TestRunner.assertEqual(namedDescendantCount(beachObby, "VerticalSlice"), 0)
	TestRunner.assertEqual(namedDescendantCount(beachObby, "KillBlock"), 0)
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant:IsDescendantOf(world)) end
	end
	for _, hazard in CollectionService:GetTagged(RunConfig.Tags.Hazard) do
		TestRunner.assertTrue(hazard:IsDescendantOf(world))
	end
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Hazard), 10)
	TestRunner.assertEqual(countTaggedDescendants(world, RunConfig.Tags.Hazard), 10)
	TestRunner.assertEqual(countTaggedDescendants(environment, RunConfig.Tags.Hazard), 1)
end)

return true
