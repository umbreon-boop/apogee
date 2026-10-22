--[=[
	A compact, standalone floating window without a tab sidebar or sections.
	Widgets are drawn directly into its scrollable container.
	@class Popup
	@location internals/components
]=]
local Workspace = game:GetService("Workspace")

local Backdrop = require("./backdrop")
local Class = require("../services/class")
local Container = require("./container")
local Drag = require("../services/drag")
local Images = require("../assets/images")
local Icons = require("../assets/icons")
local Motion = require("../services/motion")
local State = require("../public")
local Style = require("../assets/themes")
local Creator = require("../services/creator")
local Fade = require("../services/fade")
local Theme = require("../services/theme")
local Args = require("../services/args")
local Measure = require("../services/measure")

--[=[
	@interface PopupConfig
	.Title string
	.SubTitle string?
	.Size UDim2?
	.Position UDim2?
	.Visible boolean?
	.Parent Instance?
	.CloseCallback (() -> ())?
	@within Popup
]=]
export type Config = {
	Title: string, SubTitle: string?, Size: UDim2?, Position: UDim2?,
	Visible: boolean?, Parent: Instance?, CloseCallback: (() -> ())?
}

local Popup = Class.Extend({Type = "Popup"}, Container)
local camera = Workspace.CurrentCamera
local BUTTON_SIZE = 28
local TRANSITION_DURATION = 0.2
local TRANSITION_EASING = Enum.EasingStyle.Quint
local TRANSITION_DIRECTION = Enum.EasingDirection.Out
-- A hidden popup sits this many pixels lower and slides up while it fades in. Do not scale the popup: under a
-- `UIScale` Roblox draws text at a whole font size rounded down, and the text then grows when the scale reaches 1.
local SHIFT = Style.Space.XXS


--[=[
	Creates a new Popup window.

	@param config Config -- Popup title, size, position, visibility, and owner details.
	@param parent Instance? -- Container to parent the popup to
	@param owner any? -- The owning window or container
	@return [Popup](Popup.md) -- The newly created popup.
]=]
function Popup.New(config: Config, parent: Instance?, owner: any?): any
	assert(config.Title, "Popup - Missing Title")
	local visible = config.Visible ~= false

	local actualParent = assert(parent or config.Parent, "Popup.New requires a parent")
	local size = config.Size or UDim2.fromOffset(340, 380)

	-- centered in the parent: the screen for top-level popups, the window for window popups
	local area = if actualParent:IsA("ScreenGui") then camera.ViewportSize else Measure.Offset(actualParent, actualParent.AbsoluteSize)
	local centeredX = if size.X.Scale > 0
		then -math.floor(size.X.Offset / 2)
	else math.floor((area.X - size.X.Offset) / 2)
	local centeredY = if size.Y.Scale > 0
		then -math.floor(size.Y.Offset / 2)
	else math.floor((area.Y - size.Y.Offset) / 2)
	local position = if config.Position
		then config.Position
	elseif size.X.Scale == 0 and size.Y.Scale == 0 then UDim2.fromOffset(centeredX, centeredY)
	else UDim2.new(
		(1 - size.X.Scale) / 2,
		centeredX,
		(1 - size.Y.Scale) / 2,
		centeredY
	)

	local self = Class.New(Popup, {
		Size = size,
		Position = position,
		_elements = {},
		_openFrames = {},
		_dialogs = {},
		_children = {},
		_widgets = {},
		_dropdowns = {},
		_gui = actualParent,
		Transparency = if owner then owner.Transparency or 0 else 0,
		_closeCallback = config.CloseCallback
	})
	self._window = self
	State:RegisterHost(self)

	local titleLabel = Creator:New("TextLabel", {
		RichText = true,
		Text = config.Title,
		FontFace = Font.new(Style.Font, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		TextSize = Style.Type.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -BUTTON_SIZE - 24, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})

	local subtitleLabel = nil
	if config.SubTitle and config.SubTitle ~= "" then
		titleLabel.Size = UDim2.new(1, -BUTTON_SIZE - 24, 0, 20)
		titleLabel.Position = UDim2.fromOffset(14, 2)
		subtitleLabel = Creator:New("TextLabel", {
			RichText = true,
			Text = config.SubTitle,
			FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
			TextSize = Style.Type.Small,
			TextTransparency = 0.4,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			Size = UDim2.new(1, -BUTTON_SIZE - 24, 0, 14),
			Position = UDim2.fromOffset(14, 20),
			BackgroundTransparency = 1,
			Themed = {TextColor3 = "SubText"}
		})
	end

	-- the same themeable button as the window title bar
	local closeButton = Creator:New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		BackgroundTransparency = 1
	})
	Theme:Style("TitleBarButton", closeButton, self, Icons.GetIcon("x"), nil, "×")

	local titleBar = Creator:New("Frame", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1
	}, {titleLabel, subtitleLabel, closeButton})

	local layout = Creator:New("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder
	})
	local container = Creator:New("ScrollingFrame", {
		Size = UDim2.new(1, -20, 1, -50),
		Position = UDim2.fromOffset(10, 42),
		BackgroundTransparency = 1,
		BottomImage = Images.ScrollBottom,
		MidImage = Images.ScrollMiddle,
		TopImage = Images.ScrollTop,
		ScrollBarImageTransparency = 0.95,
		ScrollBarThickness = 3,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
		ScrollingDirection = Enum.ScrollingDirection.Y
	}, {
		layout,
		Creator:New("UIPadding", {
			PaddingRight = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 16)
		})
	})

	local backdrop = Backdrop.New(Style.Squircle.Window, false)
	local barrier = Creator:New("TextButton", {
		Name = "PopupBarrier",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Active = true,
		Visible = visible,
		ZIndex = 20,
		Parent = actualParent
	})

	local root = Creator:New("Frame", {
		Size = size,
		Position = position,
		BackgroundTransparency = 1,
		ZIndex = 21,
		Visible = visible,
		Parent = actualParent
	}, {
		backdrop,
		titleBar,
		container
	})

	rawset(self, "Root", root)
	rawset(self, "Container", container)
	rawset(self, "ScrollFrame", container)
	rawset(self, "TitleLabel", titleLabel)
	rawset(self, "SubtitleLabel", subtitleLabel)
	rawset(self, "CloseButton", closeButton)
	rawset(self, "Backdrop", backdrop)
	self._barrier = barrier
	self._owner = owner
	self._layout = layout
	self._window = self
	self:SetTransparency(self.Transparency)
	self._transitionId = 0
	-- the content stays hidden until the first fade in
	Fade.Hide(root)
	local function updateCanvas()
		container.CanvasSize = UDim2.fromOffset(0, Measure.Rows(container))
	end
	self._updateCanvas = updateCanvas
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)

	closeButton.MouseButton1Click:Connect(function()
		self:Close()
	end)
	-- the title bar moves the popup; Drag follows one pointer and holds the shared drag lock
	local origin: Vector2?, start: UDim2? = nil, nil
	Drag.Bind(titleBar, function(pointer)
		if not origin then
			-- the drag owns the position, so a running slide stops
			if self._slide then
				self._slide:Cancel()
				self._slide = nil
			end
			origin, start = pointer, self.Root.Position
		end
		local delta = pointer - origin
		self.Position = UDim2.fromOffset(start.X.Offset + delta.X, start.Y.Offset + delta.Y)
		self.Root.Position = self.Position
	end, nil, function()
		origin = nil
	end)

	Class.Define(self, {
		Title = function(_, value: string)
			titleLabel.Text = value
		end,
		Visible = function(_, value: boolean)
			self:_show(value)
		end
	})
	self._storage.Visible = visible
	if visible then
		self:_show(true)
	end

	return self
end

-- animates the popup in or out; a hidden popup does not block input
function Popup:_show(visible: boolean, done: (() -> ())?)
	-- a closing popup finishes its close animation, so `Open` cannot stop the destruction halfway
	if self._destroyed or (visible and self._closing) then
		return
	end
	if not visible then
		State:CloseDropdowns(self, true)
	end
	self._transitionId += 1
	local transitionId = self._transitionId
	if visible then
		self._barrier.Visible = true
		self.Root.Visible = true
		State:ResetHighlights()
	end
	-- the same motion as a dialog: the popup fades and slides a little
	local rest = self.Position
	local hidden = rest + UDim2.fromOffset(0, SHIFT)
	-- a popup that is not shown starts lower; a running or finished slide continues from where it is
	if visible and not self._shown then
		self.Root.Position = hidden
	end
	self._shown = visible
	if self._slide then
		self._slide:Cancel()
	end
	local slide = Motion.Tween(self.Root, {Position = if visible then rest else hidden}, TRANSITION_DURATION, TRANSITION_EASING, TRANSITION_DIRECTION)
	self._slide = slide
	slide.Completed:Connect(function()
		if self._slide == slide then
			self._slide = nil
		end
	end)
	Fade.To(self.Root, visible, TRANSITION_DURATION, function()
		if self._transitionId ~= transitionId or self._destroyed then
			return
		end
		if not visible then
			self.Root.Visible = false
			self._barrier.Visible = false
		end
		if done then
			done()
		end
	end)
end

--[=[
	Shows a hidden popup with its open animation. Set `Visible` to show or hide it without closing it.
]=]
function Popup:Open()
	self.Visible = true
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
	Sets the transparency of the popup surfaces.
	@param value number -- A number from 0 to 1
]=]
function Popup:SetTransparency(value: number)
	value = math.clamp(value, 0, 1)
	self.Transparency = value
	local background = self.Backdrop and self.Backdrop:FindFirstChild("Background")
	if background then
		background.ImageTransparency = value
	end
	if self.Root then
		applyTransparency(self.Root, value)
	end
	for _, child in self._children do
		if child.SetTransparency then
			child:SetTransparency(value)
		end
	end
end

--[=[
	Shows a nested popup window.

	@param config any -- The popup settings
	@param ... any -- Positional form: the title, then the size and an options table
	@return [Popup](Popup.md) -- This popup after its visibility has been updated.
]=]
function Popup:Popup(config: any, ...: any): any
	config = Args.Config({"Title", "Size"}, nil, config, ...)
	local popup = Popup.New(config, config.Parent or self.Root, self)
	State:Adopt(self, popup)
	return popup
end

--[=[
	Plays the close animation, calls `CloseCallback` and destroys the popup.
]=]
function Popup:Close()
	if self._closing or self._destroyed then
		return
	end
	self._closing = true
	-- a closing popup stops blocking input at once
	self._storage.Visible = false
	self:_show(false, function()
		State:SafeCallback(self._closeCallback)
		self:Destroy()
	end)
end

--[=[
	Sets the popup's title.
	@param title string
]=]
function Popup:SetTitle(title: string)
	self.Title = title
end

--[=[
	Shows or hides the popup without closing it.
	@param visible boolean
]=]
function Popup:SetVisible(visible: boolean)
	self.Visible = visible
end

--[=[
	Destroys the popup frame.
]=]
function Popup:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	State:UnregisterHost(self)
	State:DestroyPopups(self)
	State:DestroyDropdowns(self)
	for _, widget in table.clone(self._widgets or {}) do
		pcall(widget.Destroy, widget)
	end
	table.clear(self._widgets or {})
	table.clear(self._elements or {})
	State:Orphan(self)
	self._barrier:Destroy()
	self.Root:Destroy()
end

return Popup
