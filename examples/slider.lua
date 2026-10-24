local Apogee = require("../src/init")

-- Shorthand: Slider(title, value, min, max, rounding, callback, options)
local window = Apogee:Window("Slider example")
local tab = window:Tab("Slider")

local function report(value)
	print("Volume:", value)
end

tab:Section("Config table, all fields"):Slider({
	Name = "SliderTable",
	Title = "Volume",
	Description = "Values are clamped to the range and rounded before callbacks run.",
	Persist = true,
	Value = 0.65,
	Min = 0,
	Max = 1,
	Rounding = 2,
	Callback = report
})

-- The range is required: Value, Min, Max and Rounding.
tab:Section("Config table, required only"):Slider({
	Title = "Volume",
	Value = 0.65,
	Min = 0,
	Max = 1,
	Rounding = 2
})

tab:Section("Shorthand, all fields"):Slider("Volume", 0.65, 0, 1, 2, function(value)
	print("Volume:", value)
end, {
	Name = "SliderShorthand",
	Description = "Values are clamped to the range and rounded before callbacks run.",
	Persist = true
})

tab:Section("Shorthand, required only"):Slider("Volume", 0.65, 0, 1, 2)

window:Settings()
