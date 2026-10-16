return function(t)
	local accent = t.accent
	local Apogee = t.Apogee
	local check = t.check
	local contrast = t.contrast
	local fs = t.fs
	local input = t.input
	local pointer = t.pointer
	local roblox = t.roblox
	local SANDBOX = t.SANDBOX
	local step = t.step
	local task = t.task
	local Widgets = t.Widgets
	local win = t.win

	-- widgets ---------------------------------------------------------------------
	local toggle = Widgets.MyToggle
	local fired = {}
	toggle.Callback = function(value)
		table.insert(fired, value)
	end
	toggle.Frame.MouseButton1Click:Fire()
	check(toggle.Value == true and fired[#fired] == true, "a click flips the toggle and fires its callback")
	toggle.Value = false
	check(fired[#fired] == false, "assigning Value fires the callback")
	local count = #fired
	toggle:SetValue(false)
	check(#fired == count + 1, "SetValue fires even when the value does not change")
	toggle.Title = "Renamed"
	check(toggle._element.TitleLabel.Text == "Renamed", "Title is reactive")
	local toggleLook = Apogee.ThemeService:Look(toggle.Frame)
	check(toggleLook.Fill ~= nil and toggleLook.Knob.BackgroundColor3 == roblox.Color3.new(1, 1, 1), "the toggle has a white knob")
	check(toggleLook.Knob:FindFirstChildOfClass("UICorner").CornerRadius.Offset == 4, "the toggle knob is a rounded square")
	check(toggleLook.Fill:FindFirstChildOfClass("UICorner").CornerRadius.Offset == 8, "the toggle track is a rounded square")

	local slider = Widgets.Slider
	check(slider.Value == 3, "the slider takes SetValue(3)")
	slider:SetValue(7)
	check(slider.Value == 5, "the slider clamps to Max")
	slider:SetValue("2.57")
	check(slider.Value == 2.6, "the slider rounds string values to nearest")
	check(Apogee:Round(2.5, 0) == 3 and Apogee:Round(0.1 + 0.2, 2) == 0.3, "Round rounds to nearest")

	local dropdown = Widgets.Dropdown
	check(dropdown.Value == "four", "the dropdown takes SetValue")
	dropdown:SetValue("missing")
	check(dropdown.Value == "four", "the dropdown ignores unknown values")
	dropdown:Open()
	dropdown:Close()
	local fifthOption = dropdown._options[5]
	fifthOption.Frame.InputBegan:Fire(pointer("Touch"))
	check(dropdown.Value == "four", "touch-down alone does not select a dropdown option")
	fifthOption.Frame.Activated:Fire()
	check(dropdown.Value == "five", "a click on an option selects it")
	dropdown:SetValue("missing")
	check(dropdown.Value == "five", "an unknown value after a click keeps the clicked option")
	local pressedOption = dropdown._options[3]
	local optionTouch = pointer("Touch", 80, 80)
	pressedOption.Frame.InputBegan:Fire(optionTouch)
	pressedOption.Frame.MouseButton1Down:Fire()
	step(4)
	check(pressedOption.Highlight.ImageTransparency < 1, "pressing an option shows its pressed highlight")
	input.InputEnded:Fire(optionTouch)
	step(12)
	check(pressedOption.Highlight.ImageTransparency > 0.99, "cancelled touch restores an unselected option highlight")
	dropdown:Open()
	local picked = dropdown._options[4]
	picked.Frame.Activated:Fire()
	step()
	check(dropdown.Value == "four", "a click in an open dropdown selects the option")
	check(picked.Highlight.ImageTransparency < 1, "selecting an option shows its highlight")
	check(picked.Label.TextColor3 == accent(), "the selected option label is tinted with the accent")
	dropdown:Close()

	local multi = Widgets.MultiDropdown
	check(multi.Value.three and multi.Value.five and not multi.Value.seven, "the multi dropdown takes SetValue and skips options set to false")
	check(multi._display.Text == "three, five", "the multi dropdown shows values in list order")

	local keybind = Widgets.Keybind
	local keys, presses = {}, {}
	keybind.Callback = function(key)
		table.insert(keys, key)
	end
	keybind.Pressed = function(toggled)
		table.insert(presses, toggled)
	end
	keybind:SetValue("MouseRight", "Toggle")
	check(keys[#keys] == "MouseRight", "the keybind Callback fires on key changes")
	input.InputBegan:Fire(pointer("MouseButton2"))
	check(presses[1] == true, "the keybind Pressed fires with the toggled state")

	local textInput = Widgets.Input
	textInput:SetValue("hello")
	check(textInput.Value == "hello" and textInput._box.Text == "hello", "the input takes SetValue")

	local picker = Widgets.ColorPicker
	check(math.abs(picker.Value.B * 255 - 140) < 0.01, "the color picker takes SetValue with a Color3")

	picker._element.Frame.MouseButton1Click:Fire()
	check(picker.Opened == true, "clicking color picker opens the picker dialog")
	local pal = picker._palette
	check(pal ~= nil and pal._dialog ~= nil, "the picker dialog is created")
	check(pal._dialog.TintFrame.Parent ~= nil, "the picker dialog is visible over its window")
	check(pal._preview == nil, "color picker preview is removed")
	check(contrast(pal._confirmBtn:FindFirstChildOfClass("TextLabel").TextColor3, pal._confirmBtn:FindFirstChildOfClass("ImageLabel").ImageColor3) >= 3, "the suggested dialog button label is readable on its accent fill")
	check(contrast(pal._cancelBtn:FindFirstChildOfClass("TextLabel").TextColor3, pal._cancelBtn:FindFirstChildOfClass("ImageLabel").ImageColor3) >= 3, "the standard dialog button label is readable on its fill")
	check(#pal._actions == 2, "palette has Done and Cancel buttons")
	check(pal._confirmBtn.Parent.Parent.Position.Y.Scale == 1, "Done and Cancel buttons sit in the bottom tray")
	check(pal._confirmBtn.LayoutOrder < pal._cancelBtn.LayoutOrder, "picker buttons keep the dialog's left-to-right order")
	check(pal._confirmBtn:FindFirstChildOfClass("ImageLabel").Image == "rbxassetid://80999662900595", "Done button uses standard squircle")
	check(pal._confirmBtn:FindFirstChildOfClass("ImageLabel").ImageColor3 == accent(), "Done button is filled with the accent")
	check(pal._cancelBtn:FindFirstChildOfClass("ImageLabel").Image == "rbxassetid://80999662900595", "Cancel button uses standard squircle")

	local hexBox = pal._fields.Hex
	local redBox = pal._fields.Red
	check(hexBox ~= nil and redBox ~= nil, "palette textboxes are found")
	local indicator = hexBox.Parent.Parent:FindFirstChild("Indicator")
	check(indicator ~= nil and indicator.Visible == false, "inputs have no outline at rest")
	local bg = hexBox.Parent.Parent:FindFirstChild("Background")
	check(bg ~= nil and bg.Visible ~= false, "input fields show a fill instead of an outline")
	check(contrast(bg.ImageColor3, pal._dialog.Root:FindFirstChildOfClass("ImageLabel").ImageColor3) >= 1.2, "input fields stand out against their card")
	local dropFill = dropdown._inner:FindFirstChildOfClass("ImageLabel")
	check(contrast(dropFill.ImageColor3, dropdown._element.Surface.ImageColor3) >= 1.2, "dropdown fields stand out against their card")
	check(dropFill.ImageColor3 == bg.ImageColor3, "input and dropdown fields share the same fill")
	-- a track is one frame with a gradient, which follows the rounded corners of the track at both ends
	local function trackFill(track)
		for _, child in track:GetChildren() do
			local gradient = child:FindFirstChildOfClass("UIGradient")
			if gradient then
				return child, gradient
			end
		end
		return nil, nil
	end
	local function grabArea(track)
		for _, child in track:GetChildren() do
			if child.ClassName == "TextButton" then
				return child
			end
		end
		return nil
	end
	local hueFill, hueGradient = trackFill(pal._hueSlider)
	local hueKeys = hueGradient and hueGradient.Color.Keypoints
	check(hueKeys and #hueKeys == 7 and hueKeys[2].Value ~= hueKeys[1].Value, "the hue slider shows the color spectrum")
	check(hueGradient.Rotation == 90, "the hue slider runs top to bottom")
	check(hueFill:FindFirstChildOfClass("UICorner").CornerRadius == roblox.UDim.new(1, 0), "the hue track is round at both ends")
	local hueGrip = grabArea(pal._hueSlider)
	check(hueGrip ~= nil and hueGrip.Size.X.Offset > 0 and hueGrip.Size.Y.Offset > 0, "the hue track has a touch area larger than the track")
	check(pal._dialog.Root.Size.X.Offset == 430 and pal._dialog.Root.Size.Y.Offset == 308, "the picker dialog keeps its compact design size")
	local palBlock = pal._map.Parent
	local palScale = palBlock:FindFirstChildOfClass("UIScale").Scale
	local palTray = pal._confirmBtn.Parent.Parent
	local palTrayTop = palTray.Position.Y.Scale * pal._dialog.Root.Size.Y.Offset + palTray.Position.Y.Offset
	check(palBlock.Position.Y.Offset + palBlock.Size.Y.Offset * palScale <= palTrayTop, "picker controls stay above the button tray")
	check(palTrayTop - (palBlock.Position.Y.Offset + palBlock.Size.Y.Offset * palScale) <= 16, "the picker keeps only a small gap above the button tray")
	check(palBlock.Position.Y.Offset - (pal._dialog.Title.Position.Y.Offset + pal._dialog.Title.Size.Y.Offset) == 12, "the picker controls sit close below the title")
	check(pal._confirmBtn.Size.X.Offset == pal._cancelBtn.Size.X.Offset and pal._confirmBtn.Size.X.Offset > 150, "picker buttons match the dialog's full-width button sizing")
	hexBox.Focused:Fire()
	check(indicator.Visible == true and indicator.ImageColor3 == accent(), "focused input outline is tinted with Accent")
	hexBox.Text = "#FF00FF"
	hexBox.FocusLost:Fire(false)
	check(redBox.Text == "255", "hex input updates RGB fields without enter key")

	-- Test RGB fields update working preview
	local greenBox = pal._fields.Green
	local blueBox = pal._fields.Blue
	redBox.Text = "0"
	redBox.FocusLost:Fire(false)
	greenBox.Text = "255"
	greenBox.FocusLost:Fire(false)
	blueBox.Text = "0"
	blueBox.FocusLost:Fire(false)
	check(pal:_rgb().G == 255 and pal:_rgb().R == 0 and pal:_rgb().B == 0, "typing RGB values updates working color")

	-- Test Cancel discards changes
	local prevValue = picker.Value
	pal._cancelBtn.MouseButton1Click:Fire()
	task.wait(0.3)
	check(picker.Opened == false and pal._dialog.TintFrame.Parent == nil, "Cancel button closes the picker dialog")
	check(picker.Value == prevValue, "Cancel button discards color changes")

	-- Reopen and test Done commits changes
	picker:Open()
	check(picker.Opened == true and pal._dialog.TintFrame.Parent ~= nil, "the picker dialog reopens via Open()")
	hexBox = pal._fields.Hex
	hexBox.Text = "#FF00FF"
	hexBox.FocusLost:Fire(false)
	pal._confirmBtn.MouseButton1Click:Fire()
	task.wait(0.3)
	check(picker.Opened == false and pal._dialog.TintFrame.Parent == nil, "Done button closes the picker dialog")
	check(picker.Value.R > 0.99 and picker.Value.B > 0.99, "Done button commits color to ColorPicker")

	-- Reopen and test pressing outside the dialog dismisses it
	picker:Open()
	local outside = pointer("MouseButton1", 10, 10)
	pal._barrier.InputBegan:Fire(outside)
	input.InputEnded:Fire(outside) -- release so the window drag started by the tint press does not linger
	task.wait(0.3)
	check(picker.Opened == false and pal._dialog.TintFrame.Parent == nil, "pressing outside the picker dialog dismisses it")

	local alphaPicker = Widgets.AlphaPicker
	alphaPicker.Transparency = 0.4
	check(alphaPicker.Transparency == 0.4, "color picker transparency property is reactive")
	alphaPicker:Open()
	local apal = alphaPicker._palette
	local alphaFill, alphaGradient = trackFill(apal._alphaSlider)
	local fade = alphaGradient and alphaGradient.Transparency.Keypoints
	check(fade and fade[1].Value < fade[#fade].Value, "the transparency slider fades the color out")
	check(alphaGradient.Rotation == 90, "the transparency slider runs top to bottom")
	check(alphaFill.BackgroundColor3:ToHex() == alphaPicker.Value:ToHex(), "the transparency slider shows the picked color")
	-- the checkerboard and the fade have the same round shape, so the track is round at both ends
	local checkerboard = apal._alphaSlider:FindFirstChildOfClass("ImageLabel")
	check(alphaFill:FindFirstChildOfClass("UICorner").CornerRadius == checkerboard:FindFirstChildOfClass("UICorner").CornerRadius, "the transparency track has the same round shape at both ends")
	check(grabArea(apal._alphaSlider) ~= nil, "the transparency track has a touch area larger than the track")
	alphaPicker:Close()
	task.wait(0.3)

	-- notifications ----------------------------------------------------------------
	local toast = Apogee:Notify({Title = "Gap", Content = "tight"})
	local stack = toast.Holder.Parent
	local gap = stack:FindFirstChildOfClass("UIListLayout").Padding.Offset
	toast:Close()
	check(gap == 8, "notifications are stacked with a tight gap")

	-- persistence -----------------------------------------------------------------
	local config = Apogee.Config
	local temporary = win.Tabs[1]:Toggle({Name = "Temporary", Title = "Temporary", Persist = false, Value = true})
	Widgets.AlphaPicker:SetValue(roblox.Color3.fromRGB(10, 20, 30), 0.25)
	local ok, err = config:Save("test")
	check(ok, "a config saves " .. tostring(err))
	toggle:SetValue(true)
	slider:SetValue(1)
	multi:SetValue({})
	temporary:SetValue(false)
	keybind:SetValue("E", "Hold")
	Widgets.AlphaPicker:SetValue(roblox.Color3.fromRGB(200, 0, 0), 0)
	check(config:Load("test"), "a config loads")
	task.wait(0.1)
	check(toggle.Value == false and slider.Value == 2.6, "toggle and slider values are restored")
	check(multi.Value.three and multi.Value.five, "multi dropdown values are restored")
	check(keybind.Value == "MouseRight" and keybind.Mode == "Toggle", "keybind key and mode are restored")
	check(Widgets.AlphaPicker.Value:ToHex() == roblox.Color3.fromRGB(10, 20, 30):ToHex(), "colors are restored")
	check(temporary.Value == false, "widgets with Persist = false are not restored")
	config:SetAutoload("test")
	toggle:SetValue(true)
	config:Autoload()
	task.wait(0.1)
	check(toggle.Value == false, "Autoload loads the marked config")
	check(config:Delete("test") and fs.isFile(SANDBOX .. "/ApogeeScriptHub/specific-game/autoload.bin"), "autoload is kept as a standalone config copy")
	check(not config:Save("  "), "blank config names are rejected")
	check(config:Delete("autoload"), "autoload config can be deleted")

	t.Apogee = Apogee
	t.Widgets = Widgets
	t.accent = accent
	t.config = config
	t.dropdown = dropdown
	t.picker = picker
	t.slider = slider
	t.toggle = toggle
	t.win = win
end
