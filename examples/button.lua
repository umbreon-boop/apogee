local Apogee = require("../src/init")

-- Shorthand: Button(title, callback, description, options)
local window = Apogee:Window("Button example")
local tab = window:Tab("Button")

local function confirm()
	print("Action confirmed")
end

tab:Section("Config table, all fields"):Button({
	Name = "ButtonTable",
	Title = "Confirm action",
	Description = "Buttons have no Value state.",
	Persist = true,
	Callback = confirm
})

-- Title is the only required field.
tab:Section("Config table, required only"):Button({
	Title = "Confirm action"
})

tab:Section("Shorthand, all fields"):Button("Confirm action", confirm, "Buttons have no Value state.", {
	Name = "ButtonShorthand",
	Persist = true
})

tab:Section("Shorthand, required only"):Button("Confirm action")

window:Settings()
