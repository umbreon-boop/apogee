--[=[
	Single entry point for creating UI instances. It applies the library defaults and the given properties, binds the
	theme keys through Theme and then passes the instance through the registered hooks.
	@class Creator
	@location internals/services
]=]
local Theme = require("./theme")

local Creator = {_hooks = {}}

-- library defaults per class, `Themed` maps properties to theme keys
local DEFAULTS = {
	ScreenGui = {ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling},
	-- a canvas group only fades its children; Roblox draws its own background opaque by default
	CanvasGroup = {BackgroundTransparency = 1, BorderSizePixel = 0},
	Frame = {BorderSizePixel = 0, Themed = {BackgroundColor3 = "Surface", BorderColor3 = "Border"}},
	ScrollingFrame = {Themed = {BackgroundColor3 = "Surface", BorderColor3 = "Border", ScrollBarImageColor3 = "SubText"}},
	TextLabel = {
		Text = "",
		BackgroundTransparency = 1,
		TextSize = 14,
		Themed = {BackgroundColor3 = "Surface", BorderColor3 = "Border", TextColor3 = "Text"}
	},
	TextButton = {
		AutoButtonColor = false,
		Text = "",
		TextSize = 14,
		Themed = {BackgroundColor3 = "Control", BorderColor3 = "Border", TextColor3 = "Text"}
	},
	TextBox = {
		ClearTextOnFocus = false,
		Text = "",
		TextSize = 14,
		Themed = {BackgroundColor3 = "Field", BorderColor3 = "Border", TextColor3 = "Text"}
	},
	ImageLabel = {BackgroundTransparency = 1, BorderSizePixel = 0, Themed = {BackgroundColor3 = "Surface", BorderColor3 = "Border"}},
	ImageButton = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Themed = {BackgroundColor3 = "Control", BorderColor3 = "Border"}
	}
}

--[=[
	Creates and themes an instance, parents its children, then runs creation hooks. `Themed` maps properties
	to theme keys; explicitly set properties replace the default binding. `Parent` is applied last.

	@param class string -- Roblox class name
	@param props { [string]: any }? -- Instance properties
	@param children { Instance }? -- Child instances
	@return Instance -- The configured instance, parented after its properties and children are applied.
]=]
function Creator:New(class: string, props: { [string]: any }?, children: { Instance }?): any
	local settings = props or {}
	local defaults = DEFAULTS[class] or {}
	local instance = Instance.new(class)
	if instance:IsA("GuiBase2d") then
		instance.AutoLocalize = false
	end

	local bindings = table.clone(defaults.Themed or {})
	for property, value in defaults do
		if property ~= "Themed" then
			instance[property] = value
		end
	end
	for property, value in settings do
		if property ~= "Themed" and property ~= "Parent" then
			instance[property] = value
			bindings[property] = nil
		end
	end
	for property, key in settings.Themed or {} do
		bindings[property] = key
	end
	for _, child in children or {} do
		child.Parent = instance
	end

	Theme:Bind(instance, bindings)
	for _, hook in table.clone(self._hooks) do
		hook(instance, class, settings, children or {})
	end
	if settings.Parent then
		instance.Parent = settings.Parent
	end
	return instance
end

--[=[
	Registers a callback run after each instance is created and themed, before it is parented.
	@param hook (instance: Instance, class: string, props: { [string]: any }, children: { Instance }) -> ()
	@return () -> () -- Unregister function
]=]
function Creator:Register(hook: (Instance, string, { [string]: any }, { Instance }) -> ()): () -> ()
	assert(type(hook) == "function", "Creator:Register expects a function")
	table.insert(self._hooks, hook)
	local registered = true
	return function()
		if not registered then
			return
		end
		registered = false
		local index = table.find(self._hooks, hook)
		if index then
			table.remove(self._hooks, index)
		end
	end
end

return Creator
