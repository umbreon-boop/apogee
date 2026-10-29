--[=[
	Resolves icon names through the pack archives and optional user-registered packs.

	@class Icons
	@location internals/assets
]=]
local Manager = require("./manager")

local Icons = {DefaultType = "core", FallbackType = "lucide", Packs = {}}

--@inline
local function split(name, kind)
	local prefix, icon = string.match(name, "^([^:]+):(.+)$")
	return prefix or kind or Icons.DefaultType, icon or name
end

--[=[
	Resolves an icon name, optionally in `pack:name` form, to a local packed image.
	@param name string? -- Icon name; nil returns no asset
	@param kind string? -- Icon pack to use when `name` has no pack prefix
	@param callback ((string?) -> ())? -- Receives the image after a remote pack loads
	@return string? -- The resolved image, or nil when the name is unknown or still loading.
]=]
function Icons.GetIcon(name: string?, kind: string?, callback: ((string?) -> ())?): string?
	if name == nil or name == "" then
		return nil
	end

	local pack, icon = split(name, kind)
	local custom = Icons.Packs[pack]
	if custom and type(custom[icon]) == "string" then
		return custom[icon]
	end

	local image = Manager.Resolve(pack, icon, callback)
	if image ~= nil or pack ~= Icons.DefaultType then
		return image
	end
	return Manager.Resolve(Icons.FallbackType, icon, callback)
end

--[=[
	Adds or replaces entries in an icon pack. Values are explicit image identifiers supplied by the pack.
	@param pack string -- Pack name
	@param values { [string]: string } -- Icon names and image identifiers
]=]
function Icons.AddPack(pack: string, values: { [string]: any })
	assert(type(pack) == "string" and type(values) == "table", "Icons.AddPack expects a pack name and icon table")
	local target = Icons.Packs[pack]
	if not target then
		target = {}
		Icons.Packs[pack] = target
	end
	for name, value in values do
		if type(value) == "string" then
			target[name] = value
		else
			warn("Icons.AddPack: unsupported value for '" .. tostring(name) .. "'")
		end
	end
	Manager.Register(pack)
end

return Icons
