return function(t)
	local accent = t.accent
	local Apogee = t.Apogee
	local buttons = t.buttons
	local check = t.check
	local dropdown = t.dropdown
	local input = t.input
	local picker = t.picker
	local pointer = t.pointer
	local roblox = t.roblox
	local services = t.services
	local step = t.step
	local task = t.task
	local toggle = t.toggle
	local Widgets = t.Widgets
	local win = t.win

	-- squircle style --------------------------------------------------------------
	local group = win.Tabs[1]:Section({Title = "Grouped"})
	local rowA = group:Toggle({Title = "A", Value = true})
	local rowB = group:Button({Title = "B"})
	check(group.Panel.Image == Apogee.internals.assets.images.Squircle, "sections are squircle panels")
	check(rowA._element.Background.ImageTransparency == 1 and not rowA._element.Border.Visible, "rows in a section are flat")
	check(not rowA.Frame.Divider.Visible and rowB.Frame.Divider.Visible, "dividers separate rows after the first")
	rowB.Frame.MouseEnter:Fire()
	step()
	check(rowB._element.Background.ImageTransparency < 1, "rows highlight on hover")
	rowB.Frame.MouseLeave:Fire()
	step()
	Apogee:SetTheme("Light")
	Apogee:SetTheme("Dark")
	step(10)
	check(rowB._element.Background.ImageTransparency > 0.99, "rows stay flat across theme changes")

	local card = toggle._element
	check(card.Background.Image == Apogee.internals.assets.images.Squircle, "standalone cards are squircles")
	check(win.Tabs[1]._highlight.ImageColor3 == accent(), "the selected tab is tinted with the accent")

	local close = win.TitleBar.CloseButton
	local highlight = close:FindFirstChildOfClass("ImageLabel")
	check(highlight.ImageTransparency == 1 and close.BackgroundTransparency == 1, "title bar icons have no background at rest")
	close.MouseEnter:Fire()
	step()
	check(highlight.ImageTransparency < 1, "title bar icons highlight on hover")
	close.MouseLeave:Fire()
	step()

	local primary = win:Dialog({Title = "P", Content = "x", Buttons = {{Title = "Ok"}, {Title = "No"}}})
	local first = buttons(primary)[1]
	check(first:FindFirstChildOfClass("ImageLabel").ImageColor3 == accent(), "the default dialog button is filled with the accent")
	primary:Destroy()

	local tri = win:Dialog({Title = "Tri", Content = "msg", Buttons = {{Title = "A"}, {Title = "B"}, {Title = "C"}}})
	check(#buttons(tri) == 3, "dialog handles 3 buttons without issue")
	check(tri.Root.Size.X.Offset >= 312, "dialog properly resizes to accommodate 3 buttons")
	local triButtons = buttons(tri)
	check(triButtons[1].Size.X.Offset >= 88, "dialog buttons maintain minimum set width")
	local sumBtnWidth = triButtons[1].Size.X.Offset + triButtons[2].Size.X.Offset + triButtons[3].Size.X.Offset + 16
	check(math.abs(sumBtnWidth - (tri.Root.Size.X.Offset - 48)) <= 2, "dialog buttons expand to match dialog width")
	tri:Destroy()

	-- round corners ---------------------------------------------------------------
	-- The default theme lost its round window corners many times. Each check below guards one of these causes:
	-- a squircle with a visible background, because ImageButton is opaque by default in Roblox and the mock returns nil;
	-- an opaque full size frame over a rounded surface;
	-- a theme that squares the corners and does not restore them.
	local Images = Apogee.internals.assets.images
	local SQUIRCLES = {[Images.Squircle] = true, [Images.SquircleOutline] = true, [Images.SquircleTop] = true, [Images.SquircleBottom] = true}

	local function hasShadow(instance)
		for _, child in instance:GetChildren() do
			if child.Name == "Shadow" or hasShadow(child) then
				return true
			end
		end
		return false
	end

	local function corners(root)
		local square, round = 0, 0
		local function walk(instance, inCanvas)
			local class = instance.ClassName
			-- a canvas group clips to a rectangle, so a soft shadow inside it gets straight edges
			if inCanvas and instance.Name == "Shadow" then
				square += 1
			end
			if (class == "ImageLabel" or class == "ImageButton") and SQUIRCLES[instance.Image] then
				local radius = (instance.SliceScale or 0) * 256
				if instance.BackgroundTransparency ~= 1 or radius < 4 then
					square += 1
				end
				if radius > 1 then
					round += 1
				end
			elseif class == "UICorner" then
				if instance.CornerRadius.Offset == 0 and instance.CornerRadius.Scale == 0 then
					square += 1
				else
					round += 1
				end
			elseif instance:IsA("GuiObject") and instance.Size == roblox.UDim2.fromScale(1, 1) and instance.Visible ~= false
				and instance.BackgroundTransparency ~= 1 and not instance:FindFirstChildOfClass("UICorner") then
				square += 1
			end
			for _, child in instance:GetChildren() do
				walk(child, inCanvas or class == "CanvasGroup")
			end
		end
		walk(root, false)
		return square, round
	end

	check(corners(Apogee.GUI) == 0, "every squircle and rounded corner is round on the default theme")
	check(not hasShadow(win.Root), "the window draws no drop shadow")
	check(win.Backdrop.Background:IsA("ImageLabel") and win.Backdrop.Background.Image == Images.Squircle,
		"the window background is a rounded squircle surface")
	local windowBody = win.Backdrop:FindFirstChild("Body")
	check(windowBody ~= nil and windowBody.BackgroundTransparency == 0
		and windowBody:FindFirstChildOfClass("UICorner") ~= nil,
		"the window surface has an opaque rounded body")
	local plainToast = Apogee:Notify({Title = "Plain", Content = "no shadow", Duration = 0.1})
	check(not hasShadow(plainToast.Root), "notifications draw no drop shadow past their rounded corners")
	plainToast:Close()
	local plainPopup = Apogee:Popup({Title = "Plain popup"})
	check(not hasShadow(plainPopup.Root), "popups draw no drop shadow past their rounded corners")
	plainPopup:Destroy()

	local closing = Apogee:Window({Title = "Closing", Maximizer = false})
	closing.TitleBar.CloseButton.MouseButton1Click:Fire()
	local closeDialog = next(closing._dialogs)
	check(closeDialog ~= nil and closeDialog.TintFrame.BackgroundTransparency == 1, "the close dialog overlay has no square background")
	check(corners(closing.Root) == 0, "the window corners stay round while the close dialog is open")
	-- the tween mock completes in Play, so the corners are checked when each tween starts, in the middle state
	local function roundWhileAnimating(root, action)
		local create = services.TweenService.Create
		local tweens, square = 0, 0
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = create(service, instance, info, properties)
			local play = tween.Play
			tween.Play = function()
				tweens += 1
				-- a rectangular clip cuts the content with straight edges over the round corners
				local clipped = 0
				if root.BackgroundTransparency ~= 1 or root.ClipsDescendants == true then clipped = 1 end
				square += corners(root) + clipped
				play()
			end
			return tween
		end
		local ok, err = pcall(action)
		services.TweenService.Create = create
		assert(ok, err)
		return tweens > 0 and square == 0
	end

	local closingAt = closing.Root.Position
	check(roundWhileAnimating(closing.Root, function()
		buttons(closeDialog)[1].MouseButton1Click:Fire()
	end), "the window corners stay round during the close animation")
	check(closing._closing and closing._rootScale.Scale == 1 and closing.Root.Position == closingAt,
		"the close button plays the close animation: a fade, no slide and no scale")
	check(corners(closing.Root) == 0, "the window corners stay round at the end of the close animation")
	task.wait(0.1)
	check(closing._destroyed and Apogee.Current == win, "the close animation destroys only the closed window")

	check(roundWhileAnimating(win.Root, function()
		win:Minimize()
	end), "the window corners stay round during the minimize animation")
	check(roundWhileAnimating(win.Root, function()
		win:Minimize()
	end), "the window corners stay round during the restore animation")
	win:Maximize(true)
	local fullscreenSurface = win.Backdrop:FindFirstChild("Background")
	check(fullscreenSurface ~= nil and fullscreenSurface.Visible ~= false and win.Backdrop:FindFirstChild("Full") == nil,
		"a fullscreen window keeps the same rounded surface as normal mode")
	check(not hasShadow(win.Root), "a fullscreen window draws no drop shadow")
	check(windowBody.BackgroundTransparency == 0 and fullscreenSurface.ImageTransparency == 0,
		"a fullscreen window keeps the same opaque surface as normal mode")
	check(corners(win.Root) == 0, "a fullscreen window keeps its round corners")
	win:Maximize(false)
	local restoredSurface = win.Backdrop:FindFirstChild("Background")
	check(restoredSurface ~= nil and restoredSurface.Visible ~= false, "unmaximizing restores the rounded surface")
	check(not hasShadow(win.Root), "unmaximizing keeps the window free of drop shadows")
	check(windowBody.BackgroundTransparency == 0 and restoredSurface.ImageTransparency == 0,
		"unmaximizing restores the same opaque surface")
	check(not win.Minimized and not win.Maximized, "the window is back to its normal state after the animation checks")

	Apogee:SetTheme("ImGui")
	local imguiToast = Apogee:Notify({Title = "ImGui", Content = "square"})
	local imguiPopup = Apogee:Popup({Title = "ImGui"})
	imguiPopup:Toggle({Title = "Square", Value = true})
	dropdown:Open()
	picker:Open()
	local _, roundInImGui = corners(Apogee.GUI)
	picker:Close()
	dropdown:Close()
	imguiPopup:Destroy()
	imguiToast:Close()
	task.wait(0.3)
	check(roundInImGui == 0, "the ImGui theme squares every squircle and rounded corner")
	local heading = win.TabDisplay.FontFace
	check(heading.Family == roblox.Font.fromEnum(roblox.Enum.Font.RobotoMono).Family and heading.Weight == roblox.Enum.FontWeight.Bold, "the ImGui font keeps bold text bold")
	Apogee:SetTheme("Dark")
	check(corners(Apogee.GUI) == 0, "switching back from ImGui restores every round corner")
	heading = win.TabDisplay.FontFace
	check(heading.Family == Apogee.internals.assets.themes.Font and heading.Weight == roblox.Enum.FontWeight.Bold, "switching back from ImGui restores the font and keeps its weight")

	-- live theme switch -----------------------------------------------------------
	-- a theme change gives the existing widgets the new theme's looks: the widget objects, their values, callbacks
	-- and dragging stay, and the old looks go away completely
	local ThemeService = Apogee.ThemeService
	local liveToggle, liveSlider = Widgets.MyToggle, Widgets.Slider
	local originalToggle = liveToggle.Value
	-- on, because a new look already shows "off" before it paints anything
	liveToggle:SetValue(true)
	local toggleValue, sliderValue = liveToggle.Value, liveSlider.Value
	local elementCount = #win._elements
	local cosmicToggle, cosmicSlider = ThemeService:Look(liveToggle.Frame), ThemeService:Look(liveSlider.Frame)
	local oldKnobGone = false
	cosmicToggle.Knob.Destroying:Connect(function()
		oldKnobGone = true
	end)

	Apogee:SetTheme("Light")
	check(ThemeService:Look(liveToggle.Frame) == cosmicToggle, "a palette change keeps the looks of the widgets")
	Apogee:SetTheme("ImGui")
	local imguiToggle, imguiSlider = ThemeService:Look(liveToggle.Frame), ThemeService:Look(liveSlider.Frame)
	check(Widgets.MyToggle == liveToggle and imguiToggle ~= cosmicToggle and oldKnobGone, "the theme change replaces the toggle look of the same toggle object")

	local function checkmark()
		for _, child in liveToggle.Frame:GetChildren() do
			if child.Size == roblox.UDim2.fromOffset(18, 18) then
				return child:FindFirstChildOfClass("TextLabel")
			end
		end
		return nil
	end
	local function checkmarkTransparency(value)
		if value then return 0 end
		return 1
	end
	check(liveToggle.Value == toggleValue and checkmark().TextTransparency == checkmarkTransparency(toggleValue), "the new toggle look shows the kept value")
	local toggled = {}
	liveToggle.Callback = function(value)
		table.insert(toggled, value)
	end
	liveToggle.Frame.MouseButton1Click:Fire()
	check(liveToggle.Value == not toggleValue and toggled[1] == liveToggle.Value and checkmark().TextTransparency == checkmarkTransparency(liveToggle.Value), "a click on the restyled toggle flips it, fires its callback and shows the value")
	liveToggle:SetValue(toggleValue)

	check(liveSlider.Value == sliderValue and imguiSlider ~= cosmicSlider, "the theme change replaces the slider look and keeps its value")
	cosmicSlider.Hitbox.InputBegan:Fire(pointer("MouseButton1", 190, 0))
	input.InputEnded:Fire(pointer("MouseButton1", 190, 0))
	check(liveSlider.Value == sliderValue, "the old slider look no longer drags")
	local grab = pointer("MouseButton1", 150, 0)
	imguiSlider.Hitbox.InputBegan:Fire(grab)
	input.InputEnded:Fire(grab)
	check(liveSlider.Value == 2.5, "the new slider look drags the same slider")
	liveSlider:SetValue(sliderValue)

	local closeLabel = win.TitleBar.CloseButton:FindFirstChildOfClass("TextLabel")
	check(closeLabel ~= nil and closeLabel.Text == "X" and win.TitleBar.CloseButton:FindFirstChildOfClass("ImageLabel") == nil, "the title bar buttons take the ImGui look")
	win:Maximize(true)
	win:Maximize(false)
	check(not win.Maximized and win.TitleBar.MaxButton:FindFirstChildOfClass("TextLabel").Text == "O", "the ImGui maximizer keeps its square symbol and still toggles")

	Apogee:SetTheme("Dark")
	local backToggle = ThemeService:Look(liveToggle.Frame)
	check(backToggle.Knob ~= nil and backToggle.Knob.BackgroundColor3 == roblox.Color3.new(1, 1, 1) and checkmark() == nil, "switching back gives the toggle its default look")
	check(backToggle.Fill.BackgroundTransparency == checkmarkTransparency(toggleValue), "the default toggle look shows the value at once")
	check(win.TitleBar.MaxButton:FindFirstChild("Icon") ~= nil and win.TitleBar.CloseButton:FindFirstChildOfClass("TextLabel") == nil, "switching back gives the title bar its default buttons")
	check(#win._elements == elementCount and Apogee.Theme == "Dark", "the round trip leaves no stale highlight resets and Apogee.Theme follows the theme")
	liveToggle:SetValue(originalToggle)

	-- selection highlights and outlines ------------------------------------------
	check(win._selector == nil, "the window has no tab selector bar")
	check(win.Tabs[1]._highlight.Image == Apogee.internals.assets.images.Squircle, "tab selection highlight is a rounded square")
	check(dropdown._options[1].Selector == nil, "dropdown options have no selector bar")
	check(dropdown._options[1].Highlight.Image == Apogee.internals.assets.images.Squircle, "dropdown option selection highlight is a rounded square")

	for _, child in win.Backdrop:GetChildren() do
		if child:IsA("ImageLabel") and child.Image == Images.SquircleOutline then
			check(not child.Visible, "backdrop outline is removed")
		end
	end

	local outlineDialog = win:Dialog({Title = "Check", Content = "Msg", Buttons = {{Title = "Ok"}}})
	check(not outlineDialog._border.Visible, "dialog outline is removed")
	outlineDialog:Destroy()

	local tabPadding = win.Tabs[1].Container:FindFirstChildOfClass("UIPadding")
	check(tabPadding ~= nil and tabPadding.PaddingBottom.Offset >= 24, "window section has generous bottom padding for scrolling")
	check(win.Tabs[1].Container.CanvasSize.Y.Offset > 0, "window section canvas allows scrolling without cutting contents")
	check(win.Tabs[1].Container.AutomaticCanvasSize ~= roblox.Enum.AutomaticSize.Y
		and win.Tabs[1].Container.CanvasSize.Y.Offset == Apogee.internals.services.measure.Rows(win.Tabs[1].Container),
		"a tab canvas comes from its row heights, not from automatic sizing")
	check(win.HeaderDivider == nil, "the window has no header divider")

	local prevTabW = win.TabWidth
	win:SetTabWidth(120)
	check(win.TabWidth == 120 and win._tabFrame.Size.X.Offset == 120, "window tab section can be resized manually")
	local splitterPress = pointer("MouseButton1", win.Splitter.AbsolutePosition.X, win.Splitter.AbsolutePosition.Y)
	win.Splitter.InputBegan:Fire(splitterPress)
	splitterPress.Position = roblox.Vector3.new(splitterPress.Position.X + 25, splitterPress.Position.Y, 0)
	input.InputChanged:Fire(splitterPress)
	check(win.TabWidth == 145 and win._tabFrame.Size.X.Offset == 145, "dragging the splitter resizes the tab section")
	input.InputEnded:Fire(splitterPress)
	win:SetTabWidth(prevTabW)

	t.Apogee = Apogee
	t.ThemeService = ThemeService
	t.Widgets = Widgets
	t.buttons = buttons
	t.picker = picker
	t.prevTabW = prevTabW
	t.rowA = rowA
	t.win = win
end
