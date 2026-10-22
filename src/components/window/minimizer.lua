--[=[
	Floating button for restoring a minimized window. It can be dragged and accepts custom content.

	@class Minimizer
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
local Icons = require("../../assets/icons")
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
	topLeftInset = if parent and parent:IsA("ScreenGui") and parent.IgnoreGuiInset then Vector2.zero else topLeftInset
	bottomRightInset = if parent and parent:IsA("ScreenGui") and parent.IgnoreGuiInset then Vector2.zero else bottomRightInset
	return topLeftInset, bottomRightInset
end

--[=[
	@prop Icon string -- An icon name or an asset id, hidden while a `Body` is set
	@prop Body GuiObject? -- Custom content drawn inside the button instead of the icon
	@prop Enabled boolean -- Whether the button shows up while the window is minimized
	@prop Position UDim2 -- The position of the button's center
]=]
local Minimizer = Class.Extend({Type = "Minimizer"})

--[=[
	@interface MinimizerConfig
	.Icon string? -- Defaults to `layout-grid`
	.Body GuiObject? -- Replaces the icon when set
	.Enabled boolean? -- Defaults to true on touch devices
	.Position UDim2? -- Defaults to the middle of the left edge
	.Size number? -- The button's width and height, defaults to the theme's `Minimizer` size
	@within Minimizer
]=]
export type Config = { Icon: string?, Body: GuiObject?, Enabled: boolean?, Position: UDim2?, Size: number? }

local DEFAULT_ICON = "layout-grid"
local DRAG_THRESHOLD = 6
local PRESSED_SCALE = 0.92

--[=[
	Creates the button. Windows create one automatically, configured through `Window.Config.Minimizer`.

	@param config Config -- Icon or custom content, size, and placement settings.
	@param window Window -- The window the button toggles
	@return [Minimizer](Minimizer.md) -- The floating minimizer button attached to the window.
]=]
function Minimizer.New(config: Config, window: any): any
	local size = config.Size or Theme:Size("Minimizer")
	local self = Class.New(Minimizer, {_window = window, _size = size})

	local icon = Icon.New(Icons.GetIcon(config.Icon or DEFAULT_ICON), {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.5, 0.5),
			BackgroundTransparency = 1,
			Themed = {ImageColor3 = "Text"}
		})
	Icon.Watch(icon, function() end)
	local body = Creator:New("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ClipsDescendants = true})
	local scale = Creator:New("UIScale", {Scale = 1})

	local radius = Theme:Size("MinimizerRadius")
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
		body,
		scale
	})

	rawset(self, "Frame", button)
	Theme:Track(function()
		local themed = Theme:Size("MinimizerRadius")
		Theme:Style("Frame", button, themed, "Full")
		Theme:Style("Frame", outline, themed, "Outline")
		if not config.Size then
			self._size = Theme:Size("Minimizer")
			button.Size = UDim2.fromOffset(self._size, self._size)
		end
	end, button)
	button.ImageTransparency = window.Transparency or 0
	icon.ImageTransparency = window.Transparency or 0
	self._icon = icon
	self._body = body
	self._scale = Motion.Single(1, function(value)
		scale.Scale = value
	end)

	Class.Define(self, {
		Icon = function(_, value: string)
			Theme:Style("Icon", icon, Icons.GetIcon(value))
		end,
		Body = Minimizer._setBody,
		Enabled = Minimizer._sync,
		Position = function(_, value: UDim2)
			button.Position = value
		end
	})
	self:From({
		Icon = config.Icon or DEFAULT_ICON,
		Enabled = if config.Enabled ~= nil then config.Enabled else UserInputService.TouchEnabled == true,
		-- buttons of several windows stack downwards instead of covering each other
		Position = config.Position or UDim2.new(0, size / 2 + Style.Space.S, 0.5, #window._windows * (size + Style.Space.XXS))
	})
	if config.Body then
		self.Body = config.Body
	end

	self:_connect()
	return self
end

function Minimizer:_sync()
	self.Frame.Visible = self.Enabled == true and self._window.Minimized
end

-- Fades the button in or out together with the window. The button fill is the button itself, and a fade only
-- changes the children, so the fill gets its own tween.
function Minimizer:_show(visible: boolean, duration: number)
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
	Motion.Tween(button, {ImageTransparency = if visible then self._window.Transparency or 0 else 1}, duration)
end

function Minimizer:SetTransparency(value: number)
	self.Frame.ImageTransparency = value
	self._icon.ImageTransparency = value
end

function Minimizer:_setBody(value: GuiObject?)
	for _, child in self._body:GetChildren() do
		child.Parent = nil
	end
	if value then
		value.Parent = self._body
	end
	self._icon.Visible = value == nil
end

function Minimizer:_connect()
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
		local follows = if activeInput.UserInputType == Enum.UserInputType.Touch
			then input == activeInput
		else input.UserInputType == Enum.UserInputType.MouseMovement
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
		local released = if activeInput.UserInputType == Enum.UserInputType.Touch
			then input == activeInput
		else input.UserInputType == Enum.UserInputType.MouseButton1
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

function Minimizer:_moveTo(target: Vector2)
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
function Minimizer:Destroy()
	if Drag._active == self then
		Drag._active = nil
	end
	self.Frame:Destroy()
end

return Minimizer
