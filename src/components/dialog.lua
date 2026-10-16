--[=[
	A modal card drawn over the window with a tinted overlay, an upper content section,
	and a bottom tray with evenly spaced rounded-square buttons.

	@class Dialog
	@location internals/components
]=]
local Action = require("./action")
local Motion = require("../services/motion")
local Squircle = require("./frame")
local State = require("../public")
local Style = require("../assets/themes")
local Creator = require("../services/creator")
local Theme = require("../services/theme")
local Fade = require("../services/fade")
local Measure = require("../services/measure")

local Dialog = {}
Dialog.__index = Dialog
local BUTTON_GAP = 8
local PAD = 24
local TOP_PAD = 16
local MIN_WIDTH = 280
local MIN_HEIGHT = 100
local TRANSITION_DURATION = 0.2
-- The card slides up by this many pixels while it fades in, and back down while it fades out. Do not scale the
-- card: under a `UIScale` Roblox draws text at a whole font size rounded down, and the text then grows when the
-- scale reaches 1 at the end of the animation.
local SHIFT = Style.Space.XXS
local OVERLAY_ZINDEX = 10

-- the same curve as the other transitions: fast at the start, soft at the end
local OPEN = TweenInfo.new(TRANSITION_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local CLOSE = OPEN

local function tween(instance: Instance, properties: { [string]: any }, info: TweenInfo, completed: ((Enum.PlaybackState) -> ())?)
	return Motion.Tween(instance, properties, info, nil, nil, completed)
end

-- rounds a size up to an even number of pixels, so a centered card starts on a whole pixel
local function even(size: number): number
	return math.ceil(size / 2) * 2
end

local function trayHeight(): number
	return Theme:Size("Button") + 2 * Style.Space.XS
end

local function track(dialog: any, open: boolean)
	local dialogs = dialog._window and dialog._window._dialogs
	if dialogs then
		dialogs[dialog] = if open then true else nil
	end
end

--[=[
	Creates a new, closed dialog over a window. Presses on the overlay's title strip still move the window.

	@param window Window -- The window the overlay covers
	@return [Dialog](Dialog.md) -- The newly created and displayed dialog.
]=]
function Dialog.New(window: any): any
	local win = assert(window, "Dialog.New requires an owning window")
	local root = win.Root
	local self = setmetatable({
		_window = win,
		_buttons = 0,
		_actions = {},
		_fixedSize = nil
	}, Dialog)
	-- The overlay also covers window chrome so underlying controls cannot receive input.
	self.TintFrame = Squircle.New(Style.Squircle.Window, {
		Button = true,
		ImageColor3 = Color3.fromRGB(0, 0, 0),
		ImageTransparency = 1,
		ZIndex = OVERLAY_ZINDEX,
		Parent = root
	})

	self._buttonLayout = Creator:New("UIListLayout", {
		Padding = UDim.new(0, BUTTON_GAP),
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder
	})

	self.ButtonHolder = Creator:New("Frame", {
		Size = UDim2.new(1, -2 * PAD, 1, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1
	}, {self._buttonLayout})

	self.ButtonHolderFrame = Squircle.New(Style.Squircle.Window, {
		Name = "Surface",
		Shape = "Bottom",

		ZIndex = 1,
		Themed = {ImageColor3 = "Surface"},
		ImageTransparency = win.Transparency or 0
	}, {
		Creator:New("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			BackgroundTransparency = 0,
			Themed = {BackgroundColor3 = "SurfaceBorder"}
		}),
		self.ButtonHolder
	})

	self.Title = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		Text = "Dialog",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -2 * PAD, 0, 24),
		Position = UDim2.fromOffset(PAD, TOP_PAD),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})

	self.Content = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font),
		Text = "",
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Size = UDim2.new(1, -2 * PAD, 0, 0),
		Position = UDim2.fromOffset(PAD, TOP_PAD + 24 + 4),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})

	self._border = Squircle.New(Style.Squircle.Window, {
		Shape = "Outline",
		Visible = false,
		ZIndex = 2,
		Themed = {ImageColor3 = "SurfaceBorder"}
	})

	self.Root = Creator:New("Frame", {
		Size = UDim2.fromOffset(MIN_WIDTH, MIN_HEIGHT),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = self.TintFrame
	}, {
		Squircle.New(Style.Squircle.Window, {
			Name = "Surface",
			Themed = {ImageColor3 = "Surface"},
			ImageTransparency = win.Transparency or 0
		}),
		self._border,
		self.Title,
		self.Content,
		self.ButtonHolderFrame
	})

	-- the card stays hidden until `Open` fades it in
	Fade.Hide(self.Root)
	-- the card stays centered on whole pixels while the window changes size
	State.Connect(root:GetPropertyChangedSignal("Size"), function()
		self:_place()
	end, self.TintFrame)

	Theme:Track(function()
		self:_updateLayout()
	end, self.TintFrame)
	-- also covers dialogs destroyed along with their window without being closed
	self.TintFrame.Destroying:Connect(function()
		track(self, false)
	end)

	-- a new text or font refits the card; the text bounds also change on each frame of a scale animation
	for _, label in {self.Title, self.Content} do
		for _, property in {"Text", "FontFace", "TextSize"} do
			label:GetPropertyChangedSignal(property):Connect(function()
				self:_updateLayout()
			end)
		end
	end

	return self
end

--[=[
	Sets the message content of the dialog and refreshes the layout.

	@param text string
]=]
function Dialog:SetContent(text: string)
	self.Content.Text = text or ""
	self:_updateLayout()
end

--[=[
	Recalculates dialog dimensions, content wrapping, and button layout.
]=]
function Dialog:_updateLayout()
	local tray = trayHeight()
	self.ButtonHolderFrame.Size = UDim2.new(1, 0, 0, tray)
	self.ButtonHolderFrame.Position = UDim2.new(0, 0, 1, -tray)
	local window = self._window
	local winWidth = if window and window.Size then window.Size.X.Offset else 580
	local winHeight = if window and window.Size then window.Size.Y.Offset else 460

	local count = #self._actions
	-- the widest button text sets the smallest button width; Action already clamps it to its own range
	local maxButtonWidth = 0
	for _, action in self._actions do
		maxButtonWidth = math.max(maxButtonWidth, action._width)
	end

	-- the buttons share the tray width equally and never get narrower than the widest text
	local function sizeButtons(width: number)
		if count == 0 then
			return
		end
		local each = math.max(maxButtonWidth, math.floor((width - 2 * PAD - (count - 1) * BUTTON_GAP) / count))
		for _, action in self._actions do
			action:SetSize(UDim2.fromOffset(each, Theme:Size("Button")))
		end
	end

	if self._fixedSize then
		-- a fixed card keeps its exact size
		self.Root.Size = UDim2.fromOffset(even(self._fixedSize.X.Offset), even(self._fixedSize.Y.Offset))
		sizeButtons(self.Root.Size.X.Offset)
		self:_place()
		return
	end

	local buttonsNeededWidth = if count > 0
		then count * maxButtonWidth + (count - 1) * BUTTON_GAP + 2 * PAD
	else MIN_WIDTH

	local limitX = math.max(buttonsNeededWidth, math.max(MIN_WIDTH, winWidth - 40))
	local limitY = math.max(MIN_HEIGHT, winHeight - 40)

	-- text sizes at scale 1: the card opens from a smaller scale, and a render measurement changes when it ends
	local textMaxX = math.max(Measure.Text(self.Title).X, Measure.Text(self.Content).X)
	local contentNeededWidth = textMaxX + 2 * PAD + 24
	local targetWidth = math.clamp(math.max(MIN_WIDTH, contentNeededWidth, buttonsNeededWidth), buttonsNeededWidth, limitX)
	sizeButtons(targetWidth)

	-- Content vertical sizing
	local hasContent = self.Content.Text ~= ""
	local contentHeight = 0
	if hasContent then
		-- the height at the final wrap width; the current width of the label can be from the last layout
		contentHeight = math.max(Style.Line.Body, Measure.Text(self.Content, even(targetWidth) - 2 * PAD).Y)
	end

	local textSectionBottom = TOP_PAD + 24 + (if hasContent then 4 + contentHeight else 0) + 12
	local neededHeight = textSectionBottom + trayHeight()
	local targetHeight = math.clamp(neededHeight, MIN_HEIGHT, limitY)

	self.Root.Size = UDim2.fromOffset(even(targetWidth), even(targetHeight))
	self:_place()
	self.Title.Size = UDim2.new(1, -2 * PAD, 0, 24)
	self.Title.Position = UDim2.fromOffset(PAD, TOP_PAD)

	self.Content.Position = UDim2.fromOffset(PAD, TOP_PAD + 24 + 4)
	self.Content.Size = UDim2.new(1, -2 * PAD, 0, contentHeight)
end

-- the center of the card on a whole pixel of the window, moved down by `shift`
function Dialog:_position(shift: number): UDim2
	local area = self._window.Root.Size
	return UDim2.fromOffset(math.floor(area.X.Offset / 2), math.floor(area.Y.Offset / 2) + shift)
end

-- Centers the card on a whole pixel of the window, so its edges and text render sharp. A layout that keeps the
-- same center does not move the card, so it does not stop a slide.
function Dialog:_place()
	local center = self:_position(0)
	if center == self._center then
		return
	end
	self._center = center
	self.Root.Position = center
end

--[=[
	Sets a fixed size for the dialog.

	@param size UDim2 -- The dialog dimensions
]=]
function Dialog:SetSize(size: UDim2)
	self._fixedSize = size
	self:_updateLayout()
end

--[=[
	Animates the dialog in and marks it as open.
]=]
function Dialog:Open()
	self:_updateLayout()
	track(self, true)
	self._closing = false
	State:ResetHighlights()
	tween(self.TintFrame, {ImageTransparency = 0.5}, OPEN)
	Fade.To(self.Root, true, OPEN)
	self.Root.Position = self:_position(SHIFT)
	tween(self.Root, {Position = self:_position(0)}, OPEN)
end

--[=[
	Animates the dialog out and destroys it.

	@yields
]=]
function Dialog:Close()
	if self._closing then
		return
	end
	self._closing = true
	track(self, false)
	self._border.Visible = false
	-- the same motion as opening, played back: the card fades and slides down a little
	tween(self.TintFrame, {ImageTransparency = 1}, CLOSE)
	Fade.To(self.Root, false, CLOSE)
	tween(self.Root, {Position = self:_position(SHIFT)}, CLOSE, function(playbackState)
		if playbackState == Enum.PlaybackState.Completed and self.TintFrame.Parent then
			self.TintFrame:Destroy()
		end
	end)
end

--[=[
	Removes the dialog at once, without the close animation.
]=]
function Dialog:Destroy()
	self.TintFrame:Destroy()
end

--[=[
	Adds a button that runs its callback and then closes the dialog, unless the callback returns false.
	The first button is the suggested action unless a `Style` says otherwise.

	@param title string? -- The button text
	@param callback (() -> boolean?)? -- Called when the button is pressed, return false to keep the dialog open
	@param style ("Suggested" | "Standard" | "Destructive")? -- The button's role, defaults to the suggested action for the first button
	@return [Action](Action.md) -- The action button created for the dialog.
]=]
function Dialog:Button(title: string?, callback: (() -> boolean?)?, style: string?): any
	self._buttons += 1

	local action = Action.New(self.ButtonHolder, true, title or "Button")
	action.Frame.LayoutOrder = self._buttons
	table.insert(self._actions, action)
	for _, property in {"Text", "FontFace", "TextSize"} do
		action.Title:GetPropertyChangedSignal(property):Connect(function()
			self:_updateLayout()
		end)
	end

	action:SetRole(style or if self._buttons == 1 then "Suggested" else "Standard")

	action.Frame.MouseButton1Click:Connect(function()
		-- a click during the close animation must not run the callback again
		if self._closing then
			return
		end
		if State:SafeCallback(callback) ~= false then
			self:Close()
		end
	end)

	self:_updateLayout()
	return action
end

return Dialog
