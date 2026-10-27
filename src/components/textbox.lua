--[=[
	A single line text box with an accent focus ring that scrolls horizontally to keep the cursor visible.

	@class Textbox
	@location internals/components
]=]
local TextService = game:GetService("TextService")
local Style = require("../assets/themes")
local Squircle = require("./frame")
local Theme = require("../services/theme")
local Creator = require("../services/creator")

--[=[
	@interface Textbox
	.Frame Frame
	.Background ImageLabel
	.Indicator ImageLabel
	.Container Frame
	.Input TextBox
	@within Textbox
	`Indicator` is the outline around the field, tinted with the accent while the field is focused.
]=]
export type Textbox = {
	Frame: Frame,
	Background: ImageLabel,
	Indicator: ImageLabel,
	Container: Frame,
	Input: TextBox
}

local Textbox = {}
Textbox.__index = Textbox
local PADDING = 2

--[=[
	Creates a new text box.

	@param parent Instance? -- The instance to draw the text box in
	@param element boolean? -- Use the control palette of rows instead of the inset palette of dialogs
	@return [Textbox](Textbox.md) -- The textbox component with its input and visual elements.
]=]
function Textbox.New(parent: Instance?, element: boolean?): Textbox
	local frameKey = "Background"
	local outlineKey = "Border"
	if element then
		frameKey = "Field"
		outlineKey = "ControlBorder"
	end
	local self = setmetatable({
		_frameKey = frameKey,
		_focusedKey = "Field",
		_outlineKey = outlineKey
	}, Textbox)

	self.Input = Creator:New("TextBox", {
		FontFace = Font.new(Style.Font),
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(PADDING, 0),
		Themed = {TextColor3 = "Text", PlaceholderColor3 = "SubText"}
	})

	self.Container = Creator:New("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0)
	}, {self.Input})

	self.Background = Squircle.New(Style.Squircle.Control, {
		Name = "Background",
		ImageTransparency = 0,
		Themed = {ImageColor3 = self._frameKey}
	})
	self.Indicator = Squircle.New(Style.Squircle.Control, {
		Name = "Indicator",
		Shape = "Outline",
		Visible = false,
		Themed = {ImageColor3 = self._outlineKey}
	})
	self.Frame = Creator:New("Frame", {Size = UDim2.fromOffset(0, Theme:Size("Control")), BackgroundTransparency = 1, Parent = parent}, {
		self.Background,
		self.Indicator,
		self.Container
	})
	local function update()
		self:_update()
	end
	task.spawn(update)
	self.Input:GetPropertyChangedSignal("Text"):Connect(update)
	self.Input:GetPropertyChangedSignal("CursorPosition"):Connect(update)
	self.Input.Focused:Connect(function()
		self:_focus(true)
	end)
	self.Input.FocusLost:Connect(function()
		self:_focus(false)
	end)

	return self
end

function Textbox:_update()
	local input = self.Input
	local reveal = self.Container.AbsoluteSize.X

	if not input:IsFocused() or input.TextBounds.X <= reveal - 2 * PADDING then
		input.Position = UDim2.fromOffset(PADDING, 0)
		return
	end

	local cursor = input.CursorPosition
	if cursor == -1 then
		return
	end

	local width = TextService:GetTextSize(
		string.sub(input.Text, 1, cursor - 1),
		input.TextSize,
		input.Font,
		Vector2.new(math.huge, math.huge)
	).X
	local position = input.Position.X.Offset + width
	if position < PADDING then
		input.Position = UDim2.fromOffset(PADDING - width, 0)
	elseif position > reveal - PADDING - 1 then
		input.Position = UDim2.fromOffset(reveal - width - PADDING - 1, 0)
	end
end

function Textbox:_focus(focused: boolean)
	self:_update()
	local frameColor = self._frameKey
	local indicatorColor = self._outlineKey
	if focused then
		frameColor = self._focusedKey
		indicatorColor = "Accent"
	end
	Theme:Override(self.Background, {
		ImageColor3 = frameColor
	})
	Theme:Override(self.Indicator, {ImageColor3 = indicatorColor})
	self.Indicator.Visible = focused
end

return Textbox
