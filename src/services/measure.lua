--[=[
	Measures text and converts absolute pixel measurements to scale-independent offset units.

	@class Measure
	@location internals/services
]=]
local TextService = game:GetService("TextService")

local Measure = {}
local CACHE_LIMIT = 512
local cache, cached = {}, 0

--[=[
	Returns the product of every `UIScale` on the instance and its ancestors.

	@param instance Instance -- The instance
	@return number -- The product of UIScale values on the instance and its ancestors.
]=]
function Measure.Scale(instance: Instance): number
	local scale = 1
	local node: Instance? = instance
	while node do
		local uiScale = node:FindFirstChildOfClass("UIScale")
		if uiScale then
			scale *= uiScale.Scale
		end
		node = node.Parent
	end
	return scale
end

--[=[
	Converts an absolute measurement of `instance` into offset units.

	@param instance Instance -- The instance that was measured, or the parent of a measured layout
	@param value number | Vector2 -- The absolute measurement
	@return number | Vector2 -- The measurement converted from absolute pixels to offset units.
]=]
function Measure.Offset(instance: Instance, value: any): any
	local scale = Measure.Scale(instance)
	return if scale > 0 then value / scale else value
end

--[=[
	Returns visible row heights and layout padding in offset units.

	@param frame GuiObject -- The frame whose children are the rows
	@return number -- The content height of the frame in offset units.
]=]
function Measure.Rows(frame: GuiObject): number
	local height, rows = 0, 0
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") and child.Visible ~= false then
			height += child.Size.Y.Offset
			rows += 1
		end
	end
	local layout = frame:FindFirstChildOfClass("UIListLayout")
	if layout and rows > 1 then
		height += (rows - 1) * layout.Padding.Offset
	end
	local padding = frame:FindFirstChildOfClass("UIPadding")
	if padding then
		height += padding.PaddingTop.Offset + padding.PaddingBottom.Offset
	end
	return height
end

--[=[
	Returns text bounds at scale 1, before or during rendering. This may yield while a font loads.

	@param label TextLabel | TextButton | TextBox -- The label whose text is measured
	@param width number? -- The width at which the text wraps, or nil for one line
	@return Vector2 -- The rendered text bounds at scale 1, in offset units.
	@yields
]=]
function Measure.Text(label: any, width: number?): Vector2
	local text = label.Text
	if text == "" then
		return Vector2.zero
	end
	local font = label.FontFace
	local key = table.concat({text, font.Family, tostring(font.Weight), tostring(font.Style), label.TextSize, width or 0, tostring(label.RichText)}, "\0")
	local size = cache[key]
	if size then
		return size
	end
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = label.TextSize
	params.RichText = label.RichText == true
	if width then
		params.Width = width
	end
	local ok, result = pcall(TextService.GetTextBoundsAsync, TextService, params)
	if not ok then
		-- a font that cannot load: the render measurement is better than nothing
		return label.TextBounds
	end
	if cached >= CACHE_LIMIT then
		cache, cached = {}, 0
	end
	cache[key] = result
	cached += 1
	return result
end

return Measure
