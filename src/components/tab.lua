--[=[
	A page of the window, listed in the sidebar and shown in the content area when selected.

	@class Tab
	@location internals/components
]=]
local Class = require("../services/class")
local Container = require("./container")
local Images = require("../assets/images")
local Icon = require("./icon")
local Motion = require("../services/motion")
local Pointer = require("../services/pointer")
local Section = require("./section")
local Style = require("../assets/themes")
local Squircle = require("./frame")
local Theme = require("../services/theme")
local Creator = require("../services/creator")
local Args = require("../services/args")
local Measure = require("../services/measure")

--[=[
	@prop Title string -- The sidebar and header text
]=]
local Tab = Class.Extend({Type = "Tab"}, Container)

--[=[
	@interface TabConfig
	.Title string
	.Icon string?
	@within Tab
	`Icon` is either an icon name or an asset id.
]=]
export type Config = { Title: string, Icon: string? }

--[=[
	Creates a new tab. Use `Window:Tab` instead of calling this directly.

	@param config Config -- Tab title and optional icon.
	@param window Window -- The owning window
	@return [Tab](Tab.md) -- The new tab attached to the window.
]=]
function Tab.New(config: Config, window: any): any
	local self = Class.New(Tab, {Selected = false, _window = window})

	local label = Creator:New("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Text = config.Title,
		RichText = true,
		TextTransparency = 0,
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromOffset(math.max(0, window.TabWidth - 16), Theme:Size("Tab")),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Themed = {TextColor3 = "Text"}
	})

	local image = Icon.New(config.Icon, {
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(0, 8, 0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Themed = {ImageColor3 = "Text"}
	})
	self._icon = image
	local function updateTabLayout(width: number, fitText: boolean?)
		-- a horizontal tab is a centered content block: padding, icon, gap, text, padding.
		local iconX = 8
		if fitText then iconX = 12 end
		image.Position = UDim2.new(0, iconX, 0.5, 0)
		local textX = 12
		if image.Visible then textX = iconX + 16 + 6 end
		label.Position = UDim2.new(0, textX, 0.5, 0)
		label.Size = UDim2.new(0, math.max(0, width - textX - 12), 1, 0)
		-- horizontally the tab is sized from the text, so truncating it can still ellipsize a full title
		label.TextTruncate = fitText and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
	end
	self._updateTabLayout = updateTabLayout
	self._preferredTabWidth = function()
		-- Measure the text independently of the label's current size. `TextBounds` shrinks with
		-- the label once truncation kicks in, so reading it here would lock a tab at its current width.
		-- The icon is part of the centered content block, not extra padding on the left.
		local content = 0
		if image.Visible then content = 16 + 6 end
		return math.max(Theme:Size("Tab"), math.ceil(Measure.Text(label).X) + 12 + content + 12)
	end
	local highlight = Squircle.New(Style.Squircle.Control, {
		ImageTransparency = 1,
		ZIndex = 1,
		Themed = {ImageColor3 = "Hover"}
	})
	self._highlight = highlight
	rawset(self, "Frame", Creator:New("TextButton", {
		Size = UDim2.new(1, 0, 0, Theme:Size("Tab")),
		BackgroundTransparency = 1,
		ZIndex = 1,
		Parent = window.TabHolder
	}, {highlight, label, image}))
	Theme:Height(self.Frame, "Tab")
	-- a theme without icons moves the label to the left edge
	Icon.Watch(image, function()
		updateTabLayout(window.TabWidth)
		if window.Root then
			window:_updateTabSection(window.Root.Size.X.Offset)
		end
	end)
	label:GetPropertyChangedSignal("TextBounds"):Connect(function()
		if window._horizontalTabs and window.Root then
			window:_updateTabSection(window.Root.Size.X.Offset)
		else
			updateTabLayout(window.TabWidth)
		end
	end)

	local layout = Creator:New("UIListLayout", {Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder})
	rawset(self, "Container", Creator:New("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = window.ContainerHolder,
		Visible = false,
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
			PaddingRight = UDim.new(0, 8),
			PaddingLeft = UDim.new(0, 2),
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 24)
		})
	}))
	rawset(self, "ScrollFrame", self.Container)
	local function updateCanvas()
		self.Container.CanvasSize = UDim2.fromOffset(0, Measure.Rows(self.Container))
	end
	self._updateCanvas = updateCanvas
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
	updateCanvas()

	local _, fade = Motion.Bind(1, highlight, "ImageTransparency")
	self._fade = fade

	Pointer.Hover(self.Frame, fade, {
		Rest = function()
			if self.Selected then return 0.8 end
			return 1
		end,
		Hover = function()
			if self.Selected then return 0.8 end
			return 0.9
		end,
		Press = 0.8
	})
	self.Frame.MouseButton1Click:Connect(function()
		window:SelectTab(self)
	end)

	Class.Define(self, {
		Title = function(tab, value: string)
			label.Text = value
			if window._horizontalTabs and window.Root then
				window:_updateTabSection(window.Root.Size.X.Offset)
			else
				updateTabLayout(window.TabWidth)
			end
			if tab.Selected then
				window.TabDisplay.Text = value
			end
		end
	})
	self:From({Title = config.Title})

	return self
end

--[=[
	Adds a titled section to the tab.

	@param config { Title: string } -- Section heading configuration.
	@return [Section](Section.md) -- The section added to this tab.
]=]
function Tab:Section(config: any, ...: any): any
	config = Args.Config({"Title"}, nil, config, ...)
	return Section.New(config, self)
end

--[=[
	Marks the tab as selected or not and animates its sidebar highlight.

	@param selected boolean -- The new selection state
]=]
function Tab:SetSelected(selected: boolean)
	rawset(self, "Selected", selected)
	local color = "Hover"
	local iconColor = "Text"
	local transparency = 1
	if selected then
		color = "Accent"
		iconColor = "Accent"
		transparency = 0.8
	end
	Theme:Override(self._highlight, {ImageColor3 = color})
	Theme:Override(self._icon, {ImageColor3 = iconColor})
	-- Selection remains visible while an overlay is open.
	self._fade(transparency, true)
end

return Tab
