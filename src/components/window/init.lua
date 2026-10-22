--[=[
	The main window: a draggable, resizable and maximizable frame with a tab sidebar and an animated content area.

	@class Window
	@location internals/components
]=]
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Backdrop = require("../backdrop")
local Dialog = require("../dialog")
local Minimizer = require("./minimizer")
local Motion = require("../../services/motion")
local Popup = require("../popup")
local Settings = require("./settings")
local State = require("../../public")
local Style = require("../../assets/themes")
local Tab = require("../tab")
local TitleBar = require("./titlebar")
local Fade = require("../../services/fade")
local Input = require("./input")
local Transitions = require("./transitions")
local Creator = require("../../services/creator")
local Resize = require("../../services/resize")
local Theme = require("../../services/theme")
local Maid = require("@aria/maid")
local Args = require("../../services/args")

--[=[
	@interface WindowConfig
	.Title string -- Required initial window title; use `SetTitle` to change it.
	.SubTitle string? -- Secondary title in the title bar.
	.Icon string? -- An icon name or asset id displayed in the title bar
	.Size UDim2? -- Preferred offset dimensions; clamped to viewport bounds. Defaults to two thirds of the viewport.
	.Position UDim2? -- Initial screen position; defaults to centered and is corrected to remain on screen.
	.TabWidth number? -- Preferred sidebar width; constrained by available content width.
	.Theme string? -- Theme to activate before constructing this window.
	.Minimizer (Minimizer.Config | false)? -- Settings for the floating toggle button, false disables it
	.CloseCallback (() -> ())? -- Runs after the close animation and before the window is destroyed.
	@within Window
]=]
export type Config = {
	Title: string, SubTitle: string?, Icon: string?, Size: UDim2?, Position: UDim2?,
	TabWidth: number?, Theme: string?, Minimizer: (Minimizer.Config | false)?,
	CloseCallback: (() -> ())?
}

--[=[
	@interface DialogConfig
	.Title string -- Dialog heading.
	.Content string -- Body text; long content is clipped to the available card area.
	.Buttons { DialogButton } -- Buttons appear in supplied order. Each callback runs before dismissal; returning false keeps the dialog open.
	@within Window
]=]
--[=[
	@interface DialogButton
	.Title string -- Button label.
	.Callback (() -> boolean?)? -- Return false to leave the dialog open after activation.
	.Style "Suggested" | "Standard" | "Destructive"? -- Visual role; the first button defaults to Suggested.
	@within Window
]=]
export type DialogButtonConfig = { Title: string, Callback: (() -> boolean?)?, Style: ("Suggested" | "Standard" | "Destructive")? }

export type DialogConfig = { Title: string, Content: string, Buttons: { DialogButtonConfig } }

local Window = {}
Window.__index = Window
for name, method in Transitions do
	Window[name] = method
end
local windows = {}

function Window.GetAll(): { any }
	return windows
end

local camera = Workspace.CurrentCamera
local MIN_CONTENT_WIDTH = 310
local LAYOUT_CLEARANCE = 10
local MIN_TAB_WIDTH = 60
-- the default sidebar width is at most this; a width set by the user can be larger, up to the maximum
local DEFAULT_TAB_WIDTH = 160
local MAX_TAB_WIDTH = 240
-- the invisible splitter is wider than the gap it sits in, and wider again for fingers
local SPLITTER_WIDTH = if UserInputService.TouchEnabled then 36 else 20
local MIN_SIZE = Vector2.new(430, 200)
local MAX_SIZE = Vector2.new(2048, 2048)
local SCREEN_MARGIN = 16
local SECTION_TOP = 48
-- the title line is 24 px high, followed by a small gap
local CONTENT_TOP = SECTION_TOP + 24 + 2
local TAB_OUT_DURATION = 0.1
local TAB_IN_DURATION = 0.22
local TAB_SHIFT = 8

-- the center of the gap between the sidebar and the content
--@inline
local function splitterX(tabWidth: number): number
	return Style.Space.XS + tabWidth + Style.Space.XS / 2
end
local function defaultViewportSize(): Vector2
	local vp = camera.ViewportSize
	return Vector2.new(math.floor(vp.X * 2 / 3), math.floor(vp.Y * 2 / 3))
end

-- the window never grows past the viewport, and its minimum size shrinks on screens smaller than it
local function fit(size: Vector2, contentMinimum: number?): Vector2
	local largest = (camera.ViewportSize - Vector2.new(SCREEN_MARGIN, SCREEN_MARGIN) * 2):Min(MAX_SIZE)
	local minimumContent = math.max(MIN_CONTENT_WIDTH, contentMinimum or 0)
	local minimumWidth = math.max(MIN_SIZE.X, minimumContent + MIN_TAB_WIDTH + 3 * Style.Space.XS)
	local minimum = Vector2.new(minimumWidth, MIN_SIZE.Y):Min(largest)
	return size:Max(minimum):Min(largest)
end
local function minimumContentWidth(window: any): number
	local required = Resize.RequiredWidth(window)
	return math.max(MIN_CONTENT_WIDTH, if required > 0 then required + LAYOUT_CLEARANCE else 0)
end

function Window:_fitResize(size: Vector2): Vector2
	return fit(size, minimumContentWidth(self))
end

--[=[
	Creates a new window. Use `Apogee:Window` instead of calling this directly.

	@param config Config -- Window title, sizing, position, theme, and minimize settings.
	@param parent Instance -- The screen gui to draw the window in
	@return [Window](Window.md) -- The newly created window.
]=]
function Window.New(config: Config, parent: Instance): any
	local preferred = if config.Size
		then Vector2.new(config.Size.X.Offset, config.Size.Y.Offset)
	else defaultViewportSize()
	local fitted = fit(preferred)
	local size = UDim2.fromOffset(fitted.X, fitted.Y)
	local tabLayout = Creator:New("UIListLayout", {Padding = UDim.new(0, Style.Space.XXXS)})
	local initialTabWidth = math.clamp(config.TabWidth or math.min(fitted.X - MIN_CONTENT_WIDTH - 3 * Style.Space.XS, DEFAULT_TAB_WIDTH), MIN_TAB_WIDTH, MAX_TAB_WIDTH)
	-- the sidebar is inset from the edge and the content is inset from the sidebar
	local contentX = Style.Space.XS + initialTabWidth + Style.Space.XS

	local centeredX = math.floor((camera.ViewportSize.X - fitted.X) / 2)
	local centeredY = math.floor((camera.ViewportSize.Y - fitted.Y) / 2)
	local position = if config.Position
		then config.Position
	else UDim2.fromOffset(centeredX, centeredY)
	if config.Position and config.Position.X.Scale == 0 and config.Position.Y.Scale == 0 then
		local maxX = math.max(0, camera.ViewportSize.X - fitted.X)
		local maxY = math.max(0, camera.ViewportSize.Y - fitted.Y)
		position = UDim2.fromOffset(
			math.clamp(position.X.Offset, 0, maxX),
			math.clamp(position.Y.Offset, 0, maxY)
		)
	end

	local self = setmetatable({
		Minimized = false,
		Maximized = false,
		Size = size,
		TabWidth = initialTabWidth,
		_tabWidth = initialTabWidth,
		Position = position,
		_preferred = preferred,
		Tabs = {},
		_selected = nil,
		_notified = false,
		_restoreSize = Vector2.new(size.X.Offset, size.Y.Offset),
		_gui = parent,
		_windows = windows,
		_elements = {},
		_openFrames = {},
		_dialogs = {},
		_widgets = {},
		_dropdowns = {},
		_transitionId = 0,
		Transparency = 0,
		Title = config.Title,
		_closeCallback = config.CloseCallback,
	}, Window)
	self._window = self

	self._tabLayout = tabLayout
	self._horizontalTabs = false
	self.TabHolder = Creator:New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ScrollBarImageTransparency = 1,
		ScrollBarThickness = 0,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y
	}, {self._tabLayout})

	local tabFrame = Creator:New("Frame", {
		Size = UDim2.new(0, initialTabWidth, 1, -(SECTION_TOP + Style.Space.XS)),
		Position = UDim2.fromOffset(Style.Space.XS, SECTION_TOP),
		BackgroundTransparency = 1,
		ClipsDescendants = true
	}, {self.TabHolder})
	self._tabFrame = tabFrame

	self.TabDisplay = Creator:New("TextLabel", {
		RichText = true,
		Text = "Tab",
		TextTransparency = 0,
		FontFace = Font.new(Style.Font, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		TextSize = Style.Type.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -contentX - Style.Space.XS, 0, 24),
		Position = UDim2.fromOffset(contentX, SECTION_TOP),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})

	self.ContainerHolder = Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	-- the content moves into this frame only while a tab switch animates it
	self.ContainerAnim = Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	self.ContainerCanvas = Creator:New("Frame", {
		Size = UDim2.new(1, -contentX - Style.Space.XS, 1, -CONTENT_TOP),
		Position = UDim2.fromOffset(contentX, CONTENT_TOP),
		BackgroundTransparency = 1
	}, {self.ContainerAnim, self.ContainerHolder})

	self.Splitter = Creator:New("TextButton", {
		Name = "Splitter",
		Size = UDim2.new(0, SPLITTER_WIDTH, 1, -(SECTION_TOP + Style.Space.XS)),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(splitterX(initialTabWidth), SECTION_TOP),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Active = true,
		ZIndex = 5
	})

	self.Backdrop = Backdrop.New()
	self._rootScale = Creator:New("UIScale", {Scale = 1})
	self.Root = Creator:New("Frame", {
		BackgroundTransparency = 1,
		Active = true,
		Size = self.Size,
		Position = self.Position,
		Parent = parent
	}, {self.Backdrop, self.TabDisplay, self.ContainerCanvas, tabFrame, self.Splitter, self._rootScale})
	self:_updateMinimumWidth()
	-- the shadow is a direct child of the root and fades on its own, back to its rest transparency
	self._shadow = self.Backdrop:FindFirstChild("Shadow")
	self._shadowRest = self._shadow.ImageTransparency
	self._shadow.Parent = self.Root

	self.TitleBar = TitleBar.New(self, config)
	if config.Minimizer ~= false then
		self.Minimizer = Minimizer.New(config.Minimizer or {}, self)
	end

	self._tabTransitionId = 0
	-- the unscaled size: `AbsoluteSize` also follows the scale animations of minimize, restore and close
	self.Root:GetPropertyChangedSignal("Size"):Connect(function()
		self:_updateTabSection(self.Root.Size.X.Offset)
	end)

	Input.Connect(self, function(proposedSize)
		return self:_fitResize(proposedSize)
	end)
	-- a palette can change the tab height or the content inset while tabs already exist
	Theme:Track(function()
		self:_updateTabSection(self.Root.Size.X.Offset)
	end, self.Root)
	--@inline
	local function setTabAxis(axis: string)
		assert(axis == "X" or axis == "Y", "Window:SetTabAxis - Axis must be X or Y")
		local horizontal = axis == "X"
		if self.Splitter then
			self.Splitter.Visible = not horizontal
		end
		if self._horizontalTabs ~= horizontal then
			self._horizontalTabs = horizontal
			tabLayout.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
			self.TabHolder.ScrollingDirection = if horizontal then Enum.ScrollingDirection.X else Enum.ScrollingDirection.Y
			self:_updateMinimumWidth()
		end
	end
	self.SetTabAxis = function(_window: any, axis: string)
		setTabAxis(axis)
	end
	table.insert(windows, self)
	State.Current = self
	State:RegisterHost(self)
	return self
end
local function applyTransparency(parent: Instance, value: number)
	for _, child in parent:GetChildren() do
		if child:IsA("ImageLabel") and (child.Name == "Surface" or child.Name == "Icon") then
			child.ImageTransparency = value
		end
		applyTransparency(child, value)
	end
end

--[=[
	Sets the transparency of the window surfaces.
	@param value number -- A number from 0 to 1
]=]
function Window:SetTransparency(value: number)
	value = math.clamp(value, 0, 1)
	self.Transparency = value
	local background = self.Backdrop and self.Backdrop:FindFirstChild("Background")
	if background then
		background.ImageTransparency = value
	end
	if self.Root then
		applyTransparency(self.Root, value)
	end
	if self.Minimizer then
		self.Minimizer:SetTransparency(value)
	end
	for _, child in self._children or {} do
		if child.SetTransparency then
			child:SetTransparency(value)
		end
	end
end

-- the widest sidebar that still leaves the content its minimum width
--@inline
local function widestTab(width: number, contentMinimum: number): number
	return math.clamp(width - contentMinimum - 3 * Style.Space.XS, MIN_TAB_WIDTH, MAX_TAB_WIDTH)
end

-- Lays out the sidebar and the content for a window width. The visible sidebar is the preferred width when it fits.
-- The layout never changes the preferred width, so a small window or an animation cannot shrink the sidebar for good.
function Window:_updateTabSection(width: number)
	local contentMinimum = minimumContentWidth(self)
	if self._horizontalTabs then
		local tabHeight = Theme:Size("Tab")
		local stripWidth = math.max(0, width - 2 * Style.Space.XS)
		-- Size the strip before measuring labels: Measure.Text can yield while a font loads, and the tabs must not
		-- stay inside the old sidebar width during that time.
		self._tabFrame.Position = UDim2.fromOffset(Style.Space.XS, SECTION_TOP)
		self._tabFrame.Size = UDim2.fromOffset(stripWidth, tabHeight)
		self.TabHolder.Size = UDim2.fromOffset(stripWidth, tabHeight)
		self.TabDisplay.Position = UDim2.fromOffset(Style.Space.XS, SECTION_TOP + tabHeight + Style.Space.XS)
		self.TabDisplay.Size = UDim2.fromOffset(stripWidth, 24)
		self.ContainerCanvas.Position = UDim2.fromOffset(Style.Space.XS, SECTION_TOP + tabHeight + 40)
		self.ContainerCanvas.Size = UDim2.new(1, -2 * Style.Space.XS, 1, -(SECTION_TOP + tabHeight + 50))
		self.Splitter.Visible = false
		local tabGap = Style.Space.XXXS
		local tabTotal = 0
		for _, tab in self.Tabs do
			local tabWidth = tab._preferredTabWidth and tab._preferredTabWidth() or MIN_TAB_WIDTH
			tab.Frame.Size = UDim2.fromOffset(tabWidth, tabHeight)
			tabTotal += tabWidth + tabGap
			local update = rawget(tab, "_updateTabLayout")
			if update then
				update(tabWidth, true)
			end
		end
		tabTotal = math.max(0, tabTotal - tabGap)
		self.TabHolder.CanvasSize = UDim2.fromOffset(tabTotal, tabHeight)
		return
	end
	if self.Splitter then
		self.Splitter.Visible = true
	end
	local tabWidth = math.clamp(self._tabWidth, MIN_TAB_WIDTH, widestTab(width, contentMinimum))
	self.TabWidth = tabWidth

	local contentX = Style.Space.XS + tabWidth + Style.Space.XS
	local availableContentWidth = width - contentX - Style.Space.XS
	local contentWidth = math.max(contentMinimum, availableContentWidth)

	if self._tabFrame then
		self._tabFrame.Size = UDim2.new(0, tabWidth, 1, -(SECTION_TOP + Style.Space.XS))
	end
	if self.TabHolder then
		self.TabHolder.Size = UDim2.fromScale(1, 1)
	end
	if self.Splitter then
		self.Splitter.Position = UDim2.fromOffset(splitterX(tabWidth), SECTION_TOP)
	end
	for _, tab in self.Tabs do
		tab.Frame.Size = UDim2.new(1, 0, 0, Theme:Size("Tab"))
		local updateTabLayout = rawget(tab, "_updateTabLayout")
		if updateTabLayout then
			updateTabLayout(tabWidth)
		end
	end
	if self.TabDisplay then
		self.TabDisplay.Position = UDim2.fromOffset(contentX, SECTION_TOP)
		self.TabDisplay.Size = UDim2.fromOffset(contentWidth, 24)
	end
	if self.ContainerCanvas then
		self.ContainerCanvas.Position = UDim2.fromOffset(contentX, CONTENT_TOP)
		self.ContainerCanvas.Size = UDim2.new(0, contentWidth, 1, -CONTENT_TOP)
	end
end

-- Keep the window itself above the minimum width required by its layout contents.
function Window:_updateMinimumWidth()
	local contentMinimum = minimumContentWidth(self)
	local width = math.max(MIN_SIZE.X, contentMinimum + MIN_TAB_WIDTH + 3 * Style.Space.XS)
	local screenWidth = math.max(0, camera.ViewportSize.X - 2 * SCREEN_MARGIN)
	width = math.min(width, screenWidth, MAX_SIZE.X)
	Resize.Apply(self.Root, width)

	-- A new layout can require more room than the window currently has. Grow the logical
	-- size too, otherwise the content keeps the old width while the constraint widens the root.
	if not self.Maximized and self.Root.Size.X.Offset < width then
		local size = self:_fitResize(Vector2.new(width, self.Root.Size.Y.Offset))
		self.Size = UDim2.fromOffset(size.X, size.Y)
		self:_place(size, Vector2.new(self.Position.X.Offset, self.Position.Y.Offset))
	else
		self:_updateTabSection(self.Root.Size.X.Offset)
	end
end

--[=[
	Sets the sidebar tabs section width manually.
	@param width number -- The width in pixels
]=]
function Window:SetTabWidth(width: number)
	self._tabWidth = math.clamp(width, MIN_TAB_WIDTH, widestTab(self.Size.X.Offset, minimumContentWidth(self)))
	self:_updateTabSection(self.Root.Size.X.Offset)
end

function Window:_fitScreen()
	local viewport = camera.ViewportSize
	if self.Maximized then
		self:_updateMinimumWidth()
		self.Size = UDim2.fromOffset(viewport.X, viewport.Y)
		self:_place(viewport)
		return
	end

	local size = self:_fitResize(self._preferred)
	local x = math.clamp(self.Position.X.Offset, 0, math.max(viewport.X - size.X, 0))
	local y = math.clamp(self.Position.Y.Offset, 0, math.max(viewport.Y - size.Y, 0))
	self.Size = UDim2.fromOffset(size.X, size.Y)
	self.Position = UDim2.fromOffset(x, y)
	-- a minimized window keeps its minimized position, the restore animation moves it back
	self:_place(size, if self.Minimized then nil else Vector2.new(x, y))
end

-- sizes and moves the window frame at once, without animation
function Window:_place(size: Vector2?, position: Vector2?)
	if size then
		self.Root.Size = UDim2.fromOffset(size.X, size.Y)
		self:_updateTabSection(size.X)
	end
	if position then
		self.Root.Position = UDim2.fromOffset(position.X, position.Y)
	end
end

--[=[
	Changes the title in the title bar.

	@param title string -- The new title
]=]
function Window:SetTitle(title: string)
	self.Title = title
	self.TitleBar.TitleLabel.Text = title
end

--[=[
	Destroys the window at once, without the close animation.
]=]
function Window:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	Transitions._cancel(self)
	local index = table.find(windows, self)
	if index then
		table.remove(windows, index)
	end
	if State.Current == self then
		State.Current = windows[#windows]
	end
	State:UnregisterHost(self)
	State:DestroyPopups(self)
	State:DestroyDropdowns(self)
	for _, widget in table.clone(self._widgets or {}) do
		pcall(widget.Destroy, widget)
	end
	table.clear(self._widgets or {})
	table.clear(self._elements or {})
	State:Orphan(self)
	self.Root.Visible = false
	if self.Minimizer then
		self.Minimizer:Destroy()
		self.Minimizer = nil
	end
	local cleanup = Maid.new()
	cleanup:Task(self.Root)
	cleanup:DeferredClean(0.01)
end

--[=[
	Creates and opens a modal dialog immediately. Each button callback runs on activation;
	returning false keeps the dialog open, while nil or true allows it to close.

	@param config DialogConfig -- Dialog title, body, and ordered button contracts.
	@return [Dialog](Dialog.md) -- The created dialog.
]=]
function Window:Dialog(config: any, ...: any): any
	config = Args.Config({"Title", "Content", "Buttons"}, {Buttons = true}, config, ...)
	local dialog = Dialog.New(self)
	dialog.Title.Text = config.Title or "Dialog"
	if config.Content then
		dialog:SetContent(config.Content)
	end

	for _, button in config.Buttons or {} do
		dialog:Button(button.Title, button.Callback, button.Style)
	end

	dialog:Open()
	return dialog
end

--[=[
	Shows a compact popup window without sections.

	@param config Popup.Config -- Popup settings.
	@return [Popup](Popup.md) -- The popup shown by this window.
]=]
function Window:Popup(config: any, ...: any): any
	config = Args.Config({"Title", "Size"}, nil, config, ...)
	local popup = Popup.New(config, config.Parent or self.Root, self)
	State:Adopt(self, popup)
	return popup
end

--[=[
	Creates the built-in settings tab, containing theme, persistence, and minimize controls.
	Calling this more than once returns the existing settings tab.

	@param config { Title: string?, Icon: string? }? -- Optional settings tab label and icon
	@return [Tab](Tab.md) -- The settings tab
]=]
function Window:Settings(config: any, ...: any): any
	if config ~= nil then
		config = Args.Config({"Title", "Icon"}, nil, config, ...)
	end
	return Settings.New(self, config)
end

--[=[
	Adds a tab to the sidebar.

	@param config Tab.Config -- Tab title and optional icon.
	@return [Tab](Tab.md) -- The new tab added to this window.
]=]
function Window:Tab(config: any, ...: any): any
	config = Args.Config({"Title", "Icon"}, nil, config, ...)
	local tab = Tab.New(config, self)
	tab.Frame.LayoutOrder = #self.Tabs + 1
	table.insert(self.Tabs, tab)
	if self._horizontalTabs then
		self:_updateTabSection(self.Root.Size.X.Offset)
	end
	return tab
end

--[=[
	Selects a tab by object or one-based position. A tab not owned by this window is
	ignored. The previously selected content transitions out as the new tab appears.

	@param target Tab | number -- The tab or its index
]=]
function Window:SelectTab(target: any)
	local tab = if type(target) == "number" then self.Tabs[target] else target
	if not tab or not table.find(self.Tabs, tab) then
		return
	end
	if self._selected == tab then
		return
	end

	self._selected = tab
	for _, other in self.Tabs do
		other:SetSelected(false)
	end
	tab:SetSelected(true)

	self.TabDisplay.Text = tab.Title

	self._tabTransitionId += 1
	local transitionId = self._tabTransitionId
	-- A crossfade: the old content fades out while it rises a little, the new one fades in from a little below. Only
	-- the container in transit moves into the animation frame; moving every tab would stall the first frame.
	local leaving = self._transit
	if not leaving then
		for _, other in self.Tabs do
			if other.Container.Visible then
				leaving = other.Container
			end
		end
		if leaving then
			leaving.Parent = self.ContainerAnim
			self._transit = leaving
		end
	end
	--@inline
	local function arrive()
		local container = tab.Container
		container.Visible = true
		container.Parent = self.ContainerAnim
		self._transit = container
		Fade.Hide(self.ContainerAnim)
		self.ContainerAnim.Position = UDim2.fromOffset(0, TAB_SHIFT)
		Motion.Tween(self.ContainerAnim, {Position = UDim2.fromOffset(0, 0)}, TAB_IN_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		Fade.To(self.ContainerAnim, true, TAB_IN_DURATION, function()
			if self._tabTransitionId == transitionId then
				container.Parent = self.ContainerHolder
				self._transit = nil
			end
		end)
	end

	if not leaving then
		arrive()
		return
	end
	Motion.Tween(self.ContainerAnim, {Position = UDim2.fromOffset(0, -TAB_SHIFT)}, TAB_OUT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Fade.To(self.ContainerAnim, false, TAB_OUT_DURATION, function()
		if self._tabTransitionId ~= transitionId then
			return
		end
		-- hidden first, so the restored transparency of the leaving content never shows
		leaving.Visible = false
		Fade.Settle(self.ContainerAnim)
		leaving.Parent = self.ContainerHolder
		arrive()
	end)
end

return Window
