--[=[
	Mouse and touch helpers: what counts as a press, whether a pointer is over a frame, when a press ends, and the
	hover and press states of a button.

	@class Pointer
	@location internals/services
]=]
local UserInputService = game:GetService("UserInputService")
local State = require("../public")

local Pointer = {}
local releases = setmetatable({}, {__mode = "k"})

State.Maid:Task(UserInputService.InputEnded:Connect(function(input)
	for frame, press in releases do
		local matches = if press.input.UserInputType == Enum.UserInputType.Touch
			then input == press.input
		else input.UserInputType == Enum.UserInputType.MouseButton1
		if matches then
			releases[frame] = nil
			pcall(press.callback, input)
		end
	end
end))

--[=[
	Returns whether an input is a left click or a touch.

	@param input InputObject -- The input
	@return boolean -- Whether the input is a left mouse click or touch.
]=]
function Pointer.IsPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

--[=[
	Returns whether an input's position is over a frame.

	@param frame GuiObject -- The frame
	@param input InputObject -- The input
	@return boolean -- Whether the input position falls within the frame bounds.
]=]
function Pointer.Over(frame: GuiObject, input: InputObject): boolean
	local position = input.Position
	local corner = frame.AbsolutePosition
	local size = frame.AbsoluteSize
	return position.X >= corner.X
	and position.X <= corner.X + size.X
	and position.Y >= corner.Y
	and position.Y <= corner.Y + size.Y
end

--[=[
	Calls `callback` once when a press that began on `frame` ends, also when it ends outside the frame.

	@param frame GuiObject -- The frame the press began on
	@param input InputObject -- The press
	@param callback (InputObject) -> () -- Called with the input that ends the press
]=]
function Pointer.TrackRelease(frame: GuiObject, input: InputObject, callback: (InputObject) -> ())
	if Pointer.IsPress(input) then
		releases[frame] = {input = input, callback = callback}
	end
end

--[=[
	@interface States
	.Rest number | () -> number -- The value at rest
	.Hover number | () -> number -- The value while the pointer is over the button
	.Press number | () -> number -- The value while the button is pressed
	.Blocked (() -> boolean)? -- Returns true while hover and press effects are suppressed
	@within Pointer
]=]
export type States = {
	Rest: number | () -> number,
	Hover: number | () -> number,
	Press: number | () -> number,
	Blocked: (() -> boolean)?
}

--[=[
	Calls `set` when the pointer enters, leaves, presses, or releases the button. Function-valued states
	are evaluated on each change. The second argument is true when returning to rest.

	@param button GuiButton -- The button
	@param set (value: number, settle: boolean?) -> () -- Shows a value, usually a `Motion.Bind` setter
	@param states States -- The value of each state
	@return () -> () -- Disconnects the button
]=]
function Pointer.Hover(button: GuiButton, set: (number, boolean?) -> (), states: States): () -> ()
	local function value(state: number | () -> number): number
		return if type(state) == "function" then state() else state
	end
	local function blocked(): boolean
		return states.Blocked ~= nil and states.Blocked()
	end

	local connections = {
		button.MouseEnter:Connect(function()
			if not blocked() then
				set(value(states.Hover))
			end
		end),
		button.MouseLeave:Connect(function()
			set(value(states.Rest), true)
		end),
		button.MouseButton1Down:Connect(function()
			if not blocked() then
				set(value(states.Press))
			end
		end),
		button.InputBegan:Connect(function(input)
			Pointer.TrackRelease(button, input, function(ended)
				local over = ended.UserInputType == Enum.UserInputType.MouseButton1 and Pointer.Over(button, ended)
				if over and not blocked() then
					set(value(states.Hover))
				else
					set(value(states.Rest), true)
				end
			end)
		end)
	}
	return function()
		for _, connection in connections do
			connection:Disconnect()
		end
	end
end

return Pointer
