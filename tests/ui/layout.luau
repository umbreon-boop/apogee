return function(t)
	local check = t.check
	local Enum = t.roblox.Enum
	local win = t.win
	local tab = win.Tabs[1]
	local section = tab:Section({Title = "Layout test"})
	local defaultRow = section:Layout({Axis = "X"})
	local defaultColumn = section:Layout({Axis = "Y"})
	check(defaultRow._gap == 8 and defaultColumn._gap == 8
		and defaultRow._layout.Padding.Offset == 5 and defaultColumn._layout.Padding.Offset == 5,
		"default X and Y layouts use the same eight-pixel gap")
	defaultRow:Destroy()
	defaultColumn:Destroy()
	check(section.Panel.Visible, "destroying the last layout restores the section surface")

	local row = section:Layout({Axis = "X", Gap = 12})
	local left = row:Subcontainer()
	local right = row:Subcontainer()
	local first = left:Button({Name = "LayoutChild", Title = "First column"})
	local second = right:Toggle({Title = "Second column", Value = false})
	local Resize = t.Apogee.internals.services.resize
	check(row.Type == "Layout" and row.Frame.Parent == section.Container, "a layout attaches to its section")
	check(not section.Panel.Visible, "the section surface does not show through a layout")
	check(left.Frame.Parent == row.Frame and right.Frame.Parent == row.Frame, "a layout creates sibling subcontainers")
	check(first.Frame.Parent == left.Frame and second.Frame.Parent == right.Frame, "subcontainers accept primitive widgets")
	check(first.Frame:FindFirstChildOfClass("UISizeConstraint").MinSize.X == Resize.MinimumWidth(first)
		and right.Frame:FindFirstChildOfClass("UISizeConstraint").MinSize.X == Resize.MinimumWidth(second),
		"layout children receive resize-service minimum widths")
	check(row._minimumWidth == 2 * Resize.MinimumWidth(second) + 9
		and row.Frame:FindFirstChildOfClass("UISizeConstraint").MinSize.X == row._minimumWidth,
		"an X layout stops narrowing when its columns reach their minimum width")
	local narrowCells = right:Subcontainer({Axis = "X"})
	local cellA, cellB = narrowCells:Subcontainer(), narrowCells:Subcontainer()
	cellA:Button({Title = "Cell A"})
	cellB:Button({Title = "Cell B"})
	check(win.Root:FindFirstChildOfClass("UISizeConstraint").MinSize.X >= row._minimumWidth + 60 + 36 + 10,
		"the window resize minimum includes the layout's required content width")
	check(win:_fitResize(t.roblox.Vector2.zero).X
		>= row._minimumWidth + 60 + 36 + 10,
		"manual window resizing clamps at the layout minimum")
	check(row.Frame.BackgroundTransparency == 1 and left.Frame.BackgroundTransparency == 1 and right.Frame.BackgroundTransparency == 1,
		"layout and subcontainer frames stay transparent")
	check(first._element.Surface.Visible ~= false and second._element.Surface.Visible ~= false,
		"primitives keep their own distinct card surfaces inside layouts")
	local rowLayout
	for _, child in row.Frame:GetChildren() do
		if child.ClassName == "UIListLayout" then
			rowLayout = child
		end
	end
	check(rowLayout.FillDirection == Enum.FillDirection.Horizontal and rowLayout.Padding.Offset == 9, "an X-axis layout applies its direction and gap")
	check(left.Frame.Size.X.Scale == 0.5 and right.Frame.Size.X.Scale == 0.5, "X-axis subcontainers share the available width")
	check(left.Frame.Size.X.Offset == -4 and right.Frame.Size.X.Offset == -4, "subcontainer widths account for the visible gap")
	check(left.Frame.Size.Y.Offset == right.Frame.Size.Y.Offset, "X-axis subcontainers share the same height")
	check(left.Frame.LayoutOrder < right.Frame.LayoutOrder, "layout subcontainers preserve insertion order")
	check(t.Apogee.Widgets.LayoutChild == first, "named layout children remain registered widgets")
	for _, primitive in {"Button", "ColorPicker", "Dropdown", "Input", "Keybind", "Paragraph", "Slider", "Toggle"} do
		check(type(left[primitive]) == "function", primitive .. " is available inside a layout subcontainer")
	end

	local stack = left:Subcontainer({Axis = "Y", Gap = 4})
	local nested = stack:Paragraph({Title = "Nested", Description = "A primitive inside a nested vertical layout."})
	check(stack.Frame.Parent == left.Frame and nested.Frame.Parent == stack.Frame, "subcontainers can nest and accept primitives")
	local stackLayout
	for _, child in stack.Frame:GetChildren() do
		if child.ClassName == "UIListLayout" then
			stackLayout = child
		end
	end
	check(stackLayout.FillDirection == Enum.FillDirection.Vertical and stack._gap == 4 and stackLayout.Padding.Offset == 1,
		"Y-axis subcontainers apply the configured visible gap")

	local column = section:Layout({Axis = "Y", Gap = 5})
	local tall = column:Subcontainer()
	local short = column:Subcontainer()
	tall:Button({Title = "Tall one"})
	tall:Button({Title = "Tall two"})
	short:Button({Title = "Short"})
	check(tall.Frame.Size.Y.Offset > short.Frame.Size.Y.Offset, "Y-axis subcontainers keep their natural heights")
	check(tall.Frame.Size.X.Scale == short.Frame.Size.X.Scale, "Y-axis subcontainers share the available width")
	check(column.Frame.Size.Y.Offset == tall.Frame.Size.Y.Offset + short.Frame.Size.Y.Offset + 2,
		"a Y layout adds only its configured gap between subcontainers")

	row:Destroy()
	check(row.Frame.Parent == nil and stack.Frame.Parent == nil and nested.Frame.Parent == nil, "destroying a layout removes nested layout content")
	check(t.Apogee.Widgets.LayoutChild == nil, "destroying a layout unregisters its named widgets")
	column:Destroy()
end
