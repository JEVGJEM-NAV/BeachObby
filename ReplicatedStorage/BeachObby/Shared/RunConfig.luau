--!strict

local Tags = table.freeze({
	RunStart = "RunStart",
	Checkpoint = "Checkpoint",
	Hazard = "Hazard",
	Coin = "Coin",
	Finish = "Finish",
})

local Attributes = table.freeze({
	CheckpointId = "CheckpointId",
	CheckpointOrder = "CheckpointOrder",
	RespawnOffset = "RespawnOffset",
	CoinId = "CoinId",
	RequiredCheckpointOrder = "RequiredCheckpointOrder",
})

local Phases = table.freeze({
	NotStarted = "NotStarted",
	Running = "Running",
	Finished = "Finished",
})

local Remotes = table.freeze({
	RunStateUpdated = "RunStateUpdated",
	GetRunState = "GetRunState",
})

return table.freeze({
	Tags = Tags,
	Attributes = Attributes,
	Phases = Phases,
	Remotes = Remotes,
})
