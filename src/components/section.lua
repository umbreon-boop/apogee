--[=[
	A titled group of widgets inside a tab.

	@class Section
	@location internals/components
]=]
local Class = require("../services/class")
local Container = require("./container")
local Squircle = require("./frame")
local Style = require("../assets/themes")
local Creator = require("../services/creator")
local Measure = require("../services/measure")

--[=[
	@prop Title string -- The heading text
]=]
local Section = Class.Extend({Type = "Section"}, Container)

--[=[
	Creates a new section.

	@param config { Title: string } -- The section settings
	@param tab Tab -- The owning tab
	@return [Section](Section.md) -- The new section attached to the tab.
]=]
function Section.New(config: { Title: string }, tab: any): any
	local self = Class.New(Section, {ScrollFrame = tab.Container, _tab = tab, _window = tab._window, _rows = 0})

	local headingHeight = 18
	local title = Creator:New("TextLabel", {
		RichText = true,
		Text = config.Title,
		TextTransparency = 0,
		FontFace = Font.new(Style.Font, Enum.FontWeight.Bold, Enum.FontStyle.Normal),
		TextSize = Style.Type.Heading,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, -8, 0, headingHeight),
		Position = UDim2.fromOffset(2, 0),
		Themed = {TextColor3 = "Text"}
	})
	local layout = Creator:New("UIListLayout", {Padding = UDim.new(0, 0)})
	-- the heading sits on one line and the panel starts a small gap below it
	local offset = headingHeight + 3

	-- one rounded panel holding every widget as a row, the way COSMIC groups its settings
	rawset(self, "Container", Creator:New("Frame", {
		Size = UDim2.fromScale(1, 0),
		Position = UDim2.fromOffset(0, offset),
		BackgroundTransparency = 1
	}, {layout}))

	-- the panel is drawn by a sibling so it does not take part in the rows' list layout
	local panel = Squircle.New(Style.Squircle.Container, {
		Name = "Surface",
		Position = self.Container.Position,
		Size = self.Container.Size,
		ImageTransparency = tab._window and tab._window.Transparency or 0,
		Themed = {ImageColor3 = "Surface"}
	})
	rawset(self, "Panel", panel)

	rawset(self, "Root", Creator:New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, offset),
		LayoutOrder = 7,
		Parent = tab.Container
	}, {title, panel, self.Container}))

	local function updateSection()
		local contentHeight = Measure.Rows(self.Container)
		self.Container.Size = UDim2.new(1, 0, 0, contentHeight)
		panel.Size = self.Container.Size
		self.Root.Size = UDim2.new(1, 0, 0, contentHeight + offset)
		if self._tab and self._tab._updateCanvas then
			self._tab:_updateCanvas()
		end
	end

	self._updateSection = updateSection
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateSection)

	Class.Define(self, {
		Title = function(_, value: string)
			title.Text = value
		end
	})
	self:From({Title = config.Title})

	return self
end

--[=[
	Claims the next row of the panel, returning whether it is the first one.

	@return boolean -- Whether this is the first row in the section.
	@private
]=]
function Section:_row(): boolean
	self._rows = self._rows + 1
	if self._updateSection then
		self._updateSection()
	end
	return self._rows == 1
end

return Section
