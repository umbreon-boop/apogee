--[=[
	A color swatch that opens a picker dialog when clicked.

	@class ColorPicker
	@location internals/primitives
]=]
local Class = require("../services/class")
local Element = require("../components/element")
local Palette = require("../components/palette")
local Style = require("../assets/themes")
local Frame = require("../components/frame")
local Creator = require("../services/creator")
local Widget = require("./widget")

--[=[
	@prop Value Color3 -- The current color
	@prop Transparency number -- The current transparency, from 0 to 1
]=]
local ColorPicker = Class.Extend({Type = "ColorPicker"}, Widget)

--[=[
	@interface ColorPickerConfig
	.Name string? -- Persistence key for this widget.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Value Color3 -- Required initial color.
	.Transparency number? -- Initial alpha from zero (opaque) to one (transparent); presence enables alpha editing.
	.Callback ((value: Color3, transparency: number?) -> ())? -- Receives color and optional transparency.
	@within ColorPicker
	Transparency is stored separately from Color3. Supplying its initial value enables
	the alpha slider and includes transparency in change notifications.
]=]
export type Config = {
	Name: string?, Title: string, Description: string?, Persist: boolean?, Value: Color3,
	Transparency: number?, Callback: ((value: Color3, transparency: number?) -> ())?
}

--[=[
	Creates a new color picker. Use `Container:ColorPicker` instead of calling this directly.

	@param config Config -- Initial color, optional transparency, labels, and callback.
	@param parent Container -- The container to draw the color picker in
	@return [ColorPicker](ColorPicker.md) -- The color picker widget added to the parent container.
]=]
function ColorPicker.New(config: Config, parent: any): any
	assert(config.Title, "ColorPicker - Missing Title")
	assert(config.Value, "ColorPicker - Missing Value")

	local owningWindow = parent._window
	local scroll = parent.ScrollFrame or (if parent.Container and parent.Container:IsA("ScrollingFrame") then parent.Container else nil)
	local self = Class.New(ColorPicker, {
		Opened = false,
		_alpha = config.Transparency ~= nil,
		_window = owningWindow
	})
	local element = Element.New(config.Title, config.Description, parent.Container, true, parent._window)
	element.LabelHolder.Size = UDim2.new(0.60, -14, 0, 0)

	local swatch = Creator:New("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = config.Value
	}, {Frame.Corner(Style.Radius.Small)})
	local triggerFrame = Creator:New("Frame", {
		Size = UDim2.fromOffset(28, 28),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Parent = element.Frame,
		BackgroundTransparency = 0,
		Themed = {BackgroundColor3 = "Control"}
	}, {Frame.Corner(Style.Radius.Small), swatch})

	self._swatch = swatch
	self._trigger = triggerFrame

	self:_bind(element)
	Class.Define(self, {
		Value = function(picker, value: Color3)
			picker:SetValue(value)
		end,
		Transparency = function(picker, value: number)
			picker:SetValue(picker.Value, value)
		end
	})
	self:From({Title = config.Title, Description = config.Description, Callback = config.Callback})
	-- construction shows the value without firing the callbacks
	local hue, saturation, value = config.Value:ToHSV()
	self:_store(hue, saturation, value, if type(config.Transparency) == "number" then config.Transparency else 0)

	local palette = Palette.New(self, self._window, self.Title, self._alpha, scroll)
	self._palette = palette

	element.Frame.MouseButton1Click:Connect(function()
		if self.Opened then
			self:Close()
		else
			self:Open()
		end
	end)

	return self
end

--[=[
	Opens the color picker popup.
]=]
function ColorPicker:Open()
	self._palette:Open()
end

--[=[
	Closes the color picker popup.
]=]
function ColorPicker:Close()
	self._palette:Close()
end

-- stores the working hue, saturation and value with the color they make, and repaints the swatch and the palette
function ColorPicker:_store(hue: number, saturation: number, value: number, transparency: number?)
	rawset(self, "Hue", hue)
	rawset(self, "Sat", saturation)
	rawset(self, "Vib", value)
	self._storage.Value = Color3.fromHSV(hue, saturation, value)
	self._storage.Transparency = transparency or self.Transparency or 0
	self._swatch.BackgroundColor3 = self.Value
	self._swatch.BackgroundTransparency = self.Transparency
	local palette = rawget(self, "_palette")
	if palette then
		palette.Hue, palette.Sat, palette.Vib = hue, saturation, value
		palette.Transparency = self.Transparency
		palette:Display()
	end
end

--[=[
	Sets the color from hue, saturation and value and fires the callbacks. The picker dialog calls this.

	@param hue number -- The hue, from 0 to 1
	@param saturation number -- The saturation, from 0 to 1
	@param value number -- The brightness, from 0 to 1
	@param transparency number? -- The new transparency, the current one when nil
	@private
]=]
function ColorPicker:_setHSV(hue: number, saturation: number, value: number, transparency: number?)
	self:_store(hue, saturation, value, transparency)
	self:_fire(self.Value, self.Transparency)
end

--[=[
	Sets the color and fires the callbacks.

	@param color Color3 -- The new color
	@param transparency number? -- The new transparency, the current one when nil
]=]
function ColorPicker:SetValue(color: Color3, transparency: number?)
	local hue, saturation, value = color:ToHSV()
	-- a grey or black color has no hue, so the picker keeps the hue it shows
	if saturation == 0 or value == 0 then
		hue = rawget(self, "Hue") or hue
	end
	self:_setHSV(hue, saturation, value, transparency)
end

function ColorPicker:_save(): any
	return {self.Value, self.Transparency}
end

function ColorPicker:_load(data: { any })
	self:SetValue(data[1], data[2])
end

--[=[
	Sets a handler that is called immediately with the current color and transparency, and again on every change.

	@param handler (value: Color3, transparency: number) -> () -- The handler
]=]
function ColorPicker:OnChanged(handler: (value: Color3, transparency: number) -> ())
	self._changed = handler
	handler(self.Value, self.Transparency)
end

function ColorPicker:Destroy()
	self._palette:Destroy()
	Widget.Destroy(self)
end

return ColorPicker
