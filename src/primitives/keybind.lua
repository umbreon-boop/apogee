--[=[
	A key or mouse button binding with Toggle, Hold and Always modes.

	@class Keybind
	@location internals/primitives
]=]
local UserInputService = game:GetService("UserInputService")
local Class = require("../services/class")
local Element = require("../components/element")
local Theme = require("../services/theme")
local State = require("../public")
local Style = require("../assets/themes")
local Squircle = require("../components/frame")
local Creator = require("../services/creator")
local Widget = require("./widget")

--[=[
	@prop Value string -- The bound key name, `MouseLeft` or `MouseRight`
	@prop Mode "Toggle" | "Hold" | "Always" -- How `GetState` resolves
	@prop Toggled boolean -- The toggled state, flipped on every press in Toggle mode
	@prop Pressed ((toggled: boolean) -> ())? -- Called with the toggled state on every press in Toggle mode
]=]
local Keybind = Class.Extend({Type = "Keybind"}, Widget)

-- Only one keybind may listen for its replacement key at a time.
local picking = nil

--[=[
	@interface KeybindConfig
	.Name string? -- Persistence key for this widget.
	.Title string -- Required row label.
	.Description string? -- Optional supporting label.
	.Persist boolean? -- Set false to omit the named entry from saved configurations.
	.Value string -- Initial key name; mouse buttons use `MouseLeft` and `MouseRight`.
	.Mode ("Toggle" | "Hold" | "Always")? -- Activation toggles, follows key state, or stays active.
	.Callback ((key: string) -> ())? -- Called when the binding changes, not when the key is pressed.
	.Pressed ((toggled: boolean) -> ())? -- In Toggle mode, called on each press with the resulting state.
	@within Keybind
]=]
export type Config = {
	Name: string?, Title: string, Description: string?, Persist: boolean?, Value: string,
	Mode: ("Toggle" | "Hold" | "Always")?, Callback: ((key: string) -> ())?,
	Pressed: ((toggled: boolean) -> ())?
}
local function mouseKey(input: InputObject): string?
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "MouseLeft"
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "MouseRight"
	end
	return nil
end
local function matches(input: InputObject, key: string): boolean
	if key == "MouseLeft" or key == "MouseRight" then
		return mouseKey(input) == key
	end
	return input.KeyCode.Name == key
end

--[=[
	Creates a new keybind. Use `Container:Keybind` instead of calling this directly.

	@param config Config -- Initial key and activation mode, with optional press and change handlers.
	@param parent Container -- The container to draw the keybind in
	@return [Keybind](Keybind.md) -- The keybind widget added to the parent container.
]=]
function Keybind.New(config: Config, parent: any): any
	assert(config.Title, "Keybind - Missing Title")
	assert(config.Value, "Keybind - Missing Value")

	local self = Class.New(Keybind, {
		Toggled = false,
		_picking = false,
		_pickToken = nil,
		_pickConnections = nil
	})
	local element = Element.New(config.Title, config.Description, parent.Container, false, parent._window)
	element.LabelHolder.Size = UDim2.new(0.50, -14, 0, 0)

	local label = Creator:New("TextLabel", {
		FontFace = Font.new(Style.Font, Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Text = config.Value,
		TextSize = Style.Type.Body,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Themed = {TextColor3 = "Text"}
	})
	local display = Creator:New("TextButton", {
		Size = UDim2.fromScale(0.40, 0),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 1,
		Parent = element.Frame
	}, {
		Squircle.New(Style.Squircle.Control, {
			ImageTransparency = 0,
			Themed = {ImageColor3 = "Field"}
		}),
		Squircle.New(Style.Squircle.Control, {
			Shape = "Outline",
			Visible = false,
			Themed = {ImageColor3 = "ControlBorder"}
		}),
		label
	})
	Theme:Height(display, "Control")
	self._label = label

	self:_bind(element)
	element.Frame.Destroying:Connect(function()
		self:_cancelPick()
	end)
	Class.Define(self, {
		Value = Keybind._apply,
		Mode = function() end,
		Pressed = function() end
	})
	self._storage.Value = config.Value
	self:From({
		Title = config.Title,
		Description = config.Description,
		Callback = config.Callback,
		Pressed = config.Pressed,
		Mode = config.Mode or "Toggle"
	})

	local SWIPE_THRESHOLD = 10
	local activeTouch: InputObject? = nil
	local touchStart: Vector2? = nil
	local touchMoved = false

	display.InputBegan:Connect(function(input)
		local pressed = input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		if not pressed then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			if input.UserInputState ~= nil and input.UserInputState ~= Enum.UserInputState.Begin then
				return
			end
			activeTouch = input
			touchStart = Vector2.new(input.Position.X, input.Position.Y)
			touchMoved = false
		else
			self:_pick()
		end
	end)

	State.Connect(UserInputService.InputChanged, function(input)
		if activeTouch and input == activeTouch and touchStart then
			local delta = Vector2.new(input.Position.X, input.Position.Y) - touchStart
			if delta.Magnitude > SWIPE_THRESHOLD then
				touchMoved = true
			end
		end
	end, element.Frame)

	State.Connect(UserInputService.InputEnded, function(input)
		if activeTouch and input == activeTouch then
			if not touchMoved then
				self:_pick()
			end
			activeTouch = nil
			touchStart = nil
		end
	end, element.Frame)

	State.Connect(UserInputService.InputBegan, function(input)
		if picking or UserInputService:GetFocusedTextBox() or self.Mode ~= "Toggle" then
			return
		end

		local isMouse = self.Value == "MouseLeft" or self.Value == "MouseRight"
		if (isMouse or input.UserInputType == Enum.UserInputType.Keyboard) and matches(input, self.Value) then
			rawset(self, "Toggled", not self.Toggled)
			State:SafeCallback(self.Pressed, self.Toggled)
		end
	end, element.Frame)

	return self
end

function Keybind:_cancelPick()
	local connections = self._pickConnections
	self._pickConnections = nil
	for _, connection in connections or {} do
		connection:Disconnect()
	end
	self._pickToken = nil
	if picking == self then
		picking = nil
	end
	if self._picking then
		self._picking = false
		self._label.Text = self.Value
	end
end

function Keybind:_pick()
	if self._picking then
		return
	end
	if picking and picking ~= self then
		picking:_cancelPick()
	end
	picking = self
	self._picking = true
	local token = {}
	self._pickToken = token
	self._label.Text = "..."
	task.wait(0.2)

	-- another keybind may have started picking, or this widget was destroyed
	if self._pickToken ~= token then
		self:_cancelPick()
		return
	end

	-- the bind takes the last pressed key when that key is released, so held modifiers do not replace it
	local key: string? = nil
	local owner = self._element.Frame
	local began = State.Connect(UserInputService.InputBegan, function(input)
		local nextKey
		nextKey = input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode.Name or mouseKey(input)
		if nextKey then
			key = nextKey
		end
	end, owner)
	local ended = State.Connect(UserInputService.InputEnded, function(release)
		if not key or not matches(release, key) then
			return
		end
		local chosen = key
		self:_cancelPick()
		self:SetValue(chosen)
	end, owner)
	self._pickConnections = {began, ended}
end

--[=[
	Returns whether the bind is active: always true in Always mode, whether the key is held in Hold mode and the
	toggled state in Toggle mode. Returns false while a text box is focused unless the mode is Always.

	@return boolean -- Whether the bound key is active under the current mode.
]=]
function Keybind:GetState(): boolean
	if UserInputService:GetFocusedTextBox() and self.Mode ~= "Always" then
		return false
	end

	if self.Mode == "Always" then
		return true
	elseif self.Mode == "Hold" then
		local key = self.Value
		if key == "None" then
			return false
		elseif key == "MouseLeft" then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		elseif key == "MouseRight" then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
		end
		local ok, keyCode = pcall(function()
			return Enum.KeyCode[key]
		end)
		return ok and keyCode ~= nil and UserInputService:IsKeyDown(keyCode)
	end
	return self.Toggled
end

function Keybind:_apply(key: string)
	self._label.Text = key
	self:_fire(key)
end

--[=[
	Changes the bound key and mode and fires the callbacks.

	@param key string? -- The new key name, unchanged when nil
	@param mode ("Toggle" | "Hold" | "Always")? -- The new mode, unchanged when nil
]=]
function Keybind:SetValue(key: string?, mode: string?)
	self.Mode = mode or self.Mode
	Widget.SetValue(self, key or self.Value)
end

function Keybind:_save(): any
	return {self.Value, self.Mode}
end

function Keybind:_load(data: { any })
	self:SetValue(data[1], data[2])
end

return Keybind
