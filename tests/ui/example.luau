return function(t)
	local BUNDLE = t.BUNDLE
	local check = t.check
	local env = t.env
	local fs = t.fs
	local genv = t.genv
	local hui = t.hui
	local luau = t.luau
	local step = t.step
	local task = t.task

	-- run the example -------------------------------------------------------------
	luau.load(fs.readFile(BUNDLE), {debugName = "example", environment = env})()
	task.wait(0.3)
	step()

	local Apogee = genv.Apogee
	local Widgets = Apogee.Widgets
	local win = Apogee.Current

	check(genv.Apogee == Apogee, "getgenv().Apogee is set")
	check(Apogee.GUI.Parent == hui, "the gui is parented to gethui()")
	check(win ~= nil and #win.Tabs == 2, "the example creates a window with two tabs")
	check(win.TabDisplay.Text == "Main", "the first tab is selected")
	check(win.Root.Position.X.Offset == 320 and win.Root.Position.Y.Offset == 180, "the window spawns in the center of the screen by default")

	local function accent()
		return Apogee.ThemeService:Get("Accent")
	end

	local function channel(value)
		if value <= 0.04045 then
			return value / 12.92
		end
		return ((value + 0.055) / 1.055) ^ 2.4
	end

	local function contrast(a, b)
		local function luminance(color)
			return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
		end
		local hi, lo = math.max(luminance(a), luminance(b)), math.min(luminance(a), luminance(b))
		return (hi + 0.05) / (lo + 0.05)
	end

	t.Apogee = Apogee
	t.Widgets = Widgets
	t.accent = accent
	t.contrast = contrast
	t.win = win
end
