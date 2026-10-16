local Apogee = require("../src/init")

local window = Apogee:Window("Apogee Stress Test", "Dropdowns & Random Elements", {
	Icon = "orbit",
	Theme = "Dark",
})

local main = window:Tab("Main", "layers")

main:Paragraph({
	Title = "Benchmark Overview",
	Description = "Loading 15 dropdowns (100 elements each = 1,500 options) and 200 randomly generated UI elements.",
})

-- 1. Create 15 Dropdowns with 100 elements each
local dropdownSection = main:Section("Dropdowns (15 x 100 options)")

for i = 1, 15 do
	local values = {}
	for j = 1, 100 do
		table.insert(values, string.format("Option %d - Item %d", i, j))
	end

	dropdownSection:Dropdown({
		Title = string.format("Dropdown %d", i),
		Description = string.format("Dropdown #%d containing 100 selectable options", i),
		Values = values,
		Value = values[1],
		Callback = function(selected)
			print(string.format("Dropdown %d selection changed: %s", i, tostring(selected)))
		end,
	})
end

-- 2. Create 200 other random elements
local randomSection = main:Section("Random Elements (200 items)")

local availableKeys = {"Q", "E", "R", "F", "Z", "X", "C", "V", "B", "T", "G", "H", "J", "K", "L"}

math.randomseed(os.time())

for i = 1, 200 do
	local kind = math.random(1, 7)

	if kind == 1 then
		randomSection:Button({
			Title = string.format("Button %d", i),
			Description = string.format("Random button component #%d", i),
			Callback = function()
				print(string.format("Button %d clicked", i))
			end,
		})
	elseif kind == 2 then
		randomSection:Toggle({
			Title = string.format("Toggle %d", i),
			Description = string.format("Random toggle component #%d", i),
			Value = math.random() > 0.5,
			Callback = function(enabled)
				print(string.format("Toggle %d toggled: %s", i, tostring(enabled)))
			end,
		})
	elseif kind == 3 then
		local minVal = math.random(0, 50)
		local maxVal = minVal + math.random(50, 100)
		local initialVal = math.random(minVal, maxVal)
		randomSection:Slider({
			Title = string.format("Slider %d", i),
			Description = string.format("Random slider component [%d - %d]", minVal, maxVal),
			Value = initialVal,
			Min = minVal,
			Max = maxVal,
			Rounding = 1,
			Callback = function(val)
				print(string.format("Slider %d value: %d", i, val))
			end,
		})
	elseif kind == 4 then
		randomSection:Input({
			Title = string.format("Input %d", i),
			Value = string.format("Text input %d", i),
			Placeholder = string.format("Type here for #%d...", i),
			Callback = function(text)
				print(string.format("Input %d text: %s", i, tostring(text)))
			end,
		})
	elseif kind == 5 then
		local randomColor = Color3.fromRGB(math.random(0, 255), math.random(0, 255), math.random(0, 255))
		randomSection:ColorPicker({
			Title = string.format("Color Picker %d", i),
			Description = string.format("Random color picker component #%d", i),
			Value = randomColor,
			Callback = function(color)
				print(string.format("ColorPicker %d: %s", i, tostring(color)))
			end,
		})
	elseif kind == 6 then
		local defaultKey = availableKeys[math.random(1, #availableKeys)]
		randomSection:Keybind({
			Title = string.format("Keybind %d", i),
			Value = defaultKey,
			Mode = "Toggle",
			Callback = function(key)
				print(string.format("Keybind %d rebound to: %s", i, tostring(key)))
			end,
			Pressed = function(active)
				print(string.format("Keybind %d pressed: %s", i, tostring(active)))
			end,
		})
	elseif kind == 7 then
		randomSection:Paragraph({
			Title = string.format("Information %d", i),
			Description = string.format("Static paragraph informational component #%d.", i),
		})
	end
end

window:SelectTab(1)

Apogee:Notify({
	Title = "Stress Test Ready",
	Content = "Successfully initialized 15 dropdowns (100 options each) and 200 random elements.",
	Duration = 5,
})
