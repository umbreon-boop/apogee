local Apogee = require("../src/init")

-- Shorthand: ColorPicker(title, value, callback, transparency, options)
local window = Apogee:Window("ColorPicker example")
local tab = window:Tab("Color")

local DEFAULT = Color3.fromRGB(66, 150, 250)

local function report(color, transparency)
	print("Color:", color, "alpha:", transparency)
end

tab:Section("Config table, all fields"):ColorPicker({
	Name = "ColorPickerTable",
	Title = "Accent color",
	Description = "Supplying Transparency enables alpha editing.",
	Persist = true,
	Value = DEFAULT,
	Transparency = 0,
	Callback = report
})

-- Title and Value are the only required fields.
tab:Section("Config table, required only"):ColorPicker({
	Title = "Accent color",
	Value = DEFAULT
})

tab:Section("Shorthand, all fields"):ColorPicker("Accent color", DEFAULT, function(color, transparency)
	print("Color:", color, "alpha:", transparency)
end, 0, {
	Name = "ColorPickerShorthand",
	Description = "Supplying Transparency enables alpha editing.",
	Persist = true
})

tab:Section("Shorthand, required only"):ColorPicker("Accent color", DEFAULT)

window:Settings()
