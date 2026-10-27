--[=[
	Resolves the named core UI images from the embedded Zstandard pack and local extracted PNG cache.
	@class Images
	@location internals/assets
]=]
local Manager = require("./manager")
local Images = {}
for _, name in {"Shadow", "Checker", "Cursor", "SaturationMap", "ScrollBottom", "ScrollMiddle", "ScrollTop", "Squircle", "SquircleOutline", "SquircleTop", "SquircleBottom"} do
	Images[name] = Manager.Resolve("core", name) or ""
end
return Images
