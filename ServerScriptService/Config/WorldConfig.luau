--!strict

local Root = table.freeze({
	BeachObby = "BeachObby",
	World = "World",
	VerticalSlice = "VerticalSlice",
})

local Scenes = table.freeze({
	HotBeach = "Scene01_HotBeach",
	Water = "Scene02_Water",
	LaserIsland = "Scene03_LaserIsland",
	PalmFinish = "Scene04_PalmFinish",
})

local Shared = table.freeze({
	SharedEnvironment = "SharedEnvironment",
})

local CommonFolders = table.freeze({
	Start = "Start",
	Geometry = "Geometry",
	Hazards = "Hazards",
	MovementPaths = "MovementPaths",
	Coins = "Coins",
	Triggers = "Triggers",
})

return table.freeze({
	Root = Root,
	Scenes = Scenes,
	Shared = Shared,
	CommonFolders = CommonFolders,
})
