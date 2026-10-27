--[=[
	The push button used inside dialogs. It comes in libcosmic's three flavours: a filled `Suggested` default action,
	a quiet `Standard` button and a `Destructive` one, all sized to their title.

	@class Action
	@location internals/components
]=]
local Motion = require("../services/motion")
local Pointer = require("../services/pointer")
local Squircle = require("./frame")
local Style = require("../assets/themes")
local Theme = require("../services/theme")
local Creator = require("../services/creator")
local Measure = require("../services/measure")

--[=[
	@interface Action
	.Frame TextButton
	.Title TextLabel
	.Background ImageLabel
	.HoverFrame ImageLabel
	.Stroke ImageLabel
	@within Action
]=]
export type Action = {
	Frame: TextButton,
	Title: TextLabel,
	Background: ImageLabel,
	HoverFrame: ImageLabel,
	Stroke: ImageLabel
}

local Action = {}
Action.__index = Action
local MIN_WIDTH = 88
local MAX_WIDTH = 280
local PADDING = 2 * Style.Space.S

--[=[
	Creates a new dialog button.

	@param parent Instance? -- The instance to draw the button in
	@param ignoreDialog boolean? -- Keep the hover animation running while a dialog is open
	@param title string? -- Initial button text
	@return [Action](Action.md) -- The dialog action button with its configured label and behavior.
]=]
function Action.New(parent: Instance?, ignoreDialog: boolean?, title: string?): Action
	local action = setmetatable({
		_width = MIN_WIDTH,
		_fullWidth = false
	}, Action)

	action.Title = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		BackgroundTransparency = 1,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 1),
		Text = title or "",
		Themed = {TextColor3 = "Text"}
	})

	action.Background = Squircle.New(Style.Squircle.Control, {
		Themed = {ImageColor3 = "Control"}
	})
	action.HoverFrame = Squircle.New(Style.Squircle.Control, {ImageTransparency = 1, Themed = {ImageColor3 = "Hover"}})
	action.Stroke = Squircle.New(Style.Squircle.Control, {
		Shape = "Outline",
		Visible = false,
		Themed = {ImageColor3 = "ControlBorder"}
	})

	action.Frame = Creator:New("TextButton", {
		Size = UDim2.fromOffset(MIN_WIDTH, Theme:Size("Button")),
		BackgroundTransparency = 1,
		Parent = parent
	}, {action.Background, action.HoverFrame, action.Stroke, action.Title})

	-- the button is sized from the text bounds, since automatic sizing would also stretch the squircle children
	function action:UpdateSize()
		local textWidth = Measure.Text(action.Title).X
		local width = math.clamp(math.ceil(textWidth + PADDING), MIN_WIDTH, MAX_WIDTH)
		action._width = width
		if action._customSize then
			action.Frame.Size = action._customSize
		elseif action._fullWidth then
			action.Frame.Size = UDim2.new(1, 0, 0, Theme:Size("Button"))
		else
			action.Frame.Size = UDim2.fromOffset(width, Theme:Size("Button"))
		end
	end

	action:UpdateSize()
	Theme:Track(function()
		action:UpdateSize()
	end, action.Frame)
	-- a new text or font refits the button; the text bounds also change on each frame of a scale animation
	for _, property in {"Text", "FontFace", "TextSize"} do
		action.Title:GetPropertyChangedSignal(property):Connect(function()
			action:UpdateSize()
		end)
	end

	local _, fade = Motion.Bind(1, action.HoverFrame, "ImageTransparency", ignoreDialog)
	Pointer.Hover(action.Frame, fade, {Rest = 1, Hover = 0.9, Press = 0.8})

	return action
end

--[=[
	Overrides the automatic text-based sizing with a fixed size, matching how dialogs size their buttons.

	@param size UDim2
]=]
function Action:SetSize(size: UDim2)
	self._customSize = size
	self.Frame.Size = size
end

--[=[
	Sets whether the button expands to fill the full width of its parent container.

	@param enabled boolean
]=]
function Action:SetFullWidth(enabled: boolean)
	self._fullWidth = enabled
	self:UpdateSize()
end

--[=[
	Updates the button text and recalculates its width.

	@param title string
]=]
function Action:SetTitle(title: string)
	self.Title.Text = title
	self:UpdateSize()
end

local ROLES = {
	Suggested = {Fill = "Accent", Text = "AccentText"},
	Destructive = {Fill = "Destructive", Text = "DestructiveText"},
	Standard = {Fill = "Control", Text = "Text"}
}

--[=[
	Sets the button's role: `Suggested` fills it with the accent, `Destructive` with the destructive color and
	`Standard` with the control color.

	@param role "Suggested" | "Destructive" | "Standard" -- The role
]=]
function Action:SetRole(role: string)
	local colors = assert(ROLES[role], "Action:SetRole - unknown role")
	Theme:Override(self.Background, {ImageColor3 = colors.Fill})
	Theme:Override(self.Title, {TextColor3 = colors.Text})
end

--[=[
	Marks the button as the dialog's default action, which is filled with the accent color.

	@param primary boolean -- Whether the button is the default action
]=]
function Action:SetPrimary(primary: boolean)
	local role = "Standard"
	if primary then
		role = "Suggested"
	end
	self:SetRole(role)
end

--[=[
	Marks the button as a destructive action, which is filled with the destructive color.

	@param destructive boolean -- Whether the button is destructive
]=]
function Action:SetDestructive(destructive: boolean)
	local role = "Standard"
	if destructive then
		role = "Destructive"
	end
	self:SetRole(role)
end

return Action
