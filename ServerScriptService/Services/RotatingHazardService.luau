--!strict

export type ConfigEntry = {
	Id: string,
	SceneName: string,
	ModelName: string,
	PivotPartName: string,
	RotationAxis: string,
	SecondsPerRevolution: number,
	PhaseOffset: number,
	Direction: number,
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

type Rotator = {
	entry: ConfigEntry,
	model: Model,
	pivotPart: BasePart,
	rotationAxis: Vector3,
	fixedPivotCFrame: CFrame,
	initialAssemblyRelativeCFrame: CFrame,
}

type ServiceFields = {
	_rotators: { Rotator },
	_heartbeatSignal: any,
	_now: () -> number,
	_connection: Disconnectable?,
	_startedAtServerTime: number?,
	_started: boolean,
	_destroyed: boolean,
}

local Service = {}
Service.__index = Service

export type Service = typeof(setmetatable({} :: ServiceFields, Service))

local RotatingHazardService = {}

local AXES: { [string]: Vector3 } = {
	X = Vector3.new(1, 0, 0),
	Y = Vector3.new(0, 1, 0),
	Z = Vector3.new(0, 0, 1),
}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

local function assertNonEmptyString(value: any, fieldName: string)
	assert(typeof(value) == "string" and value ~= "", fieldName .. " must be a non-empty string")
end

local function findUniqueDirectChild(root: Instance, name: string, expectedClass: string): Instance
	local match: Instance? = nil

	for _, child in root:GetChildren() do
		if child.Name == name then
			assert(match == nil, string.format("%s contains more than one child named %q", root:GetFullName(), name))
			match = child
		end
	end

	assert(match ~= nil, string.format("%s is missing child %q", root:GetFullName(), name))
	assert((match :: Instance):IsA(expectedClass), string.format("%s must be a %s", (match :: Instance):GetFullName(), expectedClass))
	return match :: Instance
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

local function validateEntry(entry: ConfigEntry): Vector3
	assertNonEmptyString(entry.Id, "Id")
	assertNonEmptyString(entry.SceneName, "SceneName")
	assertNonEmptyString(entry.ModelName, "ModelName")
	assertNonEmptyString(entry.PivotPartName, "PivotPartName")
	assert(
		isFiniteNumber(entry.SecondsPerRevolution) and entry.SecondsPerRevolution > 0,
		"SecondsPerRevolution must be a finite number greater than zero"
	)
	assert(
		isFiniteNumber(entry.PhaseOffset) and entry.PhaseOffset >= 0 and entry.PhaseOffset < 1,
		"PhaseOffset must be a finite number in the range [0, 1)"
	)
	assert(typeof(entry.RotationAxis) == "string" and AXES[entry.RotationAxis] ~= nil, "RotationAxis must be X, Y, or Z")
	assert(entry.Direction == -1 or entry.Direction == 1, "Direction must be -1 or 1")
	return AXES[entry.RotationAxis]
end

function RotatingHazardService.CalculateAngleRadians(
	elapsedSeconds: number,
	secondsPerRevolution: number,
	phaseOffset: number,
	direction: number
): number
	assert(isFiniteNumber(elapsedSeconds), "elapsedSeconds must be a finite number")
	assert(
		isFiniteNumber(secondsPerRevolution) and secondsPerRevolution > 0,
		"secondsPerRevolution must be a finite number greater than zero"
	)
	assert(
		isFiniteNumber(phaseOffset) and phaseOffset >= 0 and phaseOffset < 1,
		"phaseOffset must be a finite number in the range [0, 1)"
	)
	assert(direction == -1 or direction == 1, "direction must be -1 or 1")

	local fraction = (elapsedSeconds / secondsPerRevolution + phaseOffset) % 1
	return direction * 2 * math.pi * fraction
end

local function resolveRotator(worldRoot: Instance, entry: ConfigEntry): Rotator
	local rotationAxis = validateEntry(entry)
	local scene = findUniqueDirectChild(worldRoot, entry.SceneName, "Model") :: Model
	local model = findUniqueDescendant(scene, entry.ModelName, "Model") :: Model
	local pivotPart = findUniqueDescendant(scene, entry.PivotPartName, "BasePart") :: BasePart
	local fixedPivotCFrame = pivotPart.CFrame

	return {
		entry = entry,
		model = model,
		pivotPart = pivotPart,
		rotationAxis = rotationAxis,
		fixedPivotCFrame = fixedPivotCFrame,
		initialAssemblyRelativeCFrame = fixedPivotCFrame:ToObjectSpace(model:GetPivot()),
	}
end

local function updateRotator(rotator: Rotator, elapsedSeconds: number)
	if rotator.model.Parent == nil or rotator.pivotPart.Parent == nil then
		return
	end

	local angle = RotatingHazardService.CalculateAngleRadians(
		elapsedSeconds,
		rotator.entry.SecondsPerRevolution,
		rotator.entry.PhaseOffset,
		rotator.entry.Direction
	)
	local targetAssemblyPivot = rotator.fixedPivotCFrame
		* CFrame.fromAxisAngle(rotator.rotationAxis, angle)
		* rotator.initialAssemblyRelativeCFrame
	rotator.model:PivotTo(targetAssemblyPivot)
end

function Service.Start(self: Service): boolean
	if self._started or self._destroyed then
		return false
	end

	local startedAtServerTime = self._now()
	assert(isFiniteNumber(startedAtServerTime), "Now must return a finite number")
	self._started = true
	self._startedAtServerTime = startedAtServerTime

	for _, rotator in self._rotators do
		updateRotator(rotator, 0)
	end

	self._connection = self._heartbeatSignal:Connect(function()
		local now = self._now()
		assert(isFiniteNumber(now), "Now must return a finite number")
		local elapsedSeconds = now - (self._startedAtServerTime :: number)

		for _, rotator in self._rotators do
			updateRotator(rotator, elapsedSeconds)
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

	table.clear(self._rotators)
	return true
end

function RotatingHazardService.new(options: Options): Service
	assert(typeof(options) == "table", "options must be a table")
	assert(typeof(options.WorldRoot) == "Instance", "WorldRoot must be an Instance")
	assert(typeof(options.ConfigEntries) == "table", "ConfigEntries must be a table")
	assert(typeof(options.HeartbeatSignal) == "table" or typeof(options.HeartbeatSignal) == "RBXScriptSignal", "HeartbeatSignal must support Connect")
	assert(typeof(options.HeartbeatSignal.Connect) == "function", "HeartbeatSignal must support Connect")
	assert(typeof(options.Now) == "function", "Now must be a function")

	local rotators = {}
	local ids: { [string]: boolean } = {}

	for _, entry in options.ConfigEntries do
		validateEntry(entry)
		assert(not ids[entry.Id], string.format("Duplicate rotating hazard Id %q", entry.Id))
		ids[entry.Id] = true
		table.insert(rotators, resolveRotator(options.WorldRoot, entry))
	end

	return setmetatable({
		_rotators = rotators,
		_heartbeatSignal = options.HeartbeatSignal,
		_now = options.Now,
		_connection = nil,
		_startedAtServerTime = nil,
		_started = false,
		_destroyed = false,
	}, Service)
end

return table.freeze(RotatingHazardService)
