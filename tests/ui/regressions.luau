return function(t)
	local Apogee = t.Apogee
	local buttons = t.buttons
	local check = t.check
	local config = t.config
	local input = t.input
	local pointer = t.pointer
	local roblox = t.roblox
	local services = t.services
	local setLayout = t.setLayout
	local step = t.step
	local task = t.task
	local ThemeService = t.ThemeService
	local Widgets = t.Widgets
	local win = t.win

	-- regressions -----------------------------------------------------------------
	local function regressions()
		-- one check for each bug found and fixed while the library was reviewed, so none of them comes back
		local Drag = Apogee.internals.services.drag
		local regTab = win:Tab("Regressions")
		local regToast = Apogee:Notify({Title = "Default duration", Content = "closes by itself"})
		local toastStarted = os.clock()
		local closeIcon = regToast.CloseButton:GetChildren()[2]
		check(regToast.CloseButton.AnchorPoint == roblox.Vector2.new(0.5, 0.5)
			and regToast.CloseButton.Size.X.Offset >= 32 and regToast.CloseButton.Size.Y.Offset >= 32
			and closeIcon.Position.X.Scale == 0.5 and closeIcon.Position.Y.Scale == 0.5,
			"notification close control sits in the top-right with a mobile-sized hit area")

		local function visibleGroups(instance, shown)
			local count = 0
			local visible = shown and instance.Visible ~= false
			if visible and instance.ClassName == "CanvasGroup" then
				count += 1
			end
			for _, child in instance:GetChildren() do
				count += visibleGroups(child, visible)
			end
			return count
		end

		-- callbacks never fire while a widget is created
		local fires = 0
		local function count()
			fires += 1
		end
		regTab:Toggle({Title = "Quiet toggle", Value = true, Callback = count})
		regTab:Slider({Title = "Quiet slider", Value = 2, Min = 0, Max = 5, Rounding = 0, Callback = count})
		regTab:ColorPicker({Title = "Quiet picker", Value = roblox.Color3.fromRGB(10, 20, 30), Callback = count})
		regTab:Dropdown({Title = "Quiet dropdown", Values = {"a", "b"}, Value = "a", Callback = count})
		regTab:Input({Title = "Quiet input", Value = "x", Callback = count})
		regTab:Keybind({Title = "Quiet keybind", Value = "Q", Callback = count})
		check(fires == 0, "creating widgets never fires their callbacks")

		-- a trailing options table works without nil padding, for widgets and for windows
		local padded = regTab:Toggle("Padded", true, {Name = "RegPadded"})
		check(Widgets.RegPadded == padded and padded.Value == true, "a widget takes a trailing options table without nil padding")
		local optionsWindow = Apogee:Window("Options", {Minimizer = false})
		check(optionsWindow.Minimizer == nil and optionsWindow.Title == "Options", "a window takes a trailing options table in place of the subtitle")
		optionsWindow:Destroy()

		-- input fires once per change, and numeric inputs accept partial numbers
		local inputFires = 0
		local regInput = regTab:Input({Title = "Once", Value = "", Callback = function()
			inputFires += 1
		end})
		regInput.Value = "abc"
		check(inputFires == 1 and regInput._box.Text == "abc", "assigning an input value fires its callback once")
		local numeric = regTab:Input({Title = "Numeric", Value = "", Numeric = true})
		numeric:SetValue("-")
		check(numeric.Value == "-", "a numeric input accepts a lone minus sign")
		numeric:SetValue("-1.")
		check(numeric.Value == "-1.", "a numeric input accepts a trailing decimal point")
		numeric:SetValue("-1.a")
		check(numeric.Value == "-1.", "a numeric input rejects letters and keeps the last number")

		-- widgets without a value accept SetValue
		local regButton = regTab:Button({Title = "No value"})
		check(pcall(regButton.SetValue, regButton, nil), "SetValue on a button does not error")

		-- sliders: an empty range draws no NaN, and a new range clamps the value
		local flat = regTab:Slider({Title = "Flat", Value = 1, Min = 1, Max = 1, Rounding = 0})
		local flatFill = ThemeService:Look(flat.Frame).Fill.Size.X.Scale
		check(flatFill == flatFill and flatFill == 0, "a slider with Min equal to Max draws an empty fill, not NaN")
		local ranged = regTab:Slider({Title = "Ranged", Value = 8, Min = 0, Max = 10, Rounding = 0})
		ranged.Max = 5
		check(ranged.Value == 5, "a smaller Max clamps the slider value")

		-- dropdowns: indexes, lists and the AllowNull rule for multi dropdowns
		local single = regTab:Dropdown({Title = "Single", Values = {"one", "two", "three"}, Value = 1})
		single:SetValue(2)
		check(single.Value == "two", "a dropdown takes an option index in SetValue")
		single:SetValue(nil)
		check(single.Value == "two", "nil keeps the selection of a dropdown without AllowNull")
		local several = regTab:Dropdown({Title = "Several", Values = {"one", "two"}, Value = {"one"}, Multi = true})
		several:SetValue({"two"})
		check(several.Value.two and not several.Value.one, "a multi dropdown takes a list of options in SetValue")
		check(#several._options == 0 and #several._list:GetChildren() == 1, "a dropdown builds no option rows before it opens")
		several:Open()
		several:Close()
		check(#several._options == 2, "a dropdown builds its option rows when it opens")
		several:_choose(several._options[2])
		check(several.Value.two == true, "the last option of a multi dropdown without AllowNull cannot be cleared")
		several:Open()
		check(several._holder.Size == roblox.UDim2.fromScale(1, 1), "an opening dropdown list keeps its full size and never squeezes its rows")
		several:Close()
		check(several._holder.Size == roblox.UDim2.fromScale(1, 1), "a closing dropdown list keeps its full size")

		-- keybind picking takes the released key, not a held modifier
		local picked = regTab:Keybind({Title = "Pick", Value = "Q"})
		local function key(name, ended)
			local event = pointer("Keyboard")
			event.KeyCode = roblox.Enum.KeyCode[name]
			if ended then
				input.InputEnded:Fire(event)
			else
				input.InputBegan:Fire(event)
			end
		end
		task.spawn(picked._pick, picked)
		task.wait(0.25)
		key("LeftShift")
		key("E")
		key("E", true)
		key("LeftShift", true)
		check(picked.Value == "E" and not picked._picking, "keybind picking ignores a held modifier and binds the released key")

		-- a grey color has no hue, so the picker keeps the hue it shows
		local hued = regTab:ColorPicker({Title = "Hued", Value = roblox.Color3.fromRGB(255, 0, 0)})
		hued:SetValue(roblox.Color3.fromRGB(0, 0, 255))
		local hue = hued.Hue
		hued:SetValue(roblox.Color3.fromRGB(128, 128, 128))
		check(hued.Hue == hue, "a grey color keeps the hue of the color picker")

		-- a repaint of the picker writes the hex field, and parsing that text back must not round the color or reset the hue
		hued:Open()
		local huedPalette = hued._palette
		huedPalette.Hue, huedPalette.Sat, huedPalette.Vib = 0.5, 0, 0.5
		huedPalette:Display()
		check(huedPalette.Hue == 0.5, "a repaint of the color picker keeps its hue for a grey color")
		hued:Close()
		task.wait(0.3)

		-- an inherited multi dropdown keeps the selection of its source
		local inherited = regTab:Dropdown(several)
		check(inherited.Multi and inherited.Value.two == true, "a multi dropdown built from another keeps its selection")

		-- theme lookups never return internals of the themes module
		check(ThemeService:Get("Names") == nil and ThemeService:Get("Space") == nil, "Theme:Get returns only theme keys")

		-- the selected tab shows its highlight even when an overlay is open
		local covering = win:Dialog("Cover", "x", {{Title = "Ok"}})
		win:SelectTab(regTab)
		step()
		check(regTab._highlight.ImageTransparency < 1, "a tab selected under an open dialog shows its highlight")
		covering:Destroy()
		win:SelectTab(1)
		step()

		-- the text of a text box is user input and never gets translated
		local typed = Apogee.Creator:New("TextBox", {Text = "Yes"})
		Apogee:SetLocale("reg", {Yes = "Oui"})
		check(typed.Text == "Yes", "localization leaves the text of a text box alone")
		Apogee:SetLocale("en")
		typed:Destroy()

		-- a theme font applies at creation, and a replaced active theme repaints at once
		Apogee:SetTheme("ImGui")
		local imguiLabel = regTab:Paragraph({Title = "Mono", Description = "text"})
		check(imguiLabel._element.TitleLabel.FontFace.Family == roblox.Font.fromEnum(roblox.Enum.Font.RobotoMono).Family, "a widget created under a theme takes the theme font")
		Apogee:AddTheme("Regression", {Text = roblox.Color3.fromRGB(1, 2, 3)})
		Apogee:SetTheme("Regression")
		Apogee:AddTheme("Regression", {Text = roblox.Color3.fromRGB(4, 5, 6)})
		check(imguiLabel._element.TitleLabel.TextColor3 == roblox.Color3.fromRGB(4, 5, 6), "replacing the active theme repaints at once")
		Apogee:SetTheme("Dark")

		-- configs read the file every time and keep the autoload copy for themselves
		config:Save("ghost")
		config:Delete("ghost")
		check(not config:SetAutoload("ghost"), "a deleted config cannot become the autoload copy")
		check(not config:Save("autoload"), "the autoload name is reserved")
		config:Save("real")
		config:SetAutoload("real")
		check(not table.find(config:List(), "autoload") and table.find(config:List(), "real") ~= nil, "the config list hides the autoload copy")
		config:SetAutoload(nil)
		config:Delete("real")

		-- unresolved icons never fall back to Roblox asset delivery
		check(Apogee:GetIcon("rbxthumb://type=Asset&id=1") == nil, "unpacked URLs do not bypass the asset manager")
		local icons = Apogee.internals.assets.icons
		local assetManager = Apogee.internals.assets.manager
		check(icons.DefaultType == "core", "the embedded core icon pack is the default")
		local localImage = function(value)
			return type(value) == "string" and string.sub(value, 1, 13) == "localasset://"
		end
		check(assetManager.Repository == "https://github.com/umbreon-boop/packs/releases/latest/download/"
			and localImage(assetManager.Resolve("core", "Shadow")) and localImage(Apogee:GetIcon("bell")),
			"core assets resolve to local packed images")
		local packs = {
			"lucide",
			"sfsymbols",
			"gravity",
			"feather",
			"heroicons-outline",
			"heroicons-solid",
			"material-design",
			"tabler-outline",
			"tabler-filled"
		}
		local waiting = #packs
		local function loaded()
			waiting -= 1
		end
		for _, pack in ipairs(packs) do
			assetManager.LoadAsync(pack, loaded)
		end
		while waiting > 0 do
			task.wait()
		end
		check(localImage(Apogee:GetIcon("house")) and localImage(Apogee:GetIcon("orbit"))
			and localImage(Apogee:GetIcon("sfsymbols:house")) and localImage(Apogee:GetIcon("gravity:house"))
			and localImage(Apogee:GetIcon("feather:home"))
			and localImage(Apogee:GetIcon("heroicons-outline:home"))
			and localImage(Apogee:GetIcon("heroicons-solid:home"))
			and localImage(Apogee:GetIcon("material-design:home"))
			and localImage(Apogee:GetIcon("tabler-outline:home"))
			and localImage(Apogee:GetIcon("tabler-filled:home")),
			"icon names resolve to local packed images")
		icons.AddPack("regression", {numeric = 12345})
		check(Apogee:GetIcon("regression:numeric") == nil, "custom icon packs do not use rbxasset fallbacks")
		icons.Packs.regression = nil

		-- dialogs: the overlay is above the window chrome, a click during the close runs nothing, and no canvas group stays
		local regClicks = 0
		local regDialog = win:Dialog("Twice", "x", {{Title = "Once", Callback = function()
			regClicks += 1
		end}})
		check(regDialog.TintFrame.ZIndex > win.Splitter.ZIndex, "the dialog overlay is above the sidebar splitter, so the splitter cannot take its clicks")
		-- on a half pixel the card renders differently inside and outside the fade layer, so the fade in would jump
		local card = regDialog.Root
		local wholePixels = card.Size.X.Offset % 2 == 0 and card.Size.Y.Offset % 2 == 0
			and card.Position.X.Offset % 1 == 0 and card.Position.Y.Offset % 1 == 0 and card.Position.X.Scale == 0
		check(wholePixels, "a dialog card has an even size and a whole pixel center")
		single:Open()
		local list = single._canvas.Position
		check(list.X.Offset % 1 == 0 and list.Y.Offset % 1 == 0, "a dropdown list opens on whole pixels")
		single:Close()
		local onlyButton = buttons(regDialog)[1]
		onlyButton.MouseButton1Click:Fire()
		onlyButton.MouseButton1Click:Fire()
		check(regClicks == 1, "a click during the dialog close animation does not run the callback again")

		-- a dialog has its final size when it opens: TextBounds of new text arrives only after a render, and a size that
		-- changes a frame later makes the card jump during its open animation
		local early = win:Dialog("A longer dialog title", string.rep("Some longer content text. ", 8), {{Title = "Confirm"}, {Title = "Cancel"}})
		local openedSize = early.Root.Size
		local buttonSize = early._actions[1].Frame.Size
		step(2)
		check(early.Root.Size == openedSize, "a dialog card has its final size when it opens")
		check(early._actions[1].Frame.Size == buttonSize, "dialog buttons have their final size when the dialog opens")
		early:Destroy()

		-- layout uses unscaled measurements: a dialog in a window that scales keeps its final width
		-- a long text, so the text and not the minimum width decides the card width
		local measured = win:Dialog("Measured", "x", {{Title = "Ok"}})
		setLayout(measured.Content, "TextBounds", roblox.Vector2.new(400, 20))
		local finalWidth = measured.Root.Size.X.Offset
		win._rootScale.Scale = 0.5
		setLayout(measured.Title, "TextBounds", roblox.Vector2.new(50, 10))
		setLayout(measured.Content, "TextBounds", roblox.Vector2.new(200, 10))
		for _, action in measured._actions do
			setLayout(action.Title, "TextBounds", roblox.Vector2.new(50, 10))
		end
		check(measured.Root.Size.X.Offset == finalWidth, "a dialog measures its text without the scale of the window")
		win._rootScale.Scale = 1
		measured:Destroy()

		-- a dropdown list takes its height from the row count, so a late or scaled measurement cannot cut its last row
		setLayout(single._layout, "AbsoluteContentSize", roblox.Vector2.new(0, 0))
		single:_resize()
		check(single._canvas.Size.Y.Offset == 3 * 32 + 2 * 4 + 20, "a dropdown list height follows its rows, not a measurement")
		setLayout(single._layout, "AbsoluteContentSize", nil)

		-- a closed dropdown list does not follow its field, so scrolling stays cheap
		local closedAt = single._canvas.Position
		setLayout(single._inner, "AbsolutePosition", roblox.Vector2.new(777, 777))
		check(single._canvas.Position == closedAt, "a closed dropdown list does not reposition when its field moves")
		setLayout(single._inner, "AbsolutePosition", nil)

		-- a tab switch moves only the container in transit, never the holder of every tab
		local moved, holderMoved = 0, false
		local switchCreate = services.TweenService.Create
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = switchCreate(service, instance, info, properties)
			local play = tween.Play
			tween.Play = function()
				local away = 0
				for _, other in win.Tabs do
					if other.Container.Parent ~= win.ContainerHolder then
						away += 1
					end
				end
				moved = math.max(moved, away)
				holderMoved = holderMoved or win.ContainerHolder.Parent ~= win.ContainerCanvas
				play()
			end
			return tween
		end
		win:SelectTab(regTab)
		win:SelectTab(1)
		services.TweenService.Create = switchCreate
		check(moved <= 1 and not holderMoved, "a tab switch moves at most one tab container")

		-- fades change the transparency of each part: no canvas group, exact values afterwards, and outside changes stay
		local groupsDuringFades = 0
		local fadeCreate = services.TweenService.Create
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = fadeCreate(service, instance, info, properties)
			local play = tween.Play
			tween.Play = function()
				groupsDuringFades += visibleGroups(Apogee.GUI, true)
				play()
			end
			return tween
		end
		local faded = win:Dialog("Faded", "x", {{Title = "Ok"}})
		single:Open()
		single:Close()
		win:SelectTab(regTab)
		win:SelectTab(1)
		services.TweenService.Create = fadeCreate
		check(groupsDuringFades == 0, "no fade uses a canvas group")
		check((faded.Title.TextTransparency or 0) == 0 and faded.Root:FindFirstChild("Surface").ImageTransparency == 0, "a fade in restores the exact transparency of every part")
		faded:Destroy()

		local subtitle = win.TitleBar.Frame:GetChildren()[1]:GetChildren()[3]
		local subtitleBase = subtitle.TextTransparency
		local steps = {}
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = fadeCreate(service, instance, info, properties)
			if instance.ClassName == "NumberValue" then
				local play = tween.Play
				tween.Play = function()
					-- intermediate frames of the fade, with values read back as 32 bit floats in between
					for _, alpha in {0.3, 0.6} do
						instance.Value = alpha
						table.insert(steps, subtitle.TextTransparency)
					end
					play()
				end
			end
			return tween
		end
		local restyled = win:Dialog("Changed", "x", {{Title = "Ok"}})
		win:Minimize()
		win:Minimize()
		services.TweenService.Create = fadeCreate
		local expected = 1 - (1 - subtitleBase) * 0.6
		check(#steps > 0 and math.abs(steps[#steps] - expected) < 1e-3, "a fade keeps fading with 32 bit float values")
		check(subtitle.TextTransparency == subtitleBase, "minimize and restore leave the exact transparency of every part")
		restyled:Destroy()

		-- a value that other code changes during a fade, such as a hover highlight, keeps that change
		local changedSurface
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = fadeCreate(service, instance, info, properties)
			if instance.ClassName == "NumberValue" and not changedSurface then
				local play = tween.Play
				tween.Play = function()
					changedSurface = true
					local dialogHost = next(win._dialogs)
					if dialogHost then
						dialogHost.Root:FindFirstChild("Surface").ImageTransparency = 0.5
					end
					play()
				end
			end
			return tween
		end
		local outside = win:Dialog("Outside", "x", {{Title = "Ok"}})
		services.TweenService.Create = fadeCreate
		check(math.abs(outside.Root:FindFirstChild("Surface").ImageTransparency - 0.5) < 1e-4, "a change by other code during a fade stays")
		outside:Destroy()

		-- canvas groups exist only while something fades
		win:SelectTab(regTab)
		win:SelectTab(1)
		single:Open()
		local openDialog = win:Dialog("Open", "x", {{Title = "Ok"}})
		local openPopup = Apogee:Popup({Title = "Open"})
		check(visibleGroups(Apogee.GUI, true) == 0, "no canvas group stays around open dialogs, popups and dropdown lists")
		single:Close()
		openDialog:Close()
		openPopup:Destroy()

		-- popups: an Open during the close animation cannot stop the destruction
		local stubborn = Apogee:Popup({Title = "Stubborn"})
		local create = services.TweenService.Create
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = create(service, instance, info, properties)
			local play = tween.Play
			tween.Play = function()
				if stubborn._closing and not stubborn._destroyed then
					stubborn:Open()
				end
				play()
			end
			return tween
		end
		stubborn:Close()
		services.TweenService.Create = create
		check(stubborn._destroyed, "opening a popup during its close animation does not leave it stuck")

		-- lifetimes: theme callbacks, drag locks and child links end with their owner
		local motors = 0
		for _ in ThemeService._motors do
			motors += 1
		end
		local shortLived = Apogee:Popup({Title = "Short lived"})
		shortLived:Toggle({Title = "Tracked"})
		local dragged = shortLived:Slider({Title = "Dragged", Value = 1, Min = 0, Max = 5, Rounding = 0})
		ThemeService:Look(dragged.Frame).Hitbox.InputBegan:Fire(pointer("MouseButton1", 120, 0))
		check(Drag._active ~= nil, "a slider press takes the shared drag lock")
		shortLived:Destroy()
		local after = 0
		for _ in ThemeService._motors do
			after += 1
		end
		check(after == motors, "destroyed widgets leave no theme callbacks behind")
		check(Drag._active == nil, "a slider destroyed during a drag releases the shared drag lock")
		check(not table.find(win._children or {}, shortLived), "a destroyed popup leaves its parent's child list")
		local owner = Apogee:Window("Owner", {Minimizer = false})
		local owned = owner:Popup("Owned")
		owner:Destroy()
		check(owned._destroyed and not Apogee:HasOverlay(), "destroying a window destroys its popups, so they stop blocking input")

		-- window transitions: nothing interrupts a close, and maximize keeps the restore size
		local closing2 = Apogee:Window("Closing", {Minimizer = false})
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = create(service, instance, info, properties)
			local play = tween.Play
			tween.Play = function()
				if closing2._closing and not closing2._destroyed then
					closing2:Minimize()
					closing2:Maximize(true)
				end
				play()
			end
			return tween
		end
		closing2:Close()
		services.TweenService.Create = create
		check(closing2._destroyed and not closing2.Minimized and not closing2.Maximized, "minimize and maximize do nothing while a window closes")
		local restoreSize = win.Root.Size
		win:Maximize(true)
		win:Maximize(true)
		win:Maximize(false)
		check(win.Root.Size == restoreSize, "a second maximize keeps the restore size")
		win:Maximize(true)
		local corner = pointer("MouseButton1", win.Root.AbsolutePosition.X + 2, win.Root.AbsolutePosition.Y + 2)
		win.Root.InputBegan:Fire(corner)
		input.InputChanged:Fire(pointer("MouseMovement", 400, 400))
		input.InputEnded:Fire(corner)
		check(win.Maximized and win.Root.Size == win.Size, "a maximized window cannot be resized by its edges")
		win:Maximize(false)

		-- maximize applies its new geometry while hidden instead of tweening Size and reflowing every child per frame
		local sizeTweens = 0
		services.TweenService.Create = function(service, instance, info, properties)
			local tween = create(service, instance, info, properties)
			if instance == win.Root and properties.Size then
				sizeTweens += 1
			end
			return tween
		end
		win:Maximize(true)
		services.TweenService.Create = create
		check(sizeTweens == 0 and win.Root.Size == win.Size, "a maximize does not tween the window size and reflow its children")
		win:Maximize(false)

		-- the sidebar keeps its width through scale animations and layouts, and the splitter is easy to hit
		local preferred = win.TabWidth
		setLayout(win.Root, "AbsoluteSize", roblox.Vector2.new(80, 45))
		check(win.TabWidth == preferred and win._tabFrame.Size.X.Offset == preferred, "a scaled AbsoluteSize does not change the sidebar width")
		setLayout(win.Root, "AbsoluteSize", nil)
		win:_updateTabSection(400)
		win:_updateTabSection(win.Root.Size.X.Offset)
		check(win.TabWidth == preferred, "a narrow layout does not shrink the sidebar for good")
		win.Minimizer.Enabled = true
		win:Minimize()
		win:Minimize()
		win.Minimizer.Enabled = false
		check(win.TabWidth == preferred, "minimize and restore keep the sidebar width")
		win:SetTabWidth(200)
		check(win.TabWidth == 200, "a manual sidebar width can be larger than the default width")
		win:SetTabWidth(1000)
		check(win.TabWidth == 240, "a manual sidebar width is capped")
		win:SetTabWidth(preferred)
		check(win.Splitter.Size.X.Offset > Apogee.internals.assets.themes.Space.XS, "the splitter hit area is wider than the gap it sits in")

		-- Minimize and restore never scale or resize window contents; they only fade the unchanged layout.
		local minimizer2 = win.Minimizer
		minimizer2.Enabled = true
		local scaleTweens, sizeTweens
		services.TweenService.Create = function(service, instance, info, properties)
			if instance == win._rootScale then
				scaleTweens += 1
			elseif instance == win.Root and properties.Size then
				sizeTweens += 1
			end
			return create(service, instance, info, properties)
		end
		scaleTweens, sizeTweens = 0, 0
		local sizeBeforeMinimize = win.Root.Size
		win:Minimize()
		check(minimizer2.Frame.Visible, "the minimizer button shows when the minimize starts, not after it ends")
		check(scaleTweens == 0 and sizeTweens == 0 and win.Root.Size == sizeBeforeMinimize,
			"minimize does not scale or resize any window elements")
		minimizer2:_moveTo(roblox.Vector2.new(500, 300))
		local positionTweens = 0
		services.TweenService.Create = function(service, instance, info, properties)
			if instance == win._rootScale then
				scaleTweens += 1
			elseif instance == win.Root and properties.Position then
				positionTweens += 1
			end
			return create(service, instance, info, properties)
		end
		scaleTweens = 0
		win:Minimize()
		services.TweenService.Create = create
		minimizer2.Enabled = false
		check(scaleTweens == 0 and sizeTweens == 0 and positionTweens == 0 and win._rootScale.Scale == 1,
			"restore does not scale or resize any window elements")
		check(win.Root.Position == win.Position, "a restore keeps the window at its own place")

		-- Under a UIScale the text draws at a whole font size rounded down. Layout that follows the rendered text, and
		-- any animation that grows to scale 1, changes when the animation ends, so the interface jumped.
		local Measure = Apogee.internals.services.measure
		local described = regTab:Paragraph({Title = "Described", Description = "a description that wraps over a few lines"})._element
		setLayout(described.LabelHolder, "AbsoluteSize", roblox.Vector2.new(200, 20))
		local descHeight = math.ceil(Measure.Text(described.DescLabel, 200).Y)
		check(described.Frame.AutomaticSize ~= roblox.Enum.AutomaticSize.Y
			and described.DescLabel.AutomaticSize ~= roblox.Enum.AutomaticSize.Y
			and described.Frame.Size.Y.Offset == math.max(42, 9 + 16 + 2 + descHeight + 9),
			"a card with a description gets its height from Measure.Text, not from automatic sizing")
		local fitHeight = described.Frame.Size.Y.Offset
		win._rootScale.Scale = 0.5
		setLayout(described.LabelHolder, "AbsoluteSize", roblox.Vector2.new(100, 10))
		check(described.Frame.Size.Y.Offset == fitHeight, "a scale animation does not change the card height")
		win._rootScale.Scale = 1
		setLayout(described.LabelHolder, "AbsoluteSize", nil)
		described:SetDesc("")
		check(described.Frame.Size.Y.Offset == 42, "a card without a description has the row height")

		local scaledSection = regTab:Section("Scaled")
		scaledSection:Toggle({Title = "Row", Value = false})
		local sectionHeight = scaledSection.Root.Size.Y.Offset
		local sectionLayout = scaledSection.Container:FindFirstChildOfClass("UIListLayout")
		setLayout(sectionLayout, "AbsoluteContentSize", roblox.Vector2.new(0, 500))
		check(scaledSection.Root.Size.Y.Offset == sectionHeight, "a section height comes from its rows, not from AbsoluteContentSize")
		setLayout(sectionLayout, "AbsoluteContentSize", nil)

		local titleLabel = win.TitleBar.TitleLabel
		check(titleLabel.AutomaticSize ~= roblox.Enum.AutomaticSize.X
			and titleLabel.Size.X.Offset == math.ceil(Measure.Text(titleLabel).X), "the window title width comes from Measure.Text")

		local slideDialog = win:Dialog({Title = "Slide", Content = "no scale", Buttons = {{Title = "OK"}}})
		check(slideDialog.Root:FindFirstChildOfClass("UIScale") == nil, "a dialog does not scale")
		check(slideDialog.Root.Position == slideDialog:_position(0), "a dialog opens at the center of the window")
		slideDialog:Destroy()

		local slidePopup = Apogee:Popup({Title = "Slide"})
		check(slidePopup.Root:FindFirstChildOfClass("UIScale") == nil and slidePopup.Root.Position == slidePopup.Position,
			"a popup opens without scale at its own position")
		slidePopup.Visible = false
		check(slidePopup.Root.Position == slidePopup.Position, "a hidden popup stays at its position")
		slidePopup:Open()
		check(slidePopup.Root.Position == slidePopup.Position, "a popup opens again without an error")
		slidePopup:Destroy()

		single:Open()
		local openPosition = single._canvas.Position
		check(single._canvas:FindFirstChildOfClass("UIScale") == nil, "a dropdown list opens without scale")
		single:Close()
		check(single._canvas.Position == openPosition, "a closing dropdown list stays at its position")

		-- the ImGui theme draws no decorative icons and closes their gaps
		local iconTab = win:Tab("Icons", "house")
		local chevronButton = regTab:Button({Title = "Chevron"})
		local chevron = chevronButton._element.Frame:FindFirstChild("Chevron")
		local listChevron = single._inner:FindFirstChild("Chevron")
		local iconToast = Apogee:Notify({Title = "Icon", Content = "toast"})
		local titleIcon = win.TitleBar.Frame:FindFirstChildOfClass("Frame"):FindFirstChild("Icon")
		local minimizerIcon = win.Minimizer.Frame:FindFirstChild("Icon")
		check(iconTab._icon.Visible and chevron.Visible and listChevron.Visible and iconToast.Icon.Visible
			and (titleIcon == nil or titleIcon.Visible) and minimizerIcon.Visible, "the default theme shows the decorative icons")
		Apogee:SetTheme("ImGui")
		check(not iconTab._icon.Visible and iconTab._icon.Image == "", "the ImGui theme hides the tab icon")
		check(not chevron.Visible and chevronButton._element.LabelHolder.Size.X.Offset == -24, "the ImGui theme hides the button chevron")
		check(not listChevron.Visible, "the ImGui theme hides the dropdown chevron")
		check(not iconToast.Icon.Visible and iconToast.LabelHolder.Position.X.Offset == 14, "the ImGui theme hides the toast icon")
		check(titleIcon == nil or not titleIcon.Visible, "the ImGui theme hides the window icon")
		check(not minimizerIcon.Visible and minimizerIcon.Image == "", "the ImGui theme hides the minimizer icon")
		check(win.Minimizer._body:FindFirstChild("ImGuiRestoreMark").Visible, "the ImGui mobile minimizer replaces its hidden icon with a restore mark")
		Apogee:SetTheme("Dark")
		check(iconTab._icon.Visible and chevron.Visible and listChevron.Visible and iconToast.Icon.Visible,
			"switching back from ImGui shows the icons again")
		check(minimizerIcon.Visible and minimizerIcon.Image == Apogee:GetIcon("layout-grid"), "switching back restores the minimizer icon")
		check(not win.Minimizer._body:FindFirstChild("ImGuiRestoreMark").Visible, "switching back hides the ImGui-only mobile restore mark")
		iconToast:Close()

		-- a palette can replace role sizes, and a live theme switch resizes the parts that exist already
		local sizedCard = Widgets.MyToggle._element.Frame
		local sizedTab = win.Tabs[1].Frame
		local sizedField = Widgets.Dropdown._inner
		local sizedMinimizer = win.Minimizer
		Apogee:AddTheme("Sized", {Size = {Row = 30, Tab = 20, Control = 22, Button = 24, Option = 26, Minimizer = 40}})
		Apogee:SetTheme("Sized")
		check(sizedCard.Size.Y.Offset == 30, "a palette Size replaces the card row height")
		check(sizedTab.Size.Y.Offset == 20 and sizedField.Size.Y.Offset == 22, "a palette Size replaces the tab and field heights")
		check(sizedMinimizer._size == 40 and sizedMinimizer.Frame.Size.X.Offset == 40, "a palette Size replaces the minimizer size")
		check(ThemeService:Size("List") == 402, "a size that the palette does not set keeps the default")
		Widgets.Dropdown:Open()
		check(Widgets.Dropdown._options[1].Frame.Size.Y.Offset == 26, "a palette Size replaces the dropdown row height")
		Widgets.Dropdown:Close()
		local sizedDialog = win:Dialog("Sized", "rows", {{Title = "Ok"}})
		check(sizedDialog._actions[1].Frame.Size.Y.Offset == 24 and sizedDialog.ButtonHolderFrame.Size.Y.Offset == 48,
			"a palette Size replaces the dialog button and tray heights")
		Apogee:SetTheme("Dark")
		check(sizedCard.Size.Y.Offset == 42 and sizedTab.Size.Y.Offset == 30 and sizedField.Size.Y.Offset == 30
			and sizedMinimizer._size == 48, "a live switch back restores the default sizes")
		check(sizedDialog._actions[1].Frame.Size.Y.Offset == 32 and sizedDialog.ButtonHolderFrame.Size.Y.Offset == 56,
			"an open dialog follows a live size switch")
		sizedDialog:Destroy()

		-- toasts without a Duration close after the default 5 seconds
		task.wait(math.max(0, 5.2 - (os.clock() - toastStarted)))
		check(regToast.Closed, "a toast without a Duration closes after 5 seconds")
	end
	regressions()

	t.Apogee = Apogee
end
