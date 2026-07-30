--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local TestRunner = require(script.Parent.TestRunner)

local beachObby = workspace:WaitForChild(WorldConfig.Root.BeachObby)
local world = beachObby:WaitForChild(WorldConfig.Root.World)
local scene = world:WaitForChild(WorldConfig.Scenes.PalmFinish)
local scene01 = world:WaitForChild(WorldConfig.Scenes.HotBeach)
local scene02 = world:WaitForChild(WorldConfig.Scenes.Water)
local scene03 = world:WaitForChild(WorldConfig.Scenes.LaserIsland)
local palmConfig = WorldConfig.PalmFinish
local spiralConfig = palmConfig.Spiral

type Bounds = { min: Vector3, max: Vector3 }

local POSITION_TOLERANCE = 0.001
local BASIS_DOT_TOLERANCE = 0.00001

local function expectChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	TestRunner.assertTrue(child ~= nil, string.format("Missing %s.%s", parent:GetFullName(), name))
	TestRunner.assertTrue((child :: Instance):IsA(className), string.format("%s.%s must be %s", parent:GetFullName(), name, className))
	return child :: Instance
end

local function assertVectorClose(actual: Vector3, expected: Vector3, tolerance: number?)
	local allowed = tolerance or POSITION_TOLERANCE
	TestRunner.assertTrue((actual - expected).Magnitude <= allowed, string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
end

local function assertCFrameClose(actual: CFrame, expected: CFrame)
	assertVectorClose(actual.Position, expected.Position)
	TestRunner.assertTrue(actual.RightVector:Dot(expected.RightVector) >= 1 - BASIS_DOT_TOLERANCE)
	TestRunner.assertTrue(actual.UpVector:Dot(expected.UpVector) >= 1 - BASIS_DOT_TOLERANCE)
	TestRunner.assertTrue(actual.LookVector:Dot(expected.LookVector) >= 1 - BASIS_DOT_TOLERANCE)
end

local function assertExactChildren(parent: Instance, expected: { [string]: string })
	local count = 0
	local seen: { [string]: boolean } = {}
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

local function getAabb(part: BasePart): Bounds
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

local function instanceAabb(root: Instance): Bounds
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	local parts = if root:IsA("BasePart") then { root } else root:GetDescendants()
	for _, descendant in parts do
		if descendant:IsA("BasePart") then
			local bounds = getAabb(descendant)
			min = Vector3.new(math.min(min.X, bounds.min.X), math.min(min.Y, bounds.min.Y), math.min(min.Z, bounds.min.Z))
			max = Vector3.new(math.max(max.X, bounds.max.X), math.max(max.Y, bounds.max.Y), math.max(max.Z, bounds.max.Z))
		end
	end
	return { min = min, max = max }
end

local function aabbsIntersect(first: Bounds, second: Bounds): boolean
	return first.min.X < second.max.X and first.max.X > second.min.X
		and first.min.Y < second.max.Y and first.max.Y > second.min.Y
		and first.min.Z < second.max.Z and first.max.Z > second.min.Z
end

local function xzOverlap(first: Bounds, second: Bounds): boolean
	return first.min.X <= second.max.X and first.max.X >= second.min.X
		and first.min.Z <= second.max.Z and first.max.Z >= second.min.Z
end

local function horizontalGap(first: Bounds, second: Bounds): number
	local dx = math.max(second.min.X - first.max.X, first.min.X - second.max.X, 0)
	local dz = math.max(second.min.Z - first.max.Z, first.min.Z - second.max.Z, 0)
	return math.sqrt(dx * dx + dz * dz)
end

local function countTaggedUnder(root: Instance, tag: string): number
	local count = 0
	for _, tagged in CollectionService:GetTagged(tag) do
		if tagged == root or tagged:IsDescendantOf(root) then count += 1 end
	end
	return count
end

local function spiralExpected(index: number): (Vector3, CFrame, number)
	local theta = spiralConfig.InitialAngleRadians + (index - 1) * spiralConfig.AngularIncrementRadians
	local position = Vector3.new(
		spiralConfig.CenterX + spiralConfig.Radius * math.cos(theta),
		spiralConfig.FirstCenterY + spiralConfig.VerticalRise * (index - 1),
		spiralConfig.CenterZ + spiralConfig.Radius * math.sin(theta)
	)
	return position, CFrame.new(position) * CFrame.Angles(0, -theta, 0), theta
end

local function orderedStep(index: number): Part
	return expectChild(scene.Geometry[palmConfig.Spiral.FolderName], string.format("%s%02d", spiralConfig.StepPrefix, index), "Part") :: Part
end

local function assertNoTagsOrAttributes(instance: Instance)
	TestRunner.assertEqual(#CollectionService:GetTags(instance), 0, instance:GetFullName() .. " must be untagged")
	TestRunner.assertEqual(next(instance:GetAttributes()), nil, instance:GetFullName() .. " must be attribute-free")
end

local function assertIdentity(cframe: CFrame)
	assertCFrameClose(cframe, CFrame.new(cframe.Position))
end

TestRunner.test("PalmFinish has the exact top-level folder hierarchy", function()
	TestRunner.assertTrue(scene:IsA("Model"))
	assertExactChildren(scene, {
		[WorldConfig.CommonFolders.Geometry] = "Folder",
		[WorldConfig.CommonFolders.Hazards] = "Folder",
		[WorldConfig.CommonFolders.Coins] = "Folder",
		[WorldConfig.CommonFolders.Triggers] = "Folder",
	})
end)

TestRunner.test("PalmFinish folders contain the exact approved children", function()
	assertExactChildren(scene.Geometry, {
		[palmConfig.EntryPlatform] = "Part",
		[palmConfig.SummitPlatform] = "Part",
		[palmConfig.PalmTree] = "Model",
		[palmConfig.Spiral.FolderName] = "Folder",
	})
	assertExactChildren(scene.Hazards, { [palmConfig.PalmFallCatch] = "Part" })
	local expectedCoins: { [string]: string } = {}
	for _, name in palmConfig.CoinMarkerNames do expectedCoins[name] = "Part" end
	assertExactChildren(scene.Coins, expectedCoins)
	assertExactChildren(scene.Triggers, { [palmConfig.FinishPlaceholder] = "Part" })
end)

TestRunner.test("PalmFinish PalmTree has the exact Trunk and Fronds hierarchy", function()
	local palmTree = expectChild(scene.Geometry, palmConfig.PalmTree, "Model")
	assertExactChildren(palmTree, { [palmConfig.Trunk] = "Model", [palmConfig.Fronds] = "Model" })
	assertExactChildren(palmTree[palmConfig.Trunk], {
		[palmConfig.TrunkCore] = "Part",
		[palmConfig.CrownNeck] = "Part",
		[palmConfig.CrownHub] = "Part",
	})
	local expectedFronds: { [string]: string } = {}
	for index = 1, palmConfig.FrondCount do expectedFronds[string.format("%s%02d", palmConfig.FrondPrefix, index)] = "Part" end
	assertExactChildren(palmTree[palmConfig.Fronds], expectedFronds)
end)

TestRunner.test("PalmFinish SpiralSteps contains unique Step01 through Step73 Parts", function()
	local steps = expectChild(scene.Geometry, spiralConfig.FolderName, "Folder")
	local expected: { [string]: string } = {}
	for index = 1, spiralConfig.StepCount do expected[string.format("%s%02d", spiralConfig.StepPrefix, index)] = "Part" end
	assertExactChildren(steps, expected)
	TestRunner.assertTrue(steps:FindFirstChild("Step00") == nil)
	TestRunner.assertTrue(steps:FindFirstChild("Step74") == nil)
end)

TestRunner.test("PalmFinish TrunkCore retains the approved vertical cylinder geometry", function()
	local trunk = scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.TrunkCore] :: Part
	TestRunner.assertEqual(trunk.Shape, Enum.PartType.Cylinder)
	assertVectorClose(trunk.Position, Vector3.new(164, 18.5, -184))
	assertVectorClose(trunk.Size, Vector3.new(48, 5, 5))
	TestRunner.assertTrue(math.abs(trunk.CFrame.RightVector:Dot(Vector3.yAxis)) >= 1 - BASIS_DOT_TOLERANCE)
	TestRunner.assertTrue(trunk.Anchored)
	TestRunner.assertTrue(trunk.CanCollide)
	TestRunner.assertFalse(trunk.CanTouch)
	TestRunner.assertFalse(trunk.CanQuery)
	TestRunner.assertFalse(trunk.CastShadow)
end)

TestRunner.test("PalmFinish CrownNeck overlaps TrunkCore and CrownHub without a gap", function()
	local trunkModel = scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk]
	local trunk = trunkModel[palmConfig.TrunkCore] :: Part
	local neck = trunkModel[palmConfig.CrownNeck] :: Part
	local hub = trunkModel[palmConfig.CrownHub] :: Part
	TestRunner.assertEqual(neck.Shape, Enum.PartType.Cylinder)
	assertVectorClose(neck.Position, Vector3.new(164, 45.15, -184))
	assertVectorClose(neck.Size, Vector3.new(5.8, 3.5, 3.5))
	TestRunner.assertTrue(math.abs(neck.CFrame.RightVector:Dot(Vector3.yAxis)) >= 1 - BASIS_DOT_TOLERANCE)
	local trunkTop = trunk.Position.Y + trunk.Size.X / 2
	local neckBottom = neck.Position.Y - neck.Size.X / 2
	local neckTop = neck.Position.Y + neck.Size.X / 2
	local hubBottom = hub.Position.Y - hub.Size.Y / 2
	TestRunner.assertTrue(math.abs(trunkTop - neckBottom - 0.25) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(neckTop - hubBottom - 0.25) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(neck.Anchored)
	TestRunner.assertFalse(neck.CanCollide)
	TestRunner.assertFalse(neck.CanTouch)
	TestRunner.assertFalse(neck.CanQuery)
end)

TestRunner.test("PalmFinish CrownHub remains a centered passive primitive ball", function()
	local hub = scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.CrownHub] :: Part
	TestRunner.assertEqual(hub.Shape, Enum.PartType.Ball)
	assertVectorClose(hub.Position, Vector3.new(164, 50.05, -184))
	assertVectorClose(hub.Size, Vector3.new(4.5, 4.5, 4.5))
	TestRunner.assertTrue(hub.Anchored)
	TestRunner.assertFalse(hub.CanCollide)
	TestRunner.assertFalse(hub.CanTouch)
	TestRunner.assertFalse(hub.CanQuery)
	TestRunner.assertFalse(hub.CastShadow)
end)

TestRunner.test("PalmFinish Fronds form the approved symmetric eight-part crown", function()
	local fronds = scene.Geometry[palmConfig.PalmTree][palmConfig.Fronds]
	TestRunner.assertEqual(#fronds:GetChildren(), palmConfig.FrondCount)
	for index = 1, palmConfig.FrondCount do
		local frond = fronds[string.format("%s%02d", palmConfig.FrondPrefix, index)] :: Part
		local phi = (index - 1) * math.pi / 4
		local position = Vector3.new(164 + 6 * math.cos(phi), 50.05, -184 + 6 * math.sin(phi))
		TestRunner.assertEqual(frond.Shape, Enum.PartType.Block)
		assertVectorClose(frond.Size, Vector3.new(14, 0.5, 3))
		assertCFrameClose(frond.CFrame, CFrame.new(position) * CFrame.Angles(0, -phi, 0))
		TestRunner.assertTrue(math.abs((Vector2.new(frond.Position.X, frond.Position.Z) - Vector2.new(164, -184)).Magnitude - 6) <= POSITION_TOLERANCE)
	end
end)

TestRunner.test("PalmFinish palm parts are anchored primitive and free of gameplay state", function()
	local palmTree = scene.Geometry[palmConfig.PalmTree]
	for _, descendant in palmTree:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("MeshPart"))
		TestRunner.assertFalse(descendant:IsA("UnionOperation"))
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		assertNoTagsOrAttributes(descendant)
		if descendant:IsA("BasePart") then
			TestRunner.assertTrue(descendant:IsA("Part"))
			TestRunner.assertTrue(descendant.Anchored)
			TestRunner.assertFalse(descendant.CanTouch)
			TestRunner.assertFalse(descendant.CanQuery)
			TestRunner.assertFalse(descendant.CastShadow)
			TestRunner.assertEqual(#descendant:GetChildren(), 0)
			if descendant.Name ~= palmConfig.TrunkCore then TestRunner.assertFalse(descendant.CanCollide) end
		end
	end
end)

TestRunner.test("PalmFinish step centers follow the configured spiral formula", function()
	for index = 1, spiralConfig.StepCount do
		local expectedPosition = spiralExpected(index)
		assertVectorClose(orderedStep(index).Position, expectedPosition)
	end
end)

TestRunner.test("PalmFinish step CFrames follow the configured tangent yaw", function()
	for index = 1, spiralConfig.StepCount do
		local _, expectedCFrame = spiralExpected(index)
		assertCFrameClose(orderedStep(index).CFrame, expectedCFrame)
	end
end)

TestRunner.test("PalmFinish steps share the approved primitive traversal properties", function()
	for index = 1, spiralConfig.StepCount do
		local step = orderedStep(index)
		TestRunner.assertEqual(step.Shape, Enum.PartType.Block)
		assertVectorClose(step.Size, Vector3.new(spiralConfig.StepWidth, spiralConfig.StepHeight, spiralConfig.StepDepth))
		TestRunner.assertTrue(step.Anchored)
		TestRunner.assertTrue(step.CanCollide)
		TestRunner.assertFalse(step.CanTouch)
		TestRunner.assertTrue(step.CanQuery)
		TestRunner.assertFalse(step.CastShadow)
		assertNoTagsOrAttributes(step)
		TestRunner.assertEqual(#step:GetChildren(), 0)
	end
end)

TestRunner.test("PalmFinish spiral derives three revolutions and thirty-six studs of rise", function()
	local intervals = spiralConfig.StepCount - 1
	local revolutions = intervals * spiralConfig.AngularIncrementRadians / (2 * math.pi)
	local totalRise = intervals * spiralConfig.VerticalRise
	TestRunner.assertEqual(intervals, 72)
	TestRunner.assertTrue(math.abs(revolutions - 3) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(totalRise - 36) <= POSITION_TOLERANCE)
	for index = 1, spiralConfig.StepCount do
		local step = orderedStep(index)
		local radius = (Vector2.new(step.Position.X, step.Position.Z) - Vector2.new(spiralConfig.CenterX, spiralConfig.CenterZ)).Magnitude
		TestRunner.assertTrue(math.abs(radius - 9.5) <= POSITION_TOLERANCE)
	end
	TestRunner.assertTrue(math.abs(math.deg(spiralConfig.AngularIncrementRadians) - 15) <= POSITION_TOLERANCE)
end)

TestRunner.test("PalmFinish adjacent steps overlap without horizontal or vertical gaps", function()
	local expectedChord = 2 * spiralConfig.Radius * math.sin(spiralConfig.AngularIncrementRadians / 2)
	local expectedTangentialOverlap = spiralConfig.StepDepth - expectedChord
	local expectedVerticalOverlap = spiralConfig.StepHeight - spiralConfig.VerticalRise
	TestRunner.assertTrue(math.abs(expectedChord - 2.479998) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(expectedTangentialOverlap - 1.520002) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(expectedVerticalOverlap - 0.25) <= POSITION_TOLERANCE)
	for index = 1, spiralConfig.StepCount - 1 do
		local first = orderedStep(index)
		local second = orderedStep(index + 1)
		local chord = (Vector2.new(second.Position.X, second.Position.Z) - Vector2.new(first.Position.X, first.Position.Z)).Magnitude
		TestRunner.assertTrue(math.abs(chord - expectedChord) <= POSITION_TOLERANCE)
		TestRunner.assertTrue(spiralConfig.StepDepth - chord > 0)
		TestRunner.assertTrue(spiralConfig.StepHeight - math.abs(second.Position.Y - first.Position.Y) > 0)
	end
end)

TestRunner.test("PalmFinish spiral preserves trunk clearance and same-angle headroom", function()
	local outerRadius = spiralConfig.Radius + spiralConfig.StepWidth / 2
	local innerRadius = spiralConfig.Radius - spiralConfig.StepWidth / 2
	local trunkRadius = 2.5
	local trunkClearance = innerRadius - trunkRadius
	local sameAngleInterval = math.floor((2 * math.pi / spiralConfig.AngularIncrementRadians) + 0.5)
	local sameAngleSeparation = sameAngleInterval * spiralConfig.VerticalRise
	local headroom = sameAngleSeparation - spiralConfig.StepHeight
	TestRunner.assertTrue(math.abs(outerRadius - 12.25) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(innerRadius - 6.75) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(trunkClearance - 4.25) <= POSITION_TOLERANCE)
	TestRunner.assertEqual(sameAngleInterval, 24)
	TestRunner.assertTrue(math.abs(sameAngleSeparation - 12) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(headroom - 11.25) <= POSITION_TOLERANCE)
	for index = 1, spiralConfig.StepCount - sameAngleInterval do
		local first = orderedStep(index)
		local second = orderedStep(index + sameAngleInterval)
		TestRunner.assertTrue((Vector2.new(first.Position.X, first.Position.Z) - Vector2.new(second.Position.X, second.Position.Z)).Magnitude <= POSITION_TOLERANCE)
		TestRunner.assertTrue(math.abs(second.Position.Y - first.Position.Y - 12) <= POSITION_TOLERANCE)
	end
end)

TestRunner.test("PalmFinish EntryPlatform retains the accepted Phase 2.6 geometry", function()
	local entry = scene.Geometry[palmConfig.EntryPlatform] :: Part
	assertVectorClose(entry.Position, Vector3.new(151, 1.5, -184))
	assertVectorClose(entry.Size, Vector3.new(16, 1, 16))
	assertIdentity(entry.CFrame)
	TestRunner.assertTrue(math.abs(entry.Position.Y + entry.Size.Y / 2 - 2) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(entry.Anchored)
	TestRunner.assertTrue(entry.CanCollide)
	TestRunner.assertFalse(entry.CanTouch)
	TestRunner.assertTrue(entry.CanQuery)
	TestRunner.assertFalse(entry.CastShadow)
end)

TestRunner.test("PalmFinish Step01 connects EntryPlatform at walkable rise", function()
	local entry = scene.Geometry[palmConfig.EntryPlatform] :: BasePart
	local step = orderedStep(1)
	local entryBounds = getAabb(entry)
	local stepBounds = getAabb(step)
	TestRunner.assertTrue(xzOverlap(entryBounds, stepBounds))
	TestRunner.assertTrue(horizontalGap(entryBounds, stepBounds) <= POSITION_TOLERANCE)
	local entryTop = entryBounds.max.Y
	local stepTop = stepBounds.max.Y
	TestRunner.assertTrue(math.abs(stepTop - 2.5) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(stepTop - entryTop - 0.5) <= POSITION_TOLERANCE)
end)

TestRunner.test("PalmFinish SummitPlatform retains the approved outboard geometry and lower-step headroom", function()
	local summit = scene.Geometry[palmConfig.SummitPlatform] :: Part
	assertVectorClose(summit.Position, Vector3.new(149.25, 38.75, -188.25))
	assertVectorClose(summit.Size, Vector3.new(12, 0.5, 8))
	assertIdentity(summit.CFrame)
	TestRunner.assertTrue(math.abs(summit.Position.Y + summit.Size.Y / 2 - 39) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(summit.Anchored and summit.CanCollide and summit.CanQuery)
	TestRunner.assertFalse(summit.CanTouch)
	TestRunner.assertFalse(summit.CastShadow)
	local summitBounds = getAabb(summit)
	local minimumHeadroom = math.huge
	for index = 1, spiralConfig.StepCount - 2 do
		local stepBounds = getAabb(orderedStep(index))
		if xzOverlap(summitBounds, stepBounds) then minimumHeadroom = math.min(minimumHeadroom, summitBounds.min.Y - stepBounds.max.Y) end
	end
	TestRunner.assertTrue(minimumHeadroom > 5.496664)
end)

TestRunner.test("PalmFinish Step73 connects SummitPlatform while Step72 stays clear", function()
	local summitBounds = getAabb(scene.Geometry[palmConfig.SummitPlatform] :: BasePart)
	local step73Bounds = getAabb(orderedStep(73))
	local step72Bounds = getAabb(orderedStep(72))
	TestRunner.assertTrue(xzOverlap(summitBounds, step73Bounds))
	TestRunner.assertTrue(math.abs(summitBounds.max.Y - step73Bounds.max.Y - 0.5) <= POSITION_TOLERANCE)
	TestRunner.assertFalse(aabbsIntersect(summitBounds, step72Bounds))
	TestRunner.assertTrue(horizontalGap(summitBounds, step73Bounds) <= POSITION_TOLERANCE)
end)

TestRunner.test("PalmFinish PalmFallCatch has the exact universal Hazard contract", function()
	local catch = scene.Hazards[palmConfig.PalmFallCatch] :: Part
	TestRunner.assertEqual(catch.Shape, Enum.PartType.Block)
	assertVectorClose(catch.Position, Vector3.new(164, -4.75, -184))
	assertVectorClose(catch.Size, Vector3.new(30, 0.5, 30))
	local bounds = getAabb(catch)
	assertVectorClose(bounds.min, Vector3.new(149, -5, -199))
	assertVectorClose(bounds.max, Vector3.new(179, -4.5, -169))
	TestRunner.assertTrue(catch.Anchored)
	TestRunner.assertFalse(catch.CanCollide)
	TestRunner.assertTrue(catch.CanTouch)
	TestRunner.assertTrue(catch.CanQuery)
	TestRunner.assertEqual(#CollectionService:GetTags(catch), 1)
	TestRunner.assertTrue(CollectionService:HasTag(catch, RunConfig.Tags.Hazard))
	TestRunner.assertEqual(next(catch:GetAttributes()), nil)
	for _, child in catch:GetChildren() do
		TestRunner.assertTrue(
			child:IsA("TouchTransmitter"),
			string.format(
				"%s child %s [%s] must be an engine TouchTransmitter",
				catch:GetFullName(),
				child.Name,
				child.ClassName
			)
		)
	end
end)

TestRunner.test("PalmFinish PalmFallCatch covers the complete spiral XZ envelope", function()
	local catchBounds = getAabb(scene.Hazards[palmConfig.PalmFallCatch] :: BasePart)
	for index = 1, spiralConfig.StepCount do
		local bounds = getAabb(orderedStep(index))
		TestRunner.assertTrue(bounds.min.X >= catchBounds.min.X - POSITION_TOLERANCE)
		TestRunner.assertTrue(bounds.max.X <= catchBounds.max.X + POSITION_TOLERANCE)
		TestRunner.assertTrue(bounds.min.Z >= catchBounds.min.Z - POSITION_TOLERANCE)
		TestRunner.assertTrue(bounds.max.Z <= catchBounds.max.Z + POSITION_TOLERANCE)
	end
end)

TestRunner.test("PalmFinish PalmFallCatch stays clear of the valid route and neighboring scenes", function()
	local catchBounds = getAabb(scene.Hazards[palmConfig.PalmFallCatch] :: BasePart)
	TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(scene.Geometry[palmConfig.EntryPlatform] :: BasePart)))
	TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(scene.Geometry[palmConfig.SummitPlatform] :: BasePart)))
	for index = 1, spiralConfig.StepCount do TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(orderedStep(index)))) end
	TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(scene03.Geometry[WorldConfig.LaserIsland.IslandBase] :: BasePart)))
	local laser = scene03.Hazards[WorldConfig.LaserIsland.LaserAssembly][WorldConfig.LaserIsland.LaserBar] :: BasePart
	TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(laser)))
	local center = scene03.Geometry[WorldConfig.LaserIsland.CenterSphere].Position
	local laserEnvelopeRadius = laser.Size.X / 2 + laser.Size.Z / 2
	TestRunner.assertTrue(catchBounds.min.X - (center.X + laserEnvelopeRadius) > 0)
end)

TestRunner.test("PalmFinish PalmFallCatch has only the accepted TrunkCore boundary overlap", function()
	local catch = scene.Hazards[palmConfig.PalmFallCatch] :: BasePart
	local catchBounds = getAabb(catch)
	local trunk = scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.TrunkCore] :: BasePart
	local trunkBounds = getAabb(trunk)
	local overlapY = math.min(catchBounds.max.Y, trunkBounds.max.Y) - math.max(catchBounds.min.Y, trunkBounds.min.Y)
	TestRunner.assertTrue(aabbsIntersect(catchBounds, trunkBounds))
	TestRunner.assertTrue(math.abs(overlapY - 0.5) <= POSITION_TOLERANCE)
	for _, descendant in scene:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= catch and descendant ~= trunk then
			TestRunner.assertFalse(aabbsIntersect(catchBounds, getAabb(descendant)), "Unexpected PalmFallCatch overlap with " .. descendant:GetFullName())
		end
	end
end)

TestRunner.test("PalmFinish Coins contains exactly three unique configured markers", function()
	local expected: { [string]: string } = {}
	for _, name in palmConfig.CoinMarkerNames do expected[name] = "Part" end
	assertExactChildren(scene.Coins, expected)
end)

TestRunner.test("PalmFinish coin markers derive from Steps 12 37 and 62", function()
	for markerIndex, stepIndex in { 12, 37, 62 } do
		local marker = scene.Coins[palmConfig.CoinMarkerNames[markerIndex]] :: BasePart
		local step = orderedStep(stepIndex)
		local center = Vector3.new(spiralConfig.CenterX, 0, spiralConfig.CenterZ)
		local stepHorizontal = Vector3.new(step.Position.X, 0, step.Position.Z)
		local outward = (stepHorizontal - center).Unit
		local expected = Vector3.new(center.X + outward.X * 11.5, step.Position.Y + step.Size.Y / 2 + 1.75, center.Z + outward.Z * 11.5)
		assertVectorClose(marker.Position, expected)
		TestRunner.assertTrue(math.abs((Vector2.new(marker.Position.X, marker.Position.Z) - Vector2.new(center.X, center.Z)).Magnitude - 11.5) <= POSITION_TOLERANCE)
		TestRunner.assertTrue(math.abs((Vector2.new(marker.Position.X, marker.Position.Z) - Vector2.new(step.Position.X, step.Position.Z)).Magnitude - 2) <= POSITION_TOLERANCE)
		TestRunner.assertTrue(math.abs((marker.Position.Y - marker.Size.Y / 2) - (step.Position.Y + step.Size.Y / 2) - 1) <= POSITION_TOLERANCE)
	end
end)

TestRunner.test("PalmFinish coin markers are passive and clear of route geometry", function()
	local trunkBounds = getAabb(scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.TrunkCore] :: BasePart)
	local summitBounds = getAabb(scene.Geometry[palmConfig.SummitPlatform] :: BasePart)
	for markerIndex, stepIndex in { 12, 37, 62 } do
		local marker = scene.Coins[palmConfig.CoinMarkerNames[markerIndex]] :: Part
		TestRunner.assertEqual(marker.Shape, Enum.PartType.Ball)
		assertVectorClose(marker.Size, Vector3.new(1.5, 1.5, 1.5))
		TestRunner.assertEqual(marker.Material, Enum.Material.Neon)
		assertVectorClose(Vector3.new(marker.Color.R, marker.Color.G, marker.Color.B), Vector3.new(1, 1, 0))
		TestRunner.assertTrue(marker.Anchored)
		TestRunner.assertFalse(marker.CanCollide)
		TestRunner.assertFalse(marker.CanTouch)
		TestRunner.assertFalse(marker.CanQuery)
		assertNoTagsOrAttributes(marker)
		TestRunner.assertTrue(marker:GetAttribute("CoinId") == nil)
		TestRunner.assertEqual(#marker:GetChildren(), 0)
		local bounds = getAabb(marker)
		TestRunner.assertFalse(aabbsIntersect(bounds, getAabb(orderedStep(stepIndex))))
		TestRunner.assertFalse(aabbsIntersect(bounds, trunkBounds))
		TestRunner.assertFalse(aabbsIntersect(bounds, summitBounds))
	end
end)

TestRunner.test("PalmFinish FinishPlaceholder has the approved summit-supported geometry", function()
	local finish = scene.Triggers[palmConfig.FinishPlaceholder] :: Part
	local summit = scene.Geometry[palmConfig.SummitPlatform] :: BasePart
	assertVectorClose(finish.Position, Vector3.new(146.25, 41, -188.25))
	assertVectorClose(finish.Size, Vector3.new(3, 4, 6))
	TestRunner.assertEqual(finish.Shape, Enum.PartType.Block)
	local finishBounds = getAabb(finish)
	local summitBounds = getAabb(summit)
	TestRunner.assertTrue(math.abs(finishBounds.min.Y - summitBounds.max.Y) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(finishBounds.min.X - summitBounds.min.X - 1.5) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(summitBounds.max.X - finishBounds.max.X - 7.5) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(finishBounds.min.Z - summitBounds.min.Z - 1) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(summitBounds.max.Z - finishBounds.max.Z - 1) <= POSITION_TOLERANCE)
end)

TestRunner.test("PalmFinish FinishPlaceholder remains passive and attribute-free", function()
	local finish = scene.Triggers[palmConfig.FinishPlaceholder] :: Part
	TestRunner.assertEqual(finish.Material, Enum.Material.Neon)
	assertVectorClose(Vector3.new(finish.Color.R, finish.Color.G, finish.Color.B), Vector3.new(0, 1, 0))
	TestRunner.assertEqual(finish.Transparency, 0.5)
	TestRunner.assertTrue(finish.Anchored)
	TestRunner.assertFalse(finish.CanCollide)
	TestRunner.assertFalse(finish.CanTouch)
	TestRunner.assertFalse(finish.CanQuery)
	TestRunner.assertFalse(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertTrue(finish:GetAttribute("RequiredCheckpointOrder") == nil)
	assertNoTagsOrAttributes(finish)
	TestRunner.assertEqual(#finish:GetChildren(), 0)
end)

TestRunner.test("PalmFinish FinishPlaceholder preserves the Step73 summit route clearance", function()
	local finishBounds = getAabb(scene.Triggers[palmConfig.FinishPlaceholder] :: BasePart)
	local stepBounds = getAabb(orderedStep(73))
	local crownNeckBounds = getAabb(scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.CrownNeck] :: BasePart)
	local crownHubBounds = getAabb(scene.Geometry[palmConfig.PalmTree][palmConfig.Trunk][palmConfig.CrownHub] :: BasePart)
	local xGap = math.max(stepBounds.min.X - finishBounds.max.X, finishBounds.min.X - stepBounds.max.X, 0)
	TestRunner.assertTrue(math.abs(xGap - 4) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(math.abs(finishBounds.min.Y - stepBounds.max.Y - 0.5) <= POSITION_TOLERANCE)
	TestRunner.assertTrue(xGap >= 4 - POSITION_TOLERANCE)
	TestRunner.assertTrue(crownNeckBounds.min.X - finishBounds.max.X >= 14.5 - POSITION_TOLERANCE)
	TestRunner.assertTrue(crownHubBounds.min.X - finishBounds.max.X >= 14 - POSITION_TOLERANCE)
	TestRunner.assertFalse(aabbsIntersect(finishBounds, stepBounds))
	TestRunner.assertFalse(aabbsIntersect(finishBounds, crownNeckBounds))
	TestRunner.assertFalse(aabbsIntersect(finishBounds, crownHubBounds))
end)

TestRunner.test("PalmFinish activates only PalmFallCatch within Scene04", function()
	local catch = scene.Hazards[palmConfig.PalmFallCatch]
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.Hazard), 1)
	TestRunner.assertTrue(CollectionService:HasTag(catch, RunConfig.Tags.Hazard))
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.Coin), 0)
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.Finish), 0)
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.Checkpoint), 0)
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.RunStart), 0)
end)

TestRunner.test("PalmFinish keeps PalmBase coins and finish Phase 2.8 contracts inactive", function()
	local checkpoint = scene03.Triggers[WorldConfig.LaserIsland.PalmBaseCheckpointMarker]
	TestRunner.assertFalse(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	for _, name in { "CheckpointId", "CheckpointOrder", "RespawnOffset" } do TestRunner.assertTrue(checkpoint:GetAttribute(name) == nil) end
	for _, name in palmConfig.CoinMarkerNames do
		local marker = scene.Coins[name]
		TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Coin))
		TestRunner.assertTrue(marker:GetAttribute("CoinId") == nil)
	end
	local finish = scene.Triggers[palmConfig.FinishPlaceholder]
	TestRunner.assertFalse(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertTrue(finish:GetAttribute("RequiredCheckpointOrder") == nil)
	for _, descendant in scene:GetDescendants() do TestRunner.assertFalse(descendant:GetAttribute("CheckpointOrder") == 4) end
end)

TestRunner.test("PalmFinish contains no scripts SpawnLocations or runtime containers", function()
	for _, descendant in scene:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		TestRunner.assertFalse(descendant:IsA("SpawnLocation"))
		TestRunner.assertFalse(descendant:IsA("RemoteEvent"))
		TestRunner.assertFalse(descendant:IsA("RemoteFunction"))
		TestRunner.assertFalse(descendant:IsA("BindableEvent"))
		TestRunner.assertFalse(descendant:IsA("BindableFunction"))
	end
end)

TestRunner.test("PalmFinish contains no constraints movers MeshParts or unions and all Parts are anchored", function()
	for _, descendant in scene:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("Constraint"))
		TestRunner.assertFalse(descendant:IsA("BodyMover"))
		TestRunner.assertFalse(descendant:IsA("LinearVelocity"))
		TestRunner.assertFalse(descendant:IsA("AngularVelocity"))
		TestRunner.assertFalse(descendant:IsA("VectorForce"))
		TestRunner.assertFalse(descendant:IsA("AlignPosition"))
		TestRunner.assertFalse(descendant:IsA("AlignOrientation"))
		TestRunner.assertFalse(descendant:IsA("MeshPart"))
		TestRunner.assertFalse(descendant:IsA("UnionOperation"))
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant.Anchored) end
	end
end)

TestRunner.test("PalmFinish retains the accepted Scene01 Scene02 and Scene03 anchors", function()
	assertVectorClose(scene01.Geometry.SceneFootprint.Position, Vector3.new(111, 0.5, -22))
	assertVectorClose(scene02.Geometry.SceneFootprint.Position, Vector3.new(111, 0.5, -107))
	assertVectorClose(scene03.Geometry[WorldConfig.LaserIsland.IslandBase].Position, Vector3.new(111, 1.5, -184))
end)

TestRunner.test("PalmFinish retains the Scene03 laser pivot coins and PalmBase boundary", function()
	local assembly = scene03.Hazards[WorldConfig.LaserIsland.LaserAssembly] :: Model
	local center = scene03.Geometry[WorldConfig.LaserIsland.CenterSphere] :: BasePart
	TestRunner.assertTrue((assembly:GetPivot().Position - center.Position).Magnitude <= POSITION_TOLERANCE)
	TestRunner.assertEqual(countTaggedUnder(scene03, RunConfig.Tags.Hazard), 1)
	TestRunner.assertTrue(CollectionService:HasTag(assembly[WorldConfig.LaserIsland.LaserBar], RunConfig.Tags.Hazard))
	TestRunner.assertEqual(#scene03.Coins:GetChildren(), 5)
	for _, marker in scene03.Coins:GetChildren() do assertNoTagsOrAttributes(marker) end
	local checkpoint = scene03.Triggers[WorldConfig.LaserIsland.PalmBaseCheckpointMarker]
	assertNoTagsOrAttributes(checkpoint)
	TestRunner.assertFalse((checkpoint :: BasePart).CanTouch)
end)

TestRunner.test("PalmFinish retains Baseplate and deep-water core geometry", function()
	assertVectorClose(workspace.Baseplate.Position, Vector3.new(0, -14, 0))
	assertVectorClose(workspace.Baseplate.Size, Vector3.new(2048, 16, 2048))
	local water = scene02.Geometry[WorldConfig.Water.WaterSurface] :: BasePart
	local kill = scene02.Hazards[WorldConfig.Water.WaterKillPlane] :: BasePart
	assertVectorClose(water.Position, Vector3.new(111, -2.3, -107))
	assertVectorClose(water.Size, Vector3.new(32, 6.8, 56))
	assertVectorClose(kill.Position, Vector3.new(111, -5.3, -107))
	assertVectorClose(kill.Size, Vector3.new(40, 0.3, 56))
end)

TestRunner.test("PalmFinish retains the short bridge and legacy VerticalSlice active paths", function()
	local bridge = beachObby.TemporaryAccess.SpawnBridge
	assertExactChildren(bridge, { BridgeSegment01 = "Part", BridgeSegment02 = "Part", BridgeSegment03 = "Part" })
	TestRunner.assertTrue(math.abs(bridge.BridgeSegment01.Size.Z - 99.397865) <= POSITION_TOLERANCE)
	for _, descendant in { bridge, table.unpack(bridge:GetDescendants()) } do assertNoTagsOrAttributes(descendant) end
	local expectedPaths = {
		[RunConfig.Tags.Coin] = { "Workspace.BeachObby.VerticalSlice.Coins.DemoCoin" },
		[RunConfig.Tags.Finish] = { "Workspace.BeachObby.VerticalSlice.Triggers.FinishLine" },
		[RunConfig.Tags.RunStart] = { "Workspace.BeachObby.VerticalSlice.Triggers.StartLine" },
		[RunConfig.Tags.Checkpoint] = {
			"Workspace.BeachObby.VerticalSlice.StartSpawn",
			"Workspace.BeachObby.VerticalSlice.Triggers.MidCheckpoint",
		},
	}
	for tag, expected in expectedPaths do
		local actual = {}
		for _, tagged in CollectionService:GetTagged(tag) do table.insert(actual, tagged:GetFullName()) end
		table.sort(actual)
		table.sort(expected)
		TestRunner.assertEqual(#actual, #expected)
		for index, path in expected do TestRunner.assertEqual(actual[index], path) end
	end
end)

TestRunner.test("PalmFinish preserves scene connection boundaries and World VerticalSlice separation", function()
	local connections = {
		{ scene01.Geometry.EndPlatform, scene02.Geometry.EntryPlatform },
		{ scene02.Geometry.ExitPlatform, scene03.Geometry.EntryPlatform },
		{ scene03.Geometry.ExitPlatform, scene.Geometry[palmConfig.EntryPlatform] },
	}
	for _, pair in connections do
		local first = getAabb(pair[1] :: BasePart)
		local second = getAabb(pair[2] :: BasePart)
		TestRunner.assertTrue(xzOverlap(first, second))
		TestRunner.assertTrue(math.abs(first.max.Y - second.max.Y) <= POSITION_TOLERANCE)
	end
	TestRunner.assertTrue(horizontalGap(instanceAabb(world), instanceAabb(beachObby.VerticalSlice)) >= 60)
end)

TestRunner.test("PalmFinish produces the approved Phase 2.7 Hazard counts", function()
	TestRunner.assertEqual(countTaggedUnder(scene01, RunConfig.Tags.Hazard), 4)
	TestRunner.assertEqual(countTaggedUnder(scene02, RunConfig.Tags.Hazard), 3)
	TestRunner.assertEqual(countTaggedUnder(scene03, RunConfig.Tags.Hazard), 1)
	TestRunner.assertEqual(countTaggedUnder(scene, RunConfig.Tags.Hazard), 1)
	TestRunner.assertEqual(countTaggedUnder(world, RunConfig.Tags.Hazard), 9)
	TestRunner.assertEqual(countTaggedUnder(beachObby, RunConfig.Tags.Hazard), 10)
end)

return true
