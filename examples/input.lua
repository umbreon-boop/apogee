local Apogee = loadstring(game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua"))()

-- Shorthand: Input(title, value, callback, placeholder, options)
local window = Apogee:Window("Input example")
local tab = window:Tab("Input")

local function report(value)
	print("Name changed:", value)
end

tab:Section("Config table, all fields"):Input({
	Name = "InputTable",
	Title = "Display name",
	Description = "Numeric commits only complete values.",
	Persist = true,
	Value = "Guest",
	Placeholder = "Enter a name",
	Numeric = false,
	Finished = false,
	MaxLength = 24,
	Callback = report
})

-- Title is the only required field; Value defaults to the empty string.
tab:Section("Config table, required only"):Input({
	Title = "Display name"
})

tab:Section("Shorthand, all fields"):Input("Display name", "Guest", function(value)
	print("Name changed:", value)
end, "Enter a name", {
	Name = "InputShorthand",
	Description = "Numeric commits only complete values.",
	Persist = true,
	MaxLength = 24
})

tab:Section("Shorthand, required only"):Input("Display name")

window:Settings()
