local Apogee = require("../src/init")

-- Shorthand: Keybind(title, value, callback, mode, pressed, options)
local window = Apogee:Window("Keybind example")
local tab = window:Tab("Keybind")

local function changed(key)
	print("Binding changed to:", key)
end

local function pressed(toggled)
	print("Overlay active:", toggled)
end

tab:Section("Config table, all fields"):Keybind({
	Name = "KeybindTable",
	Title = "Toggle overlay",
	Description = "Pressed runs on each press in Toggle mode.",
	Persist = true,
	Value = "G",
	Mode = "Toggle",
	Callback = changed,
	Pressed = pressed
})

-- Title and Value are the only required fields.
tab:Section("Config table, required only"):Keybind({
	Title = "Toggle overlay",
	Value = "G"
})

tab:Section("Shorthand, all fields"):Keybind("Toggle overlay", "G", function(key)
	print("Binding changed to:", key)
end, "Toggle", function(active)
	print("Overlay active:", active)
	end, {
	Name = "KeybindShorthand",
	Description = "Pressed runs on each press in Toggle mode.",
	Persist = true
})

tab:Section("Shorthand, required only"):Keybind("Toggle overlay", "G")

window:Settings()
