--[=[
	Roblox UI library with a libcosmic inspired theme, reactive widgets, and public internals.
	Methods accept config tables or positional shorthand. See [Window](internals/components/Window.md),
	[Popup](internals/components/Popup.md), and the widget config interfaces in the primitive pages.

	@class Apogee
	@prop Version string -- Installed library version.
	@prop Theme string -- Active theme; synchronized with changes made through ThemeService.
	@prop Themes { string } -- Registered theme names, including built-in palettes.
	@prop Widgets { [string]: Widget } -- Persistable widgets keyed by `Name`; widgets with `Persist = false` are excluded from saved state.
	@prop Current Window? -- Most recently created live window. Used as the default owner for notifications.
	@prop Windows { Window } -- Live windows in creation order; closing the last one unloads the interface.
	@prop GUI ScreenGui -- Root screen GUI containing the interface.
	@prop Unloaded boolean -- True after `Destroy`; the interface is no longer usable.
	@prop Config Config -- Persistence service for named widget values.
	@prop Creator Creator -- Instance factory; hooks can observe or customize each created Roblox instance.
	@prop ThemeService Theme -- Theme palettes, bindings, component styles, and role sizes.
	@prop Localization Localization -- Active locale and text translation dictionaries.
	@prop internals table -- Exposed implementation modules grouped by assets, components, primitives, services, and aria.
]=]
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Maid = require("@aria/maid")
local Args = require("./services/args")
local Public = {
	Maid = Maid.new(),
	Containers = {}
}
--@inline
local function hostShown(host: any): boolean
	local root = host.Root
	local hidden = (root and root.Visible == false) or (host.Type == "Window" and host.Minimized)
	local shown = true
	if hidden then
		shown = false
	elseif host.Type == "Popup" then
		shown = host.Visible == true
	end
	return shown
end

function Public:HasOverlay(targetHost: any?): boolean
	local activePopup = nil
	for _, host in self.Containers do
		local shown = hostShown(host)
		if host.Type == "Popup" and shown then
			activePopup = host
		end
	end
	if activePopup and activePopup ~= targetHost then
		return true
	end
	for _, host in self.Containers do
		if not hostShown(host) then
			continue
		end
		if next(host._dialogs or {}) then
			return true
		end
		for _, frame in host._openFrames or {} do
			if frame and frame.Visible then
				return true
			end
		end
	end
	return false
end

function Public:ResetHighlights()
	for _, host in self.Containers do
		for _, element in host._elements or {} do
			if element and element.ResetHighlight then
				element:ResetHighlight()
			end
		end
	end
end

function Public:RegisterHost(host: any)
	if not table.find(self.Containers, host) then
		table.insert(self.Containers, host)
	end
end

function Public:UnregisterHost(host: any)
	local index = table.find(self.Containers, host)
	if index then
		table.remove(self.Containers, index)
	end
end

--[=[
	Connects a long-lived signal handler and disconnects it with `owner`, or when the interface unloads.

	@param signal RBXScriptSignal -- The signal
	@param handler (...any) -> () -- The handler
	@param owner Instance? -- The instance whose destruction ends the connection
	@return RBXScriptConnection -- The connection that is disconnected when the owning instance is destroyed, or when no owner was supplied.
	@private
]=]
--[=[
	Links a child (a window, popup or notification) to its parent, so transparency changes of the parent reach it.

	@param parent any -- The parent host
	@param child any -- The child
	@private
]=]
function Public:Adopt(parent: any, child: any)
	parent._children = parent._children or {}
	table.insert(parent._children, child)
	child._parent = parent
end

--[=[
	Removes a destroyed child from its parent. Each `Destroy` calls this, so parents never keep destroyed children.

	@param child any -- The child
	@private
]=]
function Public:Orphan(child: any)
	local parent = rawget(child, "_parent")
	local children = parent and parent._children
	local index = children and table.find(children, child)
	if index then
		table.remove(children, index)
	end
end

--[=[
	Destroys the popups of a host. A popup cannot outlive its host, because it would keep blocking input as an overlay.

	@param host any -- The window or popup
	@private
]=]
function Public:DestroyPopups(host: any)
	for _, child in table.clone(host._children or {}) do
		if child.Type == "Popup" then
			pcall(child.Destroy, child)
		end
	end
end

-- Closes floating dropdowns of a host, so they cannot outlive or float over a hidden window.
function Public:CloseDropdowns(host: any, instant: boolean?)
	for _, dropdown in table.clone(host._dropdowns or {}) do
		pcall(dropdown.Close, dropdown, instant)
	end
end

-- Destroys floating dropdowns before their host disappears, including their input barriers.
function Public:DestroyDropdowns(host: any)
	for _, dropdown in table.clone(host._dropdowns or {}) do
		pcall(dropdown.Destroy, dropdown)
	end
end

function Public.Connect(signal: RBXScriptSignal, handler: (...any) -> (), owner: Instance?): RBXScriptConnection
	local connection = signal:Connect(handler)
	if owner then
		owner.Destroying:Connect(function()
			connection:Disconnect()
		end)
	else
		Public.Maid:Task(connection)
	end
	return connection
end

local Apogee = Public
local Config, Icons, Notification, Theme, Creator, Popup, Window
local Localization

--[=[
	    Calls an optional user callback without allowing its error to interrupt interface logic.
	    On failure, shows a five second error notification and returns no values; on success,
	    returns every value produced by the callback.

		@param handler ((...any) -> ...any)? -- The function to call
		@param ... any -- The arguments to pass
		@return ...any -- The function's results when it succeeds
]=]
function Apogee:SafeCallback(handler: ((...any) -> ...any)?, ...: any): ...any
	if not handler then
		return
	end

	local results = table.pack(pcall(handler, ...))
	if results[1] then
		return table.unpack(results, 2, results.n)
	end

	local message = tostring(results[2])
	local _, index = string.find(message, ":%d+: ")
	local content = message
	if index then
		content = string.sub(message, index + 1)
	end
	self:Notify({
		Title = "Interface",
		Content = "Callback error",
		SubContent = content,
		Duration = 5
	})
end

--[=[
	Rounds to the nearest decimal place. Negative factors round to tens, hundreds, and
	larger places; the result is normalized through decimal formatting to remove binary
	floating point residue.

	@param number number -- The number to round
	@param factor number -- The decimals to keep
	@return number -- The value rounded to the requested number of decimal places.
]=]
function Apogee:Round(number: number, factor: number): number
	if factor < 0 then
		local step = 10 ^ -factor
		return math.round(number / step) * step
	end
	local scale = 10 ^ factor
	-- Formatting removes binary floating point residue.
	return tonumber(string.format("%." .. factor .. "f", math.round(number * scale) / scale)) :: number
end

--[=[
	Resolves an icon name from the bundled or a registered icon pack. Returns nil when it cannot be resolved.

	@param name string? -- Icon name; nil returns no asset
	@return string? -- Resolved local image identifier, or nil when unavailable.
]=]
function Apogee:GetIcon(name: string?): string?
	return Icons.GetIcon(name)
end

--[=[
	Creates and displays a window. Multiple windows may coexist. The default size and position
	fit the viewport; a `Theme` option changes the active theme before creation.

	@param config Window.Config | string -- Window settings or a title
	@param ... any -- Subtitle and optional settings in shorthand form.
	@return [Window](internals/components/Window.md) -- The newly created window.
]=]
function Apogee:Window(config: any, ...: any): any
	config = Args.Config({"Title", "SubTitle"}, nil, config, ...)
	assert(config.Title, "Window - Missing Title")

	if config.Theme then
		self:SetTheme(config.Theme)
	end

	return Window.New(config, self.GUI)
end

--[=[
	Changes the active palette and restyles existing themed instances. Unknown names leave
	the current theme unchanged. Assigning `ThemeService` directly also updates `Theme`.

	@param name string -- One of `Apogee.Themes`
]=]
function Apogee:SetTheme(name: string)
	if Theme:Set(name) then
		self.Theme = name
	end
end

--[=[
	Registers or replaces a named palette. Missing color roles inherit the default palette;
	optional component styles and size overrides customize appearance and geometry.

	@param name string -- The theme name
	@param palette { [string]: any } -- The palette color definitions
]=]
function Apogee:AddTheme(name: string, palette: { [string]: any })
	Theme:Add(name, palette)
end

--[=[
	Sets the active locale and optionally replaces or adds its translation dictionary.
	Text elements created later and reactive text updates use the active locale.

	@param locale string -- The locale code
	@param translations { [string]: string }? -- Optional translation dictionary
]=]
function Apogee:SetLocale(locale: string, translations: {[string]: string}?)
	Localization:SetLocale(locale, translations)
end

--[=[
	Adds or replaces a locale dictionary without changing the active locale.
	Untranslated strings remain visible as supplied by the caller.

	@param locale string -- The locale code
	@param translations { [string]: string } -- The translation dictionary
]=]
function Apogee:SetTranslations(locale: string, translations: {[string]: string})
	Localization:SetTranslations(locale, translations)
end

--[=[
	Looks up a string in the active locale and returns the input unchanged when no
	translation exists.

	@param text string -- The text to translate
	@return string -- The translated text, or the original text when no translation exists.
]=]
function Apogee:Translate(text: string): string
	return Localization:Translate(text)
end

--[=[
	Creates a timed toast in the current window, or globally when no window is active.

	@param config Notification.Config | string -- Toast settings or a title
	@param ... any -- Content and optional settings in shorthand form.
	@return [Notification](internals/components/Notification.md) -- The newly displayed notification.
]=]
function Apogee:Notify(config: any, ...: any): any
	config = Args.Config({"Title", "Content"}, nil, config, ...)
	return Notification.New(config, rawget(config, "_window") or self.Current)
end

--[=[
	Creates a floating widget host. It is attached to the current window when one exists.

	@param config Popup.Config | string -- Popup settings or a title
	@param ... any -- Size and optional settings in shorthand form.
	@return [Popup](internals/components/Popup.md) -- The newly displayed popup.
]=]
function Apogee:Popup(config: any, ...: any): any
	config = Args.Config({"Title", "Size"}, nil, config, ...)
	assert(config.Title, "Popup - Missing Title")
	local parent = self.Current
	local popup = Popup.New(config, config.Parent or self.GUI, parent)
	if parent then
		self:Adopt(parent, popup)
	end
	return popup
end

--[=[
	Destroys all live hosts, clears registered widget references, disconnects library-level
	signals, and removes the root GUI. Repeated calls have no further effect.
]=]
function Apogee:Destroy()
	if self.Unloaded then
		return
	end

	self.Unloaded = true
	for _, host in table.clone(Public.Containers) do
		host:Destroy()
	end
	if Notification then
		Notification.DestroyAll()
	end
	table.clear(Config.Widgets)
	Public.Current = nil
	if getgenv and getgenv().Apogee == Public then
		getgenv().Apogee = nil
	end
	Public.Maid:Clean()
	Public.Maid:Task(self.GUI)
	Public.Maid:DeferredClean(0.01)
end

function Public._initialize()
	if Public.GUI then
		return Public
	end

	-- Load the embedded core pack before requiring or constructing any visible UI.
	local AssetManager = require("./assets/manager")
	if getcustomasset then
		assert(AssetManager.Load("core"), "Unable to load the core UI asset pack before initialization")
	end
	Config = require("./services/config")
	Icons = require("./assets/icons")
	Notification = require("./components/notification")
	Theme = require("./services/theme")
	Creator = require("./services/creator")
	Localization = require("./services/localization")
	Popup = require("./components/popup")
	Window = require("./components/window")

	Public.Version = "1.1.0"
	Public.Widgets = Config.Widgets
	Public.Current = nil
	Public.Windows = Window.GetAll()
	Public.GUI = nil
	Public.Unloaded = false
	Public.Theme = Theme.Current
	-- also follows theme changes made through `Apogee.ThemeService` directly
	Theme:Track(function(name)
		Public.Theme = name
	end)
	Public.Themes = Theme.Names
	Public.Config = Config
	Public.Creator = Creator
	Public.ThemeService = Theme
	Public.Localization = Localization

	local parent: Instance = CoreGui
	if gethui then
		parent = gethui()
	elseif RunService:IsStudio() then
		parent = Players.LocalPlayer.PlayerGui
	end

	Public.internals = {
		aria = {
			Path = require("@aria/path"),
			Deque = require("@aria/deque"),
			Event = require("@aria/event"),
			Interface = require("@aria/interface"),
			Maid = require("@aria/maid"),
			Serde = require("@aria/serde"),
			Vec = require("@aria/vec"),
		},
		assets = {
			manager = require("./assets/manager"),
			icons = Icons,
			images = require("./assets/images"),
			themes = require("./assets/themes"),
		},
		components = {
			action = require("./components/action"),
			backdrop = require("./components/backdrop"),
			container = require("./components/container"),
			dialog = require("./components/dialog"),
			element = require("./components/element"),
			maximizer = require("./components/window/maximizer"),
			notification = Notification,
			palette = require("./components/palette"),
			popup = Popup,
			section = require("./components/section"),
			settings = require("./components/window/settings"),
			frame = require("./components/frame"),
			layout = require("./components/layout"),
			tab = require("./components/tab"),
			textbox = require("./components/textbox"),
			titlebar = require("./components/window/titlebar"),
			window = Window,
			windowinput = require("./components/window/input"),
			windowtransitions = require("./components/window/transitions"),
		},
		primitives = {
			button = require("./primitives/button"),
			colorpicker = require("./primitives/colorpicker"),
			dropdown = require("./primitives/dropdown"),
			input = require("./primitives/input"),
			keybind = require("./primitives/keybind"),
			paragraph = require("./primitives/paragraph"),
			slider = require("./primitives/slider"),
			toggle = require("./primitives/toggle"),
			widget = require("./primitives/widget"),
		},
		services = {
			class = require("./services/class"),
			config = Config,
			creator = Creator,
			drag = require("./services/drag"),
			fade = require("./services/fade"),
			localization = Localization,
			args = require("./services/args"),
			measure = require("./services/measure"),
			motion = require("./services/motion"),
			pointer = require("./services/pointer"),
			resize = require("./services/resize"),
			theme = Theme,
		},
	}

	Public.GUI = Creator:New("ScreenGui", {Parent = parent})
	Notification.Init(Public.GUI)
	if getgenv then
		getgenv().Apogee = Public
	end
	return Public
end

return Apogee
