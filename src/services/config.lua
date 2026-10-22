--[=[
	Saves and loads named widgets as [Serde](https://github.com/the-unnamed-goose/aria) encoded configs.

	Every widget created with a `Name` is saved unless it was created with `Persist = false`; each widget class decides
	what state it stores.

	@class Config
	@location internals/services
]=]
local Cache = require("@aria/cache")
local Serde = require("@aria/serde")

local Config = {
	Path = "Apogee",
	Widgets = {}
}

--[=[
	Changes where configs are stored and creates the folder.

	@param folder string -- The folder configs are stored in
]=]
function Config:SetFolder(folder: string)
	self.Path = folder
	Cache.Assure(self.Path)
end

local AUTOLOAD = "autoload"
--@inline
local function path(self, name: string): string
	return self.Path .. "/" .. name .. ".bin"
end

-- Config names become file names, so a separator or parent segment would escape the folder.
local function invalidName(name: string?): boolean
	return type(name) ~= "string"
		or string.find(name, "[/\\]") ~= nil
		or string.find(name, "%.%.") ~= nil
		or name == "."
		or name == ".."
end

-- reads the file every time: the aria Cache memory copy would still return a config that was deleted
local function read(self, name: string): string?
	local file = path(self, name)
	local exists, isFile = pcall(isfile, file)
	if not exists or not isFile then
		return nil
	end
	local ok, data = pcall(readfile, file)
	return if ok then data else nil
end

--[=[
	Saves every persisted widget to a config.

	@param name string? -- The config name
	@return boolean, string? -- Whether it succeeded and the reason when it did not
]=]
function Config:Save(name: string?): (boolean, string?)
	if type(name) ~= "string" or string.gsub(name, "%s", "") == "" then
		return false, "no config name was given"
	elseif name == AUTOLOAD then
		return false, "the autoload name is reserved"
	elseif invalidName(name) then
		return false, "the config name contains an invalid path"
	end

	local values = {}
	for idx, widget in self.Widgets do
		if rawget(widget, "_persist") then
			-- a failing widget is left out, so it cannot stop the rest of the config from saving
			local ok, value = pcall(widget._save, widget)
			if ok then
				values[idx] = value
			end
		end
	end

	local success, encoded = pcall(Serde.Serialize, values)
	if not success then
		return false, "failed to encode data"
	end

	local saved, err = pcall(Cache.To, Cache, encoded, name .. ".bin", self.Path)
	if not saved then
		return false, tostring(err)
	end
	return true
end

--[=[
	Loads a config into the persisted widgets.

	@param name string? -- The config name
	@return boolean, string? -- Whether it succeeded and the reason when it did not
]=]
function Config:Load(name: string?): (boolean, string?)
	if type(name) ~= "string" then
		return false, "no config is selected"
	elseif invalidName(name) then
		return false, "the config name contains an invalid path"
	end
	local encoded = read(self, name)
	if not encoded then
		return false, "the config does not exist"
	end

	local success, values = pcall(Serde.Deserialize, encoded)
	if not success or type(values) ~= "table" then
		return false, "the config is corrupted"
	end

	for idx, data in values do
		local widget = self.Widgets[idx]
		if widget and rawget(widget, "_persist") then
			-- spawned so a failing widget cannot stop the rest of the config from loading
			task.spawn(widget._load, widget, data)
		end
	end
	return true
end

--[=[
	Deletes a config.

	@param name string? -- The config name
	@return boolean, string? -- Whether it succeeded and the reason when it did not
]=]
function Config:Delete(name: string?): (boolean, string?)
	if not name or invalidName(name) then
		return false, "the config does not exist"
	end
	local exists, isFile = pcall(isfile, path(self, name))
	if not exists or not isFile then
		return false, "the config does not exist"
	end

	local removed = pcall(delfile, path(self, name))
	if not removed then
		return false, "the config could not be deleted"
	end
	return true
end

--[=[
	Lists the saved config names, without the autoload copy.

	@return { string } -- The names of saved configurations, excluding the autoload copy.
]=]
function Config:List(): { string }
	local names = {}
	local hasFolder, isFolder = pcall(isfolder, self.Path)
	if not hasFolder or not isFolder then
		return names
	end

	local listed, files = pcall(listfiles, self.Path)
	if not listed or type(files) ~= "table" then
		return names
	end
	for _, file in files do
		local name = string.match(file, "([^/\\]+)%.bin$")
		if name and name ~= AUTOLOAD then
			table.insert(names, name)
		end
	end
	table.sort(names)
	return names
end

--[=[
	Copies a saved config to the autoload file, or removes the autoload file when `name` is nil.

	@param name string? -- The config name
	@return boolean, string? -- Whether it succeeded and the reason when it did not
]=]
function Config:SetAutoload(name: string?): (boolean, string?)
	if not name then
		if self:HasAutoload() then
			local removed = pcall(delfile, path(self, AUTOLOAD))
			if not removed then
				return false, "the autoload config could not be removed"
			end
		end
		return true
	end
	if invalidName(name) then
		return false, "the config name contains an invalid path"
	end
	local encoded = read(self, name)
	if not encoded then
		return false, "the config does not exist"
	end
	local saved, err = pcall(Cache.To, Cache, encoded, AUTOLOAD .. ".bin", self.Path)
	if not saved then
		return false, tostring(err)
	end
	return true
end

--[=[
	Returns whether an autoload config is set.

	@return boolean -- Whether an autoload configuration is set.
]=]
function Config:HasAutoload(): boolean
	local ok, exists = pcall(isfile, path(self, AUTOLOAD))
	return ok and exists
end

--[=[
	Loads `autoload.bin` if it exists.
	@return boolean -- Whether the config loaded
	@return string? -- The reason loading failed
]=]
function Config:Autoload(): (boolean, string?)
	if not self:HasAutoload() then
		return false
	end
	return self:Load(AUTOLOAD)
end

return Config
