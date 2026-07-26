--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local TestRunner = require(script.Parent.TestRunner)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)

local beachObby = workspace:WaitForChild("BeachObby")
local world = beachObby:WaitForChild("World")
local scene = world:WaitForChild(WorldConfig.Scenes.Water)

type Aabb = { min: Vector3, max: Vector3 }

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

local function getAabb(instance: Instance): Aabb
	if instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		return { min = cframe.Position - size / 2, max = cframe.Position + size / 2 }
	end
	local part = instance :: BasePart
	local half = part.Size / 2
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, x in { -half.X, half.X } do
		for _, y in { -half.Y, half.Y } do
			for _, z in { -half.Z, half.Z } do
				local point = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
				min = Vector3.new(math.min(min.X, point.X), math.min(min.Y, point.Y), math.min(min.Z, point.Z))
				max = Vector3.new(math.max(max.X, point.X), math.max(max.Y, point.Y), math.max(max.Z, point.Z))
			end
		end
	end
	return { min = min, max = max }
end

local function aabbsIntersect(a: Aabb, b: Aabb): boolean
	return a.min.X < b.max.X and a.max.X > b.min.X
		and a.min.Y < b.max.Y and a.max.Y > b.min.Y
		and a.min.Z < b.max.Z and a.max.Z > b.min.Z
end

local function horizontalAabbGap(a: Aabb, b: Aabb): number
	local dx = math.max(b.min.X - a.max.X, a.min.X - b.max.X, 0)
	local dz = math.max(b.min.Z - a.max.Z, a.min.Z - b.max.Z, 0)
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
				radius = math.max(radius, (Vector2.new(corner.X, corner.Z) - Vector2.new(center.X, center.Z)).Magnitude)
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

local function horizontalDistanceToPart(point: Vector3, part: BasePart): number
	local localPoint = part.CFrame:PointToObjectSpace(point)
	local half = part.Size / 2
	local closest = Vector3.new(
		math.clamp(localPoint.X, -half.X, half.X),
		localPoint.Y,
		math.clamp(localPoint.Z, -half.Z, half.Z)
	)
	local worldClosest = part.CFrame:PointToWorldSpace(closest)
	return (Vector2.new(point.X, point.Z) - Vector2.new(worldClosest.X, worldClosest.Z)).Magnitude
end

TestRunner.test("Water scene has the expected Model and Folder hierarchy", function()
	TestRunner.assertTrue(scene:IsA("Model"))
	local geometry = expectChild(scene, "Geometry", "Folder")
	local hazards = expectChild(scene, "Hazards", "Folder")
	expectChild(scene, "MovementPaths", "Folder")
	expectChild(scene, "Coins", "Folder")
	expectChild(scene, "Triggers", "Folder")
	expectChild(geometry, WorldConfig.Water.RingsFolder, "Folder")
	expectChild(hazards, WorldConfig.Water.SharksFolder, "Folder")
end)

TestRunner.test("WaterSurface exists as a BasePart", function()
	local water = scene.Geometry:FindFirstChild(WorldConfig.Water.WaterSurface)
	TestRunner.assertTrue(water ~= nil and water:IsA("BasePart"))
end)

TestRunner.test("WaterSurface is untagged and attribute-free", function()
	assertNoTagsOrAttributes(scene.Geometry.WaterSurface)
end)

TestRunner.test("WaterSurface is a passive visual", function()
	local water = scene.Geometry.WaterSurface :: BasePart
	TestRunner.assertTrue(water.Anchored)
	TestRunner.assertFalse(water.CanCollide)
	TestRunner.assertFalse(water.CanTouch)
	TestRunner.assertFalse(water.CanQuery)
	TestRunner.assertFalse(water.CastShadow)
end)

TestRunner.test("WaterKillPlane exists as a BasePart", function()
	local killPlane = scene.Hazards:FindFirstChild(WorldConfig.Water.WaterKillPlane)
	TestRunner.assertTrue(killPlane ~= nil and killPlane:IsA("BasePart"))
end)

TestRunner.test("WaterKillPlane has exactly the Hazard tag", function()
	local killPlane = scene.Hazards.WaterKillPlane
	local tags = CollectionService:GetTags(killPlane)
	TestRunner.assertEqual(#tags, 1)
	TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
	TestRunner.assertEqual(next(killPlane:GetAttributes()), nil)
end)

TestRunner.test("WaterKillPlane has universal trigger properties", function()
	local killPlane = scene.Hazards.WaterKillPlane :: BasePart
	TestRunner.assertTrue(killPlane.Anchored)
	TestRunner.assertTrue(killPlane.CanTouch)
	TestRunner.assertTrue(killPlane.CanQuery)
	TestRunner.assertFalse(killPlane.CanCollide)
end)

TestRunner.test("WaterKillPlane covers the WaterSurface XZ area", function()
	local killBounds = getAabb(scene.Hazards.WaterKillPlane)
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	TestRunner.assertTrue(killBounds.min.X <= waterBounds.min.X)
	TestRunner.assertTrue(killBounds.max.X >= waterBounds.max.X)
	TestRunner.assertTrue(killBounds.min.Z <= waterBounds.min.Z)
	TestRunner.assertTrue(killBounds.max.Z >= waterBounds.max.Z)
end)

TestRunner.test("WaterKillPlane does not intersect EntryPlatform", function()
	TestRunner.assertFalse(aabbsIntersect(getAabb(scene.Hazards.WaterKillPlane), getAabb(scene.Geometry.EntryPlatform)))
end)

TestRunner.test("WaterKillPlane does not intersect ExitPlatform", function()
	TestRunner.assertFalse(aabbsIntersect(getAabb(scene.Hazards.WaterKillPlane), getAabb(scene.Geometry.ExitPlatform)))
end)

TestRunner.test("Water SceneFootprint is an invisible passive marker", function()
	local footprint = scene.Geometry.SceneFootprint :: BasePart
	TestRunner.assertTrue(footprint.Anchored)
	TestRunner.assertFalse(footprint.CanCollide)
	TestRunner.assertFalse(footprint.CanTouch)
	TestRunner.assertFalse(footprint.CanQuery)
	TestRunner.assertEqual(footprint.Transparency, 1)
	assertNoTagsOrAttributes(footprint)
end)

TestRunner.test("Water scene contains exactly eight Ring Models", function()
	local rings = scene.Geometry.Rings
	TestRunner.assertEqual(#rings:GetChildren(), 8)
	for _, ring in rings:GetChildren() do
		TestRunner.assertTrue(ring:IsA("Model"))
		expectChild(ring, "LandingSegments", "Folder")
	end
end)

TestRunner.test("Water ring names match WorldConfig", function()
	for _, ringName in WorldConfig.Water.RingNames do
		expectChild(scene.Geometry.Rings, ringName, "Model")
	end
end)

TestRunner.test("Water rings contain sixteen sequential landing segments", function()
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local folder = expectChild(ring, "LandingSegments", "Folder")
		TestRunner.assertEqual(#folder:GetChildren(), 16)
		local seen: { [string]: boolean } = {}
		for index = 1, 16 do
			local segment = expectChild(folder, string.format("Segment%02d", index), "Part") :: Part
			TestRunner.assertFalse(seen[segment.Name] == true)
			seen[segment.Name] = true
			TestRunner.assertEqual(segment.Shape, Enum.PartType.Block)
			TestRunner.assertTrue(segment.Anchored)
			TestRunner.assertTrue(segment.CanCollide)
			TestRunner.assertFalse(segment.CanTouch)
			TestRunner.assertTrue(segment.CanQuery)
			TestRunner.assertFalse(segment.CastShadow)
			TestRunner.assertEqual(segment.Material, Enum.Material.SmoothPlastic)
			assertNoTagsOrAttributes(segment)
		end
	end
end)

TestRunner.test("Water ring segments share height and follow the tangent", function()
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local model = ring :: Model
		local center = ringCenter(model)
		local expectedTop: number? = nil
		for _, child in model.LandingSegments:GetChildren() do
			local segment = child :: BasePart
			local top = getAabb(segment).max.Y
			if expectedTop == nil then expectedTop = top end
			TestRunner.assertTrue(math.abs(top - (expectedTop :: number)) <= 0.001)
			local radial = Vector3.new(segment.Position.X - center.X, 0, segment.Position.Z - center.Z).Unit
			TestRunner.assertTrue(math.abs(segment.CFrame.RightVector:Dot(radial)) <= 0.001)
			TestRunner.assertTrue(math.abs(segment.CFrame.LookVector:Dot(radial)) >= 0.999)
			TestRunner.assertTrue(math.abs(segment.CFrame.UpVector:Dot(Vector3.yAxis)) >= 0.999)
		end
	end
end)

TestRunner.test("Water Ring01 is reachable from EntryPlatform", function()
	local gap = platformToRingGap(scene.Geometry.EntryPlatform, scene.Geometry.Rings.Ring01)
	TestRunner.assertTrue(gap >= 0.5, string.format("Entry gap is too small: %.3f", gap))
	TestRunner.assertTrue(gap <= 5, string.format("Entry gap is too large: %.3f", gap))
end)

TestRunner.test("Water neighboring ring gaps stay in traversal tuning range", function()
	for index = 1, 7 do
		local first = scene.Geometry.Rings[string.format("Ring%02d", index)]
		local second = scene.Geometry.Rings[string.format("Ring%02d", index + 1)]
		local gap = ringGap(first, second)
		TestRunner.assertTrue(gap >= 1, string.format("Ring gap %d is too small: %.3f", index, gap))
		TestRunner.assertTrue(gap <= 4, string.format("Ring gap %d is too large: %.3f", index, gap))
	end
end)

TestRunner.test("Water Ring08 is reachable to ExitPlatform", function()
	local gap = platformToRingGap(scene.Geometry.ExitPlatform, scene.Geometry.Rings.Ring08)
	TestRunner.assertTrue(gap >= 0.5, string.format("Exit gap is too small: %.3f", gap))
	TestRunner.assertTrue(gap <= 5, string.format("Exit gap is too large: %.3f", gap))
end)

TestRunner.test("Water rings have open centers above WaterSurface and WaterKillPlane", function()
	local killTop = getAabb(scene.Hazards.WaterKillPlane).max.Y
	local waterTop = getAabb(scene.Geometry.WaterSurface).max.Y
	local killBounds = getAabb(scene.Hazards.WaterKillPlane)
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local model = ring :: Model
		local center = ringCenter(model)
		local radius = horizontalRadius(model)
		TestRunner.assertTrue(radius * 2 >= 9.8 and radius * 2 <= 10.3, ring.Name .. " outer diameter is out of range")
		for _, child in model.LandingSegments:GetChildren() do
			local segment = child :: BasePart
			TestRunner.assertTrue(getAabb(segment).min.Y > killTop, segment.Name .. " intersects WaterKillPlane")
			TestRunner.assertTrue(horizontalDistanceToPart(center, segment) >= 2, segment.Name .. " intrudes into the four-stud hole")
		end
		TestRunner.assertTrue(waterTop < getAabb(model).min.Y)
		TestRunner.assertTrue(killBounds.min.X <= center.X and killBounds.max.X >= center.X)
		TestRunner.assertTrue(killBounds.min.Z <= center.Z and killBounds.max.Z >= center.Z)
		TestRunner.assertTrue(waterBounds.min.X <= center.X and waterBounds.max.X >= center.X)
		TestRunner.assertTrue(waterBounds.min.Z <= center.Z and waterBounds.max.Z >= center.Z)
	end
end)

TestRunner.test("Water ring rims have no unintended gaps or solid centers", function()
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local model = ring :: Model
		local segments = model.LandingSegments:GetChildren()
		for index = 1, 16 do
			local first = model.LandingSegments[string.format("Segment%02d", index)] :: BasePart
			local second = model.LandingSegments[string.format("Segment%02d", index % 16 + 1)] :: BasePart
			local centerDistance = (first.Position - second.Position).Magnitude
			TestRunner.assertTrue(centerDistance < math.max(first.Size.X, first.Size.Z), ring.Name .. " has a rim gap")
		end
		for _, descendant in model:GetDescendants() do
			TestRunner.assertFalse(descendant:IsA("CylinderMesh"))
			TestRunner.assertFalse(descendant:IsA("UnionOperation"))
			TestRunner.assertFalse(descendant:IsA("MeshPart"))
			TestRunner.assertFalse(descendant:IsA("Constraint"))
			TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		end
		TestRunner.assertEqual(#segments, 16)
	end
end)

TestRunner.test("Water route cannot use SceneFootprint as a bridge", function()
	local footprint = scene.Geometry.SceneFootprint :: BasePart
	TestRunner.assertFalse(footprint.CanCollide)
	TestRunner.assertEqual(footprint.Transparency, 1)
	for _, child in scene.Geometry:GetChildren() do
		if child:IsA("BasePart") and child ~= scene.Geometry.EntryPlatform and child ~= scene.Geometry.ExitPlatform then
			TestRunner.assertFalse(child.CanCollide, child.Name .. " must not provide a full-span bridge")
		end
	end
end)

TestRunner.test("Water scene contains exactly four coin position markers", function()
	TestRunner.assertEqual(#scene.Coins:GetChildren(), 4)
	for index = 1, 4 do
		expectChild(scene.Coins, string.format("WaterCoin%02dPosition", index), "Part")
	end
end)

TestRunner.test("Water coin position markers are passive", function()
	for _, marker in scene.Coins:GetChildren() do
		local part = marker :: BasePart
		TestRunner.assertFalse(part.CanCollide)
		TestRunner.assertFalse(part.CanTouch)
		TestRunner.assertFalse(part.CanQuery)
		TestRunner.assertFalse(CollectionService:HasTag(part, RunConfig.Tags.Coin))
		TestRunner.assertEqual(part:GetAttribute(RunConfig.Attributes.CoinId), nil)
		assertNoTagsOrAttributes(part)
	end
end)

TestRunner.test("Water checkpoint marker is passive", function()
	local marker = expectChild(scene.Triggers, WorldConfig.Water.LaserIslandStartMarker, "Part") :: BasePart
	TestRunner.assertFalse(marker.CanCollide)
	TestRunner.assertFalse(marker.CanTouch)
	TestRunner.assertFalse(marker.CanQuery)
	TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.CheckpointId), nil)
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.CheckpointOrder), nil)
	TestRunner.assertEqual(marker:GetAttribute(RunConfig.Attributes.RespawnOffset), nil)
	assertNoTagsOrAttributes(marker)
end)

TestRunner.test("Water Sharks folder exists and is empty", function()
	local sharks = expectChild(scene.Hazards, WorldConfig.Water.SharksFolder, "Folder")
	TestRunner.assertEqual(#sharks:GetChildren(), 0)
end)

TestRunner.test("Water MovementPaths folder remains empty", function()
	TestRunner.assertEqual(#scene.MovementPaths:GetChildren(), 0)
end)

TestRunner.test("Water scene contains no nested scripts", function()
	for _, descendant in scene:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"), descendant:GetFullName() .. " must not be a script")
		TestRunner.assertFalse(descendant:IsA("SpawnLocation"), descendant:GetFullName() .. " must not be a SpawnLocation")
	end
end)

TestRunner.test("Water hierarchy has no duplicate immediate child names", function()
	for _, parent in { scene, table.unpack(scene:GetDescendants()) } do
		local seen: { [string]: boolean } = {}
		for _, child in parent:GetChildren() do
			TestRunner.assertFalse(seen[child.Name] == true, parent:GetFullName() .. " has duplicate child " .. child.Name)
			seen[child.Name] = true
		end
	end
end)

TestRunner.test("HotBeach retains exactly four active hazards", function()
	local count = 0
	for _, descendant in world.Scene01_HotBeach:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then count += 1 end
	end
	TestRunner.assertEqual(count, 4)
end)

TestRunner.test("Future scenes retain the passive Phase 2.1 contract", function()
	for _, sceneName in { WorldConfig.Scenes.LaserIsland, WorldConfig.Scenes.PalmFinish } do
		for _, descendant in world[sceneName]:GetDescendants() do
			assertNoTagsOrAttributes(descendant)
			TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
			if descendant:IsA("BasePart") then
				TestRunner.assertTrue(descendant.Anchored)
				TestRunner.assertFalse(descendant.CanTouch)
			end
		end
	end
end)

TestRunner.test("VerticalSlice retains its accepted active fixture", function()
	local expected = {
		StartSpawn = { cframe = CFrame.new(0, 0.5, 0), size = Vector3.new(12, 1, 12), tag = RunConfig.Tags.Checkpoint },
		StartLine = { cframe = CFrame.new(0, 3, -12), size = Vector3.new(16, 6, 1), tag = RunConfig.Tags.RunStart },
		MidCheckpoint = { cframe = CFrame.new(0, 0.5, -28), size = Vector3.new(12, 1, 4), tag = RunConfig.Tags.Checkpoint },
		KillBlock = { cframe = CFrame.new(0, 0.5, -20), size = Vector3.new(10, 1, 10), tag = RunConfig.Tags.Hazard },
		DemoCoin = { cframe = CFrame.new(0, 2.5, -38), size = Vector3.new(2.5, 2.5, 2.5), tag = RunConfig.Tags.Coin },
		FinishLine = { cframe = CFrame.new(0, 0.5, -48), size = Vector3.new(12, 1, 4), tag = RunConfig.Tags.Finish },
	}
	for name, contract in expected do
		local part = beachObby.VerticalSlice:FindFirstChild(name, true)
		TestRunner.assertTrue(part ~= nil and part:IsA("BasePart"))
		TestRunner.assertEqual((part :: BasePart).CFrame, contract.cframe)
		TestRunner.assertEqual((part :: BasePart).Size, contract.size)
		TestRunner.assertTrue(CollectionService:HasTag(part :: Instance, contract.tag))
	end
end)

TestRunner.test("World and VerticalSlice retain safe horizontal clearance", function()
	local gap = horizontalAabbGap(getAabb(world), getAabb(beachObby.VerticalSlice))
	TestRunner.assertTrue(gap >= 60, string.format("World clearance is only %.3f studs", gap))
end)

TestRunner.test("Entire World remains inside Baseplate", function()
	local worldBounds = getAabb(world)
	local baseplateBounds = getAabb(workspace.Baseplate)
	TestRunner.assertTrue(worldBounds.min.X >= baseplateBounds.min.X)
	TestRunner.assertTrue(worldBounds.max.X <= baseplateBounds.max.X)
	TestRunner.assertTrue(worldBounds.min.Z >= baseplateBounds.min.Z)
	TestRunner.assertTrue(worldBounds.max.Z <= baseplateBounds.max.Z)
	TestRunner.assertTrue(worldBounds.min.Y >= baseplateBounds.max.Y - 0.001)
end)

return true
