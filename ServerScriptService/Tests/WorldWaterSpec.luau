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

-- Measured from the standard runtime R15 character before changing the water depth.
local measuredCharacterHeight = 5.496664047241211
local originalWaterTop = 1.1
local originalWaterPositionXZ = Vector2.new(111, -107)
local originalWaterSizeXZ = Vector2.new(32, 56)
local originalKillPositionXZ = Vector2.new(111, -107)
local originalKillSizeXZ = Vector2.new(40, 56)

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

TestRunner.test("WaterSurface retains its top and XZ contract while extending only downward", function()
	local water = scene.Geometry.WaterSurface :: BasePart
	local bounds = getAabb(water)
	TestRunner.assertTrue(math.abs(bounds.max.Y - originalWaterTop) <= 0.001)
	TestRunner.assertEqual(Vector2.new(water.Position.X, water.Position.Z), originalWaterPositionXZ)
	TestRunner.assertEqual(Vector2.new(water.Size.X, water.Size.Z), originalWaterSizeXZ)
	TestRunner.assertTrue(water.Size.Y > 0.1)
	TestRunner.assertTrue(bounds.min.Y < 1)
	TestRunner.assertTrue(math.abs(water.Position.Y - (originalWaterTop - water.Size.Y / 2)) <= 0.001)
	TestRunner.assertEqual(water.Material, Enum.Material.Glass)
	TestRunner.assertEqual(water.Color, Color3.fromRGB(65, 180, 255))
	TestRunner.assertTrue(math.abs(water.Transparency - 0.35) <= 0.001)
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

TestRunner.test("WaterKillPlane remains the only non-shark water Hazard", function()
	local nonSharkHazards = {}
	for _, descendant in scene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard)
			and not descendant:IsDescendantOf(scene.Hazards.Sharks) then
			table.insert(nonSharkHazards, descendant)
		end
	end
	TestRunner.assertEqual(#nonSharkHazards, 1)
	TestRunner.assertEqual(nonSharkHazards[1], scene.Hazards.WaterKillPlane)
end)

TestRunner.test("WaterKillPlane has universal trigger properties", function()
	local killPlane = scene.Hazards.WaterKillPlane :: BasePart
	TestRunner.assertTrue(killPlane.Anchored)
	TestRunner.assertTrue(killPlane.CanTouch)
	TestRunner.assertTrue(killPlane.CanQuery)
	TestRunner.assertFalse(killPlane.CanCollide)
end)

TestRunner.test("WaterKillPlane preserves XZ and allows the measured Character to submerge", function()
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	local killPlane = scene.Hazards.WaterKillPlane :: BasePart
	local killBounds = getAabb(killPlane)
	TestRunner.assertEqual(Vector2.new(killPlane.Position.X, killPlane.Position.Z), originalKillPositionXZ)
	TestRunner.assertEqual(Vector2.new(killPlane.Size.X, killPlane.Size.Z), originalKillSizeXZ)
	local submergedDistance = waterBounds.max.Y - killBounds.max.Y
	TestRunner.assertTrue(submergedDistance >= measuredCharacterHeight + 0.5)
	TestRunner.assertTrue(submergedDistance <= measuredCharacterHeight + 1.5)
end)

TestRunner.test("Water volume reaches below WaterKillPlane without touching solid bottom", function()
	local waterBounds = getAabb(scene.Geometry.WaterSurface)
	local killBounds = getAabb(scene.Hazards.WaterKillPlane)
	local baseplateBounds = getAabb(workspace.Baseplate)
	TestRunner.assertTrue(waterBounds.min.Y < killBounds.min.Y)
	TestRunner.assertTrue(killBounds.min.Y > baseplateBounds.max.Y)
	TestRunner.assertTrue(waterBounds.min.Y > baseplateBounds.max.Y)
	TestRunner.assertTrue(baseplateBounds.max.Y <= -6 + 0.001)
end)

TestRunner.test("Lowered WaterKillPlane avoids Rings and shark Models", function()
	local killBounds = getAabb(scene.Hazards.WaterKillPlane)
	for _, ring in scene.Geometry.Rings:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(killBounds, getAabb(ring)))
	end
	for _, shark in scene.Hazards.Sharks:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(killBounds, getAabb(shark)))
	end
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

TestRunner.test("Water ring pivots retain the accepted Phase 2.5 route", function()
	local expected = {
		Ring01 = Vector3.new(106, 2.5, -84),
		Ring02 = Vector3.new(116, 2.5, -90.5),
		Ring03 = Vector3.new(106, 2.5, -97),
		Ring04 = Vector3.new(116, 2.5, -103.5),
		Ring05 = Vector3.new(106, 2.5, -110),
		Ring06 = Vector3.new(116, 2.5, -116.5),
		Ring07 = Vector3.new(106, 2.5, -123),
		Ring08 = Vector3.new(116, 2.5, -130),
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

TestRunner.test("Water shark endpoint envelopes stay inside WaterKillPlane", function()
	local killBounds = getAabb(scene.Hazards.WaterKillPlane)
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
	TestRunner.assertEqual(sceneHazards, 3)
	local palmHazards = 0
	for _, descendant in world[WorldConfig.Scenes.PalmFinish]:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then palmHazards += 1 end
	end
	TestRunner.assertEqual(palmHazards, 1)

	local worldHazards = 0
	for _, descendant in world:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then worldHazards += 1 end
	end
	TestRunner.assertEqual(worldHazards, 9)
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

TestRunner.test("Water regression keeps Phase 2.7 Palm markers passive except PalmFallCatch", function()
	local palmScene = world[WorldConfig.Scenes.PalmFinish]
	local palmFallCatch = palmScene.Hazards[WorldConfig.PalmFinish.PalmFallCatch]
	local hazardCount = 0
	for _, descendant in palmScene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then
			hazardCount += 1
			TestRunner.assertEqual(descendant, palmFallCatch)
		end
		TestRunner.assertEqual(next(descendant:GetAttributes()), nil)
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		if descendant == palmFallCatch then
			TestRunner.assertEqual(#CollectionService:GetTags(descendant), 1)
			TestRunner.assertTrue((descendant :: BasePart).CanTouch)
		else
			TestRunner.assertEqual(#CollectionService:GetTags(descendant), 0)
			if descendant:IsA("BasePart") then TestRunner.assertFalse(descendant.CanTouch) end
		end
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant.Anchored) end
	end
	TestRunner.assertEqual(hazardCount, 1)
	local checkpoint = world[WorldConfig.Scenes.LaserIsland].Triggers[WorldConfig.LaserIsland.PalmBaseCheckpointMarker]
	TestRunner.assertFalse(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(next(checkpoint:GetAttributes()), nil)
	for _, name in WorldConfig.PalmFinish.CoinMarkerNames do
		local marker = palmScene.Coins[name]
		TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Coin))
		TestRunner.assertTrue(marker:GetAttribute("CoinId") == nil)
	end
	local finish = palmScene.Triggers[WorldConfig.PalmFinish.FinishPlaceholder]
	TestRunner.assertFalse(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertTrue(finish:GetAttribute("RequiredCheckpointOrder") == nil)
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
