--[=[
	Resolves the local Lucide, Craft, Geist, SF Symbols, and Gravity packs and user-registered packs to Roblox image
	assets. Numeric IDs are prefixed only when requested, keeping the bundled icon maps compact.

	@class Icons
	@location internals/assets
]=]
local Icons = {
	DefaultType = "lucide",
	Packs = {
		lucide = require("./lucide"),
		craft = require("./craft"),
		geist = require("./geist"),
		sfsymbols = require("./sfsymbols"),
		gravity = require("./gravity")
	},
}

local function split(name: string, kind: string?): (string, string)
	local prefix, icon = string.match(name, "^([^:]+):(.+)$")
	return prefix or kind or Icons.DefaultType, icon or name
end

--[=[
	Resolves an icon name, optionally in `pack:name` form, or passes through an asset id (any text with `://`).
	@param name string -- Icon name or image asset id
	@param kind string? -- Icon pack to use when `name` has no pack prefix
	@return string? -- The resolved image asset identifier, or nil when the name is unknown or absent.
]=]
function Icons.GetIcon(name: string?, kind: string?): string?
	if name == nil or name == "" then
		return nil
	end
	if string.find(name, "://", 1, true) then
		return name
	end
	local pack, icon = split(name, kind)
	local icons = Icons.Packs[pack]
	local asset = if icons then icons[icon] else nil
	return if type(asset) == "number" then "rbxassetid://" .. tostring(asset) else asset
end

--[=[
	Adds or replaces entries in an icon pack. Numeric IDs are prefixed with `rbxassetid://` when resolved; URL strings
	pass through unchanged.
	@param pack string -- Pack name
	@param values { [string]: (string | number) } -- Icon names and asset ids
]=]
function Icons.AddPack(pack: string, values: { [string]: any })
	assert(type(pack) == "string" and type(values) == "table", "Icons.AddPack expects a pack name and an icon table")
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
end

return Icons
