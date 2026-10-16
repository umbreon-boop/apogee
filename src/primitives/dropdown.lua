--[=[
	A single or multi select list that opens in a floating panel.
	@class Dropdown
	@location internals/primitives
]=]
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Class = require("../services/class")
local Element = require("../components/element")
local Images = require("../assets/images")
local Icon = require("../components/icon")
local Icons = require("../assets/icons")
local Motion = require("../services/motion")
local Pointer = require("../services/pointer")
local State = require("../public")
local Style = require("../assets/themes")
local Squircle = require("../components/frame")
local Theme = require("../services/theme")
local Creator = require("../services/creator")
local Fade = require("../services/fade")
local Widget = require("./widget")
local Measure = require("../services/measure")

--[=[
	@prop Value string? | { [string]: boolean } -- The selected value, or a set of selected values when `Multi`
	@prop Values { string } -- The available options
	@prop Multi boolean -- Whether several values can be selected
	@prop Opened boolean -- Whether the list is open
]=]
local Dropdown = Class.Extend({Type = "Dropdown"}, Widget)

--[=[
	@interface DropdownConfig
	.Name string? -- Persistence key for this widget.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Values { string } -- Ordered option labels; replacing this list reconciles the current selection.
	.Value (string | number | { string })? -- Initial option label or one-based index; multi mode accepts a list of labels.
	.Multi boolean? -- Enables set-valued selection; callbacks then receive a map from selected labels to true.
	.AllowNull boolean? -- Allows clearing a single selection; otherwise an available option remains selected.
	.Callback ((value: any) -> ())? -- Receives a label in single mode and a selected-label map in multi mode.
	@within Dropdown
	Selection is normalized against `Values`; indices resolve to the option at that position.
	In multi mode, the public `Value` is a map keyed by selected option label, while the
	initial config may provide a list of labels.
]=]
export type Config = {
	Name: string?, Title: string, Description: string?, Persist: boolean?, Values: { string },
	Value: (string | number | { string })?, Multi: boolean?, AllowNull: boolean?,
	Callback: ((value: any) -> ())?
}

local Option = {}
Option.__index = Option

local camera = Workspace.CurrentCamera
local MAX_VISIBLE = 10
local TRANSITION_DURATION = 0.2
local TRANSITION_EASING = Enum.EasingStyle.Quint
local TRANSITION_DIRECTION = Enum.EasingDirection.Out
-- A hidden list sits this many pixels lower and slides up while it fades in. Do not scale the list: under a
-- `UIScale` Roblox draws text at a whole font size rounded down, and the text then grows when the scale reaches 1.
local SHIFT = Style.Space.XXS

local isPress = Pointer.IsPress

function Option.New(dropdown: any, value: string): any
	local self = setmetatable({Value = value, Selected = false, _dropdown = dropdown}, Option)

	self.Label = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font),
		Text = value,
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(10, 0),
		Name = "ButtonLabel",
		Themed = {TextColor3 = "Text"}
	})

	self.Highlight = Squircle.New(Style.Squircle.Control, {
		ImageTransparency = 1,
		Themed = {ImageColor3 = "Hover"}
	})
	self.Frame = Creator:New("TextButton", {
		Size = UDim2.new(1, -5, 0, Theme:Size("Option")),
		BackgroundTransparency = 1,
		ZIndex = 23,
		Text = "",
		Parent = dropdown._list
	}, {self.Highlight, self.Label})

	local _, fade = Motion.Bind(1, self.Highlight, "ImageTransparency", true)
	self._fade = fade

	Pointer.Hover(self.Frame, fade, {
		Rest = function()
			return if self.Selected then 0.8 else 1
		end,
		Hover = function()
			return if self.Selected then 0.8 else 0.88
		end,
		Press = function()
			return if self.Selected then 0.75 else 0.82
		end
	})
	self.Frame.Activated:Connect(function()
		dropdown:_choose(self)
	end)

	self:Update()
	return self
end

function Option:Update()
	local dropdown = self._dropdown
	if dropdown.Multi then
		self.Selected = dropdown.Value[self.Value] == true
	else
		self.Selected = dropdown.Value == self.Value
	end
	Theme:Override(self.Highlight, {ImageColor3 = if self.Selected then "Accent" else "Hover"})
	Theme:Override(self.Label, {TextColor3 = if self.Selected then "Accent" else "Text"})
	self._fade(if self.Selected then 0.8 else 1)
end

--[=[
	Creates a new dropdown. Use `Container:Dropdown` instead of calling this directly.

	@param config Config -- Available options, initial selection, selection mode, and callback.
	@param parent Container -- The container to draw the dropdown in
	@return [Dropdown](Dropdown.md) -- The dropdown widget added to the parent container.
]=]
function Dropdown.New(config: Config, parent: any): any
	assert(config.Title, "Dropdown - Missing Title")
	assert(config.Values, "Dropdown - Missing Values")
	local self = Class.New(Dropdown, {
		Multi = config.Multi or false,
		Opened = false,
		_allowNull = config.AllowNull,
		_options = {},
		_scrollFrame = parent.ScrollFrame
	})
	self._window = parent._window
	local element = Element.New(config.Title, config.Description, parent.Container, false, parent._window)
	element.LabelHolder.Size = UDim2.new(0.50, -14, 0, 0)

	local display = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Text = "Value",
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -24, 0, 14),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Themed = {TextColor3 = "Text"}
	})

	local inner = Creator:New("TextButton", {
		Size = UDim2.fromScale(0.40, 0),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = element.Frame
	}, {
		Squircle.New(Style.Squircle.Control, {
			ImageTransparency = 0,
			Themed = {ImageColor3 = "Field"}
		}),
		Squircle.New(Style.Squircle.Control, {
			Name = "Hover",
			ImageTransparency = 1,
			Themed = {ImageColor3 = "Hover"}
		}),
		Squircle.New(Style.Squircle.Control, {
			Shape = "Outline",
			Visible = false,
			Themed = {ImageColor3 = "ControlBorder"}
		}),
		Icon.New(Icons.GetIcon("chevron-down"), {
				Name = "Chevron",
				Size = UDim2.fromOffset(14, 14),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -6, 0.5, 0),
				BackgroundTransparency = 1,
				Themed = {ImageColor3 = "SubText"}
			}),
		display
	})
	Theme:Height(inner, "Control")

	-- a theme without icons gives the value the space of the chevron
	Icon.Watch(inner:FindFirstChild("Chevron"), function(shown)
			display.Size = UDim2.new(1, if shown then -24 else -16, 0, 14)
		end)

	local _, innerFade = Motion.Bind(1, inner:FindFirstChild("Hover"), "ImageTransparency", true)
	Pointer.Hover(inner, innerFade, {Rest = 1, Hover = 0.88, Press = 0.82})

	local layout = Creator:New("UIListLayout", {Padding = UDim.new(0, Style.Space.XXXS)})
	local list = Creator:New("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -20),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		BottomImage = Images.ScrollBottom,
		MidImage = Images.ScrollMiddle,
		TopImage = Images.ScrollTop,
		ScrollBarImageTransparency = 0.95,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0)
	}, {layout})

	local holder = Creator:New("Frame", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 22
	}, {
		Squircle.New(Style.Squircle.Container, {
			ImageTransparency = 0,
			Themed = {ImageColor3 = "Overlay"}
		}),
		Squircle.New(Style.Squircle.Container, {Shape = "Outline", Visible = false, Themed = {ImageColor3 = "Border"}}),
		list
	})

	local barrier = Creator:New("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Active = true,
		ZIndex = 20,
		Parent = self._window._gui,
		Visible = false
	})

	local canvas = Creator:New("Frame", {
		BackgroundTransparency = 1,
		Active = true,
		Size = UDim2.fromOffset(Theme:Size("ListWidth"), 300),
		Parent = self._window._gui,
		Visible = false,
		ZIndex = 22
	}, {holder, Creator:New("UISizeConstraint", {MinSize = Vector2.new(Theme:Size("ListWidth"), 0)})})
	if self._window then
		self._window._openFrames[self] = canvas
	end

	self._display = display
	self._inner = inner
	self._layout = layout
	self._list = list
	self._holder = holder
	self._canvas = canvas
	self._barrier = barrier

	self:_bind(element)
	Class.Define(self, {
		Value = Dropdown._apply,
		Values = function(dropdown)
			dropdown:_build()
		end
	})
	self:From({Title = config.Title, Description = config.Description, Callback = config.Callback})
	self._storage.Values = config.Values
	self._storage.Value = self:_resolve(config.Value)
	self._last = self._storage.Value

	-- the slide offset of the list; the list moves only while it shows
	self._shift = Creator:New("NumberValue", {Value = SHIFT})
	self._shift.Changed:Connect(function()
		if canvas.Visible then
			self:_position()
		end
	end)

	self:_position()
	self:_resize()
	self:_build()
	Theme:Track(function()
		canvas:FindFirstChildOfClass("UISizeConstraint").MinSize = Vector2.new(Theme:Size("ListWidth"), 0)
		self:_build()
		task.spawn(self._resize, self)
	end, inner)

	-- only an open list follows its field; a closed one would recompute on every scroll and window move
	inner:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		if self.Opened then
			self:_position()
		end
	end)
	inner.MouseButton1Click:Connect(function()
		self:Open()
	end)
	barrier.InputBegan:Connect(function(input)
		if isPress(input) then
			self:Close()
		end
	end)
	barrier.MouseButton1Click:Connect(function()
		self:Close()
	end)
	State.Connect(UserInputService.InputBegan, function(input)
		if not isPress(input) then
			return
		end

		local position, size = holder.AbsolutePosition, holder.AbsoluteSize
		local x, y = input.Position.X, input.Position.Y
		if x < position.X or x > position.X + size.X or y < (position.Y - 20 - 1) or y > position.Y + size.Y then
			self:Close()
		end
	end, inner)

	return self
end

-- Turns an index, an option, a list of them or a set `{[option] = true}` into the stored value.
-- Unknown options are dropped.
function Dropdown:_resolve(value: any): any
	local values = self.Values
	local function option(item: any): string?
		local name = if type(item) == "number" then values[item] else item
		return if table.find(values, name) then name else nil
	end
	if not self.Multi then
		return option(value)
	end

	local selected = {}
	for key, item in if type(value) == "table" then value else {value} do
		local name = if type(key) == "number" then option(item) elseif item then option(key) else nil
		if name then
			selected[name] = true
		end
	end
	return selected
end

function Dropdown:_position()
	local inner, canvas = self._inner, self._canvas
	local offset = 0
	if camera.ViewportSize.Y - inner.AbsolutePosition.Y < canvas.AbsoluteSize.Y - 5 then
		offset = canvas.AbsoluteSize.Y - 5 - (camera.ViewportSize.Y - inner.AbsolutePosition.Y) + 40
	end
	-- whole pixels, so the edges and text of the list render sharp
	local shift = math.round(self._shift.Value)
	canvas.Position = UDim2.fromOffset(math.round(inner.AbsolutePosition.X - 1), math.round(inner.AbsolutePosition.Y - 5 - offset) + shift)
end

-- The height comes from the row count, not from a measurement: a layout measures new rows only a frame later, and
-- a measurement during the open animation is scaled, so a measured list would be too short and cut its last row.
function Dropdown:_resize()
	local rows = #self.Values
	local height = if rows > MAX_VISIBLE
		then Theme:Size("List")
	else rows * Theme:Size("Option") + math.max(rows - 1, 0) * Style.Space.XXXS + 20
	local width = 0
	for _, option in self._options or {} do
		width = math.max(width, Measure.Text(option.Label).X)
	end
	width = math.max(width + 30, Measure.Offset(self._inner, self._inner.AbsoluteSize.X), Theme:Size("ListWidth"))
	self._canvas.Size = UDim2.fromOffset(math.round(width), height)
end

function Dropdown:_build()
	self._stale = true
	self:Display()
	if self.Opened then
		self:_rows()
	end
end

function Dropdown:_rows()
	if not self._stale then
		return
	end
	self._stale = false
	for _, child in self._list:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local options = {}
	for _, value in self.Values do
		local option = Option.New(self, value)
		table.insert(options, option)
	end
	self._options = options
	self._list.CanvasSize = UDim2.fromOffset(0, Measure.Rows(self._list))

	-- `Values` calls this from a property setter, and a measurement can yield, so it runs in its own thread
	task.spawn(self._resize, self)
end

function Dropdown:_choose(option: any)
	local selected = not option.Selected
	local active = self:GetActiveValues()
	local count = if type(active) == "table" then #active else active
	if count == 1 and not selected and not self._allowNull then
		return
	end

	if self.Multi then
		option.Selected = selected
		self.Value[option.Value] = if selected then true else nil
	else
		option.Selected = selected
		self._storage.Value = if selected then option.Value else nil
		self._last = self._storage.Value
		for _, other in self._options do
			other:Update()
		end
	end

	option:Update()
	self:Display()
	self:_fire(self.Value)
end

function Dropdown:_apply(value: any)
	local resolved = self:_resolve(value)
	if self.Multi or resolved ~= nil or (value == nil and self._allowNull) then
		self._storage.Value = resolved
	else
		-- an unknown value, or nil without AllowNull, keeps the current selection
		self._storage.Value = rawget(self, "_last")
	end

	self._last = self._storage.Value
	self:Display()
	for _, option in self._options do
		option:Update()
	end
	self:_fire(self.Value)
end

--[=[
	Opens the option list.
]=]
function Dropdown:Open()
	if not self.Values or #self.Values == 0 then
		return
	end
	rawset(self, "Opened", true)
	self:_rows()
	State:ResetHighlights()
	-- a closing list continues from where it is
	if not self._canvas.Visible then
		self._shift.Value = SHIFT
	end
	self:_position()
	self._scrollFrame.ScrollingEnabled = false
	self._barrier.Visible = true
	self._canvas.Visible = true
	-- the list fades in and slides up a little to the field
	Fade.To(self._canvas, true, TRANSITION_DURATION)
	Motion.Tween(self._shift, {Value = 0}, TRANSITION_DURATION, TRANSITION_EASING, TRANSITION_DIRECTION)
end

--[=[
	Closes the option list.
]=]
function Dropdown:Close()
	if not self.Opened then
		return
	end
	rawset(self, "Opened", false)
	self._scrollFrame.ScrollingEnabled = true
	Motion.Tween(self._shift, {Value = SHIFT}, TRANSITION_DURATION, TRANSITION_EASING, TRANSITION_DIRECTION)
	Fade.To(self._canvas, false, TRANSITION_DURATION, function()
		if not self.Opened then
			self._canvas.Visible = false
			self._barrier.Visible = false
		end
	end)
end

--[=[
	Refreshes the text shown in the collapsed dropdown.
]=]
function Dropdown:Display()
	local text = ""
	if self.Multi then
		local selected = {}
		for _, value in self.Values do
			if self.Value[value] then
				table.insert(selected, value)
			end
		end
		text = table.concat(selected, ", ")
	else
		text = self.Value or ""
	end
	self._display.Text = if text == "" then "--" else text
end

--[=[
	Returns the selected values for multi dropdowns, otherwise 1 when a value is selected and 0 when none is.
	@return { string } | number -- The selected labels in multi mode, or 1 when selected and 0 when empty.
]=]
function Dropdown:GetActiveValues(): any
	if not self.Multi then
		return if self.Value then 1 else 0
	end

	local values = {}
	for value in self.Value do
		table.insert(values, value)
	end
	return values
end

--[=[
	Replaces the available options and rebuilds the list.
	@param values { string }? -- The new options, the current ones are kept when nil
]=]
function Dropdown:SetValues(values: { string }?)
	if values then
		self._storage.Values = values
	end
	self:_build()
end

--[=[
	Selects a value, or a set of values for multi dropdowns, and fires the callbacks.
	@param value (string | number | { string } | { [string]: boolean })? -- An option or its index; a list or a set of them for multi dropdowns
]=]
function Dropdown:SetValue(value: any)
	self:_apply(value)
end

--[=[
	Destroys the dropdown and its floating list.
]=]
function Dropdown:Destroy()
	Widget.Destroy(self)
	self._barrier:Destroy()
	self._canvas:Destroy()
end

return Dropdown
