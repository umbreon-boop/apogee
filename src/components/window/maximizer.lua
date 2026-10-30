--[=[
	Floating button for restoring a minimized window. It can be dragged and accepts custom content.

	@class Maximizer
	@location internals/components
]=]
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local Class = require("../../services/class")
local Drag = require("../../services/drag")
local Fade = require("../../services/fade")
local Frame = require("../frame")
local Icon = require("../icon")
local Motion = require("../../services/motion")
local State = require("../../public")
local Creator = require("../../services/creator")
local Style = require("../../assets/themes")
local Theme = require("../../services/theme")
local Pointer = require("../../services/pointer")

local isPress = Pointer.IsPress
--@inline
local function getInsets(parent: Instance?): (Vector2, Vector2)
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	if parent and parent:IsA("ScreenGui") and parent.IgnoreGuiInset then
		topLeftInset = Vector2.zero
		bottomRightInset = Vector2.zero
	end
	return topLeftInset, bottomRightInset
end

--[=[
	@prop Icon string? -- An icon name, hidden while a `Body` is set
	@prop Text string -- Text shown when no icon is visible, hidden while a `Body` is set
	@prop Body GuiObject? -- Custom content drawn inside the button instead of the icon and text
	@prop Enabled boolean -- Whether the button shows up while the window is minimized
	@prop Position UDim2 -- The position of the button's center
]=]
local Maximizer = Class.Extend({Type = "Maximizer"})

--[=[
	@interface MaximizerConfig
	.Icon (string | false)? -- Defaults to `layout-grid`; false leaves the button without an icon
	.Text string? -- Shown when no icon is visible
	.Body GuiObject? -- Replaces the icon and text when set
	.Enabled boolean? -- Defaults to true on touch devices
	.Position UDim2? -- Defaults to the middle of the left edge
	.Size number? -- The button's width and height, defaults to the theme's `Maximizer` size
	@within Maximizer
]=]
export type Config = { Icon: (string | false)?, Text: string?, Body: GuiObject?, Enabled: boolean?, Position: UDim2?, Size: number? }

local DEFAULT_ICON = "layout-grid"
local DRAG_THRESHOLD = 6
local PRESSED_SCALE = 0.92

--[=[
	Creates the button. Windows create one automatically, configured through `Window.Config.Maximizer`.

	@param config Config -- Icon, text or custom content, size, and placement settings.
	@param window Window -- The window the button toggles
	@return [Maximizer](Maximizer.md) -- The floating maximizer button attached to the window.
]=]
function Maximizer.New(config: Config, window: any): any
	local size = config.Size or Theme:Size("Maximizer")
	local self = Class.New(Maximizer, {_window = window, _size = size})

	local iconName = config.Icon
	if iconName == nil then
		iconName = DEFAULT_ICON
	elseif iconName == false then
		iconName = ""
	end
	local icon = Icon.New(iconName, {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Themed = {ImageColor3 = "Text"}
	})
	local text = Creator:New("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = config.Text or "",
		TextSize = math.round(size * 0.45),
		FontFace = Font.new(Style.Font, Enum.FontWeight.Bold),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		Themed = {TextColor3 = "Text"},
		Visible = false
	})
	local body = Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true})
	local scale = Creator:New("UIScale", {Scale = 1})

	local radius = Theme:Size("MaximizerRadius")
	local outline = Frame.New(radius, {Shape = "Outline", Themed = {ImageColor3 = "Border"}})
	local button = Frame.New(radius, {
		Button = true,
		Active = true,
		AutoButtonColor = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 10,
		Parent = window._gui,
		Themed = {ImageColor3 = "Overlay"}
	}, {
		outline,
		icon,
		text,
		body,
		scale
	})

	rawset(self, "Frame", button)
	Theme:Track(function()
		local themed = Theme:Size("MaximizerRadius")
		Theme:Style("Frame", button, themed, "Full")
		Theme:Style("Frame", outline, themed, "Outline")
		if not config.Size then
			self._size = Theme:Size("Maximizer")
			button.Size = UDim2.fromOffset(self._size, self._size)
			text.TextSize = math.round(self._size * 0.45)
		end
	end, button)
	button.ImageTransparency = window.Transparency or 0
	icon.ImageTransparency = window.Transparency or 0
	self._icon = icon
	self._text = text
	self._body = body
	self._iconShown = true
	self._hasBody = false
	self._scale = Motion.Single(1, function(value)
		scale.Scale = value
	end)
	Icon.Watch(icon, function(shown)
		self._iconShown = shown
		self:_syncVisuals()
	end)

	Class.Define(self, {
		Icon = function(_, value: string?)
			Icon.Set(icon, value)
		end,
		Text = function(_, value: string?)
			self._text.Text = value or ""
			self:_syncVisuals()
		end,
		Body = Maximizer._setBody,
		Enabled = Maximizer._sync,
		Position = function(_, value: UDim2)
			button.Position = value
		end
	})
	self:From({
		Icon = iconName,
		Text = config.Text or "",
		Enabled = config.Enabled,
		-- buttons of several windows stack downwards instead of covering each other
		Position = config.Position or UDim2.new(0, size / 2 + Style.Space.S, 0.5, #window._windows * (size + Style.Space.XXS))
	})
	if config.Enabled == nil then
		self.Enabled = UserInputService.TouchEnabled == true
	end
	if config.Body then
		self.Body = config.Body
	end

	self:_connect()
	return self
end

function Maximizer:_sync()
	self.Frame.Visible = self.Enabled == true and self._window.Minimized
end

function Maximizer:_syncVisuals()
	local body = self._hasBody == true
	local icon = body ~= true and self._iconShown == true
	self._icon.Visible = icon
	self._text.Visible = not body and not icon and self._text.Text ~= ""
end

-- Fades the button in or out together with the window. The button fill is the button itself, and a fade only
-- changes the children, so the fill gets its own tween.
function Maximizer:_show(visible: boolean, duration: number)
	local button = self.Frame
	if not self.Enabled then
		button.Visible = false
		return
	end
	if visible and not button.Visible then
		button.ImageTransparency = 1
		Fade.Hide(button)
	end
	button.Visible = true
	Fade.To(button, visible, duration, function()
		button.Visible = visible
	end)
	local transparency = 1
	if visible then
		transparency = self._window.Transparency or 0
	end
	Motion.Tween(button, {ImageTransparency = transparency}, duration)
end

function Maximizer:SetTransparency(value: number)
	self.Frame.ImageTransparency = value
	self._icon.ImageTransparency = value
	self._text.TextTransparency = value
end

function Maximizer:_setBody(value: GuiObject?)
	for _, child in self._body:GetChildren() do
		child.Parent = nil
	end
	if value then
		value.Parent = self._body
	end
	self._hasBody = value ~= nil
	self:_syncVisuals()
end

function Maximizer:_connect()
	local button = self.Frame
	local origin: Vector2? = nil
	local center = Vector2.zero
	local moved = false
	local activeInput: InputObject? = nil

	button.InputBegan:Connect(function(input)
		if not isPress(input) or activeInput or Drag._active then
			return
		end
		if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
			return
		end

		local topLeftInset = getInsets(button.Parent)
		activeInput = input
		origin = Vector2.new(input.Position.X, input.Position.Y)
		center = button.AbsolutePosition + button.AbsoluteSize / 2 + topLeftInset
		moved = false
		Drag._active = self
		self._scale:Set(Motion.Spring(PRESSED_SCALE, 8))
	end)

	State.Connect(UserInputService.InputChanged, function(input)
		if not activeInput or not origin then
			return
		end
		local follows = input.UserInputType == Enum.UserInputType.MouseMovement
		if activeInput.UserInputType == Enum.UserInputType.Touch then
			follows = input == activeInput
		end
		if not follows then
			return
		end

		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local delta = pos - origin
		if delta.Magnitude > DRAG_THRESHOLD then
			moved = true
		end
		if moved then
			self:_moveTo(center + delta)
		end
	end, button)

	State.Connect(UserInputService.InputEnded, function(input)
		if not activeInput then
			return
		end
		local released = input.UserInputType == Enum.UserInputType.MouseButton1
		if activeInput.UserInputType == Enum.UserInputType.Touch then
			released = input == activeInput
		end
		if released then
			activeInput = nil
			if Drag._active == self then
				Drag._active = nil
			end
			self._scale:Set(Motion.Spring(1, 8))
			if not moved then
				self._window:Minimize()
			end
			origin = nil
		end
	end, button)

	-- a destroyed button never receives InputEnded, so release the shared drag lock here
	button.Destroying:Connect(function()
		if Drag._active == self then
			Drag._active = nil
		end
	end)
end

function Maximizer:_moveTo(target: Vector2)
	local viewport = Workspace.CurrentCamera.ViewportSize
	local half = self._size / 2
	local topLeftInset, bottomRightInset = getInsets(self.Frame.Parent)
	local minX = half - topLeftInset.X
	local minY = half - topLeftInset.Y
	local maxX = math.max(viewport.X - bottomRightInset.X - topLeftInset.X - half, minX)
	local maxY = math.max(viewport.Y - bottomRightInset.Y - topLeftInset.Y - half, minY)
	local x = math.clamp(target.X - topLeftInset.X, minX, maxX)
	local y = math.clamp(target.Y - topLeftInset.Y, minY, maxY)
	self.Position = UDim2.fromOffset(x, y)
end

--[=[
	Destroys the button.
]=]
function Maximizer:Destroy()
	if Drag._active == self then
		Drag._active = nil
	end
	self.Frame:Destroy()
end

return Maximizer
