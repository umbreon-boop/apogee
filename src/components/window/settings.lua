--[=[
	The built-in settings tab. Create it explicitly with `Window:Settings`; its interface controls
	are registered in `Apogee.Widgets` and saved in configs.

	@class Settings
	@location internals/components
]=]
local State = require("../../public")
local Config = require("../../services/config")
local Theme = require("../../services/theme")

local Settings = {}
--@inline
local function notify(message: string, window: any?)
	State:Notify({Title = "Interface", Content = "Config loader", SubContent = message, Duration = 7, _window = window})
end

function Settings.New(window: any, config: { Title: string?, Icon: string? }?): any
	if window._settingsTab then
		return window._settingsTab
	end
	local tab = window:Tab({Title = config and config.Title or "Settings", Icon = config and config.Icon or "settings"})
	window._settingsTab = tab
	tab._settings = {
		Interface = Settings.Interface(tab),
		Configs = Settings.Configs(tab)
	}
	return tab
end

--[=[
	Adds theme and minimize keybind settings.

	@param tab Tab -- The tab to add the section to
	@return [Section](Section.md) -- The section containing interface settings.
]=]
function Settings.Interface(tab: any): any
	local section = tab:Section({Title = "Interface"})
	local window = tab._window

	local themeName = State.Theme
	local minimizeKey = "LeftControl"
	section:Dropdown({
		Name = "Theme",
		Title = "Theme",
		Description = "Changes the interface theme.",
		Values = Theme.Names,
		Value = themeName,
		Callback = function(value)
			State:SetTheme(value)
		end
	})

	section:Slider({
		Name = "Transparency",
		Title = "Window transparency",
		Description = "Adjusts the window background transparency.",
		Value = math.round((window.Transparency or 0) * 100),
		Min = 0,
		Max = 100,
		Rounding = 0,
		Callback = function(value)
			window:SetTransparency(value / 100)
		end
	})

	section:Keybind({
		Name = "MinimizeBind",
		Title = "Minimize Bind",
		Value = minimizeKey,
		Pressed = function()
			-- Several windows can have a Settings tab; only the active window owns the key.
			if not window._destroyed and State.Current == window then
				window:Minimize()
			end
		end
	})

	return section
end

--[=[
	Adds controls for creating, loading, overwriting, deleting and autoloading configs.

	@param tab Tab -- The tab to add the section to
	@return [Section](Section.md) -- The section containing configuration controls.
]=]
function Settings.Configs(tab: any): any
	local window = tab._window
	local section = tab:Section({Title = "Configuration"})
	local name = section:Input({Title = "Config name"})
	local list = section:Dropdown({Title = "Config list", Values = Config:List(), AllowNull = true})
	local autoload
	--@inline
	local function refresh()
		list:SetValues(Config:List())
		list:SetValue(nil)
	end
	--@inline
	local function describeAutoload()
		local status = "none"
		if Config:HasAutoload() then status = "set" end
		autoload:SetDesc("Autoload config: " .. status)
	end
	--@inline
	local function run(verb: string, past: string, target: string?, result: boolean, err: string?): boolean
		if result then
			notify(string.format("%s config %q", past, target), window)
		else
			notify(string.format("Failed to %s config: %s", verb, err), window)
		end
		return result
	end

	section:Button({
		Title = "Create config",
		Callback = function()
			if run("create", "Created", name.Value, Config:Save(name.Value)) then
				refresh()
			end
		end
	})

	section:Button({
		Title = "Load config",
		Callback = function()
			local _ = run("load", "Loaded", list.Value, Config:Load(list.Value))
		end
	})

	section:Button({
		Title = "Overwrite config",
		Callback = function()
			if list.Value then
				local _ = run("overwrite", "Overwrote", list.Value, Config:Save(list.Value))
			else
				local _ = run("overwrite", "Overwrote", nil, false, "no config is selected")
			end
		end
	})

	section:Button({
		Title = "Delete config",
		Callback = function()
			if run("delete", "Deleted", list.Value, Config:Delete(list.Value)) then
				refresh()
				describeAutoload()
			end
		end
	})

	section:Button({
		Title = "Refresh list",
		Callback = function()
			refresh()
		end
	})

	autoload = section:Button({
		Title = "Set as autoload",
		Callback = function()
			if not list.Value then
				return run("autoload", "Autoloaded", nil, false, "no config is selected")
			end
			local success, err = Config:SetAutoload(list.Value)
			if not success then
				return run("autoload", "Autoloaded", list.Value, false, err)
			end
			describeAutoload()
			notify(string.format("Set %q to auto load", list.Value), window)
		end
	})
	describeAutoload()

	return section
end

return Settings
