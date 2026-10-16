--[=[
	Unified mouse and touch dragging. A drag starts when a press lands on the target, follows that same pointer until it
	is released and optionally locks a scrolling frame so touch drags do not scroll the page underneath.

	@class Drag
	@location internals/services
]=]
local UserInputService = game:GetService("UserInputService")
local Pointer = require("./pointer")

local Drag = {}

-- The widget currently holding the shared drag lock, regardless of which drag handler owns it.
Drag._active = nil

local isPress = Pointer.IsPress

--@inline
local function follows(active: InputObject, input: InputObject): boolean
	return if active.UserInputType == Enum.UserInputType.Touch
		then input == active
	else input.UserInputType == Enum.UserInputType.MouseMovement
end

--@inline
local function releases(active: InputObject, input: InputObject): boolean
	return if active.UserInputType == Enum.UserInputType.Touch
		then input == active
	else input.UserInputType == Enum.UserInputType.MouseButton1
end

local activeTouches: { [InputObject]: boolean } = {}

--[=[
	Calls `handler` with the pointer position when a drag starts on `target` and on every move until it ends.

	@param target GuiObject -- The instance that starts the drag
	@param handler (position: Vector2) -> () -- Called with the pointer position in screen space
	@param scroll ScrollingFrame? -- A frame whose scrolling is disabled while dragging
	@param finished (() -> ())? -- Called once the drag ends
	@return () -> () -- Stops the dragging and disconnects it, which also happens when the target is destroyed
]=]
function Drag.Bind(
		target: GuiObject,
		handler: (position: Vector2) -> (),
		scroll: ScrollingFrame?,
		finished: (() -> ())?
	): () -> ()
	local active: InputObject? = nil
	target.Active = true

	local function stop()
		if Drag._active == target then
			Drag._active = nil
		end
		if active and active.UserInputType == Enum.UserInputType.Touch then
			activeTouches[active] = nil
		end
		active = nil
		if scroll then
			scroll.ScrollingEnabled = true
		end
		if finished then
			finished()
		end
	end

	local began = target.InputBegan:Connect(function(input)
		if active or not isPress(input) or Drag._active then
			return
		end
		if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch and activeTouches[input] then
			return
		end

		Drag._active = target
		active = input
		if input.UserInputType == Enum.UserInputType.Touch then
			activeTouches[input] = true
		end
		if scroll then
			scroll.ScrollingEnabled = false
		end
		handler(Vector2.new(input.Position.X, input.Position.Y))
	end)

	local changed = UserInputService.InputChanged:Connect(function(input)
		if active and follows(active, input) then
			handler(Vector2.new(input.Position.X, input.Position.Y))
		end
	end)

	local ended = UserInputService.InputEnded:Connect(function(input)
		if active and releases(active, input) then
			stop()
		end
	end)

	local function dispose()
		began:Disconnect()
		changed:Disconnect()
		ended:Disconnect()
		if active then
			stop()
		end
	end
	-- a destroyed target never releases the shared drag lock by itself
	target.Destroying:Connect(dispose)
	return dispose
end

return Drag
