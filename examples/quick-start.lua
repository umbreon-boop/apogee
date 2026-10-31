local Apogee = loadstring(game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua"))()

local window = Apogee:Window("Apogee", "Quick start")
local tab = window:Tab("Main", "house")
local section = tab:Section("Controls")

local volume = section:Slider("Volume", 50, 0, 100, 0, function(value)
	print("Volume:", value)
end, {Name = "Volume"})

section:Toggle("Enabled", false, function(value)
	print("Enabled:", value)
end, {Name = "Enabled"})

section:Button("Reset", function()
	volume:SetValue(50)
end)

section:Button("Open popup", function()
	local popup = Apogee:Popup("Quick popup", UDim2.fromOffset(300, 180))
	popup:Paragraph("Hello", "Widgets can live in a popup too.")
end)

window:Settings()
