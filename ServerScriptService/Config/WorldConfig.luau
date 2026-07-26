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

local LoungeNames = table.freeze({
	"Lounge01",
	"Lounge02",
	"Lounge03",
	"Lounge04",
	"Lounge05",
	"Lounge06",
	"Lounge07",
})

local RunnerNames = table.freeze({
	"Runner01",
	"Runner02",
	"Runner03",
})

local CoinIds = table.freeze({
	"DemoCoin",
	"HotBeachCoin01",
	"HotBeachCoin02",
	"HotBeachCoin03",
})

local HotBeach = table.freeze({
	SceneFootprint = "SceneFootprint",
	HotSandVisual = "HotSandVisual",
	HotSandHazard = "HotSandHazard",
	LoungersFolder = "Loungers",
	StickFiguresFolder = "StickFigures",
	WaterStartMarker = "WaterStartCheckpointMarker",
	LoungeNames = LoungeNames,
	RunnerNames = RunnerNames,
	CoinIds = CoinIds,
	WaterStartCheckpointId = "WaterStart",
})

return table.freeze({
	Root = Root,
	Scenes = Scenes,
	Shared = Shared,
	CommonFolders = CommonFolders,
	HotBeach = HotBeach,
})
