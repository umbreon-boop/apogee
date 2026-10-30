return function(t)
	local Apogee = t.Apogee
	local check = t.check
	local input = t.input
	local pointer = t.pointer
	local prevTabW = t.prevTabW
	local roblox = t.roblox
	local rowA = t.rowA
	local setViewport = t.setViewport
	local slider = t.slider
	local step = t.step
	local win = t.win

	-- responsive window -----------------------------------------------------------
	check(win.Root.Size.X.Offset == 1280 and win.Root.Size.Y.Offset == 720, "the window is initialized as 2/3 on each direction")
	setViewport(800, 360)
	step(10)
	check(win.Root.Size.Y.Offset == 328, "the window shrinks to fit a phone sized screen")
	setViewport(1920, 1080)
	step(10)
	check(win.Root.Size.X.Offset == 1280 and win.Root.Size.Y.Offset == 720, "the window grows back to its preferred size")

	-- empty dropdown --------------------------------------------------------------
	local emptyDropdown = win.Tabs[1]:Dropdown({Title = "Empty", Values = {}})
	emptyDropdown:Open()
	check(not emptyDropdown.Opened and not emptyDropdown._canvas.Visible, "dropdown does not open with 0 elements")

	-- centered element text -------------------------------------------------------
	check(rowA._element.LabelHolder.Position.Y.Scale == 0.5 and rowA._element.LabelHolder.AnchorPoint.Y == 0.5, "element text is vertically centered")

	-- touch slider ----------------------------------------------------------------
	local knob = Apogee.ThemeService:Look(slider.Frame).Knob
	local hitbox
	for _, child in knob.Parent.Parent:GetChildren() do
		if child.ClassName == "TextButton" then
			hitbox = child
		end
	end
	local finger = pointer("Touch", 150, 0)
	local scroll = win.Tabs[1].Container
	hitbox.InputBegan:Fire(finger)
	check(slider.Value == 2.5 and scroll.ScrollingEnabled == false, "a touch jumps the slider and locks scrolling")
	input.InputChanged:Fire(pointer("Touch", 100, 0))
	check(slider.Value == 2.5, "other fingers do not move the slider")
	finger.Position = roblox.Vector3.new(200, 0, 0)
	input.InputChanged:Fire(finger)
	check(slider.Value == 5, "the same finger drags the slider")
	input.InputEnded:Fire(finger)
	check(scroll.ScrollingEnabled == true, "releasing unlocks scrolling")

	-- maximizer -------------------------------------------------------------------
	local maximizer = win.Maximizer
	check(not maximizer.Enabled and not maximizer.Frame.Visible, "the maximizer is disabled without touch")
	maximizer.Enabled = true
	check(not maximizer.Frame.Visible, "the maximizer stays hidden while the window is open")
	local windowSizeBeforeMinimize, windowPositionBeforeMinimize = win.Root.Size, win.Root.Position
	win:Minimize()
	check(maximizer.Frame.Visible, "the maximizer shows once the window is minimized")
	check(win.Root.Size == windowSizeBeforeMinimize and win._rootScale.Scale == 1,
		"minimize fades without resizing or scaling the window contents")
	maximizer:_moveTo(roblox.Vector2.new(100, 0))
	check(maximizer.Position.Y.Offset == maximizer._size / 2 - 36, "the maximizer reaches the viewport's top edge")
	local tap = pointer("Touch", 40, 500)
	maximizer.Frame.InputBegan:Fire(tap)
	tap.Position = roblox.Vector3.new(300, 200, 0)
	input.InputChanged:Fire(tap)
	input.InputEnded:Fire(tap)
	check(win.Minimized and maximizer.Position.X.Offset ~= 40, "dragging moves the maximizer without restoring")
	maximizer.Frame.InputBegan:Fire(tap)
	input.InputEnded:Fire(tap)
	check(not win.Minimized and not maximizer.Frame.Visible, "a tap restores the window and hides the maximizer")
	check(win.Root.Size == windowSizeBeforeMinimize and win.Root.Position == windowPositionBeforeMinimize and win._rootScale.Scale == 1, "restore animation returns the window to its saved geometry")
	win:Maximize(true)
	check(win.Maximized and win.Root.Size == win.Size and win.Root.Position == roblox.UDim2.fromOffset(16, 16), "maximize animation fills the screen")
	check(win.Root.Size == roblox.UDim2.fromOffset(1888, 1012), "fullscreen uses the drawable screen area with the window margin")
	check(win.Root:FindFirstChild("Shadow") == nil and win.Backdrop:FindFirstChild("Shadow") == nil,
		"fullscreen keeps the rounded surface with no square shadow box")
	check(win.Backdrop.Body ~= nil and win.Backdrop.Body.BackgroundTransparency == 0,
		"fullscreen keeps an opaque window surface")
	check(win.TabWidth == prevTabW and win._tabFrame.Size.X.Offset == prevTabW, "tab width is preserved during maximization")
	win:Maximize(false)
	check(not win.Maximized and win.Root.Size == windowSizeBeforeMinimize, "unmaximize animation restores the previous size")
	check(win.Root:FindFirstChild("Shadow") == nil and win.Backdrop:FindFirstChild("Shadow") == nil,
		"unmaximizing keeps the rounded surface without a square shadow box")
	check(win.TabWidth == prevTabW and win._tabFrame.Size.X.Offset == prevTabW, "tab width is preserved after restoring from maximize")

	-- a screen GUI that ignores the inset starts at the screen top; the maximized window must stay below the topbar
	Apogee.GUI.IgnoreGuiInset = true
	win:Maximize(true)
	check(win.Root.Position == roblox.UDim2.fromOffset(16, 52) and win.Root.Size == roblox.UDim2.fromOffset(1888, 1012),
		"a maximized window that ignores the GUI inset stays below the topbar")
	win:Maximize(false)
	Apogee.GUI.IgnoreGuiInset = false

	win:Maximize(true)
	local maximizedPosition = win.Root.Position
	win:Minimize()
	win:Minimize()
	check(win.Root.Position == maximizedPosition, "restoring a minimized maximized window keeps the maximized position")
	win:Maximize(false)

	-- multiple windows ------------------------------------------------------------
	local second = Apogee:Window({Title = "Second", SubTitle = ""})
	check(#Apogee.Windows == 2 and Apogee.Current == second, "a second window can open")
	second:Destroy()
	check(#Apogee.Windows == 1 and Apogee.Current == win, "destroying a window hands Current back")

	t.Apogee = Apogee
	t.win = win
end
