--[=[
	The window transitions: maximize, minimize and close. Every one is the same fade, so a window never slides or
	scales between states.

	@class WindowTransitions
	@location internals/components
]=]
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local Fade = require("../../services/fade")
local State = require("../../public")
local Style = require("../../assets/themes")

local Transitions = {}
local camera = Workspace.CurrentCamera
-- A maximized window keeps the same floating margin as a normal window, so its rounded corners never sit on the
-- screen edge where the game/background shows through them as square notches.
local MARGIN = Style.Space.S
-- maximizing changes the window geometry while it is invisible; a short fade keeps the resize quick
local RESIZE = 0.12
local REVEAL = TweenInfo.new(RESIZE, Fade.Easing, Fade.Direction, 0, false, Fade.Gap / 2)

-- whether a window animation runs; input waits for it
function Transitions:_transitioning(): boolean
	return self._geometryTween ~= nil or self._effectTween ~= nil
end

--[=[
	Returns the size and position of a maximized window. A ScreenGui that ignores the GUI inset starts at the top of
	the screen, under the Roblox topbar, so the maximized window is offset by the inset instead of putting its rounded
	top corners underneath the topbar.

	@param window any -- The window
	@return Vector2, Vector2 -- The drawable size and the offset inside the screen GUI.
]=]
function Transitions.Frame(window: any): (Vector2, Vector2)
	local gui = window._gui
	local topLeft, bottomRight = GuiService:GetGuiInset()
	local viewport = camera.ViewportSize - topLeft - bottomRight
	local area = gui and (gui :: any).AbsoluteSize
	local drawable = viewport
	if area and area.X > 0 and area.Y > 0 then
		-- never grow past the drawable viewport, even if the screen GUI reports a larger size on a mobile client
		drawable = Vector2.new(math.min(area.X, viewport.X), math.min(area.Y, viewport.Y))
	end
	local size = Vector2.new(math.max(0, drawable.X - 2 * MARGIN), math.max(0, drawable.Y - 2 * MARGIN))
	local position = Vector2.new(MARGIN, MARGIN)
	if gui and gui:IsA("ScreenGui") and gui.IgnoreGuiInset then
		position += topLeft
	end
	return size, position
end

-- a maximized window hides the title bar divider; the surface keeps its rounded corners in every state
--@inline
local function updateDecorations(window: any)
	local divider = window.TitleBar and window.TitleBar.Frame:FindFirstChild("Divider")
	if divider then
		divider.Visible = not window.Maximized
	end
end

function Transitions._cancel(window: any): number
	window._transitionId += 1
	if window._cancelActiveInput then
		window._cancelActiveInput()
	end
	for _, key in {"_geometryTween", "_effectTween"} do
		local tween = window[key]
		window[key] = nil
		if tween and tween ~= true then
			tween:Cancel()
		end
	end
	return window._transitionId
end

-- Ends any running fade and restores the exact transparency of the window.
--@inline
local function unwrap(window: any)
	Fade.Settle(window.Root)
end

--[=[
	Maximizes the window to the viewport or restores it to its previous size.

	@param value boolean -- True to maximize, false to restore
	@param keepPosition boolean? -- Leave the window position untouched
	@param instant boolean? -- Skip the animation
]=]
function Transitions:Maximize(value: boolean, keepPosition: boolean?, instant: boolean?)
	if self._destroyed or self._closing or (value == self.Maximized and not instant) then
		return
	end
	State:CloseDropdowns(self, true)
	self.Maximized = value

	if value then
		self._restoreSize = Vector2.new(self.Size.X.Offset, self.Size.Y.Offset)
	end

	local width, height = self._restoreSize.X, self._restoreSize.Y
	local maxPosition = Vector2.zero
	if value then
		local maxSize, position = Transitions.Frame(self)
		width, height = maxSize.X, maxSize.Y
		maxPosition = position
	end
	local size = UDim2.fromOffset(width, height)
	self.Size = size
	local goals = {Size = size}
	if not keepPosition then
		goals.Position = self.Position
		if value then goals.Position = UDim2.fromOffset(maxPosition.X, maxPosition.Y) end
	end

	local transitionId = Transitions._cancel(self)
	self.Root.Visible = true
	unwrap(self)

	--@inline
	local function apply()
		if self._transitionId == transitionId then
			self._rootScale.Scale = 1
			local position
			if goals.Position then
				position = Vector2.new(goals.Position.X.Offset, goals.Position.Y.Offset)
			end
			self:_place(Vector2.new(width, height), position)
			self.TitleBar:SetMaximized(self.Maximized)
			updateDecorations(self)
		end
	end

	if instant then
		apply()
		return
	end
	self._geometryTween = true
	-- Swap the geometry while fully faded out, so the old layout never stretches over the new size.
	Fade.To(self.Root, false, RESIZE, function()
		if self._transitionId ~= transitionId then
			return
		end
		apply()
		Fade.To(self.Root, true, REVEAL, function()
			if self._transitionId ~= transitionId then
				return
			end
			self._geometryTween = nil
		end)
	end)
end

--[=[
	Toggles the window's visibility. The first call shows a notification explaining how to bring it back.
]=]
function Transitions:Minimize()
	if self._destroyed or self._closing then
		return
	end
	State:CloseDropdowns(self, true)
	self.Minimized = not self.Minimized
	local transitionId = Transitions._cancel(self)
	self.Root.Visible = true
	self._effectTween = true

	if self.Minimized then
		if self.Minimizer then
			self.Minimizer:_show(true, Fade.Duration)
		end
		Fade.To(self.Root, false, Fade.Duration, function()
			if self._transitionId ~= transitionId or not self.Minimized or self._destroyed then
				return
			end
			self.Root.Visible = false
			self._effectTween = nil
		end)
	else
		if self.Minimizer then
			self.Minimizer:_show(false, Fade.Duration)
		end
		local restored = self.Position
		if self.Maximized then
			local _, maxPosition = Transitions.Frame(self)
			restored = UDim2.fromOffset(maxPosition.X, maxPosition.Y)
		end
		self.Root.Position = restored
		Fade.To(self.Root, true, Fade.Duration, function()
			if self._transitionId == transitionId then
				self._effectTween = nil
			end
		end)
	end

	if self._notified then
		return
	end

	self._notified = true
	local content
	content = self.Minimizer and self.Minimizer.Enabled
	and "Tap the floating button to bring the interface back."
	or "Use the Minimize Bind keybind to toggle the interface."
	State:Notify({Title = "Interface", Content = content, Duration = 6, _window = self})
end

--[=[
	Plays the close animation, calls `CloseCallback` and destroys the window. Closing the last window unloads the
	interface.
]=]
function Transitions:Close()
	if self._closing or self._destroyed then
		return
	end
	self._closing = true
	State:CloseDropdowns(self, true)
	local transitionId = Transitions._cancel(self)
	self._effectTween = true
	Fade.To(self.Root, false, Fade.Duration, function()
		if self._destroyed or self._transitionId ~= transitionId then
			return
		end
		self._effectTween = nil
		self.Root.Visible = false
		State:SafeCallback(self._closeCallback)
		self:Destroy()
		if #self._windows == 0 then
			State:Destroy()
		end
	end)
end

return Transitions
