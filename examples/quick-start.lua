local Apogee = require("../src/init")

local window = Apogee:Window({Title = "Apogee", SubTitle = "Quick start"})
local tab = window:Tab({Title = "Main", Icon = "house"})
local section = tab:Section({Title = "Controls"})

local enabled = section:Toggle({
	Title = "Enabled",
	Value = false,
	Name = "Enabled"
})

enabled:OnChanged(function(value)
	print("Enabled:", value)
end)

local volume = section:Slider({
	Title = "Volume",
	Value = 50,
	Min = 0,
	Max = 100,
	Rounding = 0
})

section:Button({
	Title = "Reset",
	Callback = function()
		volume:SetValue(50)
	end
})

section:Button({
	Title = "Open popup",
	Callback = function()
		local popup = Apogee:Popup({Title = "Quick popup", Size = UDim2.fromOffset(300, 180)})
		popup:Paragraph({Title = "Hello", Description = "Widgets can live in a popup too."})
	end
})

window:Settings()
