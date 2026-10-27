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

function Icons.GetIcon(name: string?, kind: string?, callback: ((string?) -> ())?): string?
	if name == nil or name == "" then
		return nil
	end
	if string.find(name, "://", 1, true) then
		local id = string.match(name, "rbxassetid://(%d+)") or string.match(name, "[?&]id=(%d+)")
		if id then
			return Manager.ResolveById(id, callback)
		end
		return nil
	end

	local pack, icon = split(name, kind)
	local custom = Icons.Packs[pack]
	if custom and custom[icon] ~= nil then
		local value = custom[icon]
		if type(value) == "string" then
			return value
		end
		if type(value) == "number" then
			return Manager.ResolveById(value, callback)
		end
	end

	local image = Manager.Resolve(pack, icon, callback)
	if image ~= nil or pack ~= Icons.DefaultType then
		return image
	end
	return Manager.Resolve(Icons.FallbackType, icon, callback)
end

function Icons.AddPack(pack: string, values: { [string]: any })
	assert(type(pack) == "string" and type(values) == "table", "Icons.AddPack expects a pack name and icon table")
	local target = Icons.Packs[pack]
	if not target then
		target = {}
		Icons.Packs[pack] = target
	end
	for name, value in values do
		if type(value) == "number" or type(value) == "string" then
			target[name] = value
		else
			warn("Icons.AddPack: unsupported value for '" .. tostring(name) .. "'")
		end
	end
	Manager.Register(pack, target)
end

return Icons
