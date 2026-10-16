--[=[
	Computes minimum layout widths and applies them to GUI objects so controls stop shrinking before they overlap.

	@class Resize
	@location internals/services
]=]
local Creator = require("./creator")

local Resize = {}

-- The widths preserve the fixed controls and leave enough room for each row's title and field.
local MINIMUM_WIDTH = {
	Button = 128,
	ColorPicker = 168,
	Dropdown = 200,
	Input = 200,
	Keybind = 200,
	Paragraph = 144,
	Slider = 200,
	Toggle = 160
}

--[=[
	Returns the minimum width required by a widget or layout.
	@param item any -- A widget or layout container
	@return number -- The minimum width needed to keep its contents from overlapping.
]=]
function Resize.MinimumWidth(item: any): number
	if item.Type == "Layout" then
		return item._minimumWidth or 0
	end
	return item._minimumWidth or MINIMUM_WIDTH[item.Type] or 160
end

--[=[
	Applies a minimum width while preserving any existing minimum height on the frame.
	@param frame GuiObject -- The frame to constrain
	@param width number -- The minimum width in pixels
]=]
function Resize.Apply(frame: GuiObject, width: number)
	local constraint = frame:FindFirstChildOfClass("UISizeConstraint")
	if not constraint then
		constraint = Creator:New("UISizeConstraint", {MinSize = Vector2.new(width, 0), Parent = frame})
	else
		local minimum = constraint.MinSize
		constraint.MinSize = Vector2.new(width, minimum.Y)
	end
end

-- Layout roots register their computed width so window resizing can respect it.
function Resize.Register(window: any, owner: any, width: number?)
	if not window then
		return
	end
	window._resizeMinimums = window._resizeMinimums or {}
	window._resizeMinimums[owner] = width
	if window._updateMinimumWidth then
		window:_updateMinimumWidth()
	end
end

function Resize.RequiredWidth(window: any): number
	local width = 0
	for _, required in window and window._resizeMinimums or {} do
		width = math.max(width, required or 0)
	end
	return width
end

return Resize
