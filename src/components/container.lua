--[=[
	The base class for anything widgets can be added to. Every factory takes the widget's config table; configs with a
	`Name` are also registered in `Apogee.Widgets` under that name and saved in configs unless `Persist` is false.

	@class Container
	@location internals/components
]=]
local Class = require("../services/class")
local Config = require("../services/config")

local Button = require("../primitives/button")
local ColorPicker = require("../primitives/colorpicker")
local Dropdown = require("../primitives/dropdown")
local Input = require("../primitives/input")
local Keybind = require("../primitives/keybind")
local Paragraph = require("../primitives/paragraph")
local Slider = require("../primitives/slider")
local Toggle = require("../primitives/toggle")
local Args = require("../services/args")

local Container = Class.Extend({})
local WIDGETS = {
	Button = Button,
	ColorPicker = ColorPicker,
	Dropdown = Dropdown,
	Input = Input,
	Keybind = Keybind,
	Paragraph = Paragraph,
	Slider = Slider,
	Toggle = Toggle
}

local POSITIONAL = {
	-- Positional forms take the label first, then the most frequently supplied behavior/value.
	Button = {"Title", "Callback", "Description"},
	ColorPicker = {"Title", "Value", "Callback", "Transparency"},
	Dropdown = {"Title", "Values", "Value", "Callback"},
	Input = {"Title", "Value", "Callback", "Placeholder"},
	Keybind = {"Title", "Value", "Callback", "Mode", "Pressed"},
	Paragraph = {"Title", "Description"},
	Slider = {"Title", "Value", "Min", "Max", "Rounding", "Callback"},
	Toggle = {"Title", "Value", "Callback", "Description"}
}

-- fields whose positional value is a table, so a table there is that value and not the options
local TABLE_FIELDS = {Dropdown = {Values = true, Value = true}}
local function configFor(name: string, first: any, ...: any): {[string]: any}
	return Args.Config(POSITIONAL[name], TABLE_FIELDS[name], first, ...)
end

--[=[
	@method Button
	@within Container
	@param config Button.Config
	@return [Button](../primitives/Button.md) -- The button widget added to this container.
]=]
--[=[
	@method ColorPicker
	@within Container
	@param config ColorPicker.Config
	@return [ColorPicker](../primitives/ColorPicker.md) -- The color picker widget added to this container.
]=]
--[=[
	@method Dropdown
	@within Container
	@param config Dropdown.Config
	@return [Dropdown](../primitives/Dropdown.md) -- The dropdown widget added to this container.
]=]
--[=[
	@method Input
	@within Container
	@param config Input.Config
	@return [Input](../primitives/Input.md) -- The input widget added to this container.
]=]
--[=[
	@method Keybind
	@within Container
	@param config Keybind.Config
	@return [Keybind](../primitives/Keybind.md) -- The keybind widget added to this container.
]=]
--[=[
	@method Paragraph
	@within Container
	@param config Paragraph.Config
	@return [Paragraph](../primitives/Paragraph.md) -- The paragraph widget added to this container.
]=]
--[=[
	@method Slider
	@within Container
	@param config Slider.Config
	@return [Slider](../primitives/Slider.md) -- The slider widget added to this container.
]=]
--[=[
	@method Toggle
	@within Container
	@param config Toggle.Config
	@return [Toggle](../primitives/Toggle.md) -- The toggle widget added to this container.
]=]
for name, widget in WIDGETS do
	Container[name] = function(self, config: any, ...: any): any
		config = configFor(name, config, ...)
		assert(type(config) == "table", name .. " - Config must be a table")

		local object = widget.New(config, self)
		if self.Type == "Section" then
			object._element:Group(self:_row(), self)
		elseif self.Type == "Layout" then
			self:_attach(object)
		elseif (self.Type == "Tab" or self.Type == "Popup") and self._updateCanvas then
			self:_updateCanvas()
		end
		if config.Name then
			Config.Widgets[config.Name] = object
			object._name = config.Name
			object._persist = config.Persist ~= false
		end
		return object
	end
end

--[=[
	Adds a nested X/Y layout of widgets and same-size subcontainers.

	@param config Layout.Config -- Optional axis and pixel gap.
	@return [Layout](Layout.md) -- The new layout container.
]=]
function Container:Layout(config: any, ...: any): any
	config = Args.Config({"Axis", "Gap"}, nil, config, ...)
	assert(type(config) == "table", "Layout - Config must be a table")
	return require("./layout").New(config, self)
end

return Container
