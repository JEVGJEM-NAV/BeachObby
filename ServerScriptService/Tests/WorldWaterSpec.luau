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
local environment = world:WaitForChild(WorldConfig.Root.Environment)

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

local function countTaggedDescendants(root: Instance, tagName: string): number
	local count = 0
	for _, instance in CollectionService:GetTagged(tagName) do
		if instance:IsDescendantOf(root) then
			count += 1
		end
	end
	return count
end

local function getAabb(instance: Instance): Aabb
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	local partCount = 0

	local function includePart(part: BasePart)
		partCount += 1
		local half = part.Size / 2
		for _, x in { -half.X, half.X } do
			for _, y in { -half.Y, half.Y } do
				for _, z in { -half.Z, half.Z } do
					local point = part.CFrame:PointToWorldSpace(Vector3.new(x, y, z))
					min = Vector3.new(math.min(min.X, point.X), math.min(min.Y, point.Y), math.min(min.Z, point.Z))
					max = Vector3.new(math.max(max.X, point.X), math.max(max.Y, point.Y), math.max(max.Z, point.Z))
				end
			end
		end
	end

	if instance:IsA("BasePart") then includePart(instance) end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then includePart(descendant) end
	end
	TestRunner.assertTrue(partCount > 0, instance:GetFullName() .. " must contain a BasePart")
	return { min = min, max = max }
end

local function aabbsIntersect(a: Aabb, b: Aabb): boolean
	return a.min.X < b.max.X and a.max.X > b.min.X
		and a.min.Y < b.max.Y and a.max.Y > b.min.Y
		and a.min.Z < b.max.Z and a.max.Z > b.min.Z
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

local function landingSurfaceTop(ring: Model): number
	local top = -math.huge
	for _, segment in ring.LandingSegments:GetChildren() do
		local bounds = getAabb(segment)
		top = math.max(top, bounds.max.Y)
	end
	return top
end

local function pointInsideBox(point: Vector3, cframe: CFrame, size: Vector3): boolean
	local localPoint = cframe:PointToObjectSpace(point)
	local half = size / 2
	return math.abs(localPoint.X) <= half.X
		and math.abs(localPoint.Y) <= half.Y
		and math.abs(localPoint.Z) <= half.Z
end

local sharkRingTargets = {
	{ shark = "Shark01", ring = "Ring04", neighbors = { "Ring03", "Ring05" } },
	{ shark = "Shark02", ring = "Ring07", neighbors = { "Ring06", "Ring08" } },
}

local alignedWaterTop = 0
local originalWaterPositionXZ = Vector2.new(111, -107)
local originalWaterSizeXZ = Vector2.new(32, 56)
local oceanKillPositionXZ = Vector2.new(111, -107)
local oceanKillSizeXZ = Vector2.new(512, 512)

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

TestRunner.test("WaterSurface aligns its top with the global ocean while retaining its deep-water contract", function()
	local water = scene.Geometry.WaterSurface :: BasePart
	local bounds = getAabb(water)
	TestRunner.assertEqual(water.CFrame, CFrame.new(111, -2.85, -107))
	TestRunner.assertEqual(water.Size, Vector3.new(32, 5.7, 56))
	TestRunner.assertTrue(math.abs(bounds.max.Y - alignedWaterTop) <= 0.001)
	TestRunner.assertTrue(math.abs(bounds.min.Y + 5.7) <= 0.001)
	TestRunner.assertEqual(Vector2.new(water.Position.X, water.Position.Z), originalWaterPositionXZ)
	TestRunner.assertEqual(Vector2.new(water.Size.X, water.Size.Z), originalWaterSizeXZ)
	TestRunner.assertTrue(water.Size.Y > 0.1)
	TestRunner.assertTrue(bounds.min.Y < 1)
	TestRunner.assertTrue(math.abs(water.Position.Y - (alignedWaterTop - water.Size.Y / 2)) <= 0.001)
	TestRunner.assertEqual(water.Material, Enum.Material.Glass)
	TestRunner.assertEqual(water.Color, Color3.fromRGB(65, 180, 255))
	TestRunner.assertTrue(math.abs(water.Transparency - 0.35) <= 0.001)
end)

TestRunner.test("OceanKill exists as a global Environment BasePart", function()
	local oceanKill = environment:FindFirstChild(WorldConfig.Environment.OceanKill)
	TestRunner.assertTrue(oceanKill ~= nil and oceanKill:IsA("BasePart"))
	TestRunner.assertTrue(scene.Hazards:FindFirstChild("WaterKillPlane") == nil)
end)

TestRunner.test("OceanKill has exactly the Hazard tag", function()
	local oceanKill = environment[WorldConfig.Environment.OceanKill]
	local tags = CollectionService:GetTags(oceanKill)
	TestRunner.assertEqual(#tags, 1)
	TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
	TestRunner.assertEqual(next(oceanKill:GetAttributes()), nil)
end)

TestRunner.test("Scene02 has only shark Hazards and Environment owns OceanKill", function()
	local nonSharkHazards = {}
	for _, descendant in scene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard)
			and not descendant:IsDescendantOf(scene.Hazards.Sharks) then
			table.insert(nonSharkHazards, descendant)
		end
	end
	TestRunner.assertEqual(#nonSharkHazards, 0)
	local oceanKill = environment[WorldConfig.Environment.OceanKill]
	TestRunner.assertTrue(CollectionService:HasTag(oceanKill, RunConfig.Tags.Hazard))
	TestRunner.assertEqual(oceanKill.Parent, environment)
end)

TestRunner.test("OceanKill has universal trigger properties", function()
	local oceanKill = environment[WorldConfig.Environment.OceanKill] :: BasePart
	TestRunner.assertTrue(oceanKill.Anchored)
	TestRunner.assertTrue(oceanKill.CanTouch)
	TestRunner.assertTrue(oceanKill.CanQuery)
	TestRunner.assertTrue(oceanKill.CanCollide)
end)

TestRunner.test("OceanKill has exact global XZ and vertical geometry", function()
	local oceanKill = environment[WorldConfig.Environment.OceanKill] :: BasePart
	local killBounds = getAabb(oceanKill)
	TestRunner.assertEqual(Vector2.new(oceanKill.Position.X, oceanKill.Position.Z), oceanKillPositionXZ)
	TestRunner.assertEqual(Vector2.new(oceanKill.Size.X, oceanKill.Size.Z), oceanKillSizeXZ)
	TestRunner.assertEqual(oceanKill.CFrame, CFrame.new(111, -1, -107))
	TestRunner.assertEqual(oceanKill.Size, Vector3.new(512, 0.5, 512))
	TestRunner.assertTrue(math.abs(killBounds.max.Y + 0.75) <= 0.001)
	TestRunner.assertTrue(math.abs(killBounds.min.Y + 1.25) <= 0.001)
end)

TestRunner.test("Water and OceanKill remain above the non-gameplay Baseplate", function()
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	local killBounds = getAabb(environment[WorldConfig.Environment.OceanKill])
	local baseplateBounds = getAabb(workspace.Baseplate)
	TestRunner.assertTrue(waterBounds.min.Y < killBounds.min.Y)
	TestRunner.assertTrue(killBounds.min.Y > baseplateBounds.max.Y)
	TestRunner.assertTrue(waterBounds.min.Y > baseplateBounds.max.Y)
	TestRunner.assertTrue(baseplateBounds.max.Y <= -6 + 0.001)
	TestRunner.assertFalse(workspace.Baseplate.CanCollide)
end)

TestRunner.test("OceanKill avoids Rings and shark Hazard hitboxes while passive bodies remain immersed", function()
	local killBounds = getAabb(environment[WorldConfig.Environment.OceanKill])
	for _, ring in scene.Geometry.Rings:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(killBounds, getAabb(ring)))
	end
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(killBounds, getAabb(shark.Hitbox)))
		TestRunner.assertTrue(aabbsIntersect(killBounds, getAabb(shark.Visual.Body)))
	end
end)

TestRunner.test("OceanKill covers the WaterSurface XZ area", function()
	local killBounds = getAabb(environment[WorldConfig.Environment.OceanKill])
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	TestRunner.assertTrue(killBounds.min.X <= waterBounds.min.X)
	TestRunner.assertTrue(killBounds.max.X >= waterBounds.max.X)
	TestRunner.assertTrue(killBounds.min.Z <= waterBounds.min.Z)
	TestRunner.assertTrue(killBounds.max.Z >= waterBounds.max.Z)
end)

TestRunner.test("OceanKill does not intersect EntryPlatform", function()
	TestRunner.assertFalse(aabbsIntersect(getAabb(environment[WorldConfig.Environment.OceanKill]), getAabb(scene.Geometry.EntryPlatform)))
end)

TestRunner.test("OceanKill does not intersect ExitPlatform", function()
	TestRunner.assertFalse(aabbsIntersect(getAabb(environment[WorldConfig.Environment.OceanKill]), getAabb(scene.Geometry.ExitPlatform)))
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

TestRunner.test("Water ring pivots retain the accepted route aligned to the global ocean", function()
	local expected = {
		Ring01 = Vector3.new(106, 1.4, -84),
		Ring02 = Vector3.new(116, 1.4, -90.5),
		Ring03 = Vector3.new(106, 1.4, -97),
		Ring04 = Vector3.new(116, 1.4, -103.5),
		Ring05 = Vector3.new(106, 1.4, -110),
		Ring06 = Vector3.new(116, 1.4, -116.5),
		Ring07 = Vector3.new(106, 1.4, -123),
		Ring08 = Vector3.new(116, 1.4, -130),
	}
	for name, position in expected do
		local pivot = (scene.Geometry.Rings[name] :: Model):GetPivot().Position
		TestRunner.assertTrue((pivot - position).Magnitude <= 0.001, name .. " pivot changed")
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

TestRunner.test("Water rings have open centers above WaterSurface and OceanKill", function()
	local killTop = getAabb(environment[WorldConfig.Environment.OceanKill]).max.Y
	local waterTop = getAabb(scene.Geometry.WaterSurface).max.Y
	local killBounds = getAabb(environment[WorldConfig.Environment.OceanKill])
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local model = ring :: Model
		local center = ringCenter(model)
		local radius = horizontalRadius(model)
		TestRunner.assertTrue(radius * 2 >= 9.8 and radius * 2 <= 10.3, ring.Name .. " outer diameter is out of range")
		for _, child in model.LandingSegments:GetChildren() do
			local segment = child :: BasePart
			TestRunner.assertTrue(getAabb(segment).min.Y > killTop, segment.Name .. " intersects OceanKill")
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

TestRunner.test("Water scene contains exactly four active coins", function()
	TestRunner.assertEqual(#scene.Coins:GetChildren(), 4)
	for index = 1, 4 do
		expectChild(scene.Coins, string.format("WaterCoin%02d", index), "Part")
		TestRunner.assertTrue(scene.Coins:FindFirstChild(string.format("WaterCoin%02dPosition", index)) == nil)
	end
end)

TestRunner.test("Water coins have the final active contract", function()
	for _, coin in scene.Coins:GetChildren() do
		local part = coin :: BasePart
		TestRunner.assertFalse(part.CanCollide)
		TestRunner.assertTrue(part.CanTouch and part.CanQuery)
		TestRunner.assertTrue(CollectionService:HasTag(part, RunConfig.Tags.Coin))
		TestRunner.assertEqual(#CollectionService:GetTags(part), 1)
		TestRunner.assertEqual(part:GetAttribute(RunConfig.Attributes.CoinId), part.Name)
	end
end)

TestRunner.test("Water checkpoint has the final active contract", function()
	local checkpoint = expectChild(scene.Triggers, WorldConfig.Water.LaserIslandStartCheckpoint, "Part") :: BasePart
	TestRunner.assertFalse(checkpoint.CanCollide)
	TestRunner.assertTrue(checkpoint.CanTouch and checkpoint.CanQuery)
	TestRunner.assertTrue(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(#CollectionService:GetTags(checkpoint), 1)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId), "LaserIslandStart")
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), 3)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))
	TestRunner.assertTrue(scene.Triggers:FindFirstChild("LaserIslandStartCheckpointMarker") == nil)
end)

TestRunner.test("Water Sharks folder contains exactly two configured Models", function()
	local sharks = expectChild(scene.Hazards, WorldConfig.Water.SharksFolder, "Folder")
	TestRunner.assertEqual(#sharks:GetChildren(), 2)

	for _, entry in WorldConfig.MovingHazards.Sharks do
		local shark = expectChild(sharks, entry.ModelName, "Model")
		expectChild(shark, "Visual", "Model")
		expectChild(shark, "Hitbox", "Part")
	end
end)

TestRunner.test("Water shark visuals contain passive Body and DorsalFin Parts", function()
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		local visual = expectChild(shark, "Visual", "Model")
		TestRunner.assertEqual(#visual:GetChildren(), 2)
		for _, partName in { "Body", "DorsalFin" } do
			local part = expectChild(visual, partName, "Part") :: BasePart
			TestRunner.assertTrue(part.Anchored)
			TestRunner.assertFalse(part.CanCollide)
			TestRunner.assertFalse(part.CanTouch)
			TestRunner.assertFalse(part.CanQuery)
			TestRunner.assertFalse(part.CastShadow)
			assertNoTagsOrAttributes(part)
		end
	end
end)

TestRunner.test("Water shark Hitboxes are non-colliding universal hazards", function()
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		local hitbox = expectChild(shark, "Hitbox", "Part") :: BasePart
		TestRunner.assertEqual(hitbox.Size, Vector3.new(6, 4, 2.25))
		TestRunner.assertTrue(hitbox.Anchored)
		TestRunner.assertFalse(hitbox.CanCollide)
		TestRunner.assertTrue(hitbox.CanTouch)
		TestRunner.assertTrue(hitbox.CanQuery)
		TestRunner.assertFalse(hitbox.CastShadow)
		TestRunner.assertTrue(math.abs(hitbox.Transparency - 0.65) <= 0.001)
		local tags = CollectionService:GetTags(hitbox)
		TestRunner.assertEqual(#tags, 1)
		TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
		TestRunner.assertEqual(next(hitbox:GetAttributes()), nil)
	end
end)

TestRunner.test("Water sharks have no attributes scripts constraints or extra tags", function()
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		assertNoTagsOrAttributes(shark)
		for _, descendant in shark:GetDescendants() do
			TestRunner.assertEqual(next(descendant:GetAttributes()), nil)
			TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
			TestRunner.assertFalse(descendant:IsA("Constraint"))
			if descendant.Name ~= "Hitbox" then
				TestRunner.assertEqual(#CollectionService:GetTags(descendant), 0)
			end
			if descendant:IsA("BasePart") then
				TestRunner.assertTrue(descendant.Anchored)
			end
		end
	end
end)

TestRunner.test("Water MovementPaths contains four passive configured shark markers", function()
	local paths = scene.MovementPaths
	TestRunner.assertEqual(#paths:GetChildren(), 4)
	for _, entry in WorldConfig.MovingHazards.Sharks do
		for _, markerName in { entry.StartMarkerName, entry.EndMarkerName } do
			local marker = expectChild(paths, markerName, "Part") :: BasePart
			TestRunner.assertTrue(marker.Anchored)
			TestRunner.assertFalse(marker.CanCollide)
			TestRunner.assertFalse(marker.CanTouch)
			TestRunner.assertFalse(marker.CanQuery)
			TestRunner.assertFalse(marker.CastShadow)
			assertNoTagsOrAttributes(marker)
		end
	end
end)

TestRunner.test("Water shark paths cross the centers of Ring04 and Ring07", function()
	for index, entry in WorldConfig.MovingHazards.Sharks do
		local startMarker = scene.MovementPaths[entry.StartMarkerName] :: BasePart
		local endMarker = scene.MovementPaths[entry.EndMarkerName] :: BasePart
		TestRunner.assertTrue(startMarker.Position ~= endMarker.Position)
		TestRunner.assertTrue(math.abs(startMarker.Position.Z - endMarker.Position.Z) <= 0.001)
		TestRunner.assertTrue(math.abs(startMarker.Position.X - endMarker.Position.X) >= 20)

		local targetRing = scene.Geometry.Rings[sharkRingTargets[index].ring] :: Model
		local center = ringCenter(targetRing)
		TestRunner.assertTrue(math.abs(startMarker.Position.Z - center.Z) <= 0.001)
		local minX = math.min(startMarker.Position.X, endMarker.Position.X)
		local maxX = math.max(startMarker.Position.X, endMarker.Position.X)
		TestRunner.assertTrue(center.X > minX and center.X < maxX)
	end
end)

TestRunner.test("Water shark endpoint envelopes stay inside OceanKill", function()
	local killBounds = getAabb(environment[WorldConfig.Environment.OceanKill])
	for _, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local pivot = shark:GetPivot().Position
		local currentBounds = getAabb(shark)
		for _, markerName in { entry.StartMarkerName, entry.EndMarkerName } do
			local endpoint = (scene.MovementPaths[markerName] :: BasePart).Position
			local offset = endpoint - pivot
			local endpointBounds = { min = currentBounds.min + offset, max = currentBounds.max + offset }
			TestRunner.assertTrue(endpointBounds.min.X >= killBounds.min.X)
			TestRunner.assertTrue(endpointBounds.max.X <= killBounds.max.X)
			TestRunner.assertTrue(endpointBounds.min.Z >= killBounds.min.Z)
			TestRunner.assertTrue(endpointBounds.max.Z <= killBounds.max.Z)
		end
	end
end)

TestRunner.test("Water shark lanes avoid EntryPlatform and ExitPlatform", function()
	for _, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local pivot = shark:GetPivot().Position
		local bounds = getAabb(shark)
		local startPosition = (scene.MovementPaths[entry.StartMarkerName] :: BasePart).Position
		local endPosition = (scene.MovementPaths[entry.EndMarkerName] :: BasePart).Position
		local startBounds = { min = bounds.min + startPosition - pivot, max = bounds.max + startPosition - pivot }
		local endBounds = { min = bounds.min + endPosition - pivot, max = bounds.max + endPosition - pivot }
		local sweptBounds = {
			min = Vector3.new(math.min(startBounds.min.X, endBounds.min.X), math.min(startBounds.min.Y, endBounds.min.Y), math.min(startBounds.min.Z, endBounds.min.Z)),
			max = Vector3.new(math.max(startBounds.max.X, endBounds.max.X), math.max(startBounds.max.Y, endBounds.max.Y), math.max(startBounds.max.Z, endBounds.max.Z)),
		}
		TestRunner.assertFalse(aabbsIntersect(sweptBounds, getAabb(scene.Geometry.EntryPlatform)))
		TestRunner.assertFalse(aabbsIntersect(sweptBounds, getAabb(scene.Geometry.ExitPlatform)))
	end
end)

TestRunner.test("Water shark endpoints fully leave every Ring landing segment", function()
	for _, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local pivot = shark:GetPivot().Position
		local bounds = getAabb(shark)
		for _, markerName in { entry.StartMarkerName, entry.EndMarkerName } do
			local endpoint = (scene.MovementPaths[markerName] :: BasePart).Position
			local offset = endpoint - pivot
			local endpointBounds = { min = bounds.min + offset, max = bounds.max + offset }
			for _, ring in scene.Geometry.Rings:GetChildren() do
				for _, segment in ring.LandingSegments:GetChildren() do
					TestRunner.assertFalse(
						aabbsIntersect(endpointBounds, getAabb(segment)),
						string.format("%s endpoint overlaps %s.%s", entry.Id, ring.Name, segment.Name)
					)
				end
			end
		end
	end
end)

TestRunner.test("Water shark bite lanes avoid neighboring Rings", function()
	for index, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local hitbox = shark.Hitbox :: BasePart
		local startPosition = (scene.MovementPaths[entry.StartMarkerName] :: BasePart).Position
		local endPosition = (scene.MovementPaths[entry.EndMarkerName] :: BasePart).Position
		local half = hitbox.Size / 2
		local sweptBounds = {
			min = Vector3.new(
				math.min(startPosition.X, endPosition.X) - half.X,
				startPosition.Y - half.Y,
				startPosition.Z - half.Z
			),
			max = Vector3.new(
				math.max(startPosition.X, endPosition.X) + half.X,
				startPosition.Y + half.Y,
				startPosition.Z + half.Z
			),
		}
		for _, neighborName in sharkRingTargets[index].neighbors do
			local neighbor = scene.Geometry.Rings[neighborName] :: Model
			TestRunner.assertFalse(aabbsIntersect(sweptBounds, getAabb(neighbor)))
		end
	end
end)

TestRunner.test("Water shark Hitboxes create narrow vertical bite bands", function()
	local waterTop = getAabb(scene.Geometry.WaterSurface).max.Y
	for index, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local hitbox = shark.Hitbox :: BasePart
		local targetRing = scene.Geometry.Rings[sharkRingTargets[index].ring] :: Model
		local ringBounds = getAabb(targetRing)
		local landingTop = landingSurfaceTop(targetRing)
		local hitboxTop = hitbox.Position.Y + hitbox.Size.Y / 2
		local hitboxBottom = hitbox.Position.Y - hitbox.Size.Y / 2
		local visualBounds = getAabb(shark.Visual)

		TestRunner.assertTrue(hitboxTop >= landingTop + 1)
		TestRunner.assertTrue(hitboxTop <= landingTop + 1.5)
		TestRunner.assertTrue(hitboxBottom >= visualBounds.min.Y)
		TestRunner.assertTrue(hitboxBottom <= visualBounds.max.Y)
		TestRunner.assertTrue(hitbox.Size.Z < (ringBounds.max.Z - ringBounds.min.Z) * 0.3)
		TestRunner.assertTrue(hitbox.Size.Z < (ringBounds.max.Z - ringBounds.min.Z))
		TestRunner.assertTrue(shark.Visual.DorsalFin.Position.Y + shark.Visual.DorsalFin.Size.Y / 2 > waterTop)
		TestRunner.assertTrue(shark.Visual.DorsalFin.Position.Y + shark.Visual.DorsalFin.Size.Y / 2 >= landingTop)
	end
end)

TestRunner.test("Water shark DangerousBands intersect only part of each target Ring", function()
	for index, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local hitbox = shark.Hitbox :: BasePart
		local targetRing = scene.Geometry.Rings[sharkRingTargets[index].ring] :: Model
		local center = ringCenter(targetRing)
		local bandMinZ = center.Z - hitbox.Size.Z / 2
		local bandMaxZ = center.Z + hitbox.Size.Z / 2
		local intersectingSegments = 0
		for _, segment in targetRing.LandingSegments:GetChildren() do
			local bounds = getAabb(segment)
			if bounds.min.Z <= bandMaxZ and bounds.max.Z >= bandMinZ then
				intersectingSegments += 1
			end
		end
		TestRunner.assertTrue(intersectingSegments > 0)
		TestRunner.assertTrue(intersectingSegments < #targetRing.LandingSegments:GetChildren())
	end
end)

TestRunner.test("Water shark dangerous probes are bitten while both safe sides remain clear", function()
	local characterHalfWidth = 1
	for index, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local hitbox = shark.Hitbox :: BasePart
		local targetRing = scene.Geometry.Rings[sharkRingTargets[index].ring] :: Model
		local center = ringCenter(targetRing)
		local landingTop = landingSurfaceTop(targetRing)
		local dangerous: BasePart? = nil
		local safeA: BasePart? = nil
		local safeB: BasePart? = nil
		for _, segment in targetRing.LandingSegments:GetChildren() do
			if dangerous == nil or math.abs(segment.Position.Z - center.Z) < math.abs((dangerous :: BasePart).Position.Z - center.Z) then
				dangerous = segment :: BasePart
			end
			if safeA == nil or segment.Position.Z > (safeA :: BasePart).Position.Z then safeA = segment :: BasePart end
			if safeB == nil or segment.Position.Z < (safeB :: BasePart).Position.Z then safeB = segment :: BasePart end
		end

		local dangerPart = dangerous :: BasePart
		local dangerCFrame = CFrame.new(dangerPart.Position.X, hitbox.Position.Y, center.Z)
		local dangerProbe = Vector3.new(dangerPart.Position.X, landingTop + 0.5, center.Z)
		TestRunner.assertTrue(pointInsideBox(dangerProbe, dangerCFrame, hitbox.Size))

		for _, safePart in { safeA :: BasePart, safeB :: BasePart } do
			local safeProbe = Vector3.new(safePart.Position.X, landingTop + 0.5, safePart.Position.Z)
			TestRunner.assertTrue(math.abs(safeProbe.Z - center.Z) - hitbox.Size.Z / 2 > characterHalfWidth)
			for _, markerName in { entry.StartMarkerName, entry.EndMarkerName } do
				local marker = scene.MovementPaths[markerName] :: BasePart
				TestRunner.assertFalse(pointInsideBox(safeProbe, marker.CFrame, hitbox.Size))
			end
			TestRunner.assertFalse(pointInsideBox(safeProbe, CFrame.new(center.X, hitbox.Position.Y, center.Z), hitbox.Size))
		end
	end
end)

TestRunner.test("Water retains approved Phase 2.7 world Hazard counts", function()
	local sceneHazards = 0
	for _, descendant in scene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then sceneHazards += 1 end
	end
	TestRunner.assertEqual(sceneHazards, 2)
	local environmentHazards = 0
	for _, descendant in environment:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then environmentHazards += 1 end
	end
	TestRunner.assertEqual(environmentHazards, 1)
	local palmHazards = 0
	for _, descendant in world[WorldConfig.Scenes.PalmFinish]:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then palmHazards += 1 end
	end
	TestRunner.assertEqual(palmHazards, 2)

	local worldHazards = 0
	for _, descendant in world:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then worldHazards += 1 end
	end
	TestRunner.assertEqual(worldHazards, 10)
	local beachHazards = 0
	for _, descendant in beachObby:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then beachHazards += 1 end
	end
	TestRunner.assertEqual(beachHazards, 10)
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

TestRunner.test("Water regression keeps Palm progression active and PalmFallCatch hazardous", function()
	local palmScene = world[WorldConfig.Scenes.PalmFinish]
	local palmFallCatch = palmScene.Hazards[WorldConfig.PalmFinish.PalmFallCatch]
	local palmUpperFallCatch = palmScene.Hazards[WorldConfig.PalmFinish.PalmUpperFallCatch]
	local expectedPalmHazards = {
		[palmFallCatch] = true,
		[palmUpperFallCatch] = true,
	}
	local hazardCount = 0
	for _, descendant in palmScene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then
			hazardCount += 1
			TestRunner.assertTrue(expectedPalmHazards[descendant] == true)
		end
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant.Anchored) end
	end
	TestRunner.assertEqual(hazardCount, 2)
	TestRunner.assertTrue(CollectionService:HasTag(palmFallCatch, RunConfig.Tags.Hazard))
	TestRunner.assertTrue(CollectionService:HasTag(palmUpperFallCatch, RunConfig.Tags.Hazard))
	local checkpoint = world[WorldConfig.Scenes.LaserIsland].Triggers[WorldConfig.LaserIsland.PalmBaseCheckpoint]
	TestRunner.assertTrue(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), 4)
	for _, name in WorldConfig.PalmFinish.CoinIds do
		local coin = palmScene.Coins[name]
		TestRunner.assertTrue(CollectionService:HasTag(coin, RunConfig.Tags.Coin))
		TestRunner.assertEqual(coin:GetAttribute(RunConfig.Attributes.CoinId), name)
	end
	local finish = palmScene.Triggers[WorldConfig.PalmFinish.FinishLine]
	TestRunner.assertTrue(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertEqual(finish:GetAttribute(RunConfig.Attributes.RequiredCheckpointOrder), 4)
end)

TestRunner.test("Water release hierarchy recursively excludes VerticalSlice and KillBlock", function()
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice") == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("KillBlock", true) == nil)
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:GetChildren()[1], world)
end)

TestRunner.test("Release water and environment geometry remain under the sole World root", function()
	TestRunner.assertTrue(beachObby:FindFirstChild("TemporaryAccess") == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("SpawnBridge", true) == nil)
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:FindFirstChild(WorldConfig.Root.World), world)
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant:IsDescendantOf(world)) end
	end
	for _, hazard in CollectionService:GetTagged(RunConfig.Tags.Hazard) do
		TestRunner.assertTrue(hazard:IsDescendantOf(world))
	end
	TestRunner.assertTrue(scene:IsDescendantOf(world))
	TestRunner.assertTrue(environment:IsDescendantOf(world))
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

TestRunner.test("Global ocean visually surrounds the final gameplay world", function()
	TestRunner.assertTrue(environment:IsA("Folder"))
	TestRunner.assertEqual(#environment:GetChildren(), 2)
	local oceanSurface = expectChild(environment, WorldConfig.Environment.OceanSurface, "Part") :: Part
	local oceanKill = expectChild(environment, WorldConfig.Environment.OceanKill, "Part") :: Part
	TestRunner.assertEqual(oceanSurface.Shape, Enum.PartType.Block)
	TestRunner.assertEqual(oceanSurface.CFrame, CFrame.new(111, -0.1, -107))
	TestRunner.assertEqual(oceanSurface.Size, Vector3.new(512, 0.2, 512))
	TestRunner.assertEqual(oceanSurface.Material, Enum.Material.Glass)
	TestRunner.assertEqual(oceanSurface.Color, scene.Geometry.WaterSurface.Color)
	TestRunner.assertTrue(math.abs(oceanSurface.Transparency - 0.35) <= 0.001)
	TestRunner.assertTrue(oceanSurface.Anchored)
	TestRunner.assertFalse(oceanSurface.CanCollide)
	TestRunner.assertFalse(oceanSurface.CanTouch)
	TestRunner.assertFalse(oceanSurface.CanQuery)
	TestRunner.assertFalse(oceanSurface.CastShadow)
	assertNoTagsOrAttributes(oceanSurface)
	TestRunner.assertEqual(#oceanSurface:GetChildren(), 0)
	local surfaceBounds = getAabb(oceanSurface)
	TestRunner.assertTrue((surfaceBounds.min - Vector3.new(-145, -0.2, -363)).Magnitude <= 0.001)
	TestRunner.assertTrue((surfaceBounds.max - Vector3.new(367, 0, 149)).Magnitude <= 0.001)
	local gameplayMin = Vector3.new(math.huge, math.huge, math.huge)
	local gameplayMax = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sceneName in { WorldConfig.Scenes.HotBeach, WorldConfig.Scenes.Water, WorldConfig.Scenes.LaserIsland, WorldConfig.Scenes.PalmFinish } do
		local bounds = getAabb(world[sceneName])
		gameplayMin = Vector3.new(math.min(gameplayMin.X, bounds.min.X), math.min(gameplayMin.Y, bounds.min.Y), math.min(gameplayMin.Z, bounds.min.Z))
		gameplayMax = Vector3.new(math.max(gameplayMax.X, bounds.max.X), math.max(gameplayMax.Y, bounds.max.Y), math.max(gameplayMax.Z, bounds.max.Z))
	end
	TestRunner.assertTrue(math.abs(gameplayMin.X - 79) <= 0.001)
	TestRunner.assertTrue(math.abs(gameplayMax.X - 202) <= 0.001)
	TestRunner.assertTrue(math.abs(gameplayMin.Z + 222) <= 0.001)
	TestRunner.assertTrue(math.abs(gameplayMax.Z - 18) <= 0.001)
	local margins = {
		gameplayMin.X - surfaceBounds.min.X,
		surfaceBounds.max.X - gameplayMax.X,
		surfaceBounds.max.Z - gameplayMax.Z,
		gameplayMin.Z - surfaceBounds.min.Z,
	}
	TestRunner.assertTrue(math.abs(margins[1] - 224) <= 0.001)
	TestRunner.assertTrue(math.abs(margins[2] - 165) <= 0.001)
	TestRunner.assertTrue(math.abs(margins[3] - 131) <= 0.001)
	TestRunner.assertTrue(math.abs(margins[4] - 141) <= 0.001)
	for _, margin in margins do TestRunner.assertTrue(margin >= 131) end
	TestRunner.assertTrue(getAabb(oceanKill).max.Y < 0)
	for _, sceneName in { WorldConfig.Scenes.HotBeach, WorldConfig.Scenes.Water, WorldConfig.Scenes.LaserIsland, WorldConfig.Scenes.PalmFinish } do
		for _, descendant in world[sceneName]:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide and descendant.Name ~= WorldConfig.PalmFinish.TrunkCore then
				TestRunner.assertFalse(aabbsIntersect(surfaceBounds, getAabb(descendant)))
			end
		end
	end
end)

TestRunner.test("Water course aligns floating route hazards and coins to the global ocean without moving connectors", function()
	local water = scene.Geometry.WaterSurface :: BasePart
	local oceanSurface = environment[WorldConfig.Environment.OceanSurface] :: BasePart
	local waterBounds = getAabb(water)
	local oceanBounds = getAabb(oceanSurface)
	TestRunner.assertEqual(water.CFrame, CFrame.new(111, -2.85, -107))
	TestRunner.assertEqual(water.Size, Vector3.new(32, 5.7, 56))
	TestRunner.assertTrue(math.abs(waterBounds.max.Y) <= 0.001)
	TestRunner.assertTrue(math.abs(waterBounds.min.Y + 5.7) <= 0.001)
	TestRunner.assertTrue(math.abs(waterBounds.max.Y - oceanBounds.max.Y) <= 0.001)
	TestRunner.assertEqual(water.Material, oceanSurface.Material)
	TestRunner.assertEqual(water.Color, oceanSurface.Color)
	TestRunner.assertTrue(math.abs(water.Transparency - oceanSurface.Transparency) <= 0.001)

	local expectedRingPivots = {
		Ring01 = Vector3.new(106, 1.4, -84),
		Ring02 = Vector3.new(116, 1.4, -90.5),
		Ring03 = Vector3.new(106, 1.4, -97),
		Ring04 = Vector3.new(116, 1.4, -103.5),
		Ring05 = Vector3.new(106, 1.4, -110),
		Ring06 = Vector3.new(116, 1.4, -116.5),
		Ring07 = Vector3.new(106, 1.4, -123),
		Ring08 = Vector3.new(116, 1.4, -130),
	}
	local segmentCount = 0
	local maximumRingGap = 0
	for index = 1, 8 do
		local name = string.format("Ring%02d", index)
		local ring = scene.Geometry.Rings[name] :: Model
		TestRunner.assertTrue((ring:GetPivot().Position - expectedRingPivots[name]).Magnitude <= 0.001)
		local bounds = getAabb(ring)
		TestRunner.assertTrue(math.abs(bounds.min.Y - 0.65) <= 0.001)
		TestRunner.assertTrue(math.abs(bounds.max.Y - 2.15) <= 0.001)
		TestRunner.assertTrue(math.abs(bounds.min.Y - waterBounds.max.Y - 0.65) <= 0.001)
		TestRunner.assertEqual(#ring.LandingSegments:GetChildren(), 16)
		segmentCount += #ring.LandingSegments:GetChildren()
		if index < 8 then
			maximumRingGap = math.max(maximumRingGap, ringGap(ring, scene.Geometry.Rings[string.format("Ring%02d", index + 1)]))
		end
	end
	TestRunner.assertEqual(segmentCount, 128)
	TestRunner.assertTrue(math.abs(maximumRingGap - 2.193554) <= 0.001)
	TestRunner.assertTrue(math.abs(platformToRingGap(scene.Geometry.EntryPlatform, scene.Geometry.Rings.Ring01) - 0.993499) <= 0.001)
	TestRunner.assertTrue(math.abs(platformToRingGap(scene.Geometry.ExitPlatform, scene.Geometry.Rings.Ring08) - 0.993499) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(scene.Geometry.Rings.Ring01).max.Y - getAabb(scene.Geometry.EntryPlatform).max.Y - 0.15) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(scene.Geometry.Rings.Ring08).max.Y - getAabb(scene.Geometry.ExitPlatform).max.Y - 0.15) <= 0.001)

	local expectedMarkers = {
		Shark01_Start = Vector3.new(98, 1.4, -103.5),
		Shark01_End = Vector3.new(124, 1.4, -103.5),
		Shark02_Start = Vector3.new(124, 1.4, -123),
		Shark02_End = Vector3.new(98, 1.4, -123),
	}
	for _, entry in WorldConfig.MovingHazards.Sharks do
		local shark = scene.Hazards.Sharks[entry.ModelName] :: Model
		local pivotPosition = shark:GetPivot().Position
		local startMarker = scene.MovementPaths[entry.StartMarkerName] :: BasePart
		local endMarker = scene.MovementPaths[entry.EndMarkerName] :: BasePart
		local startPosition = startMarker.Position
		local endPosition = endMarker.Position
		TestRunner.assertTrue((startPosition - expectedMarkers[entry.StartMarkerName]).Magnitude <= 0.001)
		TestRunner.assertTrue((endPosition - expectedMarkers[entry.EndMarkerName]).Magnitude <= 0.001)
		TestRunner.assertTrue(
			(Vector2.new(startPosition.X, startPosition.Z) - Vector2.new(expectedMarkers[entry.StartMarkerName].X, expectedMarkers[entry.StartMarkerName].Z)).Magnitude <= 0.001
		)
		TestRunner.assertTrue(
			(Vector2.new(endPosition.X, endPosition.Z) - Vector2.new(expectedMarkers[entry.EndMarkerName].X, expectedMarkers[entry.EndMarkerName].Z)).Magnitude <= 0.001
		)
		TestRunner.assertTrue(math.abs(startPosition.Y - 1.4) <= 0.001)
		TestRunner.assertTrue(math.abs(endPosition.Y - 1.4) <= 0.001)
		TestRunner.assertTrue(math.abs(startPosition.Y - endPosition.Y) <= 0.001)

		local segment = endPosition - startPosition
		local segmentLengthSquared = segment:Dot(segment)
		TestRunner.assertTrue(segmentLengthSquared > 0)
		local t = (pivotPosition - startPosition):Dot(segment) / segmentLengthSquared
		TestRunner.assertTrue(t >= -0.001)
		TestRunner.assertTrue(t <= 1.001)
		local clampedT = math.clamp(t, 0, 1)
		local closest = startPosition + segment * clampedT
		TestRunner.assertTrue((pivotPosition - closest).Magnitude <= 0.01)
		TestRunner.assertTrue(math.abs(pivotPosition.Y - 1.4) <= 0.001)

		local body = shark.Visual.Body :: BasePart
		local dorsalFin = shark.Visual.DorsalFin :: BasePart
		local hitbox = shark.Hitbox :: BasePart
		TestRunner.assertTrue(body:IsDescendantOf(shark))
		TestRunner.assertTrue(dorsalFin:IsDescendantOf(shark))
		TestRunner.assertTrue(hitbox:IsDescendantOf(shark))
		TestRunner.assertEqual(body.Size, Vector3.new(6, 1.4, 2.6))
		TestRunner.assertEqual(dorsalFin.Size, Vector3.new(2.4, 2.2, 0.35))
		TestRunner.assertEqual(hitbox.Size, Vector3.new(6, 4, 2.25))
		local pivotXZ = Vector2.new(pivotPosition.X, pivotPosition.Z)
		for _, part in { body, dorsalFin, hitbox } do
			TestRunner.assertTrue((Vector2.new(part.Position.X, part.Position.Z) - pivotXZ).Magnitude <= 0.001)
		end

		local bodyBounds = getAabb(body)
		local finBounds = getAabb(dorsalFin)
		local hitboxBounds = getAabb(hitbox)
		TestRunner.assertTrue(math.abs(body.Position.Y - (pivotPosition.Y - 1.75)) <= 0.001)
		TestRunner.assertTrue(math.abs(bodyBounds.min.Y - (pivotPosition.Y - 2.45)) <= 0.001)
		TestRunner.assertTrue(math.abs(bodyBounds.max.Y - (pivotPosition.Y - 1.05)) <= 0.001)
		TestRunner.assertTrue(math.abs(dorsalFin.Position.Y - pivotPosition.Y) <= 0.001)
		TestRunner.assertTrue(math.abs(finBounds.min.Y - (pivotPosition.Y - 1.1)) <= 0.001)
		TestRunner.assertTrue(math.abs(finBounds.max.Y - (pivotPosition.Y + 1.1)) <= 0.001)
		TestRunner.assertTrue(math.abs(hitbox.Position.Y - pivotPosition.Y) <= 0.001)
		TestRunner.assertTrue(math.abs(hitboxBounds.min.Y - (pivotPosition.Y - 2)) <= 0.001)
		TestRunner.assertTrue(math.abs(hitboxBounds.max.Y - (pivotPosition.Y + 2)) <= 0.001)
		local hitboxTags = CollectionService:GetTags(hitbox)
		TestRunner.assertEqual(#hitboxTags, 1)
		TestRunner.assertEqual(hitboxTags[1], RunConfig.Tags.Hazard)
		TestRunner.assertTrue(math.abs(waterBounds.max.Y - bodyBounds.min.Y - 1.05) <= 0.001)
		TestRunner.assertTrue(math.abs(bodyBounds.max.Y - waterBounds.max.Y - 0.35) <= 0.001)
	end

	local expectedCoins = {
		WaterCoin01 = Vector3.new(116, 3.9, -90.5),
		WaterCoin02 = Vector3.new(116, 3.9, -103.5),
		WaterCoin03 = Vector3.new(111, 3.9, -113.25),
		WaterCoin04 = Vector3.new(101, 3.9, -123),
	}
	local supportingRings = {
		WaterCoin01 = "Ring02",
		WaterCoin02 = "Ring04",
		WaterCoin03 = "Ring05",
		WaterCoin04 = "Ring07",
	}
	for name, expectedPosition in expectedCoins do
		local coin = scene.Coins[name] :: BasePart
		TestRunner.assertTrue((coin.Position - expectedPosition).Magnitude <= 0.001)
		TestRunner.assertTrue(math.abs(getAabb(coin).min.Y - getAabb(scene.Geometry.Rings[supportingRings[name]]).max.Y - 1) <= 0.001)
	end

	TestRunner.assertEqual(scene.Geometry.EntryPlatform.CFrame, CFrame.new(111, 1.5, -70))
	TestRunner.assertEqual(scene.Geometry.ExitPlatform.CFrame, CFrame.new(111, 1.5, -144))
	local checkpoint = expectChild(scene.Triggers, WorldConfig.Water.LaserIslandStartCheckpoint, "Part") :: BasePart
	TestRunner.assertEqual(checkpoint.Name, "LaserIslandStartCheckpoint")
	TestRunner.assertEqual(checkpoint.Parent, scene.Triggers)
	TestRunner.assertEqual(checkpoint.ClassName, "Part")
	TestRunner.assertTrue((checkpoint.Position - Vector3.new(111, 2.3, -144)).Magnitude <= 0.001)
	TestRunner.assertTrue((checkpoint.CFrame.RightVector - Vector3.xAxis).Magnitude <= 0.000001)
	TestRunner.assertTrue((checkpoint.CFrame.UpVector - Vector3.yAxis).Magnitude <= 0.000001)
	TestRunner.assertTrue((checkpoint.CFrame.LookVector + Vector3.zAxis).Magnitude <= 0.000001)
	TestRunner.assertEqual(checkpoint.Size, Vector3.new(12, 0.4, 4))
	TestRunner.assertTrue(checkpoint.Anchored)
	TestRunner.assertFalse(checkpoint.CanCollide)
	TestRunner.assertTrue(checkpoint.CanTouch)
	TestRunner.assertTrue(checkpoint.CanQuery)
	local checkpointTags = CollectionService:GetTags(checkpoint)
	TestRunner.assertEqual(#checkpointTags, 1)
	TestRunner.assertEqual(checkpointTags[1], RunConfig.Tags.Checkpoint)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId), "LaserIslandStart")
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), 3)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))
	local checkpointBounds = getAabb(checkpoint)
	local exitBounds = getAabb(scene.Geometry.ExitPlatform)
	TestRunner.assertTrue(math.abs(checkpointBounds.min.Y - exitBounds.max.Y - 0.1) <= 0.001)
end)

TestRunner.test("OceanKill is a physical lethal catch below the passive global ocean", function()
	local oceanSurface = environment[WorldConfig.Environment.OceanSurface] :: BasePart
	local oceanKill = environment[WorldConfig.Environment.OceanKill] :: BasePart
	local surfaceBounds = getAabb(oceanSurface)
	local killBounds = getAabb(oceanKill)
	TestRunner.assertEqual(oceanSurface.CFrame, CFrame.new(111, -0.1, -107))
	TestRunner.assertEqual(oceanSurface.Size, Vector3.new(512, 0.2, 512))
	TestRunner.assertFalse(oceanSurface.CanCollide)
	TestRunner.assertFalse(oceanSurface.CanTouch)
	TestRunner.assertFalse(oceanSurface.CanQuery)
	assertNoTagsOrAttributes(oceanSurface)
	TestRunner.assertEqual(oceanKill.CFrame, CFrame.new(111, -1, -107))
	TestRunner.assertEqual(oceanKill.Size, Vector3.new(512, 0.5, 512))
	TestRunner.assertTrue(oceanKill.CanCollide and oceanKill.CanTouch and oceanKill.CanQuery)
	local killTags = CollectionService:GetTags(oceanKill)
	TestRunner.assertEqual(#killTags, 1)
	TestRunner.assertEqual(killTags[1], RunConfig.Tags.Hazard)
	TestRunner.assertTrue(math.abs(surfaceBounds.max.Y) <= 0.001)
	TestRunner.assertTrue(math.abs(killBounds.max.Y + 0.75) <= 0.001)
	TestRunner.assertTrue(math.abs(killBounds.min.Y + 1.25) <= 0.001)
	TestRunner.assertTrue(math.abs(surfaceBounds.max.Y - killBounds.max.Y - 0.75) <= 0.001)
	TestRunner.assertTrue(math.abs(surfaceBounds.min.X - killBounds.min.X) <= 0.001)
	TestRunner.assertTrue(math.abs(surfaceBounds.max.X - killBounds.max.X) <= 0.001)
	TestRunner.assertTrue(math.abs(surfaceBounds.min.Z - killBounds.min.Z) <= 0.001)
	TestRunner.assertTrue(math.abs(surfaceBounds.max.Z - killBounds.max.Z) <= 0.001)
	for _, ring in scene.Geometry.Rings:GetChildren() do
		local ringBounds = getAabb(ring)
		TestRunner.assertTrue(math.abs(ringBounds.min.Y - killBounds.max.Y - 1.4) <= 0.001)
		TestRunner.assertFalse(aabbsIntersect(ringBounds, killBounds))
	end
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		local hitboxBounds = getAabb((shark :: Model).Hitbox)
		TestRunner.assertTrue(math.abs(hitboxBounds.min.Y - killBounds.max.Y - 0.15) <= 0.001)
		TestRunner.assertFalse(aabbsIntersect(hitboxBounds, killBounds))
	end
	local baseplateBounds = getAabb(workspace.Baseplate)
	TestRunner.assertTrue(math.abs(killBounds.min.Y - baseplateBounds.max.Y - 4.75) <= 0.001)
	TestRunner.assertFalse(workspace.Baseplate.CanCollide)
	TestRunner.assertEqual(countTaggedDescendants(environment, RunConfig.Tags.Hazard), 1)
	TestRunner.assertEqual(countTaggedDescendants(world, RunConfig.Tags.Hazard), 10)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Hazard), 10)
end)

return true
