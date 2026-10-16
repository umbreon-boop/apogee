return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local input = t.input
	local pointer = t.pointer
	local roblox = t.roblox

	-- localization and positional API --------------------------------------------
	local label = Apogee.Creator:New("TextLabel", {Text = "Hello"})
	Apogee:SetLocale("test", {Hello = "Bonjour", Updated = "Modifié"})
	check(label.Text == "Bonjour", "Creator localizes text elements when the locale changes")
	label.Text = "Updated"
	check(label.Text == "Modifié", "Creator localizes text assigned after creation")
	Apogee:SetLocale("en")
	check(label.Text == "Updated", "changing locale restores the source text")
	label:Destroy()

	local shorthand = Apogee:Window("Shorthand", "Positional API", {Minimizer = false})
	local shorthandTab = shorthand:Tab("Page", "home")
	local shorthandToggle = shorthandTab:Toggle("Enabled", true)
	local shorthandButton = shorthandTab:Button("Action", function() end, "Run action")
	local shorthandPicker = shorthandTab:ColorPicker("Tint", roblox.Color3.fromRGB(1, 2, 3))
	local shorthandDropdown = shorthandTab:Dropdown("Choice", {"One", "Two"}, "One")
	local shorthandInput = shorthandTab:Input("Name", "Ada", nil, "Enter a name")
	local shorthandKeybind = shorthandTab:Keybind("Shortcut", "K")
	local shorthandParagraph = shorthandTab:Paragraph("Note", "Details")
	local shorthandSlider = shorthandTab:Slider("Amount", 5, 0, 10, 0)
	local shorthandSection = shorthandTab:Section("Group")
	local shorthandNestedPopup = shorthand:Popup("Nested")
	local shorthandDialog = shorthand:Dialog("Confirm", "Continue?", {{Title = "OK"}})
	local shorthandSettings = shorthand:Settings("Preferences", "settings")
	local sameSettings = shorthand:Settings()
	local shorthandTopPopup = Apogee:Popup("Floating", roblox.UDim2.fromOffset(260, 300))
	local shorthandToast = Apogee:Notify("Notice", "Details", {Duration = 5})
	local headerText = shorthand.TitleBar.Frame:GetChildren()[1]:GetChildren()
	check(headerText[2].Text == "Shorthand" and headerText[3].Text == "Positional API", "window accepts ordered positional arguments")
	check(shorthandTab.Title == "Page" and shorthandToggle.Title == "Enabled" and shorthandToggle.Value, "tab and widget accept ordered positional arguments")
	check(shorthandButton.Title == "Action" and shorthandPicker.Title == "Tint" and shorthandDropdown.Title == "Choice", "button, picker and dropdown accept positional arguments")
	check(shorthandInput.Title == "Name" and shorthandKeybind.Title == "Shortcut" and shorthandParagraph.Title == "Note" and shorthandSlider.Title == "Amount", "input, keybind, paragraph and slider accept positional arguments")
	check(shorthandSection.Title == "Group" and shorthandNestedPopup.TitleLabel.Text == "Nested", "section and nested popup accept positional arguments")
	check(shorthandDialog.Title.Text == "Confirm" and shorthandSettings.Title == "Preferences", "dialog and settings accept positional arguments")
	check(sameSettings == shorthandSettings, "a window reuses its settings tab and minimize callback")
	check(shorthandTopPopup.TitleLabel.Text == "Floating" and shorthandToast.Title.Text == "Notice", "top-level popup and notification accept positional arguments")
	local minimizePress = pointer("Keyboard")
	minimizePress.KeyCode = roblox.Enum.KeyCode.LeftControl
	input.InputBegan:Fire(minimizePress)
	check(shorthand.Minimized, "the settings keybind callback minimizes its owning window")
	input.InputBegan:Fire(minimizePress)
	check(not shorthand.Minimized, "the settings keybind callback restores its owning window")
	shorthandDialog:Destroy()
	shorthandNestedPopup:Destroy()
	shorthandTopPopup:Destroy()
	shorthandToast:Close()
	shorthand:Destroy()

	t.Apogee = Apogee
end
