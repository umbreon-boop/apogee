local Apogee = loadstring(game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua"))()

local window = Apogee:Window({Title = "Layout example"})
local section = window:Tab({Title = "Layouts"}):Section({Title = "Nested controls"})
local GAP = 8

-- X divides the section into equal columns. Each subcontainer stacks its own primitives on Y by default.
local columns = section:Layout({Axis = "X", Gap = GAP})
local controls = columns:Subcontainer({Axis = "Y", Gap = GAP})
local actions = columns:Subcontainer({Axis = "Y", Gap = GAP})

controls:Paragraph({
	Title = "Controls",
	Description = "Subcontainers keep related primitives together while the parent layout sizes each column evenly."
})
controls:Toggle({Title = "Enabled", Value = true})
controls:Slider({Title = "Volume", Value = 60, Min = 0, Max = 100, Rounding = 0})
controls:Dropdown({Title = "Quality", Values = {"Low", "Medium", "High"}, Value = "Medium"})
controls:Input({Title = "Player name", Value = "Player", Placeholder = "Enter a name"})

actions:ColorPicker({Title = "Accent color", Value = Color3.fromRGB(90, 190, 255)})
actions:Keybind({Title = "Toggle panel", Value = "RightShift", Mode = "Toggle"})

-- A nested X layout gives two same-size button regions inside the right-hand column.
local buttons = actions:Subcontainer({Axis = "X", Gap = GAP})
local apply = buttons:Subcontainer()
local cancel = buttons:Subcontainer()
apply:Button({Title = "Apply", Callback = function()
	print("Applied")
end})
cancel:Button({Title = "Cancel", Callback = function()
	print("Cancelled")
end})
