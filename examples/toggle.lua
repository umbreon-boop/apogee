local Apogee = require("../src/init")

-- Shorthand: Toggle(title, value, callback, description, options)
local window = Apogee:Window("Toggle example")
local tab = window:Tab("Toggle")

local function report(enabled)
	print("Feature state:", enabled)
end

tab:Section("Config table, all fields"):Toggle({
	Name = "ToggleTable",
	Title = "Enable feature",
	Description = "Named widgets are available to the config service.",
	Persist = true,
	Value = true,
	Callback = report
})

-- Title is the only required field; Value defaults to false.
tab:Section("Config table, required only"):Toggle({
	Title = "Enable feature"
})

tab:Section("Shorthand, all fields"):Toggle("Enable feature", true, report, "Named widgets are available to the config service.", {
	Name = "ToggleShorthand",
	Persist = true
})

tab:Section("Shorthand, required only"):Toggle("Enable feature")

window:Settings()
