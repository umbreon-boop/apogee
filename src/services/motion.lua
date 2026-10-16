--[=[
	Spring driven animation motors, a compact port of [Flipper](https://github.com/Reselim/Flipper) that keeps its exact
	stepping behaviour so every animation feels identical to the original library.

	@class Motion
	@location internals/services
]=]
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local State = require("../public")

local Motion = {}
-- Keep the final snap below a visible screen-space increment for UIScale motors.
local VELOCITY_THRESHOLD = 0.0001
local POSITION_THRESHOLD = 0.0001
local EPSILON = 0.0001

--[=[
	@interface Goal
	.Step (self, state: { value: number, velocity: number? }, delta: number) -> { [string]: any }
	@within Motion
]=]
export type Goal = {
	Step: (self: any, state: { [string]: any }, delta: number) -> { [string]: any }
}

--[=[
	@interface Motor
	.Set (self, goal: Goal) -> ()
	.Get (self) -> number
	@within Motion
]=]
export type Motor = {
	Set: (self: any, goal: Goal) -> (),
	Get: (self: any) -> number
}

--[=[
	@interface GroupMotor
	.Set (self, goals: { [string]: Goal }) -> ()
	.Get (self) -> { [string]: number }
	@within Motion
]=]
export type GroupMotor = {
	Set: (self: any, goals: { [string]: Goal }) -> (),
	Get: (self: any) -> { [string]: number }
}

local function stepSpring(self, state, delta)
	local damping = self._damping
	local frequency = self._frequency * 2 * math.pi
	local goal = self._target
	local offset = state.value - goal
	local velocity = state.velocity or 0
	local decay = math.exp(-damping * frequency * delta)
	local position, speed

	if damping == 1 then
		position = (offset * (1 + frequency * delta) + velocity * delta) * decay + goal
		speed = (velocity * (1 - frequency * delta) - offset * (frequency * frequency * delta)) * decay
	elseif damping < 1 then
		local c = math.sqrt(1 - damping * damping)
		local i = math.cos(frequency * c * delta)
		local j = math.sin(frequency * c * delta)
		local z, y

		if c > EPSILON then
			z = j / c
		else
			local a = delta * frequency
			z = a + ((a * a) * (c * c) * (c * c) / 20 - c * c) * (a * a * a) / 6
		end

		if frequency * c > EPSILON then
			y = j / (frequency * c)
		else
			local b = frequency * c
			y = delta + ((delta * delta) * (b * b) * (b * b) / 20 - b * b) * (delta * delta * delta) / 6
		end

		position = (offset * (i + damping * z) + velocity * y) * decay + goal
		speed = (velocity * (i - z * damping) - offset * (z * frequency)) * decay
	else
		local c = math.sqrt(damping * damping - 1)
		local r1 = -frequency * (damping - c)
		local r2 = -frequency * (damping + c)
		local co2 = (velocity - offset * r1) / (2 * frequency * c)
		local co1 = offset - co2
		local e1 = co1 * math.exp(r1 * delta)
		local e2 = co2 * math.exp(r2 * delta)
		position = e1 + e2 + goal
		speed = e1 * r1 + e2 * r2
	end

	local complete = math.abs(speed) < VELOCITY_THRESHOLD and math.abs(position - goal) < POSITION_THRESHOLD
	return {complete = complete, value = if complete then goal else position, velocity = speed}
end

local function stepInstant(self)
	return {complete = true, value = self._target}
end

--[=[
	Creates a spring goal.

	@param target number -- The value to settle on
	@param frequency number? -- Undamped frequency in hertz, defaults to 4
	@param damping number? -- Damping ratio, defaults to 1 (critically damped)
	@return Goal -- A spring goal that settles at the target value.
]=]
function Motion.Spring(target: number, frequency: number?, damping: number?): Goal
	return {_target = target, _frequency = frequency or 4, _damping = damping or 1, Step = stepSpring} :: any
end

--[=[
	Creates a goal that jumps to its target on the next frame.

	@param target number -- The value to jump to
	@return Goal -- A goal that snaps to the target on the next frame.
]=]
function Motion.Instant(target: number): Goal
	return {_target = target, Step = stepInstant} :: any
end

local function newSingle(initial: number, onStep: ((value: number) -> ())?, implicit: boolean)
	local motor = {_state = {complete = true, value = initial}, _goal = nil, _connection = nil}

	function motor:_step(delta: number): boolean
		if self._state.complete then
			return true
		end

		self._state = self._goal:Step(self._state, delta)
		if onStep then
			onStep(self._state.value)
		end
		if self._state.complete and self._connection then
			self._connection:Disconnect()
			self._connection = nil
		end
		return self._state.complete
	end

	function motor:Set(goal: Goal)
		self._state.complete = false
		self._goal = goal
		if implicit and not self._connection then
			self._connection = RunService.RenderStepped:Connect(function(delta)
				self:_step(delta)
			end)
		end
	end

	function motor:Get(): number
		return self._state.value
	end

	return motor
end

--[=[
	Creates a motor that animates a single number.

	@param initial number -- The starting value
	@param onStep (value: number) -> () -- Called with the new value every animated frame
	@return Motor -- A motor that animates one numeric value.
]=]
function Motion.Single(initial: number, onStep: (value: number) -> ()): Motor
	return newSingle(initial, onStep, true)
end

--[=[
	Creates a motor that animates several named numbers together.

	@param initial { [string]: number } -- The starting values
	@param onStep (values: { [string]: number }) -> () -- Called with every value each animated frame
	@return GroupMotor -- A motor group that animates the named numeric values.
]=]
function Motion.Group(initial: { [string]: number }, onStep: (values: { [string]: number }) -> ()): GroupMotor
	local group = {_motors = {}, _complete = true, _connection = nil}
	for key, value in initial do
		group._motors[key] = newSingle(value, nil, false)
	end

	function group:Get(): { [string]: number }
		local values = {}
		for key, motor in self._motors do
			values[key] = motor:Get()
		end
		return values
	end

	function group:_step(delta: number)
		if self._complete then
			return
		end

		local complete = true
		for _, motor in self._motors do
			if not motor:_step(delta) then
				complete = false
			end
		end

		onStep(self:Get())
		if complete then
			self._complete = true
			self._connection:Disconnect()
			self._connection = nil
		end
	end

	function group:Set(goals: { [string]: Goal })
		self._complete = false
		for key, goal in goals do
			self._motors[key]:Set(goal)
		end
		if not self._connection then
			self._connection = RunService.RenderStepped:Connect(function(delta)
				self:_step(delta)
			end)
		end
	end

	return group
end

--[=[
	Creates and plays a standard eased tween. Returns the tween so callers can cancel or inspect it.
	The completion callback receives PlaybackState for cancellation-safe cleanup.

	@param instance Instance -- The object whose properties should change
	@param properties { [string]: any } -- Target properties
	@param duration (number | TweenInfo)? -- Duration in seconds or a complete TweenInfo, defaults to 0.2 seconds
	@param easingStyle Enum.EasingStyle? -- Defaults to Quint
	@param easingDirection Enum.EasingDirection? -- Defaults to Out
	@param completed ((Enum.PlaybackState) -> ())? -- Called when the tween completes or is cancelled
	@return Tween -- The playing tween, which can be inspected or cancelled by the caller.
]=]
function Motion.Tween(
		instance: Instance,
		properties: { [string]: any },
		duration: (number | TweenInfo)?,
		easingStyle: Enum.EasingStyle?,
		easingDirection: Enum.EasingDirection?,
		completed: ((Enum.PlaybackState) -> ())?
	): Tween
	local info = if typeof(duration) == "TweenInfo"
		then duration :: TweenInfo
	else TweenInfo.new((duration :: number?) or 0.2, easingStyle or Enum.EasingStyle.Quint, easingDirection or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, properties)
	if completed then
		tween.Completed:Connect(completed)
	end
	tween:Play()
	return tween
end

--[=[
	Creates a spring motor bound to an instance property and returns a setter. Transparency increases
	are suppressed under overlays unless `ignoreDialog` or the setter's override is true.

	@param initial number -- The starting value
	@param instance Instance -- The animated instance
	@param property string -- The animated property
	@param ignoreDialog boolean? -- Keep animating while a dialog is open
	@param targetHost any? -- The host window or element owning the overlay check
	@return Motor, (value: number, ignore: boolean?) -> () -- The motor and a setter that updates the bound property.
]=]
function Motion.Bind(
		initial: number,
		instance: Instance,
		property: string,
		ignoreDialog: boolean?,
		targetHost: any?
	): (Motor, (value: number, ignore: boolean?) -> ())
	local motor = Motion.Single(initial, function(value)
		(instance :: any)[property] = value
	end)

	local function set(value: number, ignore: boolean?)
		local fade = property == "BackgroundTransparency" or property == "ImageTransparency"
		if not ignoreDialog and not ignore and fade and State:HasOverlay(targetHost) and value < 1 then
			return
		end
		motor:Set(Motion.Spring(value, 8))
	end

	return motor, set
end

return Motion
