--!strict

local CollectionService = game:GetService("CollectionService")
local ServerScriptService = game:GetService("ServerScriptService")

local TestRunner = require(script.Parent.TestRunner)
local RunConfig = require(game:GetService("ReplicatedStorage").BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)

local beachObby = workspace:WaitForChild("BeachObby")
local world = beachObby:WaitForChild("World")
local scene = world:WaitForChild("Scene01_HotBeach")

local function expectChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	TestRunner.assertTrue(child ~= nil, string.format("Missing %s.%s", parent:GetFullName(), name))
	TestRunner.assertEqual((child :: Instance).ClassName, className)
	return child :: Instance
end

local function assertNoTagsOrAttributes(instance: Instance)
	TestRunner.assertEqual(#CollectionService:GetTags(instance), 0, instance:GetFullName() .. " must have no tags")
	TestRunner.assertEqual(next(instance:GetAttributes()), nil, instance:GetFullName() .. " must have no attributes")
end

local function countNamedDescendants(parent: Instance, name: string): number
	local count = 0

	for _, descendant in parent:GetDescendants() do
		if descendant.Name == name then
			count += 1
		end
	end

	return count
end

local function horizontalDistance(a: BasePart, b: BasePart): number
	local delta = a.Position - b.Position
	return Vector2.new(delta.X, delta.Z).Magnitude
end

type Aabb = {
	min: Vector3,
	max: Vector3,
}

local function includePart(bounds: Aabb, part: BasePart)
	local halfSize = part.Size / 2

	for _, xSign in { -1, 1 } do
		for _, ySign in { -1, 1 } do
			for _, zSign in { -1, 1 } do
				local point = part.CFrame:PointToWorldSpace(Vector3.new(
					halfSize.X * xSign,
					halfSize.Y * ySign,
					halfSize.Z * zSign
				))
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

local function getAabb(root: Instance): Aabb
	local bounds = {
		min = Vector3.new(math.huge, math.huge, math.huge),
		max = Vector3.new(-math.huge, -math.huge, -math.huge),
	}
	local partCount = 0

	if root:IsA("BasePart") then
		includePart(bounds, root)
		partCount += 1
	end

	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			includePart(bounds, descendant)
			partCount += 1
		end
	end

	TestRunner.assertTrue(partCount > 0, root:GetFullName() .. " must contain a BasePart")
	return bounds
end

local function aabbsIntersect(a: Aabb, b: Aabb): boolean
	return a.min.X <= b.max.X
		and a.max.X >= b.min.X
		and a.min.Y <= b.max.Y
		and a.max.Y >= b.min.Y
		and a.min.Z <= b.max.Z
		and a.max.Z >= b.min.Z
end

local function horizontalAabbGap(a: Aabb, b: Aabb): number
	local xGap = math.max(a.min.X - b.max.X, b.min.X - a.max.X, 0)
	local zGap = math.max(a.min.Z - b.max.Z, b.min.Z - a.max.Z, 0)
	return math.sqrt(xGap * xGap + zGap * zGap)
end

local function assertVectorNear(actual: Vector3, expected: Vector3, tolerance: number, message: string)
	TestRunner.assertTrue(
		(actual - expected).Magnitude <= tolerance,
		string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual))
	)
end

TestRunner.test("HotBeach HotSandVisual is passive and untagged", function()
	local geometry = expectChild(scene, "Geometry", "Folder")
	local visual = expectChild(geometry, "HotSandVisual", "Part") :: BasePart
	TestRunner.assertEqual(visual.Material, Enum.Material.Sand)
	TestRunner.assertFalse(visual.CanCollide)
	TestRunner.assertFalse(visual.CanTouch)
	TestRunner.assertFalse(visual.CanQuery)
	assertNoTagsOrAttributes(visual)
end)

TestRunner.test("HotBeach has exactly four Hazard-tagged objects", function()
	local hazards = expectChild(scene, "Hazards", "Folder")
	local hazard = expectChild(hazards, "HotSandHazard", "Part")
	TestRunner.assertTrue(hazard:IsA("BasePart"))
	local tags = CollectionService:GetTags(hazard)
	TestRunner.assertEqual(#tags, 1)
	TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)

	local expectedHazards: { [Instance]: boolean } = { [hazard] = true }
	for _, runnerName in WorldConfig.HotBeach.RunnerNames do
		local runner = scene.Hazards.StickFigures:FindFirstChild(runnerName)
		TestRunner.assertTrue(runner ~= nil)
		expectedHazards[(runner :: Model).Hitbox] = true
	end

	local taggedCount = 0
	for _, descendant in scene:GetDescendants() do
		if #CollectionService:GetTags(descendant) > 0 then
			taggedCount += 1
			TestRunner.assertTrue(expectedHazards[descendant] == true)
			local descendantTags = CollectionService:GetTags(descendant)
			TestRunner.assertEqual(#descendantTags, 1)
			TestRunner.assertEqual(descendantTags[1], RunConfig.Tags.Hazard)
		end
	end
	TestRunner.assertEqual(taggedCount, 4)
end)

TestRunner.test("HotBeach HotSandHazard has safe trigger properties", function()
	local hazard = scene.Hazards.HotSandHazard :: BasePart
	TestRunner.assertTrue(hazard.Anchored)
	TestRunner.assertTrue(hazard.CanTouch)
	TestRunner.assertTrue(hazard.CanQuery)
	TestRunner.assertFalse(hazard.CanCollide)
	TestRunner.assertEqual(next(hazard:GetAttributes()), nil)
end)

TestRunner.test("HotBeach platforms do not overlap HotSandHazard", function()
	local geometry = scene.Geometry
	local hazard = scene.Hazards.HotSandHazard :: BasePart
	local startPlatform = geometry.StartPlatform :: BasePart
	local endPlatform = geometry.EndPlatform :: BasePart
	local hazardMinZ = hazard.Position.Z - hazard.Size.Z / 2
	local hazardMaxZ = hazard.Position.Z + hazard.Size.Z / 2
	local startMinZ = startPlatform.Position.Z - startPlatform.Size.Z / 2
	local endMaxZ = endPlatform.Position.Z + endPlatform.Size.Z / 2

	TestRunner.assertTrue(startMinZ - hazardMaxZ >= 1, "StartPlatform needs at least one stud of safe clearance")
	TestRunner.assertTrue(hazardMinZ - endMaxZ >= 1, "EndPlatform needs at least one stud of safe clearance")
end)

TestRunner.test("HotBeach has exactly seven Lounge Parts", function()
	local loungers = expectChild(scene.Geometry, "Loungers", "Folder")
	TestRunner.assertEqual(#loungers:GetChildren(), 7)

	for index = 1, 7 do
		expectChild(loungers, string.format("Lounge%02d", index), "Part")
	end
end)

TestRunner.test("HotBeach Loungers are anchored collidable and passive", function()
	for _, lounge in scene.Geometry.Loungers:GetChildren() do
		TestRunner.assertTrue(lounge:IsA("BasePart"))
		local part = lounge :: BasePart
		TestRunner.assertTrue(part.Anchored)
		TestRunner.assertTrue(part.CanCollide)
		TestRunner.assertFalse(part.CanTouch)
		assertNoTagsOrAttributes(part)
	end
end)

TestRunner.test("HotBeach adjacent landing surfaces remain in traversal tuning range", function()
	local surfaces: { BasePart } = { scene.Geometry.StartPlatform }
	for index = 1, 7 do
		table.insert(surfaces, scene.Geometry.Loungers[string.format("Lounge%02d", index)])
	end
	table.insert(surfaces, scene.Geometry.EndPlatform)

	for index = 1, #surfaces - 1 do
		local distance = horizontalDistance(surfaces[index], surfaces[index + 1])
		TestRunner.assertTrue(distance >= 6, string.format("Landing %d is too close", index))
		TestRunner.assertTrue(distance <= 18, string.format("Landing %d is too far: %.2f", index, distance))
	end
end)

TestRunner.test("HotBeach has exactly three Runner Models", function()
	local stickFigures = expectChild(scene.Hazards, "StickFigures", "Folder")
	TestRunner.assertEqual(#stickFigures:GetChildren(), 3)

	for index = 1, 3 do
		local runner = expectChild(stickFigures, string.format("Runner%02d", index), "Model")
		expectChild(runner, "Visual", "Model")
		expectChild(runner, "Hitbox", "Part")
	end
end)

TestRunner.test("HotBeach Runner hitboxes are active universal hazards", function()
	for _, runner in scene.Hazards.StickFigures:GetChildren() do
		local hitbox = runner:FindFirstChild("Hitbox") :: BasePart
		TestRunner.assertTrue(hitbox ~= nil and hitbox:IsA("BasePart"))
		TestRunner.assertTrue(hitbox.Anchored)
		TestRunner.assertFalse(hitbox.CanCollide)
		TestRunner.assertTrue(hitbox.CanTouch)
		TestRunner.assertTrue(hitbox.CanQuery)
		local tags = CollectionService:GetTags(hitbox)
		TestRunner.assertEqual(#tags, 1)
		TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
		TestRunner.assertEqual(next(hitbox:GetAttributes()), nil)
	end
end)

TestRunner.test("HotBeach Runner visuals stay passive and untagged", function()
	for _, runner in scene.Hazards.StickFigures:GetChildren() do
		for _, visualPart in runner.Visual:GetDescendants() do
			if visualPart:IsA("BasePart") then
				TestRunner.assertTrue(visualPart.Anchored)
				TestRunner.assertFalse(visualPart.CanCollide)
				TestRunner.assertFalse(visualPart.CanTouch)
				TestRunner.assertFalse(visualPart.CanQuery)
				assertNoTagsOrAttributes(visualPart)
			end
		end
	end
end)

TestRunner.test("HotBeach moving runner paths match WorldConfig", function()
	for _, entry in WorldConfig.MovingHazards.Runners do
		TestRunner.assertEqual(entry.SceneName, scene.Name)
		local runner = scene.Hazards.StickFigures:FindFirstChild(entry.ModelName)
		local startMarker = scene.MovementPaths:FindFirstChild(entry.StartMarkerName)
		local endMarker = scene.MovementPaths:FindFirstChild(entry.EndMarkerName)
		TestRunner.assertTrue(runner ~= nil and runner:IsA("Model"))
		TestRunner.assertTrue(startMarker ~= nil and startMarker:IsA("BasePart"))
		TestRunner.assertTrue(endMarker ~= nil and endMarker:IsA("BasePart"))
		TestRunner.assertTrue((startMarker :: BasePart).Position ~= (endMarker :: BasePart).Position)
	end
end)

TestRunner.test("HotBeach runner lanes avoid Start and End platforms", function()
	local startPlatform = scene.Geometry.StartPlatform :: BasePart
	local endPlatform = scene.Geometry.EndPlatform :: BasePart
	for _, entry in WorldConfig.MovingHazards.Runners do
		local runner = scene.Hazards.StickFigures[entry.ModelName] :: Model
		local hitbox = runner.Hitbox :: BasePart
		local startPosition = scene.MovementPaths[entry.StartMarkerName].Position
		local endPosition = scene.MovementPaths[entry.EndMarkerName].Position
		local laneMin = Vector3.new(
			math.min(startPosition.X, endPosition.X) - hitbox.Size.X / 2,
			0,
			math.min(startPosition.Z, endPosition.Z) - hitbox.Size.Z / 2
		)
		local laneMax = Vector3.new(
			math.max(startPosition.X, endPosition.X) + hitbox.Size.X / 2,
			0,
			math.max(startPosition.Z, endPosition.Z) + hitbox.Size.Z / 2
		)
		for _, platform in { startPlatform, endPlatform } do
			local platformMin = platform.Position - platform.Size / 2
			local platformMax = platform.Position + platform.Size / 2
			local intersectsXZ = laneMin.X <= platformMax.X and laneMax.X >= platformMin.X
				and laneMin.Z <= platformMax.Z and laneMax.Z >= platformMin.Z
			TestRunner.assertFalse(intersectsXZ, entry.Id .. " lane overlaps " .. platform.Name)
		end
	end
end)

TestRunner.test("HotBeach has six passive Runner path markers", function()
	local paths = scene.MovementPaths
	TestRunner.assertEqual(#paths:GetChildren(), 6)

	for index = 1, 3 do
		for _, suffix in { "Start", "End" } do
			local marker = expectChild(paths, string.format("Runner%02d_%s", index, suffix), "Part") :: BasePart
			TestRunner.assertTrue(marker.Anchored)
			TestRunner.assertFalse(marker.CanCollide)
			TestRunner.assertFalse(marker.CanTouch)
			TestRunner.assertFalse(marker.CanQuery)
			assertNoTagsOrAttributes(marker)
		end
	end
end)

TestRunner.test("HotBeach coin position markers are passive", function()
	local markers = {
		expectChild(scene.Start, "DemoCoinPosition", "Part"),
		expectChild(scene.Coins, "HotBeachCoin01Position", "Part"),
		expectChild(scene.Coins, "HotBeachCoin02Position", "Part"),
		expectChild(scene.Coins, "HotBeachCoin03Position", "Part"),
	}

	for _, marker in markers do
		TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Coin))
		TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.CoinId), nil)
		assertNoTagsOrAttributes(marker)
	end
end)

TestRunner.test("HotBeach WaterStart checkpoint marker is passive", function()
	local marker = expectChild(scene.Triggers, "WaterStartCheckpointMarker", "Part") :: BasePart
	TestRunner.assertFalse(marker.CanTouch)
	TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.CheckpointId), nil)
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.CheckpointOrder), nil)
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.RespawnOffset), nil)
	assertNoTagsOrAttributes(marker)
end)

TestRunner.test("HotBeach contains no scripts and every world Part is anchored", function()
	for _, descendant in scene:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"), descendant:GetFullName() .. " must not be a script")
		TestRunner.assertFalse(descendant:IsA("SpawnLocation"), descendant:GetFullName() .. " must not be a SpawnLocation")
		if descendant:IsA("BasePart") then
			TestRunner.assertTrue(descendant.Anchored, descendant:GetFullName() .. " must be anchored")
		end
	end
end)

TestRunner.test("HotBeach hierarchy has no duplicate immediate child names", function()
	for _, parent in { scene, table.unpack(scene:GetDescendants()) } do
		local seen: { [string]: boolean } = {}
		for _, child in parent:GetChildren() do
			TestRunner.assertFalse(seen[child.Name] == true, parent:GetFullName() .. " has duplicate child " .. child.Name)
			seen[child.Name] = true
		end
	end
end)

TestRunner.test("Other MVP scenes retain the passive Phase 2.1 contract", function()
	for _, sceneName in { "Scene02_Water", "Scene03_LaserIsland", "Scene04_PalmFinish" } do
		local otherScene = expectChild(world, sceneName, "Model")
		for _, descendant in otherScene:GetDescendants() do
			assertNoTagsOrAttributes(descendant)
			TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
			TestRunner.assertFalse(descendant:IsA("SpawnLocation"))
			if descendant:IsA("BasePart") then
				TestRunner.assertTrue(descendant.Anchored)
				TestRunner.assertFalse(descendant.CanTouch)
			end
		end
	end
end)

TestRunner.test("VerticalSlice retains its accepted active objects", function()
	local verticalSlice = beachObby:FindFirstChild("VerticalSlice")
	TestRunner.assertTrue(verticalSlice ~= nil)
	local expected = {
		StartSpawn = RunConfig.Tags.Checkpoint,
		StartLine = RunConfig.Tags.RunStart,
		MidCheckpoint = RunConfig.Tags.Checkpoint,
		KillBlock = RunConfig.Tags.Hazard,
		DemoCoin = RunConfig.Tags.Coin,
		FinishLine = RunConfig.Tags.Finish,
	}

	for name, tag in expected do
		TestRunner.assertEqual(countNamedDescendants(verticalSlice :: Instance, name), 1)
		local instance = (verticalSlice :: Instance):FindFirstChild(name, true)
		TestRunner.assertTrue(instance ~= nil and CollectionService:HasTag(instance, tag))
	end
end)

TestRunner.test("World and VerticalSlice bounding boxes do not intersect", function()
	TestRunner.assertFalse(aabbsIntersect(getAabb(world), getAabb(beachObby.VerticalSlice)))
end)

TestRunner.test("World has at least sixty studs of horizontal clearance from VerticalSlice", function()
	local gap = horizontalAabbGap(getAabb(world), getAabb(beachObby.VerticalSlice))
	TestRunner.assertTrue(gap >= 60, string.format("World clearance is only %.3f studs", gap))
end)

TestRunner.test("StartSpawn AABB does not intersect HotSandHazard", function()
	local startSpawn = beachObby.VerticalSlice.StartSpawn
	local hazard = scene.Hazards.HotSandHazard
	TestRunner.assertFalse(aabbsIntersect(getAabb(startSpawn), getAabb(hazard)))
end)

TestRunner.test("Hot sand is outside the conservative StartSpawn character envelope", function()
	local startSpawn = beachObby.VerticalSlice.StartSpawn
	local spawnBounds = getAabb(startSpawn)
	local spawnEnvelope = {
		min = Vector3.new(spawnBounds.min.X - 4, spawnBounds.max.Y, spawnBounds.min.Z - 4),
		max = Vector3.new(spawnBounds.max.X + 4, spawnBounds.max.Y + 8, spawnBounds.max.Z + 4),
	}
	TestRunner.assertFalse(aabbsIntersect(spawnEnvelope, getAabb(scene.Geometry.HotSandVisual)))
	TestRunner.assertFalse(aabbsIntersect(spawnEnvelope, getAabb(scene.Hazards.HotSandHazard)))
end)

TestRunner.test("World remains horizontally inside and above Baseplate", function()
	local worldBounds = getAabb(world)
	local baseplateBounds = getAabb(workspace.Baseplate)
	TestRunner.assertTrue(worldBounds.min.X >= baseplateBounds.min.X)
	TestRunner.assertTrue(worldBounds.max.X <= baseplateBounds.max.X)
	TestRunner.assertTrue(worldBounds.min.Z >= baseplateBounds.min.Z)
	TestRunner.assertTrue(worldBounds.max.Z <= baseplateBounds.max.Z)
	TestRunner.assertTrue(worldBounds.min.Y >= baseplateBounds.max.Y - 0.001)
end)

TestRunner.test("World scene center offsets retain the accepted Phase 2.2 layout", function()
	local scene01Center = select(1, world.Scene01_HotBeach:GetBoundingBox()).Position
	local expectedOffsets = {
		Scene01_HotBeach = Vector3.new(0, 0, 0),
		Scene02_Water = Vector3.new(0, -2.375, -85),
		Scene03_LaserIsland = Vector3.new(2, -2.375, -160),
		Scene04_PalmFinish = Vector3.new(103.5, -2.375, -162),
	}

	for sceneName, expectedOffset in expectedOffsets do
		local sceneCenter = select(1, world[sceneName]:GetBoundingBox()).Position
		assertVectorNear(sceneCenter - scene01Center, expectedOffset, 0.001, sceneName .. " center offset")
	end
end)

TestRunner.test("VerticalSlice geometry tags and attributes retain the accepted fixture contract", function()
	local verticalSlice = beachObby.VerticalSlice
	local expected = {
		StartSpawn = {
			cframe = CFrame.new(0, 0.5, 0), size = Vector3.new(12, 1, 12), tag = RunConfig.Tags.Checkpoint,
			attributes = { CheckpointId = "Start", CheckpointOrder = 1, RespawnOffset = Vector3.new(0, 4, 0) },
		},
		StartLine = {
			cframe = CFrame.new(0, 3, -12), size = Vector3.new(16, 6, 1), tag = RunConfig.Tags.RunStart,
			attributes = {},
		},
		MidCheckpoint = {
			cframe = CFrame.new(0, 0.5, -28), size = Vector3.new(12, 1, 4), tag = RunConfig.Tags.Checkpoint,
			attributes = { CheckpointId = "Mid", CheckpointOrder = 2, RespawnOffset = Vector3.new(0, 4, 0) },
		},
		KillBlock = {
			cframe = CFrame.new(0, 0.5, -20), size = Vector3.new(10, 1, 10), tag = RunConfig.Tags.Hazard,
			attributes = {},
		},
		DemoCoin = {
			cframe = CFrame.new(0, 2.5, -38), size = Vector3.new(2.5, 2.5, 2.5), tag = RunConfig.Tags.Coin,
			attributes = { CoinId = "DemoCoin" },
		},
		FinishLine = {
			cframe = CFrame.new(0, 0.5, -48), size = Vector3.new(12, 1, 4), tag = RunConfig.Tags.Finish,
			attributes = { RequiredCheckpointOrder = 2 },
		},
	}

	for name, contract in expected do
		local part = verticalSlice:FindFirstChild(name, true)
		TestRunner.assertTrue(part ~= nil and part:IsA("BasePart"))
		local basePart = part :: BasePart
		TestRunner.assertEqual(basePart.CFrame, contract.cframe)
		TestRunner.assertEqual(basePart.Size, contract.size)
		local tags = CollectionService:GetTags(basePart)
		TestRunner.assertEqual(#tags, 1)
		TestRunner.assertEqual(tags[1], contract.tag)
		local attributes = basePart:GetAttributes()
		local attributeCount = 0
		for _ in attributes do
			attributeCount += 1
		end
		local expectedAttributeCount = 0
		for attributeName, expectedValue in contract.attributes do
			expectedAttributeCount += 1
			TestRunner.assertEqual(attributes[attributeName], expectedValue)
		end
		TestRunner.assertEqual(attributeCount, expectedAttributeCount)
	end
end)

return true
