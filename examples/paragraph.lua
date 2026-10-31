local Apogee = loadstring(game:HttpGet("https://github.com/umbreon-boop/apogee/releases/latest/download/artifact.lua"))()

-- Shorthand: Paragraph(title, description, options)
local window = Apogee:Window("Paragraph example")
local tab = window:Tab("Paragraph")

tab:Section("Config table, all fields"):Paragraph({
	Name = "ParagraphTable",
	Title = "Connection",
	Description = "Waiting for a connection...",
	Persist = true
})

-- Title is the only required field.
tab:Section("Config table, required only"):Paragraph({
	Title = "Connection"
})

tab:Section("Shorthand, all fields"):Paragraph("Connection", "Waiting for a connection...", {
	Name = "ParagraphShorthand",
	Persist = true
})

tab:Section("Shorthand, required only"):Paragraph("Connection")

window:Settings()
