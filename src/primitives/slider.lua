--[=[
	A draggable rail for picking a number within a range.

	@class Slider
	@location internals/primitives
]=]
local Class = require("../services/class")
local Drag = require("../services/drag")
local Element = require("../components/element")
local Motion = require("../services/motion")
local State = require("../public")
local Style = require("../assets/themes")
local Frame = require("../components/frame")
local Creator = require("../services/creator")
local Theme = require("../services/theme")
local Widget = require("./widget")

--[=[
	@prop Value number -- The current value
	@prop Min number -- The lowest value
	@prop Max number -- The highest value
	@prop Rounding number -- The number of decimals kept
]=]
local Slider = Class.Extend({Type = "Slider"}, Widget)
local KNOB_SIZE = 16
local KNOB_ACTIVE_SIZE = 20
local HITBOX_HEIGHT = 32

--[=[
	@interface SliderConfig
	.Name string? -- Persistence key for this widget.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Value number -- Initial value, clamped to the inclusive range.
	.Min number -- Inclusive lower bound; must not exceed Max.
	.Max number -- Inclusive upper bound; must not be below Min.
	.Rounding number -- Decimal places retained after dragging or setting a value.
	.Callback ((value: number) -> ())? -- Receives the clamped, rounded value.
	@within Slider
]=]
export type Config = {
	Name: string?, Title: string, Description: string?, Persist: boolean?, Value: number,
	Min: number, Max: number, Rounding: number, Callback: ((value: number) -> ())?
}

--[=[
	Draws the default slider with an accent rail, draggable knob, and value label.

	@param frame Frame -- The slider's card frame
	@return { Paint: (value: number, scale: number, dragging: boolean) -> (), Rail: GuiObject, Hitbox: GuiButton, Destroy: () -> () } -- The slider look, with paint and cleanup operations.
]=]
function Slider.Look(frame: Frame): any
	local dot = Creator:New("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE),
		Themed = {BackgroundColor3 = "Accent"}
	}, {
		Frame.Corner(Style.Radius.Round),
		Creator:New("UIStroke", {Thickness = 2, Themed = {Color = "Surface"}})
	})
	local rail = Creator:New("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(7, 0),
		Size = UDim2.new(1, -14, 1, 0)
	}, {dot})
	local fill = Creator:New("Frame", {Size = UDim2.fromScale(0, 1), Themed = {BackgroundColor3 = "Accent"}}, {
		Frame.Corner(UDim.new(1, 0))
	})
	local display = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font),
		Text = "Value",
		TextSize = Style.Type.Small,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(60, 16),
		Position = UDim2.new(0, -6, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Themed = {TextColor3 = "SubText"}
	})
	-- an invisible button taller than the rail so the slider is easy to grab on touch screens
	local hitbox = Creator:New("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, KNOB_ACTIVE_SIZE, 0, HITBOX_HEIGHT),
		ZIndex = 2
	})
	local track = Creator:New("Frame", {
		Size = UDim2.new(0.40, 0, 0, 6),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Parent = frame,
		BackgroundTransparency = 0,
		Themed = {BackgroundColor3 = "Control"}
	}, {
		Frame.Corner(UDim.new(1, 0)),
		display,
		fill,
		rail,
		hitbox
	})

	local knob = Motion.Single(KNOB_SIZE, function(size)
		dot.Size = UDim2.fromOffset(size, size)
	end)
	return {
		Knob = dot,
		Fill = fill,
		Display = display,
		Rail = rail,
		Hitbox = hitbox,
		Paint = function(value: number, scale: number, dragging: boolean)
			dot.Position = UDim2.fromScale(scale, 0.5)
			fill.Size = UDim2.fromScale(scale, 1)
			display.Text = tostring(value)
			local size = KNOB_SIZE
			if dragging then size = KNOB_ACTIVE_SIZE end
			knob:Set(Motion.Spring(size, 8))
		end,
		Destroy = function()
			track:Destroy()
		end
	}
end

-- the position of a value on the rail, from 0 to 1
function Slider:_scale(value: number): number
	if self.Max == self.Min then
		return 0
	end
	return (value - self.Min) / (self.Max - self.Min)
end

function Slider:_paint()
	-- a slider destroyed during a drag has no look left when the drag ends
	local look = Theme:Look(self.Frame)
	if look and self.Value ~= nil then
		look.Paint(self.Value, self:_scale(self.Value), rawget(self, "_dragging") == true)
	end
end

-- binds dragging to the hitbox of the current look; the binding ends when the look is destroyed
function Slider:_connect(scroll: ScrollingFrame?)
	local look = Theme:Look(self.Frame)
	if rawget(self, "_hitbox") == look.Hitbox then
		return
	end
	self._hitbox = look.Hitbox
	Drag.Bind(look.Hitbox, function(position)
		self._dragging = true
		local scale = (position.X - look.Rail.AbsolutePosition.X) / look.Rail.AbsoluteSize.X
		local value = State:Round(self.Min + ((self.Max - self.Min) * math.clamp(scale, 0, 1)), self.Rounding)
		if value ~= self.Value then
			self:SetValue(value)
		else
			self:_paint()
		end
	end, scroll, function()
		self._dragging = false
		self:_paint()
	end)
end

function Slider:_reapply()
	if self.Value ~= nil then
		self:SetValue(self.Value)
	end
end

-- clamps a value to the range and rounds it
function Slider:_clamp(value: number | string): number
	return State:Round(math.clamp(tonumber(value) or self.Min, self.Min, self.Max), self.Rounding)
end

function Slider:_apply(value: number | string)
	local rounded = self:_clamp(value)
	self._storage.Value = rounded
	self:_paint()
	self:_fire(rounded)
end

--[=[
	Creates a slider and binds pointer dragging to the active theme look. Values assigned
	through the public setter are clamped and rounded before storage and callback delivery.

	@param config Config -- Initial value, inclusive range, rounding precision, and callback.
	@param parent Container -- The container to draw the slider in
	@return [Slider](Slider.md) -- The slider widget added to the parent container.
]=]
function Slider.New(config: Config, parent: any): any
	assert(config.Title, "Slider - Missing Title.")
	assert(config.Value, "Slider - Missing default value.")
	assert(config.Min, "Slider - Missing minimum value.")
	assert(config.Max, "Slider - Missing maximum value.")
	assert(config.Rounding, "Slider - Missing rounding value.")

	local self = Class.New(Slider)
	local element = Element.New(config.Title, config.Description, parent.Container, false, parent._window)
	element.LabelHolder.Size = UDim2.new(0.50, -14, 0, 0)

	self:_bind(element)
	Class.Define(self, {
		Value = Slider._apply,
		-- a new range or rounding clamps and redraws the current value
		Min = Slider._reapply,
		Max = Slider._reapply,
		Rounding = Slider._reapply
	})
	self:From({
		Title = config.Title,
		Description = config.Description,
		Callback = config.Callback,
		Min = config.Min,
		Max = config.Max,
		Rounding = config.Rounding
	})
	self._storage.Value = self:_clamp(config.Value)
	Theme:Style("Slider", element.Frame)
	self:_connect(parent.ScrollFrame)
	self:_paint()
	-- a new look after a theme change gets the dragging and shows the current value at once
	Theme:Track(function()
		self:_connect(parent.ScrollFrame)
		self:_paint()
	end, element.Frame)

	return self
end

Theme:RegisterComponent("Slider", Slider.Look)

return Slider
