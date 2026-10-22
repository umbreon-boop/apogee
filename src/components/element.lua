--[=[
	Card used by widgets to display a title, optional description, and interactive state.

	@class Element
	@location internals/components
]=]
local Motion = require("../services/motion")
local Pointer = require("../services/pointer")
local Squircle = require("./frame")
local State = require("../public")
local Style = require("../assets/themes")
local Theme = require("../services/theme")
local Creator = require("../services/creator")
local Measure = require("../services/measure")

--[=[
	@interface Element
	.Frame TextButton
	.TitleLabel TextLabel
	.DescLabel TextLabel
	.LabelHolder Frame
	.Surface ImageLabel
	.Border ImageLabel
	.Background ImageLabel
	.Group (self, first: boolean, section: any?) -> ()
	.SetTitle (self, title: string) -> ()
	.SetDesc (self, description: string?) -> ()
	.Destroy (self) -> ()
	@within Element
	`Surface` is the card's fill, `Border` its outline and `Background` the hover and press tint, which is transparent
	while the card is at rest.
]=]
export type Element = {
	Frame: TextButton,
	TitleLabel: TextLabel,
	DescLabel: TextLabel,
	LabelHolder: Frame,
	Surface: ImageLabel,
	Border: ImageLabel,
	Background: ImageLabel,
	Group: (self: any, first: boolean) -> (),
	SetTitle: (self: any, title: string) -> (),
	SetDesc: (self: any, description: string?) -> (),
	Destroy: (self: any) -> ()
}

local Element = {}
Element.__index = Element
local REST = 1
local TITLE_HEIGHT = 16
local LABEL_GAP = 2
local LABEL_PAD = 9

--[=[
	Creates a new element card.

	@param title string -- The title text
	@param description string? -- The description text, hidden when empty
	@param parent Instance? -- The container to draw the card in
	@param hover boolean? -- Animate the card on hover and press
	@param window any? -- The owning window
	@return [Element](Element.md) -- The card component with its labels and visual surfaces.
]=]
function Element.New(title: string, description: string?, parent: Instance?, hover: boolean?, window: any?): Element
	local element = setmetatable({_grouped = false, _window = window}, Element)

	element.TitleLabel = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Text = title,
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 16),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})

	element.DescLabel = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font),
		Text = description or "",
		TextSize = Style.Type.Small,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 14),
		Themed = {TextColor3 = "SubText"}
	})

	local padding = Creator:New("UIPadding", {PaddingBottom = UDim.new(0, 0), PaddingTop = UDim.new(0, 0)})
	element._padding = padding

	element.LabelHolder = Creator:New("Frame", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.new(1, -24, 0, 0)
	}, {
		Creator:New("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, LABEL_GAP)
		}),
		padding,
		element.TitleLabel,
		element.DescLabel
	})

	element.Surface = Squircle.New(Style.Squircle.Container, {
		Name = "Surface",
		ImageTransparency = window and window.Transparency or 0,
		Themed = {ImageColor3 = "Surface"}
	})
	-- kept for customization, but libcosmic cards have no outline: the surface step carries the shape
	element.Border = Squircle.New(Style.Squircle.Container, {
		Name = "Border",
		Shape = "Outline",
		Visible = false,
		Themed = {ImageColor3 = "Border"}
	})
	-- the hover and press tint, transparent while the card is at rest
	element.Background = Squircle.New(Style.Squircle.Container, {
		Name = "Background",
		ImageTransparency = REST,
		Themed = {ImageColor3 = "Hover"}
	})

	local minimum = Creator:New("UISizeConstraint", {MinSize = Vector2.new(0, Theme:Size("Row"))})
	element.Frame = Creator:New("TextButton", {
		Size = UDim2.new(1, 0, 0, Theme:Size("Row")),
		BackgroundTransparency = 1,
		Parent = parent,
		Text = "",
		LayoutOrder = 7
	}, {
		element.Surface,
		element.Border,
		element.Background,
		element.LabelHolder,
		minimum
	})
	Theme:Track(function()
		minimum.MinSize = Vector2.new(0, Theme:Size("Row"))
		element:_fit(true)
	end, element.Frame)

	-- Automatic sizing follows the rendered text, which changes under a scale animation, and the card height
	-- then changes when the animation ends. The card height comes from `Measure.Text` instead.
	element.LabelHolder:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		element:_fit(false)
	end)
	for _, property in {"Text", "FontFace", "TextSize", "Visible"} do
		element.DescLabel:GetPropertyChangedSignal(property):Connect(function()
			element:_fit(true)
		end)
	end
	element:SetTitle(title)
	element:SetDesc(description)

	if hover then
		local motor, fade = Motion.Bind(REST, element.Background, "ImageTransparency", false, window)
		element._motor = motor
		Theme:Track(function()
			motor:Set(Motion.Instant(REST))
		end, element.Frame)

		Pointer.Hover(element.Frame, fade, {
			Rest = REST,
			Hover = function()
				return REST - Theme:Get("HoverChange")
			end,
			Press = function()
				return REST - Theme:Get("HoverChange") * 2
			end,
			Blocked = function()
				return State:HasOverlay(window)
			end
		})
	end

	if window then
		table.insert(window._elements, element)
	end

	return element
end

--[=[
	Turns the card into a row of a section panel: the card's own fill and outline are dropped and a divider is
	drawn above every row but the first.

	@param first boolean -- Whether this is the section's first row
	@param section any? -- The section that owns this row
]=]
function Element:Group(first: boolean, section: any?)
	self._grouped = true
	self._section = section
	self.Surface.Visible = false
	self.Border.Visible = false
	if self._motor then
		self._motor:Set(Motion.Instant(REST))
	end

	Creator:New("Frame", {
		Name = "Divider",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 0, 1),
		Visible = not first,
		Parent = self.Frame,
		Themed = {BackgroundColor3 = "Divider"}
	})
end

--[=[
	Changes the title text.

	@param value string -- The new title
]=]
function Element:SetTitle(value: string)
	self.TitleLabel.Text = value
end

--[=[
	Changes the description text, hiding the label when it is empty.

	@param value string? -- The new description
]=]
function Element:SetDesc(value: string?)
	local text = value or ""
	local hasDesc = text ~= ""
	self.DescLabel.Visible = hasDesc
	self.DescLabel.Text = text

	if self._padding and self.LabelHolder then
		if hasDesc then
			self.LabelHolder.AnchorPoint = Vector2.new(0, 0)
			self.LabelHolder.Position = UDim2.fromOffset(12, 0)
			self._padding.PaddingTop = UDim.new(0, LABEL_PAD)
			self._padding.PaddingBottom = UDim.new(0, LABEL_PAD)
		else
			self.LabelHolder.AnchorPoint = Vector2.new(0, 0.5)
			self.LabelHolder.Position = UDim2.new(0, 12, 0.5, 0)
			self._padding.PaddingTop = UDim.new(0, 0)
			self._padding.PaddingBottom = UDim.new(0, 0)
		end
	end
end

-- Sets the card height from the description height at scale 1. The width read from `AbsoluteSize` has an error
-- of about one pixel at the current scale, so a smaller change is not a new width. This also ignores the frames
-- of a scale animation, because the real width does not change during the animation.
function Element:_fit(force: boolean)
	if not self.DescLabel.Visible then
		if force then
			self._fitToken = nil
			self.Frame.Size = UDim2.new(1, 0, 0, Theme:Size("Row"))
		end
		return
	end
	local holder = self.LabelHolder
	local scale = Measure.Scale(holder)
	local width = Measure.Offset(holder, holder.AbsoluteSize.X)
	if width <= 0 or (not force and self._fitWidth and math.abs(width - self._fitWidth) <= 1 / scale) then
		return
	end
	self._fitWidth = width

	local token = {}
	self._fitToken = token
	-- the measurement can yield while a font loads, and a property setter cannot yield
	task.spawn(function()
		local desc = math.ceil(Measure.Text(self.DescLabel, math.floor(width)).Y)
		if self._fitToken ~= token then
			return
		end
		self.DescLabel.Size = UDim2.new(1, 0, 0, desc)
		local height = LABEL_PAD + TITLE_HEIGHT + LABEL_GAP + desc + LABEL_PAD
		self.Frame.Size = UDim2.new(1, 0, 0, math.max(Theme:Size("Row"), height))
	end)
end

function Element:ResetHighlight()
	if self._motor then
		self._motor:Set(Motion.Instant(REST))
	end
	if self.Background then
		self.Background.ImageTransparency = REST
	end
end

--[=[
	Destroys the card.
]=]
function Element:Destroy()
	local elements = self._window and self._window._elements
	local idx = elements and table.find(elements, self)
	if idx then
		table.remove(elements, idx)
	end
	self.Frame:Destroy()
	local section = rawget(self, "_section")
	if section and section._updateSection then
		section:_updateSection()
	end
end

return Element
