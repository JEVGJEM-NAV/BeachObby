--!strict

export type ConfigEntry = {
	Id: string,
	SceneName: string,
	ModelName: string,
	StartMarkerName: string,
	EndMarkerName: string,
	OneWayDurationSeconds: number,
	PhaseOffset: number,
}

export type Options = {
	WorldRoot: Instance,
	ConfigEntries: { ConfigEntry },
	HeartbeatSignal: any,
	Now: () -> number,
}

type Disconnectable = {
	Disconnect: (self: Disconnectable) -> (),
}

type Mover = {
	entry: ConfigEntry,
	model: Model,
	startMarker: BasePart,
	endMarker: BasePart,
	positionOffset: Vector3,
	rotation: CFrame,
}

type ServiceFields = {
	_movers: { Mover },
	_heartbeatSignal: any,
	_now: () -> number,
	_connection: Disconnectable?,
	_started: boolean,
	_destroyed: boolean,
}

local Service = {}
Service.__index = Service

export type Service = typeof(setmetatable({} :: ServiceFields, Service))

local MovingHazardService = {}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function assertNonEmptyString(value: any, fieldName: string)
	assert(typeof(value) == "string" and value ~= "", fieldName .. " must be a non-empty string")
end

local function findUniqueDescendant(root: Instance, name: string, expectedClass: string): Instance
	local match: Instance? = nil

	for _, descendant in root:GetDescendants() do
		if descendant.Name == name then
			assert(match == nil, string.format("%s contains more than one descendant named %q", root:GetFullName(), name))
			match = descendant
		end
	end

	assert(match ~= nil, string.format("%s is missing descendant %q", root:GetFullName(), name))
	assert((match :: Instance):IsA(expectedClass), string.format("%s must be a %s", (match :: Instance):GetFullName(), expectedClass))
	return match :: Instance
end

local function validateEntry(entry: ConfigEntry)
	assertNonEmptyString(entry.Id, "Id")
	assertNonEmptyString(entry.SceneName, "SceneName")
	assertNonEmptyString(entry.ModelName, "ModelName")
	assertNonEmptyString(entry.StartMarkerName, "StartMarkerName")
	assertNonEmptyString(entry.EndMarkerName, "EndMarkerName")
	assert(
		isFiniteNumber(entry.OneWayDurationSeconds) and entry.OneWayDurationSeconds > 0,
		"OneWayDurationSeconds must be a finite number greater than zero"
	)
	assert(
		isFiniteNumber(entry.PhaseOffset) and entry.PhaseOffset >= 0 and entry.PhaseOffset < 1,
		"PhaseOffset must be a finite number in the range [0, 1)"
	)
end

function MovingHazardService.CalculatePingPongAlpha(
	elapsedSeconds: number,
	oneWayDurationSeconds: number,
	phaseOffset: number
): number
	assert(isFiniteNumber(elapsedSeconds), "elapsedSeconds must be a finite number")
	assert(
		isFiniteNumber(oneWayDurationSeconds) and oneWayDurationSeconds > 0,
		"oneWayDurationSeconds must be a finite number greater than zero"
	)
	assert(
		isFiniteNumber(phaseOffset) and phaseOffset >= 0 and phaseOffset < 1,
		"phaseOffset must be a finite number in the range [0, 1)"
	)

	local totalCycle = oneWayDurationSeconds * 2
	local cycleFraction = ((elapsedSeconds % totalCycle) / totalCycle + phaseOffset) % 1

	if cycleFraction <= 0.5 then
		return cycleFraction * 2
	end

	return (1 - cycleFraction) * 2
end

local function resolveMover(worldRoot: Instance, entry: ConfigEntry): Mover
	validateEntry(entry)

	local scene = worldRoot:FindFirstChild(entry.SceneName)
	assert(scene ~= nil and scene:IsA("Model"), string.format("WorldRoot is missing scene Model %q", entry.SceneName))

	local model = findUniqueDescendant(scene, entry.ModelName, "Model") :: Model
	local startMarker = findUniqueDescendant(scene, entry.StartMarkerName, "BasePart") :: BasePart
	local endMarker = findUniqueDescendant(scene, entry.EndMarkerName, "BasePart") :: BasePart
	assert((endMarker.Position - startMarker.Position).Magnitude > 0, entry.Id .. " markers must have different positions")

	local originalPivot = model:GetPivot()

	return {
		entry = entry,
		model = model,
		startMarker = startMarker,
		endMarker = endMarker,
		positionOffset = originalPivot.Position - startMarker.Position,
		rotation = originalPivot - originalPivot.Position,
	}
end

local function updateMover(mover: Mover, now: number)
	if mover.model.Parent == nil or mover.startMarker.Parent == nil or mover.endMarker.Parent == nil then
		return
	end

	local alpha = MovingHazardService.CalculatePingPongAlpha(
		now,
		mover.entry.OneWayDurationSeconds,
		mover.entry.PhaseOffset
	)
	local markerPosition = mover.startMarker.Position:Lerp(mover.endMarker.Position, alpha)
	mover.model:PivotTo(CFrame.new(markerPosition + mover.positionOffset) * mover.rotation)
end

function Service.Start(self: Service): boolean
	if self._started or self._destroyed then
		return false
	end

	self._started = true
	local now = self._now()

	for _, mover in self._movers do
		updateMover(mover, now)
	end

	self._connection = self._heartbeatSignal:Connect(function()
		local heartbeatNow = self._now()

		for _, mover in self._movers do
			updateMover(mover, heartbeatNow)
		end
	end)

	return true
end

function Service.Destroy(self: Service): boolean
	if self._destroyed then
		return false
	end

	self._destroyed = true
	self._started = false

	if self._connection ~= nil then
		self._connection:Disconnect()
		self._connection = nil
	end

	table.clear(self._movers)
	return true
end

function MovingHazardService.new(options: Options): Service
	assert(typeof(options) == "table", "options must be a table")
	assert(typeof(options.WorldRoot) == "Instance", "WorldRoot must be an Instance")
	assert(typeof(options.ConfigEntries) == "table", "ConfigEntries must be a table")
	assert(typeof(options.HeartbeatSignal) == "table" or typeof(options.HeartbeatSignal) == "RBXScriptSignal", "HeartbeatSignal must support Connect")
	assert(typeof(options.HeartbeatSignal.Connect) == "function", "HeartbeatSignal must support Connect")
	assert(typeof(options.Now) == "function", "Now must be a function")

	local movers = {}
	local ids: { [string]: boolean } = {}

	for _, entry in options.ConfigEntries do
		validateEntry(entry)
		assert(not ids[entry.Id], string.format("Duplicate moving hazard Id %q", entry.Id))
		ids[entry.Id] = true
		table.insert(movers, resolveMover(options.WorldRoot, entry))
	end

	return setmetatable({
		_movers = movers,
		_heartbeatSignal = options.HeartbeatSignal,
		_now = options.Now,
		_connection = nil,
		_started = false,
		_destroyed = false,
	}, Service)
end

return table.freeze(MovingHazardService)
