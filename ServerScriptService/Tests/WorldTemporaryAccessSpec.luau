--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RunConfig = require(ReplicatedStorage.BeachObby.Shared.RunConfig)
local WorldConfig = require(ServerScriptService.Config.WorldConfig)
local TestRunner = require(script.Parent.TestRunner)

local beachObby = workspace:WaitForChild("BeachObby")
local bridge = beachObby:WaitForChild("TemporaryAccess"):WaitForChild("SpawnBridge")
local spawn = beachObby.VerticalSlice.StartSpawn :: BasePart
local scene01 = beachObby.World.Scene01_HotBeach
local scene02 = beachObby.World.Scene02_Water
local startPlatform = scene01.Geometry.StartPlatform :: BasePart

local function aabb(part: BasePart): { min: Vector3, max: Vector3 }
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

local function intersects(first: { min: Vector3, max: Vector3 }, second: { min: Vector3, max: Vector3 }): boolean
	return first.min.X < second.max.X and first.max.X > second.min.X
		and first.min.Y < second.max.Y and first.max.Y > second.min.Y
		and first.min.Z < second.max.Z and first.max.Z > second.min.Z
end

local function countHazards(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then count += 1 end
	end
	return count
end

TestRunner.test("TemporaryAccess hierarchy exists", function()
	TestRunner.assertEqual(beachObby.TemporaryAccess.ClassName, "Folder")
	TestRunner.assertEqual(bridge.ClassName, "Model")
end)

TestRunner.test("SpawnBridge contains exactly three sequential Parts", function()
	TestRunner.assertEqual(#bridge:GetChildren(), 3)
	for index = 1, 3 do
		local part = bridge:FindFirstChild(string.format("BridgeSegment%02d", index))
		TestRunner.assertTrue(part ~= nil and part:IsA("Part"))
	end
end)

TestRunner.test("SpawnBridge Parts are anchored collidable and queryable", function()
	for _, part in bridge:GetChildren() do
		local basePart = part :: BasePart
		TestRunner.assertTrue(basePart.Anchored)
		TestRunner.assertTrue(basePart.CanCollide)
		TestRunner.assertFalse(basePart.CanTouch)
		TestRunner.assertTrue(basePart.CanQuery)
		TestRunner.assertEqual(basePart.Material, Enum.Material.SmoothPlastic)
	end
end)

TestRunner.test("SpawnBridge is untagged attribute-free and script-free", function()
	for _, instance in { bridge, table.unpack(bridge:GetDescendants()) } do
		TestRunner.assertEqual(#CollectionService:GetTags(instance), 0)
		TestRunner.assertEqual(next(instance:GetAttributes()), nil)
		TestRunner.assertFalse(instance:IsA("LuaSourceContainer"))
		TestRunner.assertFalse(instance:IsA("Constraint"))
	end
end)

TestRunner.test("SpawnBridge avoids WaterKillPlane and HotSandHazard", function()
	for _, child in bridge:GetChildren() do
		local part = child :: BasePart
		for _, overlap in workspace:GetPartBoundsInBox(part.CFrame, part.Size) do
			TestRunner.assertFalse(overlap == scene02.Hazards.WaterKillPlane)
			TestRunner.assertFalse(overlap == scene01.Hazards.HotSandHazard)
		end
	end
end)

TestRunner.test("SpawnBridge avoids every runner movement corridor", function()
	for _, runnerName in { "Runner01", "Runner02", "Runner03" } do
		local startMarker = scene01.MovementPaths[runnerName .. "_Start"] :: BasePart
		local endMarker = scene01.MovementPaths[runnerName .. "_End"] :: BasePart
		local hitbox = scene01.Hazards.StickFigures[runnerName].Hitbox :: BasePart
		local corridor = {
			min = Vector3.new(math.min(startMarker.Position.X, endMarker.Position.X) - hitbox.Size.X / 2, 1, startMarker.Position.Z - hitbox.Size.Z / 2),
			max = Vector3.new(math.max(startMarker.Position.X, endMarker.Position.X) + hitbox.Size.X / 2, 6.75, startMarker.Position.Z + hitbox.Size.Z / 2),
		}
		for _, child in bridge:GetChildren() do
			TestRunner.assertFalse(intersects(aabb(child :: BasePart), corridor))
		end
	end
end)

TestRunner.test("SpawnBridge surface connects spawn and StartPlatform", function()
	local ramp = bridge.BridgeSegment01 :: BasePart
	local firstTop = ramp.CFrame:PointToWorldSpace(Vector3.new(0, ramp.Size.Y / 2, -ramp.Size.Z / 2))
	local secondTop = ramp.CFrame:PointToWorldSpace(Vector3.new(0, ramp.Size.Y / 2, ramp.Size.Z / 2))
	local spawnTop = spawn.Position.Y + spawn.Size.Y / 2
	local platformTop = startPlatform.Position.Y + startPlatform.Size.Y / 2
	local spawnEnd = if (Vector2.new(firstTop.X, firstTop.Z) - Vector2.new(spawn.Position.X, spawn.Position.Z)).Magnitude
		< (Vector2.new(secondTop.X, secondTop.Z) - Vector2.new(spawn.Position.X, spawn.Position.Z)).Magnitude then firstTop else secondTop
	local platformEnd = if spawnEnd == firstTop then secondTop else firstTop
	TestRunner.assertTrue(math.abs(spawnEnd.Y - spawnTop) <= 0.001)
	TestRunner.assertTrue(math.abs(platformEnd.Y - platformTop) <= 0.001)
	TestRunner.assertTrue(math.abs(spawnEnd.X - spawn.Position.X) <= spawn.Size.X / 2)
	TestRunner.assertTrue(math.abs(spawnEnd.Z - spawn.Position.Z) <= spawn.Size.Z / 2)
	TestRunner.assertTrue(math.abs(platformEnd.X - startPlatform.Position.X) <= startPlatform.Size.X / 2)
	TestRunner.assertTrue(math.abs(platformEnd.Z - startPlatform.Position.Z) <= startPlatform.Size.Z / 2)
end)

TestRunner.test("SpawnBridge has mobile-safe width and gentle slope", function()
	local ramp = bridge.BridgeSegment01 :: BasePart
	local railWidth = (bridge.BridgeSegment02 :: BasePart).Size.X
	local usefulWidth = ramp.Size.X - railWidth * 2
	local slope = math.deg(math.asin(math.abs(ramp.CFrame.LookVector.Y)))
	TestRunner.assertTrue(usefulWidth >= 8)
	TestRunner.assertTrue(slope < 10)
end)

TestRunner.test("SpawnBridge rails are continuous and do not obstruct useful width", function()
	local ramp = bridge.BridgeSegment01 :: BasePart
	for _, name in { "BridgeSegment02", "BridgeSegment03" } do
		local rail = bridge[name] :: BasePart
		TestRunner.assertEqual(rail.Size.Z, ramp.Size.Z)
		TestRunner.assertTrue(rail.Size.Y >= 1.5 and rail.Size.Y <= 2)
	end
end)

TestRunner.test("Temporary access does not move SpawnLocation", function()
	TestRunner.assertEqual(spawn.CFrame, CFrame.new(0, 0.5, 0))
	TestRunner.assertEqual(spawn.Size, Vector3.new(12, 1, 12))
end)

TestRunner.test("Temporary access retains lowered Baseplate", function()
	local baseplate = workspace.Baseplate
	TestRunner.assertEqual(baseplate.Position, Vector3.new(0, -14, 0))
	TestRunner.assertEqual(baseplate.Size, Vector3.new(2048, 16, 2048))
	TestRunner.assertEqual(baseplate.Position.Y + baseplate.Size.Y / 2, -6)
end)

TestRunner.test("Temporary access retains deep water geometry", function()
	local water = scene02.Geometry.WaterSurface :: BasePart
	local killPlane = scene02.Hazards.WaterKillPlane :: BasePart
	TestRunner.assertTrue((water.Position - Vector3.new(111, -2.3, -107)).Magnitude <= 0.001)
	TestRunner.assertTrue((water.Size - Vector3.new(32, 6.8, 56)).Magnitude <= 0.001)
	TestRunner.assertTrue(math.abs(water.Position.Y + water.Size.Y / 2 - 1.1) <= 0.001)
	TestRunner.assertTrue((killPlane.Position - Vector3.new(111, -5.3, -107)).Magnitude <= 0.001)
	TestRunner.assertTrue((killPlane.Size - Vector3.new(40, 0.3, 56)).Magnitude <= 0.001)
end)

TestRunner.test("Temporary access retains approved Phase 2.7 Hazard counts", function()
	TestRunner.assertEqual(countHazards(scene02), 3)
	TestRunner.assertEqual(countHazards(beachObby.World[WorldConfig.Scenes.PalmFinish]), 1)
	TestRunner.assertEqual(countHazards(beachObby.World), 9)
	TestRunner.assertEqual(countHazards(beachObby), 10)
end)

TestRunner.test("Temporary access ends only at Scene01 StartPlatform", function()
	local ramp = bridge.BridgeSegment01 :: BasePart
	for _, overlap in workspace:GetPartBoundsInBox(ramp.CFrame, ramp.Size) do
		if overlap:IsDescendantOf(scene01) and overlap ~= startPlatform then
			TestRunner.assertFalse(overlap.CanCollide, "Bridge intersects unexpected Scene01 collider " .. overlap:GetFullName())
		end
	end
end)

TestRunner.test("Temporary access remains isolated from Phase 2.7 and Phase 2.8 gameplay", function()
	for _, descendant in { bridge, table.unpack(bridge:GetDescendants()) } do
		TestRunner.assertEqual(#CollectionService:GetTags(descendant), 0)
		TestRunner.assertEqual(next(descendant:GetAttributes()), nil)
	end
	local palmScene = beachObby.World[WorldConfig.Scenes.PalmFinish]
	local palmFallCatch = palmScene.Hazards[WorldConfig.PalmFinish.PalmFallCatch]
	local hazardCount = 0
	for _, descendant in palmScene:GetDescendants() do
		if CollectionService:HasTag(descendant, RunConfig.Tags.Hazard) then
			hazardCount += 1
			TestRunner.assertEqual(descendant, palmFallCatch)
		end
		TestRunner.assertFalse(descendant:IsA("LuaSourceContainer"))
	end
	TestRunner.assertEqual(hazardCount, 1)
	for _, name in WorldConfig.PalmFinish.CoinMarkerNames do
		local marker = palmScene.Coins[name]
		TestRunner.assertFalse(CollectionService:HasTag(marker, RunConfig.Tags.Coin))
		TestRunner.assertTrue(marker:GetAttribute("CoinId") == nil)
	end
	local finish = palmScene.Triggers[WorldConfig.PalmFinish.FinishPlaceholder]
	TestRunner.assertFalse(CollectionService:HasTag(finish, RunConfig.Tags.Finish))
	TestRunner.assertTrue(finish:GetAttribute("RequiredCheckpointOrder") == nil)
	local checkpoint = beachObby.World[WorldConfig.Scenes.LaserIsland].Triggers[WorldConfig.LaserIsland.PalmBaseCheckpointMarker]
	TestRunner.assertFalse(CollectionService:HasTag(checkpoint, RunConfig.Tags.Checkpoint))
	TestRunner.assertTrue(checkpoint:GetAttribute("CheckpointId") == nil)
	TestRunner.assertTrue(checkpoint:GetAttribute("CheckpointOrder") == nil)
	TestRunner.assertTrue(checkpoint:GetAttribute("RespawnOffset") == nil)
end)

return true
