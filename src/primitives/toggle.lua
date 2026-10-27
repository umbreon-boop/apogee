--[=[
	An on/off switch.

	@class Toggle
	@location internals/primitives
]=]
local Class = require("../services/class")
local Element = require("../components/element")
local Motion = require("../services/motion")
local Style = require("../assets/themes")
local Frame = require("../components/frame")
local Creator = require("../services/creator")
local Theme = require("../services/theme")
local Widget = require("./widget")

--[=[
	@prop Value boolean -- Whether the toggle is on
]=]
local Toggle = Class.Extend({Type = "Toggle"}, Widget)
local TRACK = Vector2.new(42, 24)
local KNOB = 18
local PADDING = 3

--[=[
	@interface ToggleConfig
	.Name string? -- Persistence key for this widget.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Value boolean? -- Initial state; defaults to false.
	.Callback ((value: boolean) -> ())? -- Receives the new state after a change.
	@within Toggle
]=]
export type Config = {
	Name: string?,
	Title: string,
	Description: string?,
	Persist: boolean?,
	Value: boolean?,
	Callback: ((value: boolean) -> ())?
}

--[=[
	Draws the default switch: an accent track and a knob that moves when enabled.

	@param frame Frame -- The toggle's card frame
	@return { Paint: (enabled: boolean, instant: boolean?) -> (), Destroy: () -> () } -- The toggle look, with paint and cleanup operations.
]=]
function Toggle.Look(frame: Frame): any
	local knob = Creator:New("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(KNOB, KNOB),
		Position = UDim2.new(0, PADDING, 0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 2
	}, {Frame.Corner(Style.Radius.Small)})
	local fill = Creator:New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Themed = {BackgroundColor3 = "Accent"}
	}, {Frame.Corner(Style.Radius.Control)})
	local track = Creator:New("Frame", {
		Size = UDim2.fromOffset(TRACK.X, TRACK.Y),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = frame,
		BackgroundTransparency = 0,
		Themed = {BackgroundColor3 = "Control"}
	}, {
		Frame.Corner(Style.Radius.Control),
		Creator:New("UIStroke", {Thickness = 1, Enabled = false, Themed = {Color = "ControlBorder"}}),
		fill,
		knob
	})

	return {
		Knob = knob,
		Fill = fill,
		Paint = function(enabled: boolean, instant: boolean?)
			local positionX = PADDING
			local transparency = 1
			if enabled then
				positionX = TRACK.X - KNOB - PADDING
				transparency = 0
			end
			local position = {Position = UDim2.new(0, positionX, 0.5, 0)}
			local accent = {BackgroundTransparency = transparency}
			if instant then
				knob.Position = position.Position
				fill.BackgroundTransparency = accent.BackgroundTransparency
			else
				Motion.Tween(knob, position, 0.25)
				Motion.Tween(fill, accent, 0.25)
			end
		end,
		Destroy = function()
			track:Destroy()
		end
	}
end

function Toggle:_apply(value: any)
	local enabled = not not value
	self._storage.Value = enabled
	local look = Theme:Look(self.Frame)
	if look then
		look.Paint(enabled)
	end
	self:_fire(enabled)
end

--[=[
	Creates a boolean control. Assigning `Value` updates the control; callback timing
	follows the shared widget contract.
	The active `Toggle` look draws the switch.

	@param config Config -- Initial boolean value, labels, persistence settings, and callback.
	@param parent Container -- The container to draw the toggle in
	@return [Toggle](Toggle.md) -- The toggle widget added to the parent container.
]=]
function Toggle.New(config: Config, parent: any): any
	assert(config.Title, "Toggle - Missing Title")

	local self = Class.New(Toggle)
	local element = Element.New(config.Title, config.Description, parent.Container, true, parent._window)
	element.LabelHolder.Size = UDim2.new(1, -66, 0, 0)

	self:_bind(element)
	Class.Define(self, {Value = Toggle._apply})
	self:From({Title = config.Title, Description = config.Description, Callback = config.Callback})
	self._storage.Value = config.Value == true
	Theme:Style("Toggle", element.Frame)
	local function paint()
		Theme:Look(element.Frame).Paint(self.Value, true)
	end
	paint()
	-- a new look after a theme change shows the current value at once
	Theme:Track(paint, element.Frame)

	element.Frame.MouseButton1Click:Connect(function()
		self:SetValue(not self.Value)
	end)

	return self
end

Theme:RegisterComponent("Toggle", Toggle.Look)

return Toggle
