--[=[
	Shared behavior for value widgets, including reactive labels and callbacks.
	Creation does not fire callbacks; `SetValue` always does, while assigning `Value` fires on change.
	`OnChanged` reports the current value immediately.

	@class Widget
	@location internals/primitives
]=]
local Class = require("../services/class")
local Config = require("../services/config")
local State = require("../public")

--[=[
	@prop Title string -- Reactive label displayed on the widget's row.
	@prop Description string? -- Reactive secondary label; an empty or nil value hides it.
	@prop Callback ((value: any) -> ())? -- Protected callback for value changes; callback arguments are widget-specific.
]=]
local Widget = Class.Extend({})

--[=[
	Wires the shared reactive properties to an element card. Called by subclasses during construction.

	@param element Element -- The widget's card
	@private
]=]
function Widget:_bind(element: any)
	self._element = element
	self._window = element._window
	if self._window then
		self._window._widgets = self._window._widgets or {}
		table.insert(self._window._widgets, self)
	end
	rawset(self, "Frame", element.Frame)
	Class.Define(self, {
		Title = function(_, value: string)
			element:SetTitle(value)
		end,
		Description = function(_, value: string?)
			element:SetDesc(value)
		end,
		Callback = function() end
	})
end

--[=[
	Fires the widget's `Callback` and `OnChanged` handler inside protected calls.

	@param ... any -- The arguments to pass
	@private
]=]
function Widget:_fire(...: any)
	State:SafeCallback(self.Callback, ...)
	State:SafeCallback(rawget(self, "_changed"), ...)
end

--[=[
	Changes the title through the same reactive property path as assigning `Title`.

	@param value string -- The new title
]=]
function Widget:SetTitle(value: string)
	self.Title = value
end

--[=[
	Changes the secondary label through the same reactive property path as assigning `Description`.

	@param value string? -- The new description
]=]
function Widget:SetDesc(value: string?)
	self.Description = value
end

--[=[
	Applies a value through the widget's validator and always fires its callbacks, even
	when the resulting value equals the current value. Widget subclasses define coercion
	and callback argument shape.

	@param value any -- The new value
]=]
function Widget:SetValue(value: any)
	self._storage.Value = value
	-- Value-less widgets have no value handlers.
	for _, handler in self._callbacks.Value or {} do
		handler(value)
	end
end

--[=[
	Returns the state a config stores for this widget, nil when there is nothing to store.

	@return any -- The persisted value for this widget, or nil when the widget has no value to save.
	@private
]=]
function Widget:_save(): any
	return self.Value
end

--[=[
	Restores the state returned by `_save`.

	@param data any -- The stored state
	@private
]=]
function Widget:_load(data: any)
	self:SetValue(data)
end

--[=[
	Replaces the widget's `OnChanged` handler, invokes it immediately with the current
	value, then invokes it after subsequent changes. For a color picker the handler also
	receives transparency; other value widgets pass one value.

	@param handler (value: any) -> () -- The handler
]=]
function Widget:OnChanged(handler: (value: any) -> ())
	self._changed = handler
	State:SafeCallback(handler, self.Value)
end

--[=[
	Destroys the widget's row and removes its name from the persistence registry. Later
	property assignments do not recreate the widget.
]=]
function Widget:Destroy()
	self._element:Destroy()
	local window = rawget(self, "_window")
	if window then
		if window._openFrames then
			window._openFrames[self] = nil
		end
		for _, list in {window._widgets, window._dropdowns} do
			local index = list and table.find(list, self)
			if index then
				table.remove(list, index)
			end
		end
	end
	if rawget(self, "_name") and Config.Widgets[self._name] == self then
		Config.Widgets[self._name] = nil
	end
end

return Widget
