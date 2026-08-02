--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local TestRunner = require(script.Parent.TestRunner)

local beachObby = Workspace:WaitForChild(WorldConfig.Root.BeachObby)
local world = beachObby:WaitForChild(WorldConfig.Root.World)
local environment = world:WaitForChild(WorldConfig.Root.Environment)

local gameplayTags = {
	RunConfig.Tags.RunStart,
	RunConfig.Tags.Checkpoint,
	RunConfig.Tags.Coin,
	RunConfig.Tags.Finish,
	RunConfig.Tags.Hazard,
}

local function resolveCheckpoint(definition: any): BasePart
	local scene = world:FindFirstChild(definition.Scene)
	TestRunner.assertTrue(scene ~= nil and scene:IsA("Model"))
	local container = (scene :: Model):FindFirstChild(definition.Folder)
	TestRunner.assertTrue(container ~= nil and container:IsA("Folder"))
	local checkpoint = (container :: Folder):FindFirstChild(definition.Name)
	TestRunner.assertTrue(checkpoint ~= nil and checkpoint:IsA("BasePart"))
	return checkpoint :: BasePart
end

local function assertSoleTag(instance: Instance, expectedTag: string)
	local tags = CollectionService:GetTags(instance)
	TestRunner.assertEqual(#tags, 1, instance:GetFullName() .. " must have exactly one tag")
	TestRunner.assertEqual(tags[1], expectedTag)
end

local function assertNoAttributes(instance: Instance)
	local count = 0
	for _ in instance:GetAttributes() do count += 1 end
	TestRunner.assertEqual(count, 0, instance:GetFullName() .. " must have no attributes")
end

local function collectConfiguredCoins(): { { id: string, instance: BasePart } }
	local result: { { id: string, instance: BasePart } } = {}
	local sceneContracts = {
		{ scene = WorldConfig.Scenes.HotBeach, ids = WorldConfig.HotBeach.CoinIds },
		{ scene = WorldConfig.Scenes.Water, ids = WorldConfig.Water.CoinIds },
		{ scene = WorldConfig.Scenes.LaserIsland, ids = WorldConfig.LaserIsland.CoinIds },
		{ scene = WorldConfig.Scenes.PalmFinish, ids = WorldConfig.PalmFinish.CoinIds },
	}

	for _, contract in sceneContracts do
		local scene = world:FindFirstChild(contract.scene)
		TestRunner.assertTrue(scene ~= nil and scene:IsA("Model"))
		for _, coinId in contract.ids do
			local folderName = if coinId == "DemoCoin" then WorldConfig.CommonFolders.Start else WorldConfig.CommonFolders.Coins
			local container = (scene :: Model):FindFirstChild(folderName)
			TestRunner.assertTrue(container ~= nil and container:IsA("Folder"))
			local coin = (container :: Folder):FindFirstChild(coinId)
			TestRunner.assertTrue(coin ~= nil and coin:IsA("BasePart"), coinId .. " must resolve")
			table.insert(result, { id = coinId, instance = coin :: BasePart })
		end
	end

	return result
end

local function getAabb(container: Instance): (Vector3, Vector3)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local partCount = 0

	for _, descendant in container:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
			local half = descendant.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local point = descendant.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						minimum = Vector3.new(
							math.min(minimum.X, point.X),
							math.min(minimum.Y, point.Y),
							math.min(minimum.Z, point.Z)
						)
						maximum = Vector3.new(
							math.max(maximum.X, point.X),
							math.max(maximum.Y, point.Y),
							math.max(maximum.Z, point.Z)
						)
					end
				end
			end
		end
	end

	TestRunner.assertTrue(partCount > 0, container:GetFullName() .. " must contain a BasePart")
	return minimum, maximum
end

local function partAabb(part: BasePart): (Vector3, Vector3)
	local minimum = Vector3.new(math.huge, math.huge, math.huge)
	local maximum = Vector3.new(-math.huge, -math.huge, -math.huge)
	local half = part.Size / 2
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local point = part.CFrame:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
				minimum = Vector3.new(math.min(minimum.X, point.X), math.min(minimum.Y, point.Y), math.min(minimum.Z, point.Z))
				maximum = Vector3.new(math.max(maximum.X, point.X), math.max(maximum.Y, point.Y), math.max(maximum.Z, point.Z))
			end
		end
	end
	return minimum, maximum
end

TestRunner.test("World progression has exact global active tag counts", function()
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.RunStart), 1)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Checkpoint), 4)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Coin), 16)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Finish), 1)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Hazard), 10)
	local palmScene = world[WorldConfig.Scenes.PalmFinish]
	local expectedHazards = {
		[WorldConfig.PalmFinish.PalmFallCatch] = true,
		[WorldConfig.PalmFinish.PalmUpperFallCatch] = true,
	}
	local seen = 0
	for _, child in palmScene.Hazards:GetChildren() do
		seen += 1
		TestRunner.assertTrue(expectedHazards[child.Name] == true)
		TestRunner.assertTrue(child:IsA("Part"))
		assertSoleTag(child, RunConfig.Tags.Hazard)
		assertNoAttributes(child)
	end
	TestRunner.assertEqual(seen, 2)
	local hotSand = palmScene.Geometry[WorldConfig.PalmFinish.HotSandIsland] :: BasePart
	local hotSandTint = palmScene.Geometry[WorldConfig.PalmFinish.HotSandTint] :: BasePart
	local palmFallCatch = palmScene.Hazards[WorldConfig.PalmFinish.PalmFallCatch] :: BasePart
	TestRunner.assertTrue(hotSandTint:IsA("Part"))
	TestRunner.assertEqual(hotSandTint.CFrame, CFrame.new(164, 1.92, -184) * CFrame.Angles(0, 0, math.rad(90)))
	TestRunner.assertEqual(hotSandTint.Size, Vector3.new(0.06, 76, 76))
	TestRunner.assertEqual(hotSandTint.Material, Enum.Material.Neon)
	TestRunner.assertEqual(hotSandTint.Color, Color3.fromRGB(235, 92, 42))
	TestRunner.assertTrue(math.abs(hotSandTint.Transparency - 0.65) <= 0.001)
	TestRunner.assertFalse(hotSand.CanCollide)
	TestRunner.assertFalse(hotSandTint.CanCollide)
	TestRunner.assertFalse(hotSandTint.CanTouch)
	TestRunner.assertFalse(hotSandTint.CanQuery)
	TestRunner.assertEqual(#CollectionService:GetTags(hotSandTint), 0)
	assertNoAttributes(hotSandTint)
	TestRunner.assertEqual(#hotSandTint:GetChildren(), 0)
	TestRunner.assertTrue(palmFallCatch.CanCollide and palmFallCatch.CanTouch and palmFallCatch.CanQuery)
	assertSoleTag(palmFallCatch, RunConfig.Tags.Hazard)
	TestRunner.assertEqual(#environment:GetChildren(), 2)
	local oceanKill = environment[WorldConfig.Environment.OceanKill]
	local oceanSurface = environment[WorldConfig.Environment.OceanSurface] :: BasePart
	TestRunner.assertFalse(oceanSurface.CanCollide)
	TestRunner.assertEqual(#CollectionService:GetTags(oceanSurface), 0)
	TestRunner.assertTrue((oceanKill :: BasePart).CanCollide)
	assertSoleTag(oceanKill, RunConfig.Tags.Hazard)
	assertNoAttributes(oceanKill)
end)

TestRunner.test("World has the exact single active RunStart", function()
	local runStarts = CollectionService:GetTagged(RunConfig.Tags.RunStart)
	local expected = world.Scene01_HotBeach.Start.StartLine
	TestRunner.assertEqual(#runStarts, 1)
	TestRunner.assertEqual(runStarts[1], expected)
	TestRunner.assertTrue(expected:IsA("Part"))
	assertSoleTag(expected, RunConfig.Tags.RunStart)
	assertNoAttributes(expected)
	TestRunner.assertTrue(expected.CanTouch and expected.CanQuery)
	TestRunner.assertFalse(expected.CanCollide)
end)

TestRunner.test("World has the exact four ordered checkpoint paths and contracts", function()
	TestRunner.assertEqual(#WorldConfig.Progression.Checkpoints, 4)
	for index, definition in WorldConfig.Progression.Checkpoints do
		local checkpoint = resolveCheckpoint(definition)
		if index == 1 then
			TestRunner.assertTrue(checkpoint:IsA("SpawnLocation"))
		else
			TestRunner.assertTrue(checkpoint:IsA("BasePart"))
		end
		assertSoleTag(checkpoint, RunConfig.Tags.Checkpoint)
		TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId), definition.Id)
		TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder), definition.Order)
		TestRunner.assertEqual(checkpoint:GetAttribute(RunConfig.Attributes.RespawnOffset), Vector3.new(0, 4, 0))
		TestRunner.assertTrue(checkpoint.CanTouch and checkpoint.CanQuery)
		TestRunner.assertEqual(checkpoint.CanCollide, index == 1)
	end
end)

TestRunner.test("World checkpoint IDs and orders are unique and exactly sequential", function()
	local expectedIds = { "Start", "WaterStart", "LaserIslandStart", "PalmBase" }
	local seenIds: { [string]: boolean } = {}
	local seenOrders: { [number]: boolean } = {}
	for index, definition in WorldConfig.Progression.Checkpoints do
		local checkpoint = resolveCheckpoint(definition)
		local checkpointId = checkpoint:GetAttribute(RunConfig.Attributes.CheckpointId) :: string
		local checkpointOrder = checkpoint:GetAttribute(RunConfig.Attributes.CheckpointOrder) :: number
		TestRunner.assertEqual(checkpointId, expectedIds[index])
		TestRunner.assertEqual(checkpointOrder, index)
		TestRunner.assertFalse(seenIds[checkpointId] == true)
		TestRunner.assertFalse(seenOrders[checkpointOrder] == true)
		seenIds[checkpointId] = true
		seenOrders[checkpointOrder] = true
	end
end)

TestRunner.test("World has exactly one enabled production SpawnLocation", function()
	local enabled: { SpawnLocation } = {}
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("SpawnLocation") and descendant.Enabled then table.insert(enabled, descendant) end
	end
	local startSpawn = resolveCheckpoint(WorldConfig.Progression.Checkpoints[1])
	TestRunner.assertEqual(#enabled, 1)
	TestRunner.assertEqual(enabled[1], startSpawn)
	TestRunner.assertTrue(startSpawn:IsA("SpawnLocation"))
	TestRunner.assertEqual(startSpawn:GetAttribute(RunConfig.Attributes.CheckpointOrder), 1)
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:GetChildren()[1], world)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("StartSpawn", true) == startSpawn)
	TestRunner.assertTrue(startSpawn:IsDescendantOf(world))
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("SpawnLocation") then
			TestRunner.assertTrue(descendant:IsDescendantOf(world))
			TestRunner.assertEqual(descendant, startSpawn)
		end
	end
end)

TestRunner.test("World has the exact sixteen configured coin paths", function()
	local configured = collectConfiguredCoins()
	local taggedSet: { [Instance]: boolean } = {}
	for _, coin in CollectionService:GetTagged(RunConfig.Tags.Coin) do taggedSet[coin] = true end
	TestRunner.assertEqual(#configured, 16)
	TestRunner.assertEqual(#CollectionService:GetTagged(RunConfig.Tags.Coin), 16)
	for _, contract in configured do TestRunner.assertTrue(taggedSet[contract.instance] == true) end
end)

TestRunner.test("World coin IDs are unique and match their Instance names", function()
	local seen: { [string]: boolean } = {}
	for _, contract in collectConfiguredCoins() do
		local coin = contract.instance
		local coinId = coin:GetAttribute(RunConfig.Attributes.CoinId)
		TestRunner.assertEqual(coinId, coin.Name)
		TestRunner.assertEqual(coinId, contract.id)
		TestRunner.assertFalse(seen[contract.id] == true)
		seen[contract.id] = true
		assertSoleTag(coin, RunConfig.Tags.Coin)
		local attributeCount = 0
		for name in coin:GetAttributes() do attributeCount += 1; TestRunner.assertEqual(name, RunConfig.Attributes.CoinId) end
		TestRunner.assertEqual(attributeCount, 1)
		TestRunner.assertTrue(coin.CanTouch and coin.CanQuery)
		TestRunner.assertFalse(coin.CanCollide)
	end
end)

TestRunner.test("World has the exact single active Finish contract", function()
	local finishes = CollectionService:GetTagged(RunConfig.Tags.Finish)
	local definition = WorldConfig.Progression.Finish
	local scene = world:FindFirstChild(definition.Scene) :: Model
	local finish = scene[definition.Folder][definition.Name] :: BasePart
	TestRunner.assertEqual(#finishes, 1)
	TestRunner.assertEqual(finishes[1], finish)
	assertSoleTag(finish, RunConfig.Tags.Finish)
	TestRunner.assertEqual(finish:GetAttribute(RunConfig.Attributes.RequiredCheckpointOrder), 4)
	TestRunner.assertTrue(finish.CanTouch and finish.CanQuery)
	TestRunner.assertFalse(finish.CanCollide)
end)

TestRunner.test("Every active progression object is a descendant of World", function()
	for _, tag in { RunConfig.Tags.RunStart, RunConfig.Tags.Checkpoint, RunConfig.Tags.Coin, RunConfig.Tags.Finish } do
		for _, instance in CollectionService:GetTagged(tag) do TestRunner.assertTrue(instance:IsDescendantOf(world)) end
	end
end)

TestRunner.test("Release hierarchy contains World as its sole direct child", function()
	TestRunner.assertTrue(beachObby:IsA("Folder"))
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:GetChildren()[1], world)
	TestRunner.assertTrue(world:IsA("Model"))
	TestRunner.assertTrue(beachObby:FindFirstChild("TemporaryAccess", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("SpawnBridge", true) == nil)
end)

TestRunner.test("Release hierarchy recursively excludes VerticalSlice and KillBlock", function()
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice") == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("KillBlock", true) == nil)
	for _, descendant in beachObby:GetDescendants() do
		if descendant:IsA("BasePart") then
			TestRunner.assertTrue(descendant:IsDescendantOf(world))
		end
	end
end)

TestRunner.test("Every release Hazard is a descendant of World", function()
	local worldHazards = 0
	for _, hazard in CollectionService:GetTagged(RunConfig.Tags.Hazard) do
		TestRunner.assertTrue(hazard:IsDescendantOf(world))
		worldHazards += 1
	end
	TestRunner.assertEqual(worldHazards, 10)
end)

TestRunner.test("Active progression objects have no incompatible tags or extra gameplay attributes", function()
	local allowedAttributes = {
		[RunConfig.Tags.RunStart] = {},
		[RunConfig.Tags.Checkpoint] = {
			[RunConfig.Attributes.CheckpointId] = true,
			[RunConfig.Attributes.CheckpointOrder] = true,
			[RunConfig.Attributes.RespawnOffset] = true,
		},
		[RunConfig.Tags.Coin] = { [RunConfig.Attributes.CoinId] = true },
		[RunConfig.Tags.Finish] = { [RunConfig.Attributes.RequiredCheckpointOrder] = true },
	}
	for expectedTag, allowed in allowedAttributes do
		for _, instance in CollectionService:GetTagged(expectedTag) do
			for _, gameplayTag in gameplayTags do
				TestRunner.assertEqual(CollectionService:HasTag(instance, gameplayTag), gameplayTag == expectedTag)
			end
			for attributeName in instance:GetAttributes() do TestRunner.assertTrue(allowed[attributeName] == true) end
		end
	end
end)

TestRunner.test("WorldConfig resolves every active progression path and World has no nested source", function()
	for _, definition in WorldConfig.Progression.Checkpoints do resolveCheckpoint(definition) end
	local finishDefinition = WorldConfig.Progression.Finish
	local finishScene = world:FindFirstChild(finishDefinition.Scene)
	TestRunner.assertTrue(finishScene ~= nil and finishScene:IsA("Model"))
	local finishContainer = (finishScene :: Model):FindFirstChild(finishDefinition.Folder)
	TestRunner.assertTrue(finishContainer ~= nil and finishContainer:IsA("Folder"))
	TestRunner.assertTrue((finishContainer :: Folder):FindFirstChild(finishDefinition.Name) ~= nil)
	TestRunner.assertEqual(#collectConfiguredCoins(), 16)
	TestRunner.assertTrue(environment:IsA("Folder"))
	TestRunner.assertEqual(#environment:GetChildren(), 2)
	TestRunner.assertTrue(environment:FindFirstChild(WorldConfig.Environment.OceanSurface) ~= nil)
	TestRunner.assertTrue(environment:FindFirstChild(WorldConfig.Environment.OceanKill) ~= nil)
	for _, descendant in world:GetDescendants() do TestRunner.assertFalse(descendant:IsA("LuaSourceContainer")) end
end)

TestRunner.test("OceanKill catches normal outward trajectories before Baseplate", function()
	local walkSpeed = 16
	local jumpHeight = 7.2
	local gravity = Workspace.Gravity
	TestRunner.assertTrue(math.abs(gravity - 196.2) <= 0.001)
	local jumpVelocity = math.sqrt(2 * gravity * jumpHeight)
	local oceanKill = environment[WorldConfig.Environment.OceanKill] :: BasePart
	local killMin, killMax = partAabb(oceanKill)
	local sampleParts: { BasePart } = {
		world.Scene01_HotBeach.Geometry.EndPlatform,
		world.Scene02_Water.Geometry.ExitPlatform,
		world.Scene03_LaserIsland.Geometry.IslandBase,
		world.Scene03_LaserIsland.Geometry.ExitPlatform,
		world.Scene04_PalmFinish.Geometry.EntryPlatform,
		world.Scene04_PalmFinish.Geometry.SpiralSteps.Step01,
		world.Scene04_PalmFinish.Geometry.SpiralSteps.Step20,
		world.Scene04_PalmFinish.Geometry.SpiralSteps.Step54,
		world.Scene04_PalmFinish.Geometry.SpiralSteps.Step73,
		world.Scene04_PalmFinish.Geometry.SummitPlatform,
		world.Scene04_PalmFinish.Triggers.FinishLine,
	}
	for _, sample in sampleParts do
		local sampleMin, sampleMax = partAabb(sample)
		for _, initialVelocityY in { 0, jumpVelocity } do
			local distanceY = sampleMax.Y - killMax.Y
			local time = (initialVelocityY + math.sqrt(initialVelocityY * initialVelocityY + 2 * gravity * distanceY)) / gravity
			local drift = walkSpeed * time
			TestRunner.assertTrue(sampleMin.X - drift >= killMin.X)
			TestRunner.assertTrue(sampleMax.X + drift <= killMax.X)
			TestRunner.assertTrue(sampleMin.Z - drift >= killMin.Z)
			TestRunner.assertTrue(sampleMax.Z + drift <= killMax.Z)
		end
	end
	local gameplayMin = Vector3.new(math.huge, math.huge, math.huge)
	local gameplayMax = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sceneName in { WorldConfig.Scenes.HotBeach, WorldConfig.Scenes.Water, WorldConfig.Scenes.LaserIsland, WorldConfig.Scenes.PalmFinish } do
		local sceneMin, sceneMax = getAabb(world[sceneName])
		gameplayMin = Vector3.new(math.min(gameplayMin.X, sceneMin.X), math.min(gameplayMin.Y, sceneMin.Y), math.min(gameplayMin.Z, sceneMin.Z))
		gameplayMax = Vector3.new(math.max(gameplayMax.X, sceneMax.X), math.max(gameplayMax.Y, sceneMax.Y), math.max(gameplayMax.Z, sceneMax.Z))
	end
	local margins = {
		gameplayMin.X - killMin.X,
		killMax.X - gameplayMax.X,
		killMax.Z - gameplayMax.Z,
		gameplayMin.Z - killMin.Z,
	}
	for _, margin in margins do TestRunner.assertTrue(margin >= 131) end
	local baseplateMin, baseplateMax = partAabb(Workspace.Baseplate)
	TestRunner.assertTrue(math.abs(killMax.Y + 0.75) <= 0.001)
	TestRunner.assertTrue(math.abs(baseplateMax.Y + 6) <= 0.001)
	TestRunner.assertTrue(math.abs(killMin.Y - baseplateMax.Y - 4.75) <= 0.001)
	TestRunner.assertFalse(Workspace.Baseplate.CanCollide)
end)

TestRunner.test("Baseplate cannot serve as gameplay floor and no legacy release shell remains", function()
	local baseplate = Workspace.Baseplate
	TestRunner.assertTrue(baseplate:IsA("Part"))
	TestRunner.assertEqual(baseplate.CFrame, CFrame.new(0, -14, 0))
	TestRunner.assertEqual(baseplate.Size, Vector3.new(2048, 16, 2048))
	TestRunner.assertTrue(baseplate.Anchored)
	TestRunner.assertFalse(baseplate.CanCollide)
	TestRunner.assertFalse(baseplate.CanTouch)
	TestRunner.assertTrue(baseplate.CanQuery)
	TestRunner.assertEqual(baseplate.Transparency, 1)
	TestRunner.assertFalse(baseplate.CastShadow)
	TestRunner.assertEqual(#CollectionService:GetTags(baseplate), 0)
	assertNoAttributes(baseplate)
	local children = baseplate:GetChildren()
	TestRunner.assertEqual(#children, 1)
	local texture = children[1]
	TestRunner.assertEqual(texture.Name, "Texture")
	TestRunner.assertTrue(texture:IsA("Texture"))
	TestRunner.assertEqual(texture.Parent, baseplate)
	TestRunner.assertEqual((texture :: Texture).Texture, "rbxassetid://6372755229")
	TestRunner.assertEqual((texture :: Texture).Face, Enum.NormalId.Top)
	TestRunner.assertEqual((texture :: Texture).StudsPerTileU, 8)
	TestRunner.assertEqual((texture :: Texture).StudsPerTileV, 8)
	TestRunner.assertEqual((texture :: Texture).OffsetStudsU, 0)
	TestRunner.assertEqual((texture :: Texture).OffsetStudsV, 0)
	TestRunner.assertEqual((texture :: Texture).Color3, Color3.new(0, 0, 0))
	TestRunner.assertTrue(math.abs((texture :: Texture).Transparency - 0.8) <= 0.001)
	TestRunner.assertEqual((texture :: Texture).ZIndex, 1)
	TestRunner.assertEqual(#CollectionService:GetTags(texture), 0)
	assertNoAttributes(texture)
	TestRunner.assertFalse(texture:IsA("LuaSourceContainer"))
	TestRunner.assertEqual(#texture:GetChildren(), 0)
	TestRunner.assertTrue(beachObby:FindFirstChild("TemporaryAccess") == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("SpawnBridge", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("VerticalSlice", true) == nil)
	TestRunner.assertTrue(beachObby:FindFirstChild("KillBlock", true) == nil)
	TestRunner.assertEqual(#beachObby:GetChildren(), 1)
	TestRunner.assertEqual(beachObby:FindFirstChild(WorldConfig.Root.World), world)
	for _, tag in { RunConfig.Tags.RunStart, RunConfig.Tags.Checkpoint, RunConfig.Tags.Coin, RunConfig.Tags.Finish } do
		for _, instance in CollectionService:GetTagged(tag) do TestRunner.assertTrue(instance:IsDescendantOf(world)) end
	end
	for _, hazard in CollectionService:GetTagged(RunConfig.Tags.Hazard) do
		TestRunner.assertTrue(hazard:IsDescendantOf(world))
	end
	for _, descendant in environment:GetDescendants() do TestRunner.assertFalse(descendant:IsA("LuaSourceContainer")) end
end)

return true
