--[=[
	The draggable strip at the top of the window holding its title and the minimize, maximize and close buttons.

	@class TitleBar
	@location internals/components
]=]
local Icon = require("../icon")
local Icons = require("../../assets/icons")
local Motion = require("../../services/motion")
local Pointer = require("../../services/pointer")
local State = require("../../public")
local Style = require("../../assets/themes")
local Squircle = require("../frame")
local Creator = require("../../services/creator")
local Measure = require("../../services/measure")

local Theme = require("../../services/theme")

local TitleBar = {}
TitleBar.__index = TitleBar
local iconRequests = setmetatable({}, {__mode = "k"})
local BUTTON_SIZE = 28
local HOVERED = 0.9
local PRESSED = 0.8

-- The label width comes from `Measure.Text`. Automatic sizing follows the rendered text, which changes under the
-- scale animations of the window, and the title then moves when the animation ends.
--@inline
local function title(text: string?, transparency: number, key: string, size: number): TextLabel
	local label = Creator:New("TextLabel", {
		RichText = true,
		Text = text,
		TextTransparency = transparency,
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextSize = size,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(0, 1),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = key}
	})
	local function fit()
		-- the measurement can yield while a font loads
		task.spawn(function()
			label.Size = UDim2.new(0, math.ceil(Measure.Text(label).X), 1, 0)
		end)
	end
	for _, property in {"Text", "FontFace", "TextSize"} do
		label:GetPropertyChangedSignal(property):Connect(fit)
	end
	fit()
	return label
end

local function styleButtonIcon(frame: Instance, window: any, name: string, highlight: string?, text: string?)
	local request = {}
	local completed = false
	iconRequests[frame] = request
	local function apply(image: string?)
		Theme:Style("TitleBarButton", frame, window, image, highlight, text)
	end
	local image = Icons.GetIcon(name, nil, function(resolved)
		completed = true
		if iconRequests[frame] == request and frame.Parent then
			apply(resolved)
		end
	end)
	if not completed then
		apply(image)
	end
end

--[=[
	Draws an icon button with a hover highlight and returns a cleanup handle.

	@param button TextButton -- The title bar button, which owns the click
	@param window Window -- The window of the title bar
	@param icon string -- The icon asset
	@param highlight string? -- The theme key of the hover tint, `Hover` by default
	@param _text string -- A text symbol for looks without icons, this look draws the icon
	@return { Destroy: () -> () } -- A cleanup handle that removes the title bar button look.
]=]
function TitleBar.ButtonLook(button: TextButton, window: any, icon: string, highlight: string?, _text: string): any
	button.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	local tint = Squircle.New(Style.Squircle.Control, {
		ImageTransparency = 1,
		ZIndex = 1,
		Parent = button,
		Themed = {ImageColor3 = highlight or "Hover"}
	})
	local iconElem = Creator:New("ImageLabel", {
		Image = icon,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Name = "Icon",
		ZIndex = 2,
		Parent = button,
		Themed = {ImageColor3 = "Text"}
	})

	local _, fade = Motion.Bind(1, tint, "ImageTransparency")
	local disconnect = Pointer.Hover(button, fade, {
		Rest = 1,
		Hover = HOVERED,
		Press = PRESSED,
		Blocked = function()
			return State:HasOverlay()
		end
	})
	local reset = {
		ResetHighlight = function()
			fade(1, true)
		end
	}
	table.insert(window._elements, reset)

	return {
		Destroy = function()
			disconnect()
			local index = table.find(window._elements, reset)
			if index then
				table.remove(window._elements, index)
			end
			tint:Destroy()
			iconElem:Destroy()
		end
	}
end

-- a stable button that keeps its click across theme changes, the active `TitleBarButton` look draws it
--@inline
local function button(icon: string, position: UDim2, parent: Instance, window: any, callback: () -> (), highlight: string?, text: string): TextButton
	local frame = Creator:New("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
		Position = position,
		Text = ""
	})
	frame.MouseButton1Click:Connect(callback)
	styleButtonIcon(frame, window, icon, highlight, text)
	return frame
end

function TitleBar.New(window: any, config: { Title: string, SubTitle: string?, Icon: string? }): any
	local self = setmetatable({}, TitleBar)

	local children: { Instance } = {
		Creator:New("UIListLayout", {
			Padding = UDim.new(0, 6),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center
		})
	}

	if config.Icon and config.Icon ~= "" then
		local icon = Icon.New(config.Icon, {
			Name = "Icon",
			Size = UDim2.fromOffset(16, 16),
			BackgroundTransparency = 1,
			Themed = {ImageColor3 = "Text"}
		})
		-- the list layout skips a hidden icon
		Icon.Watch(icon, function() end)
		table.insert(children, icon)
	end

	self.TitleLabel = title(config.Title, 0, "Text", Style.Type.Body)
	table.insert(children, self.TitleLabel)
	table.insert(children, title(config.SubTitle, 0.4, "SubText", Style.Type.Small))

	self.Frame = Creator:New("Frame", {Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = window.Root}, {
		Creator:New("Frame", {
			-- leave the three title-bar buttons their own space; clip a long title instead of drawing under them
			Size = UDim2.new(1, -2 * Style.Space.S - 3 * BUTTON_SIZE, 1, 0),
			Position = UDim2.fromOffset(Style.Space.S, 0),
			BackgroundTransparency = 1,
			ClipsDescendants = true
		}, children),
		Creator:New("Frame", {
			Name = "Divider",
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromScale(0, 1),
			Themed = {BackgroundColor3 = "Divider"}
		})
	})

	-- closing the last window unloads the interface, otherwise only this window is closed
	self.CloseButton = button("x", UDim2.new(1, -10, 0.5, 0), self.Frame, window, function()
		local last = #window._windows <= 1
		local content = "Are you sure you want to close this window?"
		if last then
			content = "Are you sure you want to unload the interface?"
		end
		window:Dialog({
			Title = "Close",
			Content = content,
			Buttons = {
				{
					Title = "Yes",
					Style = "Destructive",
					Callback = function()
						window:Close()
					end
				},
				{Title = "No"}
			}
		})
	end, "Destructive", "×")
	self.MaxButton = button("scan", UDim2.new(1, -46, 0.5, 0), self.Frame, window, function()
		window:Maximize(not window.Maximized)
	end, nil, "□")
	self.MinButton = button("minus", UDim2.new(1, -82, 0.5, 0), self.Frame, window, function()
		window:Minimize()
	end, nil, "_")

	self._window = window
	return self
end

--[=[
	Shows the restore icon on the maximize button while the window is maximized.

	@param maximized boolean -- Whether the window is maximized
]=]
function TitleBar:SetMaximized(maximized: boolean)
	local iconName = "scan"
	if maximized then iconName = "minimize-2" end
	styleButtonIcon(self.MaxButton, self._window, iconName, nil, "□")
end

Theme:RegisterComponent("TitleBarButton", TitleBar.ButtonLook)

return TitleBar
