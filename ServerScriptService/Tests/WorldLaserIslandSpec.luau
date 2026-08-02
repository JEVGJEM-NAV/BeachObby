--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local TestRunner = require(script.Parent.TestRunner)

local beachObby = workspace:WaitForChild(WorldConfig.Root.BeachObby)
local world = beachObby:WaitForChild(WorldConfig.Root.World)
local scene = world:WaitForChild(WorldConfig.Scenes.LaserIsland)
local scene02 = world:WaitForChild(WorldConfig.Scenes.Water)
local scene04 = world:WaitForChild(WorldConfig.Scenes.PalmFinish)
local environment = world:WaitForChild(WorldConfig.Root.Environment)

type Bounds = { min: Vector3, max: Vector3 }

local function expectChild(parent: Instance, name: string, className: string): Instance
	local child = parent:FindFirstChild(name)
	TestRunner.assertTrue(child ~= nil, parent:GetFullName() .. " is missing " .. name)
	TestRunner.assertTrue((child :: Instance):IsA(className), (child :: Instance):GetFullName() .. " must be " .. className)
	return child :: Instance
end

local function assertVectorClose(actual: Vector3, expected: Vector3, tolerance: number?)
	TestRunner.assertTrue((actual - expected).Magnitude <= (tolerance or 0.001), string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
end

local function assertCFrameClose(actual: CFrame, expected: CFrame, tolerance: number?)
	local allowed = tolerance or 0.001
	assertVectorClose(actual.Position, expected.Position, allowed)
	TestRunner.assertTrue(actual.RightVector:Dot(expected.RightVector) >= 1 - allowed)
	TestRunner.assertTrue(actual.UpVector:Dot(expected.UpVector) >= 1 - allowed)
	TestRunner.assertTrue(actual.LookVector:Dot(expected.LookVector) >= 1 - allowed)
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

local function modelAabb(model: Model): Bounds
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, descendant in model:GetDescendants() do
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

local function countHazards(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then count += 1 end
	end
	return count
end

local function assertPassive(part: BasePart)
	TestRunner.assertTrue(part.Anchored)
	TestRunner.assertFalse(part.CanCollide)
	TestRunner.assertFalse(part.CanTouch)
	TestRunner.assertFalse(part.CanQuery)
	TestRunner.assertEqual(#CollectionService:GetTags(part), 0)
	TestRunner.assertEqual(next(part:GetAttributes()), nil)
end

TestRunner.test("LaserIsland has the exact Phase 2.6 hierarchy", function()
	TestRunner.assertTrue(scene:IsA("Model"))
	local geometry = expectChild(scene, "Geometry", "Folder")
	local hazards = expectChild(scene, "Hazards", "Folder")
	local coins = expectChild(scene, "Coins", "Folder")
	local triggers = expectChild(scene, "Triggers", "Folder")
	TestRunner.assertEqual(#geometry:GetChildren(), 4)
	TestRunner.assertEqual(#hazards:GetChildren(), 1)
	TestRunner.assertEqual(#coins:GetChildren(), 5)
	TestRunner.assertEqual(#triggers:GetChildren(), 1)
	TestRunner.assertTrue(geometry:FindFirstChild("IslandFootprint") == nil)
end)

TestRunner.test("LaserIsland hierarchy has unique immediate child names", function()
	for _, parent in { scene, table.unpack(scene:GetDescendants()) } do
		local seen: { [string]: boolean } = {}
		for _, child in parent:GetChildren() do
			TestRunner.assertFalse(seen[child.Name] == true, parent:GetFullName() .. " has duplicate child " .. child.Name)
			seen[child.Name] = true
		end
	end
end)

TestRunner.test("LaserIsland IslandBase has the approved cylinder geometry", function()
	local island = expectChild(scene.Geometry, WorldConfig.LaserIsland.IslandBase, "Part") :: Part
	TestRunner.assertEqual(island.Shape, Enum.PartType.Cylinder)
	assertVectorClose(island.Position, Vector3.new(111, 1.5, -184))
	assertVectorClose(island.Size, Vector3.new(1, 64, 64))
	local bounds = getAabb(island)
	TestRunner.assertTrue(math.abs(bounds.max.Y - 2) <= 0.001)
	TestRunner.assertTrue(math.abs(bounds.max.X - bounds.min.X - 64) <= 0.001)
	TestRunner.assertTrue(math.abs(bounds.max.Z - bounds.min.Z - 64) <= 0.001)
	TestRunner.assertTrue(island.Anchored and island.CanCollide and island.CanQuery)
	TestRunner.assertFalse(island.CanTouch)
	TestRunner.assertEqual(#CollectionService:GetTags(island), 0)
	TestRunner.assertEqual(next(island:GetAttributes()), nil)
end)

TestRunner.test("LaserIsland CenterSphere has the approved passive hub geometry", function()
	local center = expectChild(scene.Geometry, WorldConfig.LaserIsland.CenterSphere, "Part") :: Part
	TestRunner.assertEqual(center.Shape, Enum.PartType.Ball)
	assertVectorClose(center.Position, Vector3.new(111, 3.25, -184))
	assertVectorClose(center.Size, Vector3.new(5, 5, 5))
	TestRunner.assertTrue(center.Anchored and center.CanCollide and center.CanQuery)
	TestRunner.assertFalse(center.CanTouch)
	TestRunner.assertEqual(#CollectionService:GetTags(center), 0)
	TestRunner.assertEqual(next(center:GetAttributes()), nil)
end)

TestRunner.test("LaserIsland Entry and Exit retain accepted geometry", function()
	local entry = scene.Geometry.EntryPlatform :: BasePart
	local exit = scene.Geometry.ExitPlatform :: BasePart
	assertCFrameClose(entry.CFrame, CFrame.new(111, 1.55, -156))
	assertVectorClose(entry.Size, Vector3.new(16, 1, 16))
	assertCFrameClose(exit.CFrame, CFrame.new(139, 1.55, -184))
	assertVectorClose(exit.Size, Vector3.new(16, 1, 16))
end)

TestRunner.test("LaserIsland connects Scene02 Entry Island Exit and Scene04", function()
	local scene02Exit = scene02.Geometry.ExitPlatform :: BasePart
	local entry = scene.Geometry.EntryPlatform :: BasePart
	local island = scene.Geometry.IslandBase :: BasePart
	local exit = scene.Geometry.ExitPlatform :: BasePart
	local scene04Entry = scene04.Geometry.EntryPlatform :: BasePart
	for _, pair in {
		{ scene02Exit, entry },
		{ entry, island },
		{ island, exit },
		{ exit, scene04Entry },
	} do
		TestRunner.assertTrue(xzOverlap(getAabb(pair[1]), getAabb(pair[2])))
	end
	TestRunner.assertTrue(math.abs(getAabb(scene02Exit).max.Y - 2) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(entry).max.Y - 2.05) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(island).max.Y - 2) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(exit).max.Y - 2.05) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(scene04Entry).max.Y - 2) <= 0.001)
end)

TestRunner.test("LaserIsland contains one assembly with one continuous LaserBar", function()
	local assembly = expectChild(scene.Hazards, WorldConfig.LaserIsland.LaserAssembly, "Model") :: Model
	TestRunner.assertEqual(#assembly:GetChildren(), 1)
	local bar = expectChild(assembly, WorldConfig.LaserIsland.LaserBar, "Part") :: Part
	TestRunner.assertEqual(bar.Shape, Enum.PartType.Block)
	assertVectorClose(bar.Size, Vector3.new(60, 1.5, 2.5))
	assertVectorClose(bar.Position, Vector3.new(111, 3.25, -184), 0.01)
	TestRunner.assertEqual(bar.Material, Enum.Material.Neon)
end)

TestRunner.test("LaserIsland LaserAssembly uses the external CenterSphere pivot", function()
	local center = scene.Geometry.CenterSphere :: BasePart
	local assembly = scene.Hazards.LaserAssembly :: Model
	assertVectorClose(assembly:GetPivot().Position, center.Position, 0.001)
	TestRunner.assertFalse(center:IsDescendantOf(assembly))
	TestRunner.assertEqual(center.Parent, scene.Geometry)
end)

TestRunner.test("LaserIsland one bar forms symmetric opposite arms inside the island", function()
	local center = scene.Geometry.CenterSphere :: BasePart
	local bar = scene.Hazards.LaserAssembly.LaserBar :: BasePart
	local first = bar.CFrame:PointToWorldSpace(Vector3.new(bar.Size.X / 2, 0, 0))
	local second = bar.CFrame:PointToWorldSpace(Vector3.new(-bar.Size.X / 2, 0, 0))
	local firstOffset = first - center.Position
	local secondOffset = second - center.Position
	assertVectorClose((first + second) / 2, center.Position, 0.001)
	TestRunner.assertTrue(firstOffset.Unit:Dot(secondOffset.Unit) < -0.99999)
	TestRunner.assertTrue(math.abs(firstOffset.Magnitude - 30) <= 0.001)
	TestRunner.assertTrue(math.abs(secondOffset.Magnitude - 30) <= 0.001)
	TestRunner.assertTrue(firstOffset.Magnitude + bar.Size.Z / 2 < 32)
end)

TestRunner.test("LaserIsland LaserBar has the universal non-pushing Hazard contract", function()
	local bar = scene.Hazards.LaserAssembly.LaserBar :: BasePart
	TestRunner.assertTrue(bar.Anchored)
	TestRunner.assertFalse(bar.CanCollide)
	TestRunner.assertTrue(bar.CanTouch)
	TestRunner.assertTrue(bar.CanQuery)
	TestRunner.assertFalse(bar.CastShadow)
	local tags = CollectionService:GetTags(bar)
	TestRunner.assertEqual(#tags, 1)
	TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
	TestRunner.assertEqual(next(bar:GetAttributes()), nil)
end)

TestRunner.test("LaserIsland only LaserBar is Hazard-tagged", function()
	local laserBar = scene.Hazards.LaserAssembly.LaserBar
	local hazardCount = 0
	for _, descendant in scene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then
			hazardCount += 1
			TestRunner.assertEqual(descendant, laserBar)
		end
	end
	TestRunner.assertEqual(hazardCount, 1)
	local tags = CollectionService:GetTags(laserBar)
	TestRunner.assertEqual(#tags, 1)
	TestRunner.assertEqual(tags[1], RunConfig.Tags.Hazard)
end)

TestRunner.test("LaserIsland bar height and landing zones retain safe traversal margins", function()
	local islandTop = getAabb(scene.Geometry.IslandBase).max.Y
	local barBounds = getAabb(scene.Hazards.LaserAssembly.LaserBar)
	TestRunner.assertTrue(barBounds.min.Y >= islandTop + 0.49)
	TestRunner.assertTrue(barBounds.max.Y <= islandTop + 2.01)
	local radius = scene.Hazards.LaserAssembly.LaserBar.Size.X / 2
	TestRunner.assertTrue(36 - radius >= 6)
end)

TestRunner.test("LaserIsland has five unique active coins", function()
	local seen: { [string]: boolean } = {}
	local expectedPositions = {
		Vector3.new(111, 5, -162),
		Vector3.new(90, 5, -177),
		Vector3.new(98, 5, -202),
		Vector3.new(124, 5, -202),
		Vector3.new(132, 5, -177),
	}
	TestRunner.assertEqual(#scene.Coins:GetChildren(), 5)
	for index, name in WorldConfig.LaserIsland.CoinIds do
		local coin = expectChild(scene.Coins, name, "Part") :: Part
		TestRunner.assertFalse(seen[name] == true)
		seen[name] = true
		TestRunner.assertEqual(coin.Shape, Enum.PartType.Ball)
		assertVectorClose(coin.Size, Vector3.new(1.5, 1.5, 1.5))
		assertVectorClose(coin.Position, expectedPositions[index])
		TestRunner.assertTrue(coin.Anchored and coin.CanTouch and coin.CanQuery)
		TestRunner.assertFalse(coin.CanCollide)
		TestRunner.assertTrue(CollectionService:HasTag(coin, RunConfig.Tags.Coin))
		TestRunner.assertEqual(#CollectionService:GetTags(coin), 1)
		TestRunner.assertEqual(coin:GetAttribute(RunConfig.Attributes.CoinId), name)
	end
end)

TestRunner.test("LaserIsland PalmBaseCheckpoint has the final active contract", function()
	local checkpoint = expectChild(scene.Triggers, WorldConfig.LaserIsland.PalmBaseCheckpoint, "Part") :: BasePart
	assertVectorClose(checkpoint.Position, Vector3.new(151, 2.3, -184))
	assertVectorClose(checkpoint.Size, Vector3.new(4, 0.4, 12))
	TestRunner.assertTrue(checkpoint.Anchored and checkpoint.CanTouch and checkpoint.CanQuery)
	TestRunner.assertFalse(checkpoint.CanCollide)
	TestRunner.assertTrue(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(#CollectionService:GetTags(checkpoint), 1)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId), "PalmBase")
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), 4)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))
	TestRunner.assertTrue(xzOverlap(getAabb(checkpoint), getAabb(scene04.Geometry.EntryPlatform)))
end)

TestRunner.test("LaserIsland contains no scripts attributes constraints or movers", function()
	for _, descendant in scene:GetDescendants() do
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
		TestRunner.assertFalse(descendant:IsA("Constraint"))
		TestRunner.assertFalse(descendant:IsA("BodyMover"))
		if not CollectionService:HasTag(descendant, RunConfig.Tags.Coin)
			and not CollectionService:HasTag(descendant, RunConfig.Tags.Checkpoint) then
			TestRunner.assertEqual(next(descendant:GetAttributes()), nil)
		end
		if descendant:IsA("BasePart") then TestRunner.assertTrue(descendant.Anchored) end
	end
end)

TestRunner.test("LaserIsland stays clear of water rings and sharks", function()
	local islandBounds = getAabb(scene.Geometry.IslandBase)
	TestRunner.assertFalse(aabbsIntersect(islandBounds, getAabb(scene02.Geometry.WaterSurface)))
	TestRunner.assertFalse(aabbsIntersect(islandBounds, getAabb(environment[WorldConfig.Environment.OceanKill])))
	for _, ring in scene02.Geometry.Rings:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(islandBounds, modelAabb(ring :: Model)))
	end
	for _, shark in scene02.Hazards.Sharks:GetChildren() do
		TestRunner.assertFalse(aabbsIntersect(islandBounds, modelAabb(shark :: Model)))
	end
end)

TestRunner.test("LaserIsland belongs to the sole World release root without legacy shells", function()
	TestRunner.assertTrue(scene:IsDescendantOf(world))
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:GetChildren()[1], world)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("KillBlock", true) == nil)
end)

TestRunner.test("LaserIsland preserves Baseplate and the release hierarchy", function()
	assertVectorClose(workspace.Baseplate.Position, Vector3.new(0, -14, 0))
	assertVectorClose(workspace.Baseplate.Size, Vector3.new(2048, 16, 2048))
	TestRunner.assertEqual(workspace.Baseplate.Position.Y + workspace.Baseplate.Size.Y / 2, -6)
	TestRunner.assertFalse(workspace.Baseplate.CanCollide)
	TestRunner.assertFalse(workspace.Baseplate.CanTouch)
	TestRunner.assertTrue(workspace.Baseplate.CanQuery)
	TestRunner.assertEqual(workspace.Baseplate.Transparency, 1)
	TestRunner.assertFalse(workspace.Baseplate.CastShadow)
	local baseplateChildren = workspace.Baseplate:GetChildren()
	TestRunner.assertEqual(#baseplateChildren, 1)
	local texture = baseplateChildren[1]
	TestRunner.assertTrue(texture:IsA("Texture"))
	TestRunner.assertEqual(texture.Name, "Texture")
	TestRunner.assertEqual((texture :: Texture).Texture, "rbxassetid://6372755229")
	TestRunner.assertEqual((texture :: Texture).Face, Enum.NormalId.Top)
	TestRunner.assertEqual((texture :: Texture).StudsPerTileU, 8)
	TestRunner.assertEqual((texture :: Texture).StudsPerTileV, 8)
	TestRunner.assertEqual((texture :: Texture).Color3, Color3.new(0, 0, 0))
	TestRunner.assertTrue(math.abs((texture :: Texture).Transparency - 0.8) <= 0.001)
	TestRunner.assertTrue(beachObby:FindFirstChild("TemporaryAccess") == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("SpawnBridge", true) == nil)
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:FindFirstChild(WorldConfig.Root.World), world)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("KillBlock", true) == nil)
	local expectedWorldChildren = {
		[WorldConfig.Root.Environment] = "Folder",
		[WorldConfig.Scenes.HotBeach] = "Model",
		[WorldConfig.Scenes.Water] = "Model",
		[WorldConfig.Scenes.LaserIsland] = "Model",
		[WorldConfig.Scenes.PalmFinish] = "Model",
		SharedEnvironment = "Model",
	}
	TestRunner.assertEqual(#world:GetChildren(), 6)
	for _, child in world:GetChildren() do
		local expectedClass = expectedWorldChildren[child.Name]
		TestRunner.assertTrue(expectedClass ~= nil)
		TestRunner.assertTrue(child:IsA(expectedClass))
	end
end)

TestRunner.test("LaserIsland preserves deep water and shark timing contracts", function()
	local water = scene02.Geometry.WaterSurface :: BasePart
	local kill = environment[WorldConfig.Environment.OceanKill] :: BasePart
	assertVectorClose(water.Position, Vector3.new(111, -2.85, -107))
	assertVectorClose(water.Size, Vector3.new(32, 5.7, 56))
	TestRunner.assertTrue(math.abs(water.Position.Y + water.Size.Y / 2) <= 0.001)
	assertVectorClose(kill.Position, Vector3.new(111, -1, -107))
	assertVectorClose(kill.Size, Vector3.new(512, 0.5, 512))
	TestRunner.assertEqual(WorldConfig.MovingHazards.Sharks[1].PhaseOffset, 0.1)
	TestRunner.assertEqual(WorldConfig.MovingHazards.Sharks[2].PhaseOffset, 0.35)
	for _, entry in WorldConfig.MovingHazards.Sharks do TestRunner.assertEqual(entry.OneWayDurationSeconds, 6) end
end)

TestRunner.test("LaserIsland produces the approved Hazard counts", function()
	TestRunner.assertEqual(countHazards(world.Scene01_HotBeach), 4)
	TestRunner.assertEqual(countHazards(scene02), 2)
	TestRunner.assertEqual(countHazards(scene), 1)
	TestRunner.assertEqual(countHazards(scene04), 2)
	TestRunner.assertEqual(countHazards(world), 10)
	TestRunner.assertEqual(countHazards(beachObby), 10)
end)

TestRunner.test("LaserIsland accepts final Palm geometry and progression", function()
	expectChild(scene04.Geometry, WorldConfig.PalmFinish.PalmTree, "Model")
	expectChild(scene04.Geometry, WorldConfig.PalmFinish.Spiral.FolderName, "Folder")
	expectChild(scene04.Geometry, WorldConfig.PalmFinish.SummitPlatform, "Part")
	expectChild(scene04.Geometry, WorldConfig.PalmFinish.HotSandIsland, "Part")
	expectChild(scene04.Geometry, WorldConfig.PalmFinish.HotSandTint, "Part")
	expectChild(scene04.Hazards, WorldConfig.PalmFinish.PalmFallCatch, "Part")
	expectChild(scene04.Hazards, WorldConfig.PalmFinish.PalmUpperFallCatch, "Part")
	for _, name in WorldConfig.PalmFinish.CoinIds do
		local coin = expectChild(scene04.Coins, name, "Part")
		TestRunner.assertTrue(CollectionService:HasTag(coin, RunConfig.Tags.Coin))
		TestRunner.assertEqual(coin:GetAttribute(RunConfig.Attributes.CoinId), name)
	end
	local finish = expectChild(scene04.Triggers, WorldConfig.PalmFinish.FinishLine, "Part")
	TestRunner.assertTrue(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertEqual(finish:GetAttribute(RunConfig.Attributes.RequiredCheckpointOrder), 4)
	for _, coin in scene.Coins:GetChildren() do
		TestRunner.assertTrue(CollectionService:HasTag(coin, RunConfig.Tags.Coin))
	end
	local checkpoint = scene.Triggers.PalmBaseCheckpoint
	TestRunner.assertTrue(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId), "PalmBase")
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), 4)
	TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))
end)

TestRunner.test("LaserIsland visible route transitions have separated top faces", function()
	local scene02Exit = scene02.Geometry.ExitPlatform :: BasePart
	local entry = scene.Geometry.EntryPlatform :: BasePart
	local island = scene.Geometry.IslandBase :: BasePart
	local exit = scene.Geometry.ExitPlatform :: BasePart
	local scene04Entry = scene04.Geometry.EntryPlatform :: BasePart

	assertCFrameClose(entry.CFrame, CFrame.new(111, 1.55, -156))
	assertCFrameClose(exit.CFrame, CFrame.new(139, 1.55, -184))

	local transitionPairs = {
		{ scene02Exit, entry },
		{ entry, island },
		{ exit, island },
		{ exit, scene04Entry },
	}
	for _, pair in transitionPairs do
		local first = pair[1] :: BasePart
		local second = pair[2] :: BasePart
		local firstBounds = getAabb(first)
		local secondBounds = getAabb(second)
		local overlapX = math.min(firstBounds.max.X, secondBounds.max.X) - math.max(firstBounds.min.X, secondBounds.min.X)
		local overlapZ = math.min(firstBounds.max.Z, secondBounds.max.Z) - math.max(firstBounds.min.Z, secondBounds.min.Z)
		local separation = math.abs(firstBounds.max.Y - secondBounds.max.Y)
		TestRunner.assertTrue(overlapX > 0 and overlapZ > 0)
		TestRunner.assertEqual(first.Transparency, 0)
		TestRunner.assertEqual(second.Transparency, 0)
		TestRunner.assertTrue(first.CanCollide and second.CanCollide)
		TestRunner.assertTrue(separation > 0.01)
		TestRunner.assertTrue(math.abs(separation - 0.05) <= 0.001)
	end
end)

TestRunner.test("LaserIsland and HotSandIsland overlap without coplanar visible faces", function()
	local island = scene.Geometry[WorldConfig.LaserIsland.IslandBase] :: Part
	local hotSand = scene04.Geometry[WorldConfig.PalmFinish.HotSandIsland] :: Part
	local tint = scene04.Geometry[WorldConfig.PalmFinish.HotSandTint] :: Part
	local catch = scene04.Hazards[WorldConfig.PalmFinish.PalmFallCatch] :: BasePart
	local islandBounds = getAabb(island)
	local sandBounds = getAabb(hotSand)
	local islandCenter = Vector2.new(island.Position.X, island.Position.Z)
	local sandCenter = Vector2.new(hotSand.Position.X, hotSand.Position.Z)
	local islandRadius = island.Size.Y / 2
	local sandRadius = hotSand.Size.Y / 2
	local centerDistance = (sandCenter - islandCenter).Magnitude
	local overlapDepth = islandRadius + sandRadius - centerDistance
	TestRunner.assertEqual(island.Shape, Enum.PartType.Cylinder)
	TestRunner.assertEqual(hotSand.Shape, Enum.PartType.Cylinder)
	TestRunner.assertTrue(math.abs(islandRadius - 32) <= 0.001)
	TestRunner.assertTrue(math.abs(sandRadius - 38) <= 0.001)
	TestRunner.assertTrue(math.abs(centerDistance - 53) <= 0.001)
	TestRunner.assertTrue(math.abs(overlapDepth - 17) <= 0.001)
	TestRunner.assertTrue(xzOverlap(islandBounds, sandBounds))
	local topSeparation = math.abs(islandBounds.max.Y - sandBounds.max.Y)
	TestRunner.assertTrue(math.abs(topSeparation - 0.1) <= 0.001)
	TestRunner.assertTrue(topSeparation > 0.01)
	TestRunner.assertTrue(xzOverlap(getAabb(scene.Geometry.ExitPlatform), getAabb(scene04.Geometry.EntryPlatform)))
	TestRunner.assertTrue((scene.Geometry.ExitPlatform :: BasePart).CanCollide)
	TestRunner.assertTrue((scene04.Geometry.EntryPlatform :: BasePart).CanCollide)
	TestRunner.assertFalse(hotSand.CanCollide)
	TestRunner.assertFalse(hotSand.CanTouch)
	TestRunner.assertFalse(hotSand.CanQuery)
	TestRunner.assertEqual(#CollectionService:GetTags(hotSand), 0)
	assertCFrameClose(tint.CFrame, CFrame.new(164, 1.92, -184) * CFrame.Angles(0, 0, math.rad(90)))
	assertVectorClose(tint.Size, Vector3.new(0.06, 76, 76))
	TestRunner.assertEqual(tint.Material, Enum.Material.Neon)
	TestRunner.assertEqual(tint.Color, Color3.fromRGB(235, 92, 42))
	TestRunner.assertTrue(math.abs(tint.Transparency - 0.65) <= 0.001)
	assertPassive(tint)
	local tintTop = getAabb(tint).max.Y
	TestRunner.assertTrue(math.abs(tintTop - 1.95) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(scene.Geometry.ExitPlatform).max.Y - tintTop - 0.1) <= 0.001)
	TestRunner.assertTrue(math.abs(getAabb(scene04.Geometry.EntryPlatform).max.Y - tintTop - 0.05) <= 0.001)
	TestRunner.assertTrue(catch.CanCollide and catch.CanTouch)
	TestRunner.assertFalse(aabbsIntersect(getAabb(catch), getAabb(scene.Geometry.ExitPlatform)))
	TestRunner.assertFalse(aabbsIntersect(getAabb(catch), getAabb(scene04.Geometry.EntryPlatform)))
end)

TestRunner.test("LaserIsland and World remain inside Baseplate", function()
	local baseBounds = getAabb(workspace.Baseplate)
	for _, sceneModel in world:GetChildren() do
		if sceneModel:IsA("Model") then
			local bounds = modelAabb(sceneModel)
			TestRunner.assertTrue(bounds.min.X >= baseBounds.min.X and bounds.max.X <= baseBounds.max.X)
			TestRunner.assertTrue(bounds.min.Z >= baseBounds.min.Z and bounds.max.Z <= baseBounds.max.Z)
		end
	end
end)

return true
