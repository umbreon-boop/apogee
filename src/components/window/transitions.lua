--[=[
	The window transitions: maximize, minimize and close. They never clip the window and never grow it to scale 1.

	@class WindowTransitions
	@location internals/components
]=]
local Workspace = game:GetService("Workspace")

local Fade = require("../../services/fade")
local Motion = require("../../services/motion")
local State = require("../../public")
local Style = require("../../assets/themes")

local Transitions = {}
local camera = Workspace.CurrentCamera
local MAXIMIZE_DURATION = 0.2
local MINIMIZE_DURATION = 0.32
local CLOSE_DURATION = 0.2
-- Window transitions only fade or move the existing layout. They never scale or resize child controls mid-flight.
local SHIFT = Style.Space.XXS
-- every window transition starts fast and settles softly, like the springs of the original library
local TRANSITION_EASING = Enum.EasingStyle.Quint
local TRANSITION_DIRECTION = Enum.EasingDirection.Out

-- whether a window animation runs; input waits for it
function Transitions:_transitioning(): boolean
	return self._geometryTween ~= nil or self._effectTween ~= nil
end

-- a maximized window fills the screen, so it shows no shadow and no title bar divider
local function updateDecorations(window: any)
	window._shadow.Visible = not window.Maximized
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

-- Transitions never clip the window: a rectangular clip cuts the content with straight edges over the round corners.
local function playWindowTween(
		window: any,
		key: string,
		instance: Instance,
		properties: { [string]: any },
		duration: number,
		transitionId: number,
		completed: (() -> ())?
	)
	window[key] = true
	local tween = Motion.Tween(instance, properties, duration, TRANSITION_EASING, TRANSITION_DIRECTION, function(state)
		if window._transitionId ~= transitionId then
			return
		end
		window[key] = nil
		if state == Enum.PlaybackState.Completed and completed then
			completed()
		end
	end)
	if window[key] == true then
		window[key] = tween
	end
	return tween
end

-- Fades the window content together with its shadow. The shadow fades on its own, because it rests at its own
-- transparency, not at 0.
local function fade(window: any, visible: boolean, duration: number, completed: (() -> ())?)
	Fade.To(window.Root, visible, duration, completed, function(child)
		return child == window._shadow
	end)
	Motion.Tween(window._shadow, {ImageTransparency = if visible then window._shadowRest else 1}, duration, TRANSITION_EASING, TRANSITION_DIRECTION)
end

-- ends a fade at once, fully visible
local function unwrap(window: any)
	Fade.Settle(window.Root)
	window._shadow.ImageTransparency = window._shadowRest
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
	self.Maximized = value
	self.TitleBar:SetMaximized(value)
	updateDecorations(self)

	if value then
		self._restoreSize = Vector2.new(self.Size.X.Offset, self.Size.Y.Offset)
	end

	local width = if value then camera.ViewportSize.X else self._restoreSize.X
	local height = if value then camera.ViewportSize.Y else self._restoreSize.Y
	local size = UDim2.fromOffset(width, height)
	self.Size = size
	local goals = {Size = size}
	if not keepPosition then
		goals.Position = if value then UDim2.fromOffset(0, 0) else self.Position
	end

	local transitionId = Transitions._cancel(self)
	unwrap(self)
	if instant then
		self._rootScale.Scale = 1
		self:_place(Vector2.new(width, height), if goals.Position then Vector2.new(goals.Position.X.Offset, goals.Position.Y.Offset) else nil)
	else
		local position = goals.Position or self.Root.Position
		-- Swap geometry while fully faded out, then animate only the fade so child controls don't reflow mid-tween.
		Fade.Hide(self.Root, function(child)
			return child == self._shadow
		end)
		self._shadow.ImageTransparency = 1
		self.Root.Visible = true
		self._rootScale.Scale = 1
		self.Root.Size = size
		self.Root.Position = position
		self._geometryTween = true
		fade(self, true, MAXIMIZE_DURATION, function()
			if self._transitionId == transitionId then
				self._geometryTween = nil
			end
		end)
	end
end

--[=[
	Toggles the window's visibility. The first call shows a notification explaining how to bring it back.
]=]
function Transitions:Minimize()
	if self._destroyed or self._closing then
		return
	end
	self.Minimized = not self.Minimized
	local transitionId = Transitions._cancel(self)
	local hidden = not self.Root.Visible
	self.Root.Visible = true

	if self.Minimized then
		if self.Minimizer then
			self.Minimizer:_show(true, MINIMIZE_DURATION)
		end
		fade(self, false, MINIMIZE_DURATION, function()
			if self._transitionId == transitionId and self.Minimized and not self._destroyed then
				self.Root.Visible = false
			end
		end)
		playWindowTween(self, "_geometryTween", self.Root, {
			Position = self.Root.Position + UDim2.fromOffset(0, SHIFT)
		}, MINIMIZE_DURATION, transitionId)
	else
		if self.Minimizer then
			self.Minimizer:_show(false, MINIMIZE_DURATION)
		end
		local restored = if self.Maximized then UDim2.fromOffset(0, 0) else self.Position
		-- A fully minimized window fades and slides in at its own place without scaling its contents.
		if hidden then
			self.Root.Position = restored + UDim2.fromOffset(0, SHIFT)
		end
		fade(self, true, MINIMIZE_DURATION)
		playWindowTween(self, "_geometryTween", self.Root, {Position = restored}, MINIMIZE_DURATION, transitionId)
	end

	if self._notified then
		return
	end

	self._notified = true
	local content
	if self.Minimizer and self.Minimizer.Enabled then
		content = "Tap the floating button to bring the interface back."
	else
		content = "Use the Minimize Bind keybind to toggle the interface."
	end
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
	local transitionId = Transitions._cancel(self)
	-- the same motion as a dialog: the window fades and slides down a little
	fade(self, false, CLOSE_DURATION)
	playWindowTween(self, "_geometryTween", self.Root, {Position = self.Root.Position + UDim2.fromOffset(0, SHIFT)}, CLOSE_DURATION, transitionId, function()
		if self._destroyed then
			return
		end
		self.Root.Visible = false
		State:SafeCallback(self._closeCallback)
		self:Destroy()
		if #self._windows == 0 then
			State:Destroy()
		end
	end)
end

return Transitions
