--[=[
	A nestable X/Y layout that divides its space among child containers and accepts every widget primitive.

	@class Layout
	@location internals/components
]=]
local Class = require("../services/class")
local Container = require("./container")
local Creator = require("../services/creator")
local Args = require("../services/args")
local Resize = require("../services/resize")
local VISUAL_GAP_ADJUSTMENT = 3

--[=[
	@interface LayoutConfig
	.Axis ("X" | "Y")? -- Defaults to Y, stacking children vertically.
	.Gap number? -- Visible gap between children on the selected axis; defaults to 8.
	@within Layout
]=]
export type Config = {Axis: ("X" | "Y")?, Gap: number?}

local Layout = Class.Extend({Type = "Layout"}, Container)

--[=[
	Creates a layout inside another container. Use `Container:Layout` instead of calling this directly.

	@param config Config -- Axis and spacing.
	@param parent Container -- The container to draw the layout in.
	@return [Layout](Layout.md) -- The new nested container.
]=]
function Layout.New(config: Config, parent: any): any
	local axis = config.Axis or "Y"
	assert(axis == "X" or axis == "Y", "Layout - Axis must be X or Y")
	local gap = config.Gap or 8
	assert(type(gap) == "number" and gap >= 0, "Layout - Gap must be a non-negative number")
	-- Reduce the list padding to compensate for the gap visible between adjacent widget surfaces.
	local spacing = math.max(0, gap - VISUAL_GAP_ADJUSTMENT)

	local self = Class.New(Layout, {
		Type = "Layout",
		_axis = axis,
		_gap = gap,
		_spacing = spacing,
		_items = {},
		_naturalHeight = 0,
		_refreshing = false,
		_parentContainer = parent,
		_window = parent._window
	})
	self._rootLayout = if parent.Type == "Layout" then parent._rootLayout else self
	local layout = Creator:New("UIListLayout", {
		FillDirection = if axis == "X" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, spacing)
	})
	local rootFrame = Creator:New("Frame", {
		Name = "Layout",
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = 7,
		BackgroundTransparency = 1
	}, {layout})
	rawset(self, "Frame", rootFrame)
	rawset(self, "Container", rootFrame)
	self._layout = layout

	self._refresh = function(_layout: any)
		if self._refreshing then
			return
		end
		self._refreshing = true
		local visible = 0
		for _, item in self._items do
			if item.Frame.Parent == self.Frame and item.Frame.Visible ~= false then
				visible += 1
			end
		end
		local widest = 0
		local equalHeight = 0
		local widestMinimum = 0
		for index, item in self._items do
			local itemFrame = item.Frame
			if itemFrame and itemFrame.Parent == self.Frame then
				if itemFrame.Visible ~= false then
					itemFrame.LayoutOrder = index
					local itemMinimum = Resize.MinimumWidth(item)
					Resize.Apply(itemFrame, itemMinimum)
					widestMinimum = math.max(widestMinimum, itemMinimum)
					local itemHeight = if item.Type == "Layout" then item._naturalHeight else itemFrame.Size.Y.Offset
					if axis == "X" and item.Type == "Layout" then
						equalHeight = math.max(equalHeight, itemHeight)
					end
					if axis == "X" then
						local columns = math.max(visible, 1)
						itemFrame.Size = UDim2.new(1 / columns, -spacing * (columns - 1) / columns, 0, itemFrame.Size.Y.Offset)
						widest = math.max(widest, itemHeight)
					end
				end
			end
		end

		local height = 0
		local minimumWidth = widestMinimum
		if axis == "X" then
			minimumWidth = visible * widestMinimum + math.max(visible - 1, 0) * spacing
			for _, item in self._items do
				if item.Type == "Layout" and item.Frame.Parent == self.Frame then
					item._sharedHeight = equalHeight
					item:_refresh()
				end
			end
			height = widest
		else
			for _, item in self._items do
				local itemFrame = item.Frame
				if itemFrame and itemFrame.Parent == self.Frame and itemFrame.Visible ~= false then
					local itemHeight = itemFrame.Size.Y.Offset
					if item.Type == "Layout" then
						item._sharedHeight = nil
						item:_refresh()
						itemHeight = item._naturalHeight
					end
					height += itemHeight
				end
			end
		end
		if axis == "Y" and visible > 1 then
			height += (visible - 1) * spacing
		end
		self._naturalHeight = height
		self._minimumWidth = minimumWidth
		Resize.Apply(self.Frame, minimumWidth)
		local width = if self._parentContainer.Type == "Layout" then self.Frame.Size.X else UDim.new(1, 0)
		self.Frame.Size = UDim2.new(width.Scale, width.Offset, 0, self._sharedHeight or height)
		self._refreshing = false
		if self == self._rootLayout then
			Resize.Register(self._window, self, minimumWidth)
		end

		local owner = self._parentContainer
		if owner.Type == "Layout" then
			owner:_refresh()
		elseif owner._updateSection then
			owner:_updateSection()
		elseif owner._updateCanvas then
			owner:_updateCanvas()
		end
	end

	self._forget = function(_layout: any, item: any)
		local index = table.find(self._items, item)
		if index then
			table.remove(self._items, index)
			self:_refresh()
		end
	end

	self._attach = function(_layout: any, item: any)
		table.insert(self._items, item)
		item.Frame.Destroying:Connect(function()
			self:_forget(item)
		end)
		item.Frame:GetPropertyChangedSignal("Size"):Connect(function()
			self:_refresh()
		end)
		item.Frame:GetPropertyChangedSignal("Visible"):Connect(function()
			self:_refresh()
		end)
		self:_refresh()
	end

	if parent.Type == "Layout" then
		self.Frame.Parent = parent.Container
		parent:_attach(self)
	else
		-- Layout children draw their own card surfaces; don't render the section's shared surface beneath them.
		if parent.Type == "Section" and parent.Panel then
			if not parent._layoutCount then
				parent._layoutPanelVisible = parent.Panel.Visible ~= false
				parent._layoutCount = 0
			end
			parent._layoutCount += 1
			self._hidesSectionPanel = true
			parent.Panel.Visible = false
		end
		self.Frame.Parent = parent.Container
		if parent.Type == "Section" then
			self.Frame.LayoutOrder = parent:_row() and 1 or 7
		elseif parent._updateCanvas then
			parent:_updateCanvas()
		end
	end
	return self
end

--[=[
	Adds a subcontainer along this layout's axis. X layouts give nested columns matching heights; Y layouts keep each
	stack at its natural height. The new subcontainer defaults to its own Y-axis stack and can contain all primitives
	and further subcontainers.

	@param config Config? -- Optional axis and gap for this subcontainer.
	@return [Layout](Layout.md) -- The nested subcontainer.
]=]
function Layout:Subcontainer(config: any, ...: any): any
	config = Args.Config({"Axis", "Gap"}, nil, config, ...)
	assert(type(config) == "table", "Layout - Config must be a table")
	return Layout.New(config, self)
end

--[=[
	Destroys every widget and nested layout in this container, then removes its frame.
]=]
function Layout:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, item in table.clone(self._items) do
		item:Destroy()
	end
	local parent = self._parentContainer
	self.Frame:Destroy()
	if self == self._rootLayout then
		Resize.Register(self._window, self, nil)
	end
	if self._hidesSectionPanel then
		parent._layoutCount -= 1
		if parent._layoutCount == 0 then
			parent.Panel.Visible = parent._layoutPanelVisible
			parent._layoutCount = nil
			parent._layoutPanelVisible = nil
		end
	end
	if parent.Type ~= "Layout" then
		if parent._updateSection then
			parent:_updateSection()
		elseif parent._updateCanvas then
			parent:_updateCanvas()
		end
	end
end

return Layout
