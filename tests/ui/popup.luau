return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local input = t.input
	local picker = t.picker
	local pointer = t.pointer
	local roblox = t.roblox
	local step = t.step
	local task = t.task
	local Widgets = t.Widgets
	local win = t.win

	-- popup element ---------------------------------------------------------------
	local popup = Apogee:Popup({Title = "Quick Popup", Size = roblox.UDim2.fromOffset(300, 350)})
	check(popup ~= nil and popup.Type == "Popup", "popup element is created")
	check(popup.Root.Parent == Apogee.GUI, "popup is parented to GUI by default")
	check(popup._barrier.Visible and popup._barrier.Active and popup._barrier.Size == roblox.UDim2.fromScale(1, 1), "an open popup blocks input across its parent")
	Widgets.Slider._element.Frame.MouseEnter:Fire()
	check(Widgets.Slider._element.Background.ImageTransparency == 1, "hover does not pass through an open popup")
	local popToggle = popup:Toggle({Title = "PopToggle", Value = true})
	local popSlider = popup:Slider({Title = "PopSlider", Value = 5, Min = 0, Max = 10, Rounding = 0})
	local popBtn = popup:Button({Title = "PopBtn"})
	local popPara = popup:Paragraph({Title = "PopPara", Description = "Directly hosted"})
	check(popToggle._element.Frame.Parent == popup.Container, "popup directly hosts widgets without sections")
	check(popSlider.Value == 5 and popToggle.Value == true, "popup widgets function correctly")
	check(popBtn ~= nil and popPara._element.TitleLabel.Text == "PopPara", "popup button and paragraph are instantiated")
	check(popup.Container.CanvasSize.Y.Offset > 0, "popup canvas size updates with content")

	local popPicker = popup:ColorPicker({Title = "PopColor", Value = roblox.Color3.fromRGB(1, 2, 3)})
	popPicker:Open()
	local popPal = popPicker._palette
	check(popPal._dialog.Root.Size.X.Offset == 430 and popPal._dialog.Root.Size.Y.Offset == 308, "a picker dialog keeps its compact size inside a small popup")
	local popBlock = popPal._map.Parent
	local popScale = popBlock:FindFirstChildOfClass("UIScale").Scale
	local popTray = popPal._confirmBtn.Parent.Parent
	local popTrayTop = popTray.Position.Y.Scale * popPal._dialog.Root.Size.Y.Offset + popTray.Position.Y.Offset
	check(popBlock.Position.Y.Offset + popBlock.Size.Y.Offset * popScale <= popTrayTop, "picker controls stay above the tray in a small dialog")
	popPicker:Close()
	task.wait(0.3)

	local pStart = popup.Root.Position.X.Offset
	popup.TitleLabel.Parent.InputBegan:Fire(pointer("MouseButton1", 20, 20))
	input.InputChanged:Fire(pointer("MouseMovement", 60, 20))
	input.InputEnded:Fire(pointer("MouseButton1", 60, 20))
	check(popup.Root.Position.X.Offset == pStart + 40, "popup is draggable by its titlebar")

	-- mutual exclusion test: dragging popup prevents window from dragging simultaneously
	local winXBefore = win.Position.X.Offset
	local pXBefore = popup.Root.Position.X.Offset
	local dragInput = pointer("MouseButton1", 20, 20)
	popup.TitleLabel.Parent.InputBegan:Fire(dragInput)
	-- attempt to initiate window drag while popup is dragging
	local winDragInput = pointer("MouseButton1", 100, 10)
	win.TitleBar.Frame.InputBegan:Fire(winDragInput)
	input.InputChanged:Fire(pointer("MouseMovement", 50, 20))
	input.InputEnded:Fire(dragInput)
	input.InputEnded:Fire(winDragInput)
	check(popup.Root.Position.X.Offset == pXBefore + 30, "popup moves during its drag")
	check(win.Position.X.Offset == winXBefore, "only one window or popup moves at a time")

	popup.Visible = false
	check(popup.Root.Visible == false and not popup._barrier.Visible and not Apogee:HasOverlay(), "a hidden popup hides its input barrier and stops blocking input")
	popup:Open()
	check(popup.Visible == true and popup.Root.Visible == true and popup._barrier.Visible, "popup Open shows a hidden popup")

	local winPopup = win:Popup({Title = "Nested Popup"})
	check(winPopup.Root.Parent == win.Root, "window popup is parented to window root")
	winPopup:Destroy()
	local closedWith = 0
	local closing = Apogee:Popup({Title = "Closing", CloseCallback = function()
		closedWith += 1
	end})
	closing.CloseButton.MouseButton1Click:Fire()
	check(closedWith == 1 and closing._destroyed and closing.Root.Parent == nil, "the popup close button plays the close animation, calls CloseCallback and destroys the popup")
	popup:Destroy()
	check(popup.Root.Parent == nil, "destroying popup removes its root")

	local customToast = Apogee:Notify({
		Title = "Update Available",
		Content = "A new version is ready to install.",
		Icon = "bell"
	})
	check(customToast.Icon.Visible and customToast.Icon.Image ~= "", "notification displays custom icon")
	check(customToast.Title.Text == "Update Available", "notification displays title")
	check(customToast.ContentLabel.Text == "A new version is ready to install.", "notification displays content")
	check(customToast.SubContentLabel == nil, "notification subcontent is removed")
	customToast.CloseButton.MouseButton1Click:Fire()
	task.wait(0.5)
	check(customToast.Closed, "notification close button dismisses toast")

	local shortToast = Apogee:Notify({Title = "Short", Content = "Hi"})
	local hugeToast = Apogee:Notify({
		Title = "Very Long Notification Title",
		Content = string.rep("This is a multi-line long toast notification text intended to test variable length. ", 4)
	})
	check(hugeToast.Holder.Size.Y.Offset == 58 and shortToast.Holder.Size.Y.Offset == 58, "notifications have a fixed height")
	check(hugeToast.Holder.Size.X.Offset > shortToast.Holder.Size.X.Offset, "notification length varies with content")
	check(hugeToast.LabelHolder.ClipsDescendants == true, "notification label holder clips overflow")
	shortToast:Close()
	hugeToast:Close()

	-- modal barrier and overlay highlight suppression ----------------------------
	Widgets.Dropdown:Open()
	check(Widgets.Dropdown._barrier ~= nil and Widgets.Dropdown._barrier.Visible == true and Widgets.Dropdown._barrier.Active == true, "dropdown open shows modal dismiss barrier")
	check(Widgets.Dropdown._element.Background.ImageTransparency == 1, "dropdown element is at rest when dropdown is open")
	Widgets.Slider._element.Frame.MouseEnter:Fire()
	step()
	check(Widgets.Slider._element.Background.ImageTransparency == 1, "elements do not highlight when mouse enters during open dropdown")
	Widgets.Slider._element.Frame.MouseButton1Down:Fire()
	step()
	check(Widgets.Slider._element.Background.ImageTransparency == 1, "elements do not highlight when mouse clicks during open dropdown")
	Widgets.Dropdown._barrier.InputBegan:Fire(pointer("MouseButton1", 10, 10))
	check(Widgets.Dropdown.Opened == false and Widgets.Dropdown._barrier.Visible == false, "clicking modal barrier dismisses dropdown")

	picker:Open()
	check(picker._element.Background.ImageTransparency == 1, "color picker element is at rest when palette is open")
	Widgets.Input._element.Frame.MouseEnter:Fire()
	step()
	check(Widgets.Input._element.Background.ImageTransparency == 1, "elements do not highlight when mouse enters during open palette")
	picker:Close()

	t.Apogee = Apogee
	t.Widgets = Widgets
	t.win = win
end
