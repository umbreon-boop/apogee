return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local input = t.input
	local pointer = t.pointer
	local roblox = t.roblox
	local setLayout = t.setLayout
	local win = t.win

	-- numeric rounding, including negative factors
	check(Apogee:Round(1234, -1) == 1230 and Apogee:Round(1234, -2) == 1200, "Round handles negative factors")

	-- widgets constructed from another widget keep private configuration
	local limited = win.Tabs[1]:Input({Title = "Limited", Value = "abcdef", MaxLength = 2})
	check(limited.Value == "ab" and limited._box.Text == "ab", "an input applies MaxLength to its initial value")
	local inherited = win.Tabs[1]:Input(limited)
	check(inherited._maxLength == 2, "an inherited input keeps MaxLength")

	local noAlpha = win.Tabs[1]:ColorPicker({Title = "NoAlpha", Value = roblox.Color3.fromRGB(1, 2, 3)})
	local transparency
	noAlpha:OnChanged(function(_, value)
		transparency = value
	end)
	check(transparency == nil, "a color picker without alpha sends no transparency")
	local alpha = win.Tabs[1]:ColorPicker({Title = "Alpha", Value = roblox.Color3.fromRGB(1, 2, 3), Transparency = 0.5})
	local alphaValue
	alpha:OnChanged(function(_, value)
		alphaValue = value
	end)
	check(alphaValue == 0.5, "a color picker with alpha sends transparency")
	local inheritedAlpha = win.Tabs[1]:ColorPicker(noAlpha)
	check(inheritedAlpha._alpha == false, "an inherited color picker keeps its alpha setting")

	-- layouts expose the tab scroll frame to dropdowns and color pickers
	local section = win.Tabs[1]:Section({Title = "Layout dropdown"})
	local layout = section:Layout({Axis = "Y"})
	local layoutDropdown = layout:Dropdown({Title = "In layout", Values = {"a", "b"}})
	check(layoutDropdown._scrollFrame == win.Tabs[1].Container, "a layout passes its scroll frame to widgets")
	check(pcall(layoutDropdown.Open, layoutDropdown), "a dropdown opens inside a layout")
	layoutDropdown:Close(true)
	layout:Destroy()

	-- replacing Values reconciles a removed selection
	local valuesDropdown = win.Tabs[1]:Dropdown({Title = "Values", Values = {"a", "b"}, Value = "b"})
	valuesDropdown:SetValues({"a"})
	check(valuesDropdown.Value == "a" and valuesDropdown._display.Text == "a", "replacing dropdown values reconciles the selection")
	valuesDropdown:Destroy()

	-- notification subcontent and popup subtitles
	local toast = Apogee:Notify({Title = "Toast", Content = "Body", SubContent = "Extra"})
	check(toast.SubContentLabel ~= nil and toast.SubContentLabel.Text == "Extra", "notifications show subcontent")
	check(toast.Root.Active, "notifications use an active input frame")
	toast:Close()
	local parent = Apogee.Creator:New("Frame", {Size = roblox.UDim2.fromOffset(400, 300)})
	local popup = Apogee:Popup({Title = "Popup", SubTitle = "Sub", Parent = parent})
	check(popup.SubtitleLabel ~= nil and popup.SubtitleLabel.Text == "Sub", "popups show a subtitle")
	check(popup.Root.Parent == parent, "a popup honors its configured parent")
	popup:Destroy()
	parent:Destroy()

	-- destroying a window cleans up widgets and floating dropdowns
	local cleanupWindow = Apogee:Window({Title = "Cleanup", Minimizer = false})
	local cleanupTab = cleanupWindow:Tab("Cleanup")
	local named = cleanupTab:Toggle({Title = "Named", Name = "CleanupWidget"})
	local floating = cleanupTab:Dropdown({Title = "Floating", Values = {"a"}})
	floating:Open()
	cleanupWindow:Destroy()
	check(Apogee.Widgets.CleanupWidget == nil, "destroying a window unregisters its widgets")
	check(floating._barrier.Parent == nil and floating._canvas.Parent == nil,
		"destroying a window destroys floating dropdowns")
	check(named._element.Frame.Parent == nil, "destroying a window destroys its rows")

	-- a foreign tab is ignored by SelectTab
	local other = Apogee:Window({Title = "Other", Minimizer = false})
	local otherTab = other:Tab("Other")
	other:SelectTab(otherTab)
	local before = otherTab.Container.Parent
	win:SelectTab(otherTab)
	check(otherTab.Container.Parent == before and win._selected ~= otherTab, "SelectTab ignores tabs from another window")
	other:Destroy()

	-- horizontal tabs keep their canvas and newly added tabs update immediately
	local horizontal = Apogee:Window({Title = "Horizontal", Minimizer = false})
	local first = horizontal:Tab("First")
	local second = horizontal:Tab("Second")
	horizontal:SetTabAxis("X")
	horizontal:_updateTabSection(horizontal.Root.Size.X.Offset)
	check(horizontal._tabFrame.Size.X.Scale == 0 and horizontal._tabFrame.Size.X.Offset > horizontal.TabWidth,
		"the horizontal tab strip fills the window width")
	local stripWidth = horizontal._tabFrame.Size.X.Offset
	horizontal.Root.Size = roblox.UDim2.fromOffset(horizontal.Root.Size.X.Offset + 400, horizontal.Root.Size.Y.Offset)
	check(horizontal._tabFrame.Size.X.Offset == stripWidth + 400, "resizing the window resizes the horizontal tab strip")
	check(first.Frame.Size.X.Scale == 0 and second.Frame.Size.X.Scale == 0, "horizontal tabs use fixed widths")
	local extra = horizontal:Tab("Extra")
	check(extra.Frame.Size.X.Scale == 0 and extra.Frame.Size.X.Offset > 0, "a tab added in horizontal mode gets a horizontal width")
	local extraLabel = extra.Frame:FindFirstChildOfClass("TextLabel")
	setLayout(extraLabel, "TextBounds", roblox.Vector2.new(4, 14))
	check(extra.Frame.Size.X.Offset > 30, "a horizontal tab measures its full title instead of a truncated TextBounds")
	check(extraLabel.TextTruncate == roblox.Enum.TextTruncate.None, "a horizontal tab does not ellipsize an auto-sized title")
	check(extraLabel.Position.X.Offset == 12 and extra.Frame.Size.X.Offset == extraLabel.Position.X.Offset + extraLabel.Size.X.Offset + 12,
		"a horizontal tab has equal left and right padding around its text")
	local iconTab = horizontal:Tab({Title = "Icon", Icon = "star"})
	local iconLabel = iconTab.Frame:FindFirstChildOfClass("TextLabel")
	check(iconTab._icon.Visible and iconTab._icon.Position.X.Offset == 12,
		"a horizontal tab treats the icon as part of the padded content")
	check(iconLabel.Position.X.Offset == 34 and iconTab.Frame.Size.X.Offset == iconLabel.Position.X.Offset + iconLabel.Size.X.Offset + 12,
		"a horizontal tab keeps its right padding aligned with an icon tab's content")
	setLayout(horizontal._tabLayout, "AbsoluteContentSize", roblox.Vector2.new(500, 30))
	check(horizontal.TabHolder.CanvasSize.X.Offset > 0, "a content-size change keeps the horizontal tab canvas width")
	check(horizontal.TabHolder.CanvasSize.Y.Offset > 0, "the horizontal tab canvas keeps the tab height")
	horizontal:SetTabAxis("Y")
	check(horizontal.Splitter.Visible, "the splitter is visible again after horizontal tabs are disabled")
	check(horizontal._tabFrame.Size.X.Scale == 0 and horizontal._tabFrame.Size.X.Offset == horizontal.TabWidth,
		"the tab strip returns to the sidebar width after horizontal tabs are disabled")
	check(extraLabel.TextTruncate == roblox.Enum.TextTruncate.AtEnd, "vertical tabs truncate long titles again")
	setLayout(horizontal._tabLayout, "AbsoluteContentSize", nil)
	horizontal:Destroy()

	-- section dividers follow the first remaining row
	local dividerSection = win.Tabs[1]:Section({Title = "Dividers"})
	local firstRow = dividerSection:Button({Title = "First"})
	local secondRow = dividerSection:Button({Title = "Second"})
	check(not firstRow.Frame.Divider.Visible and secondRow.Frame.Divider.Visible, "only the first section row hides its divider")
	firstRow:Destroy()
	check(not secondRow.Frame.Divider.Visible, "the next section row becomes the first row after a removal")

	-- config names cannot escape the config folder
	check(not Apogee.Config:Save("../escape"), "config names reject path traversal")
	check(not Apogee.Config:Delete("../escape"), "config deletes reject path traversal")

	-- a keybind that starts picking cancels another keybind's pending pick
	local firstBind = win.Tabs[1]:Keybind({Title = "First bind", Value = "Q"})
	local secondBind = win.Tabs[1]:Keybind({Title = "Second bind", Value = "W"})
	t.task.spawn(firstBind._pick, firstBind)
	t.task.wait(0.05)
	t.task.spawn(secondBind._pick, secondBind)
	t.task.wait(0.25)
	local key = pointer("Keyboard")
	key.KeyCode = roblox.Enum.KeyCode.E
	input.InputBegan:Fire(key)
	input.InputEnded:Fire(key)
	check(firstBind.Value == "Q" and secondBind.Value == "E", "only the latest keybind receives a picked key")
	firstBind:Destroy()
	secondBind:Destroy()

	t.Apogee = Apogee
	t.win = win
end
