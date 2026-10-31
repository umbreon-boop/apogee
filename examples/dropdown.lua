local Apogee = loadstring(game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua"))()

-- Shorthand: Dropdown(title, values, value, callback, options)
local window = Apogee:Window("Dropdown example")
local tab = window:Tab("Dropdown")

local QUALITY = {"Low", "Medium", "High"}

local function report(value)
	print("Quality:", value)
end

tab:Section("Config table, all fields"):Dropdown({
	Name = "DropdownTable",
	Title = "Quality",
	Description = "AllowNull lets a single selection be cleared.",
	Persist = true,
	Values = QUALITY,
	Value = 2,
	Multi = false,
	AllowNull = true,
	Callback = report
})

-- Title and Values are the only required fields.
tab:Section("Config table, required only"):Dropdown({
	Title = "Quality",
	Values = QUALITY
})

tab:Section("Shorthand, all fields"):Dropdown("Quality", QUALITY, 2, function(value)
	print("Quality:", value)
end, {
	Name = "DropdownShorthand",
	Description = "AllowNull lets a single selection be cleared.",
	Persist = true,
	Multi = false,
	AllowNull = true
})

tab:Section("Shorthand, required only"):Dropdown("Quality", QUALITY)

window:Settings()
