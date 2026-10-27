--[=[
	A text field.

	@class Input
	@location internals/primitives
]=]
local State = require("../public")
local UserInputService = game:GetService("UserInputService")

local Class = require("../services/class")
local Element = require("../components/element")
local Theme = require("../services/theme")
local Textbox = require("../components/textbox")
local Widget = require("./widget")

--[=[
	@prop Value string -- The current text
	@prop Numeric boolean -- Only accept numbers
	@prop Finished boolean -- Only commit the text when enter is pressed
]=]
local Input = Class.Extend({Type = "Input"}, Widget)

--[=[
	@interface InputConfig
	.Name string? -- Persistence key; duplicate names share the same registry slot.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Value string? -- Initial text; defaults to the empty string.
	.Placeholder string? -- Hint shown while the field is empty.
	.Numeric boolean? -- Restricts input to a signed decimal representation; incomplete values remain editable.
	.Finished boolean? -- When true, commit and notify only after Enter; otherwise notify as text changes.
	.MaxLength number? -- Maximum text length applied to user and programmatic updates.
	.Callback ((value: string) -> ())? -- Receives committed text.
	@within Input
]=]
export type Config = {
	Name: string?, Title: string, Description: string?, Persist: boolean?, Value: string?,
	Placeholder: string?, Numeric: boolean?, Finished: boolean?, MaxLength: number?,
	Callback: ((value: string) -> ())?
}

--[=[
	Creates an input whose callback timing is controlled by `Finished`. In finished mode,
	focus loss without Enter does not commit the field's text.

	@param config Config -- Initial text, validation and commit behavior, and callback.
	@param parent Container -- The container to draw the input in
	@return [Input](Input.md) -- The input widget added to the parent container.
]=]
function Input.New(config: Config, parent: any): any
	assert(config.Title, "Input - Missing Title")

	local numeric = config.Numeric
	local finished = config.Finished
	local maxLength = config.MaxLength
	if type(config) == "table" then
		if numeric == nil then
			numeric = rawget(config, "Numeric")
		end
		if finished == nil then
			finished = rawget(config, "Finished")
		end
		if maxLength == nil then
			maxLength = rawget(config, "_maxLength")
		end
	end
	local self = Class.New(Input, {Numeric = numeric or false, Finished = finished or false})
	local element = Element.New(config.Title, config.Description, parent.Container, false, parent._window)
	element.LabelHolder.Size = UDim2.new(0.50, -14, 0, 0)

	local textbox = Textbox.New(element.Frame, true)
	textbox.Input.TextXAlignment = Enum.TextXAlignment.Left
	textbox.Frame.Position = UDim2.new(1, -12, 0.5, 0)
	textbox.Frame.AnchorPoint = Vector2.new(1, 0.5)
	textbox.Frame.Size = UDim2.fromScale(0.40, 0)
	Theme:Height(textbox.Frame, "Control")

	local initial = config.Value or ""
	if maxLength and #initial > maxLength then
		initial = string.sub(initial, 1, maxLength)
	end
	textbox.Input.Text = initial
	textbox.Input.PlaceholderText = config.Placeholder or ""

	self._box = textbox.Input
	self._maxLength = maxLength
	self._committed = initial

	local SWIPE_THRESHOLD = 10
	local activeTouch: InputObject? = nil
	local touchStart: Vector2? = nil
	local touchMoved = false

	textbox.Input.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
				if textbox.Input:IsFocused() then
					textbox.Input:ReleaseFocus()
				end
				return
			end
			activeTouch = input
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
			touchMoved = false
		end
	end)

	State.Connect(UserInputService.InputChanged, function(input)
		if activeTouch and input == activeTouch and touchStart then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - touchStart
			if delta.Magnitude > SWIPE_THRESHOLD then
				touchMoved = true
				if textbox.Input:IsFocused() then
					textbox.Input:ReleaseFocus()
				end
			end
		end
	end, element.Frame)

	State.Connect(UserInputService.InputEnded, function(input)
		if activeTouch and input == activeTouch then
			if touchMoved and textbox.Input:IsFocused() then
				textbox.Input:ReleaseFocus()
			end
			activeTouch = nil
			touchStart = nil
		end
	end, element.Frame)

	self:_bind(element)
	Class.Define(self, {Value = Input._apply})
	self:From({Title = config.Title, Description = config.Description, Callback = config.Callback})
	self._storage.Value = initial

	local box = textbox.Input
	if self.Finished then
		box.FocusLost:Connect(function(enter)
			if enter then
				self:SetValue(box.Text)
			end
		end)
	else
		box:GetPropertyChangedSignal("Text"):Connect(function()
			-- `_apply` writes the box too, and that write must not fire the callbacks a second time
			if box.Text ~= self.Value then
				self:SetValue(box.Text)
			end
		end)
	end

	return self
end

function Input:_apply(value: string)
	local text = value
	if self._maxLength and #text > self._maxLength then
		text = string.sub(text, 1, self._maxLength)
	end
	-- Incomplete numeric input remains editable while the user types.
	if self.Numeric and not string.match(text, "^%-?%d*%.?%d*$") then
		text = self._committed
	end

	self._committed = text
	self._storage.Value = text
	self._box.Text = text

	self:_fire(text)
end

function Input:_load(data: any)
	if type(data) == "string" then
		self:SetValue(data)
	end
end

return Input
