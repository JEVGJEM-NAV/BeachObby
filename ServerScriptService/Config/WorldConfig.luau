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

local RingNames = table.freeze({
	"Ring01",
	"Ring02",
	"Ring03",
	"Ring04",
	"Ring05",
	"Ring06",
	"Ring07",
	"Ring08",
})

local WaterCoinIds = table.freeze({
	"WaterCoin01",
	"WaterCoin02",
	"WaterCoin03",
	"WaterCoin04",
})

local Water = table.freeze({
	SceneFootprint = "SceneFootprint",
	WaterSurface = "WaterSurface",
	WaterKillPlane = "WaterKillPlane",
	RingsFolder = "Rings",
	SharksFolder = "Sharks",
	LaserIslandStartMarker = "LaserIslandStartCheckpointMarker",
	RingNames = RingNames,
	CoinIds = WaterCoinIds,
	LaserIslandStartCheckpointId = "LaserIslandStart",
})

local Runner01 = table.freeze({
	Id = "Runner01",
	SceneName = "Scene01_HotBeach",
	ModelName = "Runner01",
	StartMarkerName = "Runner01_Start",
	EndMarkerName = "Runner01_End",
	OneWayDurationSeconds = 6,
	PhaseOffset = 0,
})

local Runner02 = table.freeze({
	Id = "Runner02",
	SceneName = "Scene01_HotBeach",
	ModelName = "Runner02",
	StartMarkerName = "Runner02_Start",
	EndMarkerName = "Runner02_End",
	OneWayDurationSeconds = 6,
	PhaseOffset = 0.2,
})

local Runner03 = table.freeze({
	Id = "Runner03",
	SceneName = "Scene01_HotBeach",
	ModelName = "Runner03",
	StartMarkerName = "Runner03_Start",
	EndMarkerName = "Runner03_End",
	OneWayDurationSeconds = 6,
	PhaseOffset = 0.55,
})

local Shark01 = table.freeze({
	Id = "Shark01",
	SceneName = "Scene02_Water",
	ModelName = "Shark01",
	StartMarkerName = "Shark01_Start",
	EndMarkerName = "Shark01_End",
	OneWayDurationSeconds = 6,
	PhaseOffset = 0.1,
})

local Shark02 = table.freeze({
	Id = "Shark02",
	SceneName = "Scene02_Water",
	ModelName = "Shark02",
	StartMarkerName = "Shark02_Start",
	EndMarkerName = "Shark02_End",
	OneWayDurationSeconds = 6,
	PhaseOffset = 0.35,
})

local Runners = table.freeze({
	Runner01,
	Runner02,
	Runner03,
})

local Sharks = table.freeze({
	Shark01,
	Shark02,
})

local MovingHazards = table.freeze({
	Runners = Runners,
	Sharks = Sharks,
})

return table.freeze({
	Root = Root,
	Scenes = Scenes,
	Shared = Shared,
	CommonFolders = CommonFolders,
	HotBeach = HotBeach,
	Water = Water,
	MovingHazards = MovingHazards,
})
