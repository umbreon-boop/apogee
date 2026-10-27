--[=[
	Toast notifications that fade in at the bottom right corner of the screen,
	featuring a clean custom icon, title, content, and squircle card styling.

	@class Notification
	@location internals/components
]=]
local State = require("../public")
local Backdrop = require("./backdrop")
local Icon = require("./icon")
local Icons = require("../assets/icons")
local Motion = require("../services/motion")
local Pointer = require("../services/pointer")
local Squircle = require("./frame")
local Style = require("../assets/themes")
local Theme = require("../services/theme")
local Creator = require("../services/creator")
local Fade = require("../services/fade")
local Maid = require("@aria/maid")
local Measure = require("../services/measure")

--[=[
	@interface NotificationConfig
	.Title string?
	.Content string?
	.SubContent string?
	.Duration number? -- Seconds until the toast closes, 5 by default
	.Icon (string | boolean)? -- Icon name, image asset id, or false to hide
	@within Notification
]=]
export type Config = {
	Title: string?, Content: string?, SubContent: string?, Duration: number?,
	Icon: (string | boolean)?, Width: number?
}

local Notification = {Holder = nil}
Notification.__index = Notification
local active = {}
local PAD = 14
local ICON_SIZE = 22
local CLOSE_SIZE = 32
-- Match the window close control's center: 10 px from the right plus half its 28 px button,
-- and half the 42 px title bar height from the top. Keep the toast hit area larger around that center.
local CLOSE_CENTER_RIGHT = 10 + 28 / 2
local CLOSE_CENTER_TOP = 42 / 2
local FIXED_HEIGHT = 58
local MIN_WIDTH = 200
local MAX_WIDTH = 450
--@inline
local function label(text: string, size: number, weight: Enum.FontWeight, key: string): TextLabel
	return Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, weight, Enum.FontStyle.Normal),
		Text = text,
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		TextWrapped = true,
		RichText = true,
		Visible = text ~= "",
		Themed = {TextColor3 = key}
	})
end

--[=[
	Creates the stack every notification is placed in.

	@param gui ScreenGui -- The screen gui to draw notifications in
]=]
function Notification.Init(gui: ScreenGui)
	Notification.Holder = Creator:New("Frame", {
		Position = UDim2.new(1, -24, 1, -24),
		Size = UDim2.new(0, MAX_WIDTH, 1, -24),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = gui
	}, {
		Creator:New("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, Style.Space.XXS)
		})
	})
end

--[=[
	Shows a new notification with custom icon, title, and contents.

	@param config Config -- Toast content, duration, icon, and width.
	@param window any? -- The owning window
	@return [Notification](Notification.md) -- The newly created notification toast.
]=]
function Notification.New(config: Config, window: any?): any
	local self = setmetatable({Closed = false, _window = window}, Notification)
	active[self] = true

	-- Custom Icon
	local iconName = config.Icon
	if iconName ~= false then
		if type(iconName) ~= "string" or iconName == "" then
			iconName = "bell"
		end
	end

	-- the left edge of the text, after the icon when the icon shows
	local iconLeft = PAD + ICON_SIZE + 10
	local textLeft = PAD
	self.Icon = Icon.New(iconName, {
		Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, math.floor(iconLeft / 2), 0.5, 0),
		BackgroundTransparency = 1,
		Themed = {ImageColor3 = "Accent"}
	})

	-- Title and Contents
	self.Title = label(config.Title or "Notification", Style.Type.Body, Enum.FontWeight.Bold, "Text")
	self.ContentLabel = label(config.Content or "", Style.Type.Small, Enum.FontWeight.Regular, "Text")
	if config.SubContent and config.SubContent ~= "" then
		self.SubContentLabel = label(config.SubContent, Style.Type.Small, Enum.FontWeight.Regular, "SubText")
	end

	self.LabelHolder = Creator:New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		ClipsDescendants = true
	}, {
		Creator:New("UISizeConstraint", {
			MaxSize = Vector2.new(math.huge, FIXED_HEIGHT - 2 * PAD)
		}),
		Creator:New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2)
		}),
		self.Title,
		self.ContentLabel,
		self.SubContentLabel
	})

	-- Rounded square close button
	local closeHover = Squircle.New(Style.Squircle.Small, {
		ImageTransparency = 1,
		ZIndex = 1,
		Themed = {ImageColor3 = "Hover"}
	})
	local closeIcon = Creator:New("ImageLabel", {
		Name = "CloseIcon",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Themed = {ImageColor3 = "SubText"}
	})
	local closeImage = Icons.GetIcon("x", nil, function(image)
		if closeIcon.Parent then
			closeIcon.Image = image or ""
		end
	end)
	if closeImage then
		closeIcon.Image = closeImage
	end
	self.CloseButton = Creator:New("TextButton", {
		Text = "",
		Position = UDim2.new(1, -CLOSE_CENTER_RIGHT, 0, CLOSE_CENTER_TOP),
		Size = UDim2.fromOffset(CLOSE_SIZE, CLOSE_SIZE),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 1
	}, {closeHover, closeIcon})

	local _, closeFade = Motion.Bind(1, closeHover, "ImageTransparency", true)
	Pointer.Hover(self.CloseButton, closeFade, {Rest = 1, Hover = 0.85, Press = 0.7})

	-- No drop shadow: its square bounds would peek out past the rounded toast
	local surface = Backdrop.New(Style.Squircle.Container)
	Theme:Override(surface.Background, {ImageColor3 = "Overlay"})
	surface.Background.ImageTransparency = 0
	if window then
		surface.Background.ImageTransparency = window.Transparency or 0
	end

	self.Root = Creator:New("Frame", {
		BackgroundTransparency = 1,
		Active = true,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		ClipsDescendants = true
	}, {surface, self.Icon, self.CloseButton, self.LabelHolder})

	self.Holder = Creator:New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(MIN_WIDTH, FIXED_HEIGHT),
		Parent = Notification.Holder
	}, {self.Root})

	self.CloseButton.MouseButton1Click:Connect(function()
		self:Close()
	end)
	local function updateSize()
		local textWidth = math.max(Measure.Text(self.Title).X, Measure.Text(self.ContentLabel).X)
		if self.SubContentLabel then
			textWidth = math.max(textWidth, Measure.Text(self.SubContentLabel).X)
		end
		local naturalWidth = textLeft + textWidth + 12 + CLOSE_SIZE + PAD
		local targetWidth = config.Width or math.clamp(naturalWidth, MIN_WIDTH, MAX_WIDTH)
		self.Holder.Size = UDim2.fromOffset(targetWidth, FIXED_HEIGHT)
	end

	for _, textObj in {self.Title, self.ContentLabel, self.SubContentLabel} do
		if textObj then
			for _, property in {"Text", "FontFace", "TextSize"} do
				textObj:GetPropertyChangedSignal(property):Connect(updateSize)
			end
		end
	end
	-- a theme without icons moves the text to the left edge
	Icon.Watch(self.Icon, function(shown)
		textLeft = PAD
		if shown then textLeft = iconLeft end
		self.LabelHolder.Size = UDim2.new(1, -(textLeft + PAD + CLOSE_SIZE + 6), 0, 0)
		self.LabelHolder.Position = UDim2.new(0, textLeft, 0.5, 0)
		updateSize()
	end)

	self:Open()
	if window then
		State:Adopt(window, self)
	end
	self._timer = task.delay(config.Duration or 5, function()
		self._timer = nil
		self:Close()
	end)

	return self
end

--[=[
	Animates the notification into view.
]=]
function Notification:Open()
	Fade.To(self.Root, true, Fade.Duration)
end

--[=[
	Fades the notification out and destroys it.
]=]
function Notification:Close()
	if self.Closed then
		return
	end

	self.Closed = true
	if self._timer then
		pcall(task.cancel, self._timer)
		self._timer = nil
	end
	Fade.To(self.Root, false, Fade.Duration, function()
		self:Destroy()
	end)
end

function Notification:SetTransparency(value: number)
	local background = self.Root and self.Root:FindFirstChild("Background", true)
	if background then
		background.ImageTransparency = value
	end
end

function Notification:Destroy()
	active[self] = nil
	self.Closed = true
	if self._timer then
		pcall(task.cancel, self._timer)
		self._timer = nil
	end
	State:Orphan(self)
	if self.Holder then
		self.Holder.Visible = false
		local maid = Maid.new()
		maid:Task(self.Holder)
		maid:DeferredClean(0.01)
	end
end

-- Cancels toast timers and removes toasts before the root GUI is destroyed.
function Notification.DestroyAll()
	for notification in table.clone(active) do
		pcall(notification.Destroy, notification)
	end
end

return Notification
