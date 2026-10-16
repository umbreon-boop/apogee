--[=[
	Pointer input of a window: moving, edge resizing and the sidebar splitter. Only one drag runs at a time across
	the interface, and no drag starts during a window animation or under an overlay.

	@class WindowInput
	@location internals/components
]=]
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Drag = require("../../services/drag")
local Pointer = require("../../services/pointer")
local State = require("../../public")
local Measure = require("../../services/measure")

local WindowInput = {}
local camera = Workspace.CurrentCamera
local isPress = Pointer.IsPress

-- starts moving the window with a press on the title bar
local function beginDrag(self: any, input: InputObject)
	if not isPress(input) or self._drag or Drag._active or self:_transitioning() or State:HasOverlay() then
		return
	end

	Drag._active = self
	local start = self.Root.Position
	if self.Maximized then
		local rootWidth = math.max(self.Root.AbsoluteSize.X, 1)
		local localRatioX = math.clamp((input.Position.X - self.Root.AbsolutePosition.X) / rootWidth, 0, 1)
		local offsetX = math.round(input.Position.X - localRatioX * self._restoreSize.X)
		local offsetY = self.Root.Position.Y.Offset
		start = UDim2.fromOffset(offsetX, offsetY)
	end
	self._drag = {input = input, origin = input.Position, start = start}
end

--[=[
	Connects the pointer input of a window: moving it by the title bar, resizing it by its edges and resizing the
	sidebar with the splitter. A move of a maximized window restores it under the pointer.

	@param self Window -- The window
	@param fit (size: Vector2) -> Vector2 -- Fits a size to the screen
]=]
function WindowInput.Connect(self: any, fit: (Vector2) -> Vector2)
	local resizing = false
	local resizeEdge = {X = 0, Y = 0}
	local resizeOrigin = Vector2.zero
	local resizeStartSize = Vector2.zero
	local resizeStartPos = Vector2.zero
	local activeResizeInput: InputObject? = nil
	local splitterDragging = false
	local splitterOriginX = 0
	local splitterStartWidth = 0
	local activeSplitterInput: InputObject? = nil

	self._cancelActiveInput = function()
		self._drag = nil
		resizing = false
		activeResizeInput = nil
		splitterDragging = false
		activeSplitterInput = nil
		if Drag._active == self then
			Drag._active = nil
		end
	end
	local EDGE_THRESHOLD = 14
	local DRAG_SLIP_THRESHOLD = 4

	local function getEdge(pos: Vector2): {X: number, Y: number}?
		local rootPos = self.Root.AbsolutePosition
		local rootSize = self.Root.AbsoluteSize
		local relX = pos.X - rootPos.X
		local relY = pos.Y - rootPos.Y

		if relX < 0 or relX > rootSize.X or relY < 0 or relY > rootSize.Y then
			return nil
		end

		local edgeX = 0
		local edgeY = 0

		if relX <= EDGE_THRESHOLD then
			edgeX = -1
		elseif relX >= rootSize.X - EDGE_THRESHOLD then
			edgeX = 1
		end

		if relY <= EDGE_THRESHOLD then
			edgeY = -1
		elseif relY >= rootSize.Y - EDGE_THRESHOLD then
			edgeY = 1
		end

		if edgeX ~= 0 or edgeY ~= 0 then
			return {X = edgeX, Y = edgeY}
		end
		return nil
	end

	local function tryStartResize(input: InputObject): boolean
		if not isPress(input) or self.Maximized or Drag._active or resizing or splitterDragging or self:_transitioning() or State:HasOverlay() then
			return false
		end
		if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
			return false
		end

		local edge = getEdge(Vector2.new(input.Position.X, input.Position.Y))
		if edge then
			resizing = true
			resizeEdge = edge
			activeResizeInput = input
			resizeOrigin = Vector2.new(input.Position.X, input.Position.Y)
			resizeStartSize = Vector2.new(self.Size.X.Offset, self.Size.Y.Offset)
			resizeStartPos = Vector2.new(self.Position.X.Offset, self.Position.Y.Offset)
			Drag._active = self
			return true
		end
		return false
	end

	self.Root.InputBegan:Connect(function(input)
		tryStartResize(input)
	end)

	if self._tabFrame then
		self._tabFrame.InputBegan:Connect(function(input)
			tryStartResize(input)
		end)
	end

	if self.Splitter then
		self.Splitter.InputBegan:Connect(function(input)
			if not isPress(input) or Drag._active or resizing or splitterDragging or self:_transitioning() or State:HasOverlay() then
				return
			end
			if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
				return
			end
			splitterDragging = true
			activeSplitterInput = input
			splitterOriginX = input.Position.X
			splitterStartWidth = self.TabWidth
			Drag._active = self
		end)
	end

	self.TitleBar.Frame.InputBegan:Connect(function(input)
		if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
			return
		end
		if not resizing and not splitterDragging then
			beginDrag(self, input)
		end
	end)

	State.Connect(UserInputService.InputChanged, function(input)
		local drag = self._drag
		local followsDrag = drag
		and (if drag.input.UserInputType == Enum.UserInputType.Touch
				then input == drag.input
			else input.UserInputType == Enum.UserInputType.MouseMovement)
		if followsDrag then
			local delta = input.Position - drag.origin
			if delta.Magnitude > DRAG_SLIP_THRESHOLD or drag.input.UserInputType ~= Enum.UserInputType.Touch then
				if self.Maximized then
					local activeDrag = self._drag
					self:Maximize(false, true, true)
					self._drag = activeDrag
					Drag._active = self
				end

				self.Position = UDim2.fromOffset(drag.start.X.Offset + delta.X, drag.start.Y.Offset + delta.Y)
				self:_place(nil, Vector2.new(self.Position.X.Offset, self.Position.Y.Offset))
			end
		end

		local followsSplitter = splitterDragging and activeSplitterInput
		and (if activeSplitterInput.UserInputType == Enum.UserInputType.Touch
				then input == activeSplitterInput
			else (input.UserInputType == Enum.UserInputType.MouseMovement or input == activeSplitterInput))
		if followsSplitter then
			local deltaX = input.Position.X - splitterOriginX
			self:SetTabWidth(splitterStartWidth + deltaX)
		end

		local followsResize = resizing and activeResizeInput
		and (if activeResizeInput.UserInputType == Enum.UserInputType.Touch
				then input == activeResizeInput
			else input.UserInputType == Enum.UserInputType.MouseMovement)
		if followsResize then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeOrigin
			local newW = resizeStartSize.X + (delta.X * resizeEdge.X)
			local newH = resizeStartSize.Y + (delta.Y * resizeEdge.Y)
			local clamped = fit(Vector2.new(newW, newH))

			local newX = resizeStartPos.X
			local newY = resizeStartPos.Y
			if resizeEdge.X == -1 then
				newX = resizeStartPos.X - (clamped.X - resizeStartSize.X)
			end
			if resizeEdge.Y == -1 then
				newY = resizeStartPos.Y - (clamped.Y - resizeStartSize.Y)
			end

			self:_place(clamped, Vector2.new(newX, newY))
		end
	end, self.Root)

	State.Connect(UserInputService.InputEnded, function(input)
		local drag = self._drag
		local released = drag
		and (if drag.input.UserInputType == Enum.UserInputType.Touch
				then input == drag.input
			else input.UserInputType == Enum.UserInputType.MouseButton1)
		if released then
			self._drag = nil
			if Drag._active == self and not resizing and not splitterDragging then
				Drag._active = nil
			end
		end

		local releasedSplitter = splitterDragging and activeSplitterInput
		and (if activeSplitterInput.UserInputType == Enum.UserInputType.Touch
				then input == activeSplitterInput
			else input.UserInputType == Enum.UserInputType.MouseButton1)
		if releasedSplitter then
			splitterDragging = false
			activeSplitterInput = nil
			if Drag._active == self and not self._drag and not resizing then
				Drag._active = nil
			end
		end

		local releasedResize = resizing and activeResizeInput
		and (if activeResizeInput.UserInputType == Enum.UserInputType.Touch
				then input == activeResizeInput
			else input.UserInputType == Enum.UserInputType.MouseButton1)
		if releasedResize then
			resizing = false
			activeResizeInput = nil
			if Drag._active == self and not self._drag and not splitterDragging then
				Drag._active = nil
			end
			self.Size = self.Root.Size
			self.Position = self.Root.Position
			self._preferred = Vector2.new(self.Size.X.Offset, self.Size.Y.Offset)
		end
	end, self.Root)

	State.Connect(camera:GetPropertyChangedSignal("ViewportSize"), function()
			self:_fitScreen()
		end, self.Root)

	self._tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		self.TabHolder.CanvasSize = UDim2.fromOffset(0, Measure.Offset(self.TabHolder, self._tabLayout.AbsoluteContentSize.Y))
	end)
end

return WindowInput
