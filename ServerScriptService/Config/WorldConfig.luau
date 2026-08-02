--!strict

local Root = table.freeze({
	BeachObby = "BeachObby",
	World = "World",
	Environment = "Environment",
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

local Environment = table.freeze({
	OceanSurface = "OceanSurface",
	OceanKill = "OceanKill",
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
	StartSpawn = "StartSpawn",
	StartLine = "StartLine",
	WaterStartCheckpoint = "WaterStartCheckpoint",
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
	RingsFolder = "Rings",
	SharksFolder = "Sharks",
	LaserIslandStartCheckpoint = "LaserIslandStartCheckpoint",
	RingNames = RingNames,
	CoinIds = WaterCoinIds,
	LaserIslandStartCheckpointId = "LaserIslandStart",
})

local LaserIslandCoinIds = table.freeze({
	"LaserIslandCoin01",
	"LaserIslandCoin02",
	"LaserIslandCoin03",
	"LaserIslandCoin04",
	"LaserIslandCoin05",
})

local LaserIsland = table.freeze({
	IslandBase = "IslandBase",
	CenterSphere = "CenterSphere",
	LaserAssembly = "LaserAssembly",
	LaserBar = "LaserBar",
	CoinIds = LaserIslandCoinIds,
	PalmBaseCheckpoint = "PalmBaseCheckpoint",
	PalmBaseCheckpointId = "PalmBase",
})

local PalmCoinIds = table.freeze({
	"PalmCoin01",
	"PalmCoin02",
	"PalmCoin03",
})

local PalmFinishSpiral = table.freeze({
	FolderName = "SpiralSteps",
	StepPrefix = "Step",
	StepCount = 73,
	CenterX = 164,
	CenterZ = -184,
	InitialAngleRadians = math.pi,
	AngularIncrementRadians = math.pi / 12,
	Radius = 9.5,
	FirstCenterY = 2.125,
	VerticalRise = 0.5,
	StepWidth = 5.5,
	StepHeight = 0.75,
	StepDepth = 4,
})

local PalmFinish = table.freeze({
	EntryPlatform = "EntryPlatform",
	SummitPlatform = "SummitPlatform",
	PalmTree = "PalmTree",
	Trunk = "Trunk",
	TrunkCore = "TrunkCore",
	CrownNeck = "CrownNeck",
	CrownHub = "CrownHub",
	Fronds = "Fronds",
	FrondPrefix = "Frond",
	FrondCount = 8,
	Spiral = PalmFinishSpiral,
	HotSandIsland = "HotSandIsland",
	HotSandTint = "HotSandTint",
	PalmFallCatch = "PalmFallCatch",
	PalmUpperFallCatch = "PalmUpperFallCatch",
	CoinIds = PalmCoinIds,
	FinishLine = "FinishLine",
})

local ProgressionCheckpoints = table.freeze({
	table.freeze({
		Scene = Scenes.HotBeach,
		Folder = CommonFolders.Start,
		Name = HotBeach.StartSpawn,
		Id = "Start",
		Order = 1,
	}),
	table.freeze({
		Scene = Scenes.HotBeach,
		Folder = CommonFolders.Triggers,
		Name = HotBeach.WaterStartCheckpoint,
		Id = HotBeach.WaterStartCheckpointId,
		Order = 2,
	}),
	table.freeze({
		Scene = Scenes.Water,
		Folder = CommonFolders.Triggers,
		Name = Water.LaserIslandStartCheckpoint,
		Id = Water.LaserIslandStartCheckpointId,
		Order = 3,
	}),
	table.freeze({
		Scene = Scenes.LaserIsland,
		Folder = CommonFolders.Triggers,
		Name = LaserIsland.PalmBaseCheckpoint,
		Id = LaserIsland.PalmBaseCheckpointId,
		Order = 4,
	}),
})

local ProgressionFinish = table.freeze({
	Scene = Scenes.PalmFinish,
	Folder = CommonFolders.Triggers,
	Name = PalmFinish.FinishLine,
	RequiredCheckpointOrder = 4,
})

local Progression = table.freeze({
	Checkpoints = ProgressionCheckpoints,
	Finish = ProgressionFinish,
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

local LaserIslandLaser = table.freeze({
	Id = "LaserIslandLaser",
	SceneName = "Scene03_LaserIsland",
	ModelName = "LaserAssembly",
	PivotPartName = "CenterSphere",
	RotationAxis = "Y",
	SecondsPerRevolution = 6,
	PhaseOffset = 0,
	Direction = -1,
})

local RotatingLasers = table.freeze({
	LaserIslandLaser,
})

local RotatingHazards = table.freeze({
	Lasers = RotatingLasers,
})

return table.freeze({
	Root = Root,
	Scenes = Scenes,
	Shared = Shared,
	Environment = Environment,
	CommonFolders = CommonFolders,
	HotBeach = HotBeach,
	Water = Water,
	LaserIsland = LaserIsland,
	PalmFinish = PalmFinish,
	Progression = Progression,
	MovingHazards = MovingHazards,
	RotatingHazards = RotatingHazards,
})
